"""뉴스투데이 데이터 수집기.

1. 언론사 RSS를 모아 날짜(KST)별 원본 목록(data/raw/YYYY-MM-DD.json)에 쌓습니다.
2. 같은 사건을 다룬 기사끼리 묶고, 보도한 언론사 수가 많은 순으로 국내/해외 1~10위를 정합니다.
3. 각 이슈마다 기사 본문을 읽어 핵심 문장 3개로 요약하고, 본문이 가장 긴(가장 자세한) 기사를 고릅니다.
4. 결과를 data/daily/YYYY-MM-DD.json, 날짜 목록을 data/index.json에 저장합니다.

실행: python collector/collect.py
"""

from __future__ import annotations

import html
import json
import math
import re
import sys
import time
import urllib.parse
import urllib.request
import urllib.robotparser
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path

import feedparser
import trafilatura

sys.path.insert(0, str(Path(__file__).resolve().parent))
from feeds import DOMESTIC_SOURCES, FEEDS  # noqa: E402

KST = timezone(timedelta(hours=9))
ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data"
RAW = DATA / "raw"
DAILY = DATA / "daily"

USER_AGENT = "NewsTodayBot/1.0 (+https://github.com)"
TOP_N = 10
CLUSTER_THRESHOLD = 0.32
RAW_KEEP_DAYS = 3
FETCH_PER_TOPIC = 5

# 순위에서 뺄 기사 (사진, 인사, 부고, 운세 등)
SKIP_TITLE = re.compile(
    r"\[(포토|사진|화보|인사|부고|게시판|오늘의\s*운세|운세|날씨|부음|알림|모집|공고|광고|카드뉴스|그래픽)\]"
    r"|^(포토|사진|인사|부고)\s|오늘의 운세|\b인사\b.*\(종합\)?$"
)
TITLE_TAGS = re.compile(r"\[[^\]]{1,12}\]|\((종합|속보|단독|1보|2보|종합\d*보|상보|영상|사진|포토)[^)]{0,6}\)|<[^>]+>")


# ---------------------------------------------------------------- 유틸

def now_kst() -> datetime:
    return datetime.now(KST)


def clean_html(s: str) -> str:
    s = re.sub(r"<[^>]+>", " ", s or "")
    s = html.unescape(html.unescape(s))
    return re.sub(r"\s+", " ", s).strip()


def clean_title(t: str) -> str:
    t = TITLE_TAGS.sub(" ", t)
    return re.sub(r"\s+", " ", t).strip(" -|")


def load_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def save_json(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


def normalize_link(link: str) -> str:
    p = urllib.parse.urlsplit(link.strip())
    q = [(k, v) for k, v in urllib.parse.parse_qsl(p.query) if not k.startswith("utm_")]
    return urllib.parse.urlunsplit((p.scheme, p.netloc.lower(), p.path, urllib.parse.urlencode(q), ""))


# ---------------------------------------------------------------- 1. 수집

def fetch_feed(feed):
    source, url, intl = feed
    try:
        parsed = feedparser.parse(url, agent=USER_AGENT, request_headers={"Accept": "*/*"})
    except Exception as e:  # noqa: BLE001
        print(f"  ! {source} {url}: {e}")
        return []
    items = []
    fetched = now_kst()
    for e in parsed.entries:
        title = clean_html(e.get("title", ""))
        link = e.get("link", "")
        if not title or not link:
            continue
        tm = e.get("published_parsed") or e.get("updated_parsed")
        if tm:
            published = datetime(*tm[:6], tzinfo=timezone.utc).astimezone(KST)
            if published > fetched + timedelta(hours=1):
                published = fetched
        else:
            published = fetched
        image = None
        for m in e.get("media_content", []) + e.get("media_thumbnail", []):
            if m.get("url"):
                image = m["url"]
                break
        items.append({
            "title": title,
            "link": normalize_link(link),
            "desc": clean_html(e.get("summary", ""))[:400],
            "source": source,
            "intl": intl,
            "published": published.isoformat(timespec="seconds"),
            "image": image,
        })
    print(f"  {source:<6} {'국제' if intl else '전체'} {len(items):>4}건")
    return items


def collect() -> set[str]:
    """RSS를 받아 날짜별 원본 파일에 합칩니다. 바뀐 날짜 목록을 돌려줍니다."""
    print("[1] RSS 수집")
    with ThreadPoolExecutor(max_workers=8) as ex:
        results = list(ex.map(fetch_feed, FEEDS))

    today = now_kst().date()
    keep_from = today - timedelta(days=1)
    by_date: dict[str, list[dict]] = defaultdict(list)
    for items in results:
        for it in items:
            d = datetime.fromisoformat(it["published"]).date()
            if keep_from <= d <= today:
                by_date[d.isoformat()].append(it)

    changed = set()
    for d, items in by_date.items():
        path = RAW / f"{d}.json"
        existing = {it["link"]: it for it in load_json(path, [])}
        before = len(existing)
        for it in items:
            old = existing.get(it["link"])
            if old is None:
                existing[it["link"]] = it
            else:
                old["intl"] = old["intl"] or it["intl"]
                if not old.get("image") and it.get("image"):
                    old["image"] = it["image"]
        save_json(path, list(existing.values()))
        print(f"  {d}: {before} -> {len(existing)}건")
        changed.add(d)
    return changed


# ---------------------------------------------------------------- 2. 묶기 / 순위

WORD = re.compile(r"[가-힣]+|[A-Za-z][A-Za-z0-9]+|\d+[A-Za-z가-힣]*")
STOP = {"기자", "연합", "뉴스", "종합", "속보", "단독", "오늘", "사진", "영상", "the", "and", "for"}


def tokens(text: str) -> list[str]:
    out = []
    for w in WORD.findall(text):
        if re.match(r"[가-힣]", w):
            if len(w) == 1:
                continue
            if w in STOP:
                continue
            out.extend(w[i:i + 2] for i in range(len(w) - 1))
            if len(w) >= 3:
                out.append(w)
        else:
            w = w.lower()
            if w not in STOP and not w.isdigit():
                out.append(w)
    return out


def vectorize(items: list[dict]) -> list[dict[str, float]]:
    docs = []
    for it in items:
        tf = Counter()
        for t in tokens(clean_title(it["title"])):
            tf[t] += 2.0
        for t in tokens(it["desc"][:120]):
            tf[t] += 0.5
        docs.append(tf)
    df = Counter()
    for tf in docs:
        df.update(tf.keys())
    n = len(docs)
    vecs = []
    for tf in docs:
        v = {t: w * math.log((n + 1) / (df[t] + 0.5)) for t, w in tf.items() if df[t] < n * 0.2}
        norm = math.sqrt(sum(x * x for x in v.values())) or 1.0
        vecs.append({t: x / norm for t, x in v.items()})
    return vecs


def cluster(items: list[dict]) -> list[list[int]]:
    vecs = vectorize(items)
    order = sorted(range(len(items)), key=lambda i: items[i]["published"])
    centroids: list[dict[str, float]] = []
    cnorms: list[float] = []
    members: list[list[int]] = []
    index: dict[str, set[int]] = defaultdict(set)

    for i in order:
        v = vecs[i]
        if not v:
            continue
        scores: dict[int, float] = defaultdict(float)
        for t, x in v.items():
            for c in index.get(t, ()):
                scores[c] += x * centroids[c].get(t, 0.0)
        best, best_s = -1, 0.0
        for c, s in scores.items():
            s /= cnorms[c]
            if s > best_s:
                best, best_s = c, s
        if best >= 0 and best_s >= CLUSTER_THRESHOLD:
            c = best
        else:
            c = len(centroids)
            centroids.append({})
            cnorms.append(1.0)
            members.append([])
        cen = centroids[c]
        for t, x in v.items():
            cen[t] = cen.get(t, 0.0) + x
            index[t].add(c)
        cnorms[c] = math.sqrt(sum(x * x for x in cen.values())) or 1.0
        members[c].append(i)
    return members, vecs, centroids, cnorms


def rank_topics(items: list[dict]):
    items = [it for it in items if not SKIP_TITLE.search(it["title"])]
    domestic = [it for it in items if not it["intl"] and it["source"] in DOMESTIC_SOURCES]
    international = [it for it in items if it["intl"]]
    return rank_region(domestic), rank_region(international)


def rank_region(items: list[dict]) -> list[dict]:
    """같은 사건끼리 묶은 뒤 (보도 언론사 수, 기사 수) 순으로 상위 TOP_N을 고릅니다."""
    if not items:
        return []
    members, vecs, centroids, cnorms = cluster(items)
    topics = []
    for c, idx in enumerate(members):
        outlets = {items[i]["source"] for i in idx}
        # 한 곳만 한 번 보도한 기사는 제외 (여러 곳이 다뤘거나, 한 곳이라도 후속 보도가 있어야 함)
        if len(outlets) < 2 and len(idx) < 2:
            continue

        # 대표 기사: 묶음 중심과 가장 비슷한 기사
        def sim(i):
            return sum(x * centroids[c].get(t, 0.0) for t, x in vecs[i].items()) / cnorms[c]
        rep = max(idx, key=sim)
        topic = {
            "outlets": len(outlets),
            "count": len(idx),
            "headline": clean_title(items[rep]["title"]),
            "image": next((items[i]["image"] for i in sorted(idx, key=sim, reverse=True) if items[i].get("image")), None),
            "articles": [items[i] for i in sorted(idx, key=sim, reverse=True)],
            "keywords": [t for t, _ in sorted(centroids[c].items(), key=lambda kv: -kv[1]) if len(t) >= 2][:5],
        }
        topics.append(topic)

    topics.sort(key=lambda t: (t["outlets"], t["count"]), reverse=True)
    return topics[:TOP_N]


# ---------------------------------------------------------------- 3. 본문 / 요약

_robots: dict[str, urllib.robotparser.RobotFileParser | None] = {}


def allowed(url: str) -> bool:
    p = urllib.parse.urlsplit(url)
    base = f"{p.scheme}://{p.netloc}"
    if base not in _robots:
        rp = urllib.robotparser.RobotFileParser()
        try:
            req = urllib.request.Request(base + "/robots.txt", headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=10) as r:
                rp.parse(r.read().decode("utf-8", "ignore").splitlines())
            _robots[base] = rp
        except Exception:  # noqa: BLE001  robots.txt가 없으면 허용으로 봅니다
            _robots[base] = None
    rp = _robots[base]
    return rp is None or rp.can_fetch(USER_AGENT, url)


def fetch_body(url: str) -> str:
    if not allowed(url):
        return ""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=15) as r:
            raw = r.read(3_000_000)
            charset = r.headers.get_content_charset()
        html = raw.decode(charset or "utf-8", "ignore")
        if not charset and "euc-kr" in html[:2000].lower():
            html = raw.decode("euc-kr", "ignore")
        text = trafilatura.extract(html, include_comments=False, include_tables=False, favor_precision=True)
        return text or ""
    except Exception:  # noqa: BLE001
        return ""


BYLINE = re.compile(r"^\s*[\(\[][^)\]]{0,30}=[^)\]]{0,20}[\)\]]\s*([가-힣 ·]{2,40}(기자|특파원)\s*=)?\s*")
JUNK = re.compile(r"무단|전재|재배포|저작권|copyright|ⓒ|©|@|기자\s*$|구독|제보|카카오톡|▶|☞|사진=|\[사진", re.I)


def sentences(text: str) -> list[str]:
    out = []
    for para in text.split("\n"):
        para = BYLINE.sub("", para.strip())
        for s in re.split(r"(?<=[.!?。])\s+|(?<=다\.)", para):
            s = s.strip()
            if (25 <= len(s) <= 220 and not JUNK.search(s) and re.search(r"[가-힣]", s)
                    and re.search(r"[.!?다요\"”’']$", s) and not s.startswith("[")):
                out.append(s)
    return out


def summarize(topic: dict) -> None:
    arts = []
    seen_src = set()
    for a in topic["articles"]:
        if a["source"] in seen_src:
            continue
        seen_src.add(a["source"])
        arts.append(a)
        if len(arts) >= FETCH_PER_TOPIC:
            break
    with ThreadPoolExecutor(max_workers=FETCH_PER_TOPIC) as ex:
        bodies = list(ex.map(lambda a: fetch_body(a["link"]), arts))

    # 가장 자세한 기사 = 본문이 가장 긴 기사 (못 읽으면 요약문 길이)
    best_i = max(range(len(arts)), key=lambda i: (len(bodies[i]), len(arts[i]["desc"])))
    best = arts[best_i]
    topic["best"] = {
        "title": clean_title(best["title"]),
        "link": best["link"],
        "source": best["source"],
        "length": len(bodies[best_i]),
    }

    # 여러 기사에 공통으로 나오는 단어가 많은 문장을 골라 요약
    cands = []  # (문장, 기사번호, 문장위치)
    for ai, body in enumerate(bodies):
        sents = sentences(body) if body else sentences(arts[ai]["desc"])
        for pos, s in enumerate(sents[:25]):
            cands.append((s, ai, pos))
    if not cands:
        for ai, a in enumerate(topic["articles"][:5]):
            for pos, s in enumerate(sentences(a["desc"])):
                cands.append((s, ai, pos))

    doc_freq = Counter()
    for ai in {c[1] for c in cands}:
        toks = set()
        for s, a2, _ in cands:
            if a2 == ai:
                toks.update(tokens(s))
        doc_freq.update(toks)
    headline_toks = set(tokens(topic["headline"]))

    def score(c):
        s, _, pos = c
        toks = set(tokens(s))
        if not toks:
            return 0.0
        base = sum(doc_freq[t] for t in toks) + 2.0 * len(toks & headline_toks)
        return base / math.sqrt(len(toks)) * (1.0 / (1 + 0.08 * pos))

    # 중요도는 높고 이미 고른 문장과는 덜 겹치는 문장을 차례로 고릅니다 (MMR)
    scored = [(c[0], score(c), set(tokens(c[0]))) for c in cands]
    top_score = max((x[1] for x in scored), default=1.0) or 1.0

    def overlap(a: set, b: set) -> float:
        return len(a & b) / (min(len(a), len(b)) or 1)

    picked: list[tuple[str, set]] = []
    pool = sorted(scored, key=lambda x: x[1], reverse=True)[:40]
    while pool and len(picked) < 3:
        def mmr(x):
            red = max((overlap(x[2], p[1]) for p in picked), default=0.0)
            return x[1] / top_score - 0.9 * red
        s, _, toks = max(pool, key=mmr)
        pool = [x for x in pool if x[0] != s]
        if picked and max(overlap(toks, p[1]) for p in picked) > 0.75:
            continue
        picked.append((s, toks))
    topic["summary"] = [p[0] for p in picked]


def finalize(topic: dict, rank: int) -> dict:
    links = []
    seen = set()
    for a in topic["articles"]:
        if a["source"] in seen:
            continue
        seen.add(a["source"])
        links.append({"title": clean_title(a["title"]), "link": a["link"], "source": a["source"]})
    return {
        "rank": rank,
        "headline": topic["headline"],
        "outlets": topic["outlets"],
        "count": topic["count"],
        "keywords": topic["keywords"],
        "image": topic.get("image"),
        "summary": topic.get("summary", []),
        "best": topic.get("best"),
        "articles": links[:8],
    }


# ---------------------------------------------------------------- 4. 저장

def build_day(date: str) -> None:
    items = load_json(RAW / f"{date}.json", [])
    print(f"[2] {date} 순위 계산 ({len(items)}건)")
    domestic, international = rank_topics(items)
    for region, lst in (("국내", domestic), ("해외", international)):
        print(f"  {region}")
        for i, t in enumerate(lst, 1):
            summarize(t)
            print(f"   {i:>2}. ({t['outlets']}곳/{t['count']}건) {t['headline']}")
    save_json(DAILY / f"{date}.json", {
        "date": date,
        "updated": now_kst().isoformat(timespec="minutes"),
        "articleTotal": len(items),
        "domestic": [finalize(t, i) for i, t in enumerate(domestic, 1)],
        "international": [finalize(t, i) for i, t in enumerate(international, 1)],
    })


def write_index() -> None:
    dates = sorted((p.stem for p in DAILY.glob("*.json")), reverse=True)
    save_json(DATA / "index.json", {
        "updated": now_kst().isoformat(timespec="minutes"),
        "today": now_kst().date().isoformat(),
        "dates": dates,
    })


def prune_raw() -> None:
    cutoff = now_kst().date() - timedelta(days=RAW_KEEP_DAYS)
    for p in RAW.glob("*.json"):
        try:
            if datetime.fromisoformat(p.stem).date() < cutoff:
                p.unlink()
        except ValueError:
            pass


def main() -> None:
    t0 = time.time()
    changed = collect()
    now = now_kst()
    # 어제 순위는 새벽 6시까지만 갱신하고 그 뒤로는 확정합니다.
    targets = {now.date().isoformat()}
    yesterday = (now.date() - timedelta(days=1)).isoformat()
    if now.hour < 6 or not (DAILY / f"{yesterday}.json").exists():
        targets.add(yesterday)
    for d in sorted(targets & changed | (targets - {yesterday})):
        build_day(d)
    write_index()
    prune_raw()
    print(f"완료 ({time.time() - t0:.0f}초)")


if __name__ == "__main__":
    main()

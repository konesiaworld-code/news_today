"""수집할 언론사 RSS 목록.

- 국내뉴스 순위: DOMESTIC_SOURCES 언론사의 국내 기사만 사용합니다.
- 해외뉴스 순위: intl=True(국제 섹션) 피드에 나온 기사를 언론사 구분 없이 사용합니다.
  같은 기사가 전체 피드와 국제 피드에 모두 나오면 국제 기사로 봅니다.

MBC는 기사 단위 RSS가 없고 robots.txt가 자동 접근을 막고 있어 제외했습니다.
"""

DOMESTIC_SOURCES = {"연합뉴스", "JTBC", "SBS"}

_JTBC = "https://news-ex.jtbc.co.kr/v1/get/rss"
_SBS = "https://news.sbs.co.kr/news/SectionRssFeed.do?plink=RSSREADER&sectionId="

FEEDS = [
    # (언론사, 피드 URL, 국제 섹션 여부)

    # ---- 국내뉴스 (연합뉴스 · JTBC · SBS)
    ("연합뉴스", "https://www.yna.co.kr/rss/news.xml", False),
    ("연합뉴스", "https://www.yna.co.kr/rss/politics.xml", False),
    ("연합뉴스", "https://www.yna.co.kr/rss/economy.xml", False),
    ("연합뉴스", "https://www.yna.co.kr/rss/society.xml", False),
    ("JTBC", f"{_JTBC}/section/politics", False),
    ("JTBC", f"{_JTBC}/section/economy", False),
    ("JTBC", f"{_JTBC}/section/society", False),
    ("JTBC", f"{_JTBC}/section/culture", False),
    ("JTBC", f"{_JTBC}/section/entertainment", False),
    ("JTBC", f"{_JTBC}/section/sports", False),
    ("SBS", "https://news.sbs.co.kr/news/newsflashRssFeed.do?plink=RSSREADER", False),
    ("SBS", f"{_SBS}01", False),
    ("SBS", f"{_SBS}02", False),
    ("SBS", f"{_SBS}03", False),

    # ---- 해외뉴스 (국내 언론사 국제면)
    ("연합뉴스", "https://www.yna.co.kr/rss/international.xml", True),
    ("JTBC", f"{_JTBC}/section/international", True),
    ("SBS", f"{_SBS}08", True),
    ("한겨레", "https://www.hani.co.kr/rss/international/", True),
    ("동아일보", "https://rss.donga.com/international.xml", True),
    ("조선일보", "https://www.chosun.com/arc/outboundfeeds/rss/category/international/?outputType=xml", True),
    ("매일경제", "https://www.mk.co.kr/rss/30300018/", True),
    ("한국경제", "https://www.hankyung.com/feed/international", True),
    ("국민일보", "https://www.kmib.co.kr/rss/data/kmibIntRss.xml", True),
    ("노컷뉴스", "https://rss.nocutnews.co.kr/category/world.xml", True),
    ("뉴시스", "https://newsis.com/RSS/international.xml", True),
    ("오마이뉴스", "http://rss.ohmynews.com/rss/international.xml", True),
    ("서울신문", "https://www.seoul.co.kr/xml/rss/rss_international.xml", True),
    ("세계일보", "https://www.segye.com/Articles/RSSList/segye_international.xml", True),
]

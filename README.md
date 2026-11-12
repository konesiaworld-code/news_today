# 뉴스투데이

날짜별로 그날 가장 많이 보도된 뉴스 TOP 10을 보여주고, 요약과 가장 자세한 기사 링크를 알려주는 Android 앱 (Flutter).

## 화면 흐름

1. **첫 화면**: 국내뉴스 / 해외뉴스 선택
2. **날짜 선택**: `2026년 11월 9일` 형태의 날짜 목록
3. **TOP 10**: 그날 가장 많은 언론사가 보도한 이슈 1~10위 헤드라인
4. **상세**: 핵심 요약 3문장 + 본문이 가장 긴(가장 자세한) 기사 링크 + 다른 언론사 보도

## 동작 방식

```
[GitHub Actions, 매시간]                     [앱]
collector/collect.py                        lib/
 ├ 언론사 RSS 28개 수집 (collector/feeds.py)    └ data/index.json, data/daily/날짜.json 을
 ├ 국내 피드의 다른 나라 소식은 해외뉴스로 분류 (collector/region.py)
 ├ 같은 사건끼리 묶기 → 보도 언론사 수로 순위       GitHub에서 읽어와 화면에 표시
 ├ 기사 본문 읽어 핵심 문장 요약 (robots.txt 준수)
 └ data/ 에 JSON 저장 후 커밋
```

- 순위는 실제 클릭 수가 아니라 **보도한 언론사 수 → 기사 수** 기준입니다.
- 국내뉴스: 연합뉴스 · JTBC · SBS 의 국내 기사 중 **한국 관련 기사만**
  (국내 피드에 섞여 온 다른 나라 소식은 해외뉴스로 보냅니다. 판단 기준은 `collector/region.py`)
  (MBC는 기사 단위 RSS가 없고 robots.txt가 자동 접근을 막아 제외)
- 해외뉴스: 국내 언론사 14곳의 국제면 기사 (한국어라 번역 불필요)
  (로이터는 자동 수집 금지, BBC는 요약 제작 금지라 사용하지 않음)
- 수집을 시작한 날부터의 날짜만 선택할 수 있습니다.
- 요약은 AI가 아니라 여러 기사에 공통으로 나오는 핵심 문장을 골라서 만듭니다.

## 설정 순서

### 1) 수집기 올리기 (GitHub)
1. GitHub에서 **공개(Public)** 저장소 `news_today` 를 만들고 이 폴더 전체를 올립니다.
2. 저장소 **Settings → Actions → General → Workflow permissions** 를 *Read and write* 로 바꿉니다.
3. **Actions** 탭 → `뉴스 수집` → *Run workflow* 로 한 번 실행합니다. 이후로는 매시간 자동 실행됩니다.
4. `lib/config.dart` 의 `YOUR_GITHUB_ID` 를 본인 GitHub 아이디로 바꿉니다.

> 저장소에 60일 동안 사람이 만든 커밋이 없으면 GitHub가 예약 실행을 멈출 수 있습니다. 그럴 땐 Actions 탭에서 다시 켜면 됩니다.

### 2) 앱 실행
1. Flutter SDK와 Android Studio 설치 → `flutter doctor` 로 확인
2. 이 폴더에서:
   ```
   flutter create . --project-name news_today --org com.newstoday --platforms android
   flutter pub get
   flutter test
   flutter run
   ```

### 앱 아이콘
- `android/app/src/main/res/mipmap-*` 에 아이콘이 들어 있습니다 (기본 · 원형 · 적응형).
  `flutter create .` 는 이미 있는 파일을 덮어쓰지 않으므로 그대로 유지됩니다.
- 원본/스토어용: `assets/icon/app_icon_1024.png`, `assets/icon/playstore_512.png`

### 수집기만 로컬에서 돌려보기
```
python -m venv .venv
.venv\Scripts\pip install -r collector\requirements.txt
.venv\Scripts\python collector\collect.py
```

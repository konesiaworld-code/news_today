import 'package:flutter_test/flutter_test.dart';
import 'package:news_today/main.dart';
import 'package:news_today/models/news.dart';
import 'package:news_today/utils/format.dart';

void main() {
  test('날짜를 한국어로 표시한다', () {
    expect(koreanDate('2026-10-08'), '2026년 10월 8일');
    expect(koreanWeekday('2026-10-08'), '목요일');
    expect(hourMinute('2026-11-09T23:46+09:00'), '23:46');
  });

  test('순위 데이터를 읽는다', () {
    final r = DailyRanking.fromJson({
      'date': '2026-11-09',
      'updated': '2026-11-09T23:46+09:00',
      'domestic': [
        {
          'rank': 1,
          'headline': '헤드라인',
          'outlets': 8,
          'count': 9,
          'keywords': ['특검'],
          'image': null,
          'summary': ['문장1', '문장2'],
          'best': {'title': '기사', 'link': 'https://example.com/a', 'source': '연합뉴스'},
          'articles': [
            {'title': '기사', 'link': 'https://example.com/a', 'source': '연합뉴스'}
          ],
        }
      ],
      'international': [],
    });
    expect(r.of(Region.domestic).single.best!.source, '연합뉴스');
    expect(r.of(Region.international), isEmpty);
  });

  testWidgets('첫 화면에 국내뉴스와 해외뉴스가 보인다', (tester) async {
    await tester.pumpWidget(const NewsTodayApp());
    expect(find.text('국내뉴스'), findsOneWidget);
    expect(find.text('해외뉴스'), findsOneWidget);
  });
}

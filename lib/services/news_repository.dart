import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/news.dart';

/// 데이터를 GitHub(수집기 결과)에서 받아옵니다.
/// 주소가 아직 설정되지 않았거나 받아오지 못하면 앱에 들어 있는 데이터(assets/data)를 보여줍니다.
class NewsRepository {
  NewsRepository._();
  static final NewsRepository instance = NewsRepository._();

  final _client = http.Client();
  final Map<String, DailyRanking> _daily = {};

  bool get _remoteConfigured => !dataBaseUrl.contains('YOUR_GITHUB_ID');

  Future<Map<String, dynamic>> _get(String path) async {
    if (_remoteConfigured) {
      try {
        // GitHub raw는 약 5분 캐시되므로 분 단위 값을 붙여 새로 받습니다.
        final uri = Uri.parse('$dataBaseUrl/$path').replace(
            queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch ~/ 60000}'});
        final res = await _client.get(uri).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) {
          return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        }
      } catch (_) {
        // 아래에서 앱 내장 데이터로 대체
      }
    }
    final text = await rootBundle.loadString('assets/data/$path');
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<DateIndex> fetchIndex() async => DateIndex.fromJson(await _get('index.json'));

  /// 지난 날짜는 바뀌지 않으므로 메모리에 보관합니다. 오늘 날짜는 [refresh]로 다시 받습니다.
  Future<DailyRanking> fetchDaily(String date, {bool refresh = false}) async {
    if (!refresh && _daily.containsKey(date)) return _daily[date]!;
    final ranking = DailyRanking.fromJson(await _get('daily/$date.json'));
    _daily[date] = ranking;
    return ranking;
  }
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// '2026-10-08' → '2026년 10월 8일'
String koreanDate(String iso) {
  final d = DateTime.parse(iso);
  return '${d.year}년 ${d.month}월 ${d.day}일';
}

/// '2026-10-08' → '목요일'
String koreanWeekday(String iso) => '${_weekdays[DateTime.parse(iso).weekday - 1]}요일';

/// 휴대폰 기준 오늘 날짜 'YYYY-MM-DD'
String todayIso() {
  final n = DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
}

/// '2026-11-09T23:46+09:00' → '23:46'
String hourMinute(String isoDateTime) {
  final m = RegExp(r'T(\d{2}:\d{2})').firstMatch(isoDateTime);
  return m?.group(1) ?? '';
}

import 'package:flutter/material.dart';

import '../models/news.dart';
import '../services/news_repository.dart';
import '../utils/format.dart';
import '../widgets/states.dart';
import 'ranking_screen.dart';

/// 2번 화면: 날짜 선택
class DateListScreen extends StatefulWidget {
  const DateListScreen({super.key, required this.region});

  final Region region;

  @override
  State<DateListScreen> createState() => _DateListScreenState();
}

class _DateListScreenState extends State<DateListScreen> {
  late Future<DateIndex> _future = NewsRepository.instance.fetchIndex();

  Future<void> _reload() async {
    final next = NewsRepository.instance.fetchIndex();
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.region.label} · 날짜 선택')),
      body: FutureBuilder<DateIndex>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return MessageView(
              icon: Icons.wifi_off_rounded,
              text: '날짜 목록을 불러오지 못했어요.\n인터넷 연결을 확인해주세요.',
              onRetry: _reload,
            );
          }
          final index = snap.data!;
          if (index.dates.isEmpty) {
            return MessageView(
              icon: Icons.event_busy_rounded,
              text: '아직 모인 뉴스가 없어요.',
              onRetry: _reload,
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: index.dates.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (context, i) {
                final date = index.dates[i];
                final isToday = date == todayIso();
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  title: Text(
                    koreanDate(date),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(isToday ? '${koreanWeekday(date)} · 오늘 (집계 중)' : koreanWeekday(date)),
                  trailing: Icon(Icons.chevron_right_rounded, color: scheme.outline),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RankingScreen(
                      region: widget.region,
                      date: date,
                      isToday: isToday,
                    ),
                  )),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

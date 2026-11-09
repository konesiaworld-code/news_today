import 'package:flutter/material.dart';

import '../models/news.dart';
import '../services/news_repository.dart';
import '../utils/format.dart';
import '../widgets/states.dart';
import 'topic_screen.dart';

/// 3번 화면: 그날의 TOP 10 헤드라인
class RankingScreen extends StatefulWidget {
  const RankingScreen({
    super.key,
    required this.region,
    required this.date,
    this.isToday = false,
  });

  final Region region;
  final String date;
  final bool isToday;

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  late Future<DailyRanking> _future =
      NewsRepository.instance.fetchDaily(widget.date, refresh: widget.isToday);

  Future<void> _reload() async {
    final next = NewsRepository.instance.fetchDaily(widget.date, refresh: true);
    setState(() => _future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(koreanDate(widget.date)),
            Text(
              '${widget.region.label} TOP 10',
              style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),
      ),
      body: FutureBuilder<DailyRanking>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) {
            return MessageView(
              icon: Icons.wifi_off_rounded,
              text: '순위를 불러오지 못했어요.',
              onRetry: _reload,
            );
          }
          final ranking = snap.data!;
          final topics = ranking.of(widget.region);
          if (topics.isEmpty) {
            return MessageView(
              icon: Icons.hourglass_empty_rounded,
              text: '이 날짜에는 집계된 뉴스가 부족해요.',
              onRetry: _reload,
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    widget.isToday
                        ? '언론사 보도량 기준 · ${hourMinute(ranking.updated)} 기준 집계'
                        : '언론사 보도량 기준',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ),
                for (final t in topics)
                  _RankTile(
                    topic: t,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => TopicScreen(topic: t, region: widget.region, date: widget.date),
                    )),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({required this.topic, required this.onTap});

  final Topic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top3 = topic.rank <= 3;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                '${topic.rank}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: top3 ? scheme.primary : scheme.outline,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.headline,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: top3 ? FontWeight.w700 : FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '언론사 ${topic.outlets}곳 · 기사 ${topic.count}건',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.outline),
          ],
        ),
      ),
    );
  }
}

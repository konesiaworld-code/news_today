import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/news.dart';
import '../utils/format.dart';

/// 4번 화면: 요약 + 가장 자세한 기사 링크
class TopicScreen extends StatelessWidget {
  const TopicScreen({
    super.key,
    required this.topic,
    required this.region,
    required this.date,
  });

  final Topic topic;
  final Region region;
  final String date;

  Future<void> _open(BuildContext context, String link) async {
    final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.inAppBrowserView);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기사를 열 수 없어요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final best = topic.best;
    final others = topic.articles.where((a) => a.link != best?.link).toList();

    return Scaffold(
      appBar: AppBar(title: Text('${koreanDate(date)} ${region.label} ${topic.rank}위')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            topic.headline,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.3),
          ),
          const SizedBox(height: 8),
          Text(
            '언론사 ${topic.outlets}곳에서 ${topic.count}건 보도',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
          if (topic.image != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  topic.image!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: scheme.surfaceContainerHighest),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('핵심 요약', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          if (topic.summary.isEmpty)
            Text('요약을 만들지 못했어요. 아래 기사 원문을 확인해주세요.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant))
          else
            for (final (i, s) in topic.summary.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(top: 1, right: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                      child: Text('${i + 1}',
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: Text(s, style: theme.textTheme.bodyLarge?.copyWith(height: 1.6)),
                    ),
                  ],
                ),
              ),
          Text(
            '요약은 여러 언론사 기사에서 핵심 문장을 자동으로 골라 만들었어요.',
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
          ),
          if (best != null) ...[
            const SizedBox(height: 28),
            Text('가장 자세한 기사',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              color: scheme.secondaryContainer,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _open(context, best.link),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(best.source,
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSecondaryContainer, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(best.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onSecondaryContainer, height: 1.35)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text('기사 원문 보기',
                              style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.primary, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Icon(Icons.open_in_new_rounded, size: 16, color: scheme.primary),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (others.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('다른 언론사 보도',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final a in others)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(a.source),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => _open(context, a.link),
              ),
          ],
        ],
      ),
    );
  }
}

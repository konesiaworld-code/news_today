import 'package:flutter/material.dart';

import '../models/news.dart';
import 'date_list_screen.dart';

/// 1번 화면: 국내뉴스 / 해외뉴스 선택
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '뉴스투데이',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '그날 가장 많이 보도된 뉴스 TOP 10',
                style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: _RegionCard(
                  region: Region.domestic,
                  icon: Icons.location_city_rounded,
                  caption: '연합뉴스 · JTBC · SBS',
                  color: scheme.primaryContainer,
                  onColor: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _RegionCard(
                  region: Region.international,
                  icon: Icons.public_rounded,
                  caption: '국내 언론사 14곳의 국제면',
                  color: scheme.tertiaryContainer,
                  onColor: scheme.onTertiaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  const _RegionCard({
    required this.region,
    required this.icon,
    required this.caption,
    required this.color,
    required this.onColor,
  });

  final Region region;
  final IconData icon;
  final String caption;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DateListScreen(region: region)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 44, color: onColor),
              const Spacer(),
              Text(
                region.label,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: onColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      caption,
                      style: theme.textTheme.bodyMedium?.copyWith(color: onColor.withValues(alpha: 0.8)),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, color: onColor),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

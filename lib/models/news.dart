enum Region {
  domestic('국내뉴스', 'domestic'),
  international('해외뉴스', 'international');

  const Region(this.label, this.key);
  final String label;
  final String key;
}

class ArticleLink {
  final String title;
  final String link;
  final String source;

  const ArticleLink({required this.title, required this.link, required this.source});

  factory ArticleLink.fromJson(Map<String, dynamic> j) => ArticleLink(
        title: j['title'] as String? ?? '',
        link: j['link'] as String? ?? '',
        source: j['source'] as String? ?? '',
      );
}

class Topic {
  final int rank;
  final String headline;
  final int outlets;
  final int count;
  final List<String> keywords;
  final String? image;
  final List<String> summary;
  final ArticleLink? best;
  final List<ArticleLink> articles;

  const Topic({
    required this.rank,
    required this.headline,
    required this.outlets,
    required this.count,
    required this.keywords,
    required this.image,
    required this.summary,
    required this.best,
    required this.articles,
  });

  factory Topic.fromJson(Map<String, dynamic> j) => Topic(
        rank: j['rank'] as int,
        headline: j['headline'] as String,
        outlets: j['outlets'] as int? ?? 0,
        count: j['count'] as int? ?? 0,
        keywords: [for (final k in (j['keywords'] as List? ?? const [])) k as String],
        image: j['image'] as String?,
        summary: [for (final s in (j['summary'] as List? ?? const [])) s as String],
        best: j['best'] == null
            ? null
            : ArticleLink.fromJson(j['best'] as Map<String, dynamic>),
        articles: [
          for (final a in (j['articles'] as List? ?? const []))
            ArticleLink.fromJson(a as Map<String, dynamic>)
        ],
      );
}

class DailyRanking {
  final String date;
  final String updated;
  final List<Topic> domestic;
  final List<Topic> international;

  const DailyRanking({
    required this.date,
    required this.updated,
    required this.domestic,
    required this.international,
  });

  List<Topic> of(Region r) => r == Region.domestic ? domestic : international;

  factory DailyRanking.fromJson(Map<String, dynamic> j) {
    List<Topic> list(String k) => [
          for (final t in (j[k] as List? ?? const []))
            Topic.fromJson(t as Map<String, dynamic>)
        ];
    return DailyRanking(
      date: j['date'] as String,
      updated: j['updated'] as String? ?? '',
      domestic: list('domestic'),
      international: list('international'),
    );
  }
}

class DateIndex {
  final String today;
  final List<String> dates;

  const DateIndex({required this.today, required this.dates});

  factory DateIndex.fromJson(Map<String, dynamic> j) => DateIndex(
        today: j['today'] as String? ?? '',
        dates: [for (final d in (j['dates'] as List? ?? const [])) d as String],
      );
}

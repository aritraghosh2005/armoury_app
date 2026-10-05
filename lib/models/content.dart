class ContentMeta {
  final String siteName;
  final String tagline;
  final String footer;
  final String version;

  ContentMeta({
    required this.siteName,
    required this.tagline,
    required this.footer,
    required this.version,
  });

  factory ContentMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ContentMeta(
        siteName: 'ORCUS · ARMOURY',
        tagline: 'CENTRAL HARDWARE REPOSITORY',
        footer: 'ORCUS DYNAMICS',
        version: 'v2.0',
      );
    }
    return ContentMeta(
      siteName: json['siteName']?.toString() ?? 'ORCUS · ARMOURY',
      tagline: json['tagline']?.toString() ?? '',
      footer: json['footer']?.toString() ?? '',
      version: json['version']?.toString() ?? 'v2.0',
    );
  }
}

class ContentData {
  final ContentMeta meta;
  final Map<String, dynamic> nav;
  final Map<String, dynamic> landing;

  ContentData({
    required this.meta,
    required this.nav,
    required this.landing,
  });

  factory ContentData.fromJson(Map<String, dynamic> json) {
    return ContentData(
      meta: ContentMeta.fromJson(json['meta'] as Map<String, dynamic>?),
      nav: (json['nav'] as Map<String, dynamic>?) ?? {},
      landing: (json['landing'] as Map<String, dynamic>?) ?? {},
    );
  }
}

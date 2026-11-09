// A book's English Wikipedia page, from the API's /wikipedia-book route.
// Only fetched for display, never stored.
class WikiBook {
  final String title; // the page title, e.g. "Dune (novel)"
  final String url;
  final String? summary; // the page intro as plain text
  final String? publishedYear; // first publication, not this edition
  final int? pageCount;
  final List<String> genres;
  final String? series;
  final String? country;
  final String? language;

  const WikiBook({
    required this.title,
    required this.url,
    this.summary,
    this.publishedYear,
    this.pageCount,
    this.genres = const [],
    this.series,
    this.country,
    this.language,
  });

  factory WikiBook.fromApi(Map<String, dynamic> json) {
    return WikiBook(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      summary: json['summary'] as String?,
      publishedYear: json['publishedYear'] as String?,
      pageCount: (json['pageCount'] as num?)?.toInt(),
      genres: (json['genres'] as List?)?.whereType<String>().toList() ??
          const [],
      series: json['series'] as String?,
      country: json['country'] as String?,
      language: json['language'] as String?,
    );
  }

  bool get hasFacts =>
      publishedYear != null ||
      pageCount != null ||
      series != null ||
      country != null ||
      language != null ||
      genres.isNotEmpty;
}

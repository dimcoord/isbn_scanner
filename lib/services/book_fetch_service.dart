import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/book.dart';

class BookFetchResult {
  final Book? book;
  final String? error;
  final String source; // 'Indonesia OneSearch (Perpusnas)', 'Open Library', 'Google Books', or 'Manual'

  const BookFetchResult({this.book, this.error, this.source = ''});

  bool get isSuccess => book != null;
}

class BookFetchService {
  final http.Client _client;

  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  BookFetchService({http.Client? client}) : _client = client ?? http.Client();

  /// Cleans an ISBN string by stripping whitespace and dashes.
  static String cleanIsbn(String rawIsbn) {
    return rawIsbn.toUpperCase().replaceAll(RegExp(r'[^0-9X]'), '');
  }

  /// Checks if an ISBN is likely an Indonesian publication.
  /// Indonesian ISBN publisher prefixes: 978-602, 978-623, 978-979, 602, 623, 979
  static bool isLikelyIndonesianIsbn(String isbn) {
    final clean = cleanIsbn(isbn);
    return clean.startsWith('978602') ||
        clean.startsWith('978623') ||
        clean.startsWith('978979') ||
        clean.startsWith('602') ||
        clean.startsWith('623') ||
        clean.startsWith('979');
  }

  /// Unescapes HTML entities commonly found in catalog pages and OpenURL strings
  static String unescapeHtml(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
          final code = int.tryParse(match.group(1)!, radix: 16);
          return code != null ? String.fromCharCode(code) : match.group(0)!;
        })
        .replaceAllMapped(RegExp(r'&#([0-9]+);'), (match) {
          final code = int.tryParse(match.group(1)!);
          return code != null ? String.fromCharCode(code) : match.group(0)!;
        });
  }

  /// Formats author name into readable human-friendly form
  /// E.g. "MANAMPIRING, Henry" -> "Henry Manampiring"
  static String formatAuthorName(String raw) {
    var name = raw.trim();
    if (name.contains(',')) {
      final parts = name.split(',');
      if (parts.length == 2) {
        name = '${parts[1].trim()} ${parts[0].trim()}';
      }
    }
    // Convert any ALL-CAPS words (e.g. MANAMPIRING or JAMES) to Title Case
    name = name
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          if (word == word.toUpperCase() && word.length > 1) {
            return word[0].toUpperCase() + word.substring(1).toLowerCase();
          }
          return word;
        })
        .join(' ');
    return name.trim();
  }

  /// Attempts to fetch book details with multi-source fallback.
  /// For Indonesian books, queries Indonesia OneSearch (Perpusnas) first.
  Future<BookFetchResult> fetchBookByIsbn(
    String rawIsbn, {
    String? googleApiKey,
  }) async {
    final isbn = cleanIsbn(rawIsbn);
    if (isbn.isEmpty) {
      return const BookFetchResult(error: 'Invalid or empty ISBN code.');
    }

    final isIndo = isLikelyIndonesianIsbn(isbn);

    if (isIndo) {
      // 1. Indonesian Database: Indonesia OneSearch (Perpustakaan Nasional RI)
      try {
        final iosResult = await _fetchFromIndonesiaOneSearch(isbn);
        if (iosResult != null) {
          return BookFetchResult(
            book: iosResult,
            source: 'Indonesia OneSearch (Perpusnas)',
          );
        }
      } catch (_) {}

      // 2. Open Library
      try {
        final openLibResult = await _fetchFromOpenLibrary(isbn);
        if (openLibResult != null) {
          return BookFetchResult(book: openLibResult, source: 'Open Library');
        }
      } catch (_) {}

      // 3. Google Books
      try {
        final googleResult = await _fetchFromGoogleBooks(isbn, apiKey: googleApiKey);
        if (googleResult != null) {
          return BookFetchResult(book: googleResult, source: 'Google Books');
        }
      } catch (_) {}
    } else {
      // International flow
      // 1. Google Books
      try {
        final googleResult = await _fetchFromGoogleBooks(isbn, apiKey: googleApiKey);
        if (googleResult != null) {
          return BookFetchResult(book: googleResult, source: 'Google Books');
        }
      } catch (_) {}

      // 2. Open Library
      try {
        final openLibResult = await _fetchFromOpenLibrary(isbn);
        if (openLibResult != null) {
          return BookFetchResult(book: openLibResult, source: 'Open Library');
        }
      } catch (_) {}

      // 3. Indonesia OneSearch fallback
      try {
        final iosResult = await _fetchFromIndonesiaOneSearch(isbn);
        if (iosResult != null) {
          return BookFetchResult(
            book: iosResult,
            source: 'Indonesia OneSearch (Perpusnas)',
          );
        }
      } catch (_) {}
    }

    return BookFetchResult(
      error: 'Book not found for ISBN $isbn. You can enter details manually.',
      source: 'Not Found',
    );
  }

  /// Fetches from Indonesia OneSearch (onesearch.id) - The comprehensive national catalog
  Future<Book?> _fetchFromIndonesiaOneSearch(String isbn) async {
    // 1. Try search by ISN
    var url = Uri.parse(
      'https://onesearch.id/Search/Results?lookfor=$isbn&type=ISN',
    );
    var response = await _client.get(
      url,
      headers: {'User-Agent': _defaultUserAgent},
    ).timeout(const Duration(seconds: 12));

    var reg = RegExp(r'class="Z3988"\s+title="([^"]+)"');
    var matches = reg.allMatches(response.body).toList();

    // 2. Fallback to AllFields if ISN returned nothing
    if (matches.isEmpty) {
      url = Uri.parse(
        'https://onesearch.id/Search/Results?lookfor=$isbn&type=AllFields',
      );
      response = await _client.get(
        url,
        headers: {'User-Agent': _defaultUserAgent},
      ).timeout(const Duration(seconds: 12));
      matches = reg.allMatches(response.body).toList();
    }

    if (matches.isEmpty) return null;

    String bestTitle = '';
    String bestSubtitle = '';
    String bestAuthor = '';
    String bestPublisher = '';
    String bestDate = '';
    String bestCategory = '';

    for (final m in matches) {
      final rawParam = unescapeHtml(m.group(1)!);
      final query = Uri.splitQueryString(rawParam);

      var title = (query['rft.title'] ?? query['rft.btitle'] ?? '').trim();
      final author = (query['rft.creator'] ?? query['rft.au'] ?? '').trim();
      final pub = (query['rft.pub'] ?? '').trim();
      final date = (query['rft.date'] ?? '').trim();
      final genre = (query['rft.genre'] ?? query['rft.format'] ?? '').trim();

      // Clean author trails from title (e.g. "Bumi / Tere Liye")
      if (title.contains(' / ')) {
        final split = title.split(' / ');
        title = split.first.trim();
      }

      // Check if title has subtitle (e.g. "Filosofi Teras: Filsafat...")
      if (title.length > bestTitle.length) {
        if (title.contains(':')) {
          final parts = title.split(':');
          bestTitle = parts.first.trim();
          bestSubtitle = parts.sublist(1).join(':').trim();
        } else {
          bestTitle = title;
        }
      }

      if (author.isNotEmpty &&
          (bestAuthor.isEmpty || bestAuthor.contains(';') || bestAuthor.contains(','))) {
        bestAuthor = author;
      }
      if (pub.isNotEmpty && bestPublisher.isEmpty) {
        bestPublisher = pub;
      }
      if (date.isNotEmpty && bestDate.isEmpty) {
        bestDate = date;
      }
      if (genre.isNotEmpty && bestCategory.isEmpty) {
        bestCategory = genre.replaceAll('Other:', '').replaceAll('Other', '').trim();
      }
    }

    if (bestTitle.isEmpty) return null;

    // Extract page count from HTML if present (e.g. "344 hlm" or "344hlm")
    int? pageCount;
    final pageMatch = RegExp(
      r'(\d+)\s*(?:hlm|pages|p\.)',
      caseSensitive: false,
    ).firstMatch(response.body);
    if (pageMatch != null) {
      pageCount = int.tryParse(pageMatch.group(1)!);
    }

    final formattedAuthor = formatAuthorName(bestAuthor);
    final authorsList = formattedAuthor.isNotEmpty ? [formattedAuthor] : <String>[];
    final categoriesList = bestCategory.isNotEmpty ? [bestCategory] : <String>[];
    final parsedYear = int.tryParse(RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(bestDate)?.group(1) ?? '');
    final cover = 'https://onesearch.id/Cover/Show?size=medium&isbn=$isbn';

    return Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isbn: isbn,
      isbn13: isbn.length == 13 ? isbn : null,
      isbn10: isbn.length == 10 ? isbn : null,
      title: bestTitle,
      subtitle: bestSubtitle,
      author: formattedAuthor,
      authors: authorsList,
      publisher: bestPublisher,
      publishedDate: bestDate,
      publicationYear: parsedYear,
      categoryId: 8,
      rackLocation: 'Rak-A1',
      stock: 5,
      coverImage: cover,
      description: 'Cataloged in Indonesia OneSearch (Perpustakaan Nasional RI)',
      pageCount: pageCount,
      categories: categoriesList,
      language: 'id',
      thumbnailUrl: cover,
      scannedAt: DateTime.now(),
      syncStatus: 'pending',
    );
  }

  /// Fetches from Open Library API with direct ISBN endpoint and search fallback
  Future<Book?> _fetchFromOpenLibrary(String isbn) async {
    // 1. Try direct ISBN edition JSON
    try {
      final directUri = Uri.parse('https://openlibrary.org/isbn/$isbn.json');
      final directRes = await _client.get(
        directUri,
        headers: {'User-Agent': _defaultUserAgent},
      ).timeout(const Duration(seconds: 10));

      if (directRes.statusCode == 200) {
        final data = json.decode(directRes.body) as Map<String, dynamic>;
        final title = data['title']?.toString() ?? '';
        if (title.isNotEmpty) {
          final pubs = (data['publishers'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          final publisher = pubs.isNotEmpty ? pubs.first : '';
          final publishDate = data['publish_date']?.toString() ?? '';
          final pages = data['number_of_pages'] is int
              ? data['number_of_pages'] as int
              : int.tryParse(data['number_of_pages']?.toString() ?? '');

          String? coverUrl;
          final covers = data['covers'] as List<dynamic>?;
          if (covers != null && covers.isNotEmpty && covers.first is int && covers.first > 0) {
            coverUrl = 'https://covers.openlibrary.org/b/id/${covers.first}-M.jpg';
          }

          final byStatement = data['by_statement']?.toString();
          final authors = byStatement != null && byStatement.isNotEmpty
              ? [byStatement.replaceAll('.', '').trim()]
              : <String>[];
          final parsedYear = int.tryParse(
              RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(publishDate)?.group(1) ?? '');

          return Book(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            isbn: isbn,
            isbn10: isbn.length == 10 ? isbn : null,
            isbn13: isbn.length == 13 ? isbn : null,
            title: title,
            subtitle: data['subtitle']?.toString() ?? '',
            author: authors.isNotEmpty ? authors.first : '',
            authors: authors,
            publisher: publisher,
            publishedDate: publishDate,
            publicationYear: parsedYear,
            categoryId: 8,
            rackLocation: 'Rak-A1',
            stock: 5,
            coverImage: coverUrl,
            pageCount: pages,
            thumbnailUrl: coverUrl,
            scannedAt: DateTime.now(),
            syncStatus: 'pending',
          );
        }
      }
    } catch (_) {}

    // 2. Try Open Library Search API
    try {
      final searchUri = Uri.parse('https://openlibrary.org/search.json?q=$isbn');
      final searchRes = await _client.get(
        searchUri,
        headers: {'User-Agent': _defaultUserAgent},
      ).timeout(const Duration(seconds: 10));

      if (searchRes.statusCode == 200) {
        final data = json.decode(searchRes.body) as Map<String, dynamic>;
        final docs = data['docs'] as List<dynamic>?;
        if (docs != null && docs.isNotEmpty) {
          final first = docs.first as Map<String, dynamic>;
          final title = first['title']?.toString() ?? '';
          if (title.isNotEmpty) {
            final authors = (first['author_name'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                <String>[];
            final pubs = (first['publisher'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                <String>[];
            final publisher = pubs.isNotEmpty ? pubs.first : '';
            final firstPublishYear = first['first_publish_year']?.toString() ?? '';
            final parsedYear = int.tryParse(firstPublishYear);
            final coverI = first['cover_i'];
            final coverUrl = coverI is int && coverI > 0
                ? 'https://covers.openlibrary.org/b/id/$coverI-M.jpg'
                : null;

            return Book(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              isbn: isbn,
              isbn10: isbn.length == 10 ? isbn : null,
              isbn13: isbn.length == 13 ? isbn : null,
              title: title,
              author: authors.isNotEmpty ? authors.first : '',
              authors: authors,
              publisher: publisher,
              publishedDate: firstPublishYear,
              publicationYear: parsedYear,
              categoryId: 8,
              rackLocation: 'Rak-A1',
              stock: 5,
              coverImage: coverUrl,
              thumbnailUrl: coverUrl,
              scannedAt: DateTime.now(),
              syncStatus: 'pending',
            );
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Fetches from Google Books API
  Future<Book?> _fetchFromGoogleBooks(String isbn, {String? apiKey}) async {
    final queryUrl = apiKey != null && apiKey.trim().isNotEmpty
        ? 'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn&key=${apiKey.trim()}'
        : 'https://www.googleapis.com/books/v1/volumes?q=isbn:$isbn';

    final uri = Uri.parse(queryUrl);
    final response = await _client.get(
      uri,
      headers: {'User-Agent': _defaultUserAgent},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final data = json.decode(response.body) as Map<String, dynamic>;
    final totalItems = data['totalItems'] as int? ?? 0;
    final items = data['items'] as List<dynamic>?;

    if (totalItems == 0 || items == null || items.isEmpty) {
      return null;
    }

    final firstItem = items.first as Map<String, dynamic>;
    final volumeInfo = firstItem['volumeInfo'] as Map<String, dynamic>? ?? {};

    String? isbn10;
    String? isbn13;
    final identifiers = volumeInfo['industryIdentifiers'] as List<dynamic>?;
    if (identifiers != null) {
      for (final idObj in identifiers) {
        final type = idObj['type']?.toString();
        final idVal = idObj['identifier']?.toString();
        if (type == 'ISBN_10') isbn10 = idVal;
        if (type == 'ISBN_13') isbn13 = idVal;
      }
    }

    if (isbn.length == 10) isbn10 ??= isbn;
    if (isbn.length == 13) isbn13 ??= isbn;

    final authorsList = (volumeInfo['authors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    final categoriesList = (volumeInfo['categories'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    String? thumb;
    final images = volumeInfo['imageLinks'] as Map<String, dynamic>?;
    if (images != null) {
      thumb = images['thumbnail']?.toString() ??
          images['smallThumbnail']?.toString();
      if (thumb != null && thumb.startsWith('http://')) {
        thumb = thumb.replaceFirst('http://', 'https://');
      }
    }

    final pubDate = volumeInfo['publishedDate']?.toString() ?? '';
    final parsedYear = int.tryParse(
        RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(pubDate)?.group(1) ?? '');

    return Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isbn: isbn,
      isbn10: isbn10,
      isbn13: isbn13,
      title: volumeInfo['title']?.toString() ?? 'Untitled Book',
      subtitle: volumeInfo['subtitle']?.toString() ?? '',
      author: authorsList.isNotEmpty ? authorsList.first : '',
      authors: authorsList,
      publisher: volumeInfo['publisher']?.toString() ?? '',
      publishedDate: pubDate,
      publicationYear: parsedYear,
      categoryId: 8,
      rackLocation: 'Rak-A1',
      stock: 5,
      coverImage: thumb,
      description: volumeInfo['description']?.toString() ?? '',
      pageCount: volumeInfo['pageCount'] is int
          ? volumeInfo['pageCount'] as int
          : int.tryParse(volumeInfo['pageCount']?.toString() ?? ''),
      categories: categoriesList,
      language: volumeInfo['language']?.toString() ?? '',
      thumbnailUrl: thumb,
      scannedAt: DateTime.now(),
      syncStatus: 'pending',
    );
  }
}

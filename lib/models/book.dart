import 'dart:convert';

/// Represents book metadata fetched via ISBN or entered by the user.
class Book {
  final String id;
  final String isbn;
  final String? isbn10;
  final String? isbn13;
  final String title;
  final String subtitle;
  final String author;
  final List<String> authors;
  final String publisher;
  final String publishedDate;
  final int? publicationYear;
  final int categoryId;
  final String rackLocation;
  final int stock;
  final String? coverImage;
  final String description;
  final String sinopsis;
  final int? pageCount;
  final List<String> categories;
  final String language;
  final String? thumbnailUrl;
  final DateTime scannedAt;
  final String syncStatus; // 'pending', 'sent', 'failed'
  final String notes;

  const Book({
    required this.id,
    required this.isbn,
    this.isbn10,
    this.isbn13,
    required this.title,
    this.subtitle = '',
    this.author = '',
    this.authors = const [],
    this.publisher = '',
    this.publishedDate = '',
    this.publicationYear,
    this.categoryId = 8,
    this.rackLocation = 'Rak-A1',
    this.stock = 5,
    this.coverImage,
    this.description = '',
    this.sinopsis = '',
    this.pageCount,
    this.categories = const [],
    this.language = '',
    this.thumbnailUrl,
    required this.scannedAt,
    this.syncStatus = 'pending',
    this.notes = '',
  });

  /// Formatted authors string, e.g. "Robert C. Martin, Martin Fowler"
  String get authorsFormatted {
    if (author.trim().isNotEmpty) return author.trim();
    if (authors.isNotEmpty) return authors.join(', ');
    return 'Unknown Author';
  }

  /// Primary ISBN representation
  String get primaryIsbn =>
      isbn13 ?? (isbn.isNotEmpty ? isbn : (isbn10 ?? 'N/A'));

  /// Resolves the 4-digit publication year from publicationYear or publishedDate
  int get resolvedPublicationYear {
    if (publicationYear != null && publicationYear! > 0) {
      return publicationYear!;
    }
    final match = RegExp(r'\b(19\d\d|20\d\d)\b').firstMatch(publishedDate);
    if (match != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null) return parsed;
    }
    return DateTime.now().year;
  }

  /// Resolved cover image URL
  String get resolvedCoverImage {
    if (coverImage != null && coverImage!.trim().isNotEmpty) {
      return coverImage!.trim();
    }
    if (thumbnailUrl != null && thumbnailUrl!.trim().isNotEmpty) {
      return thumbnailUrl!.trim();
    }
    return '';
  }

  /// Resolved synopsis / description text
  String get resolvedSinopsis {
    if (sinopsis.trim().isNotEmpty) {
      return sinopsis.trim();
    }
    if (description.trim().isNotEmpty) {
      return description.trim();
    }
    return '';
  }

  /// Converts book into the exact JSON format required by the API endpoint:
  /// {
  ///   "isbn": "9786020332956",
  ///   "title": "Bumi Manusia",
  ///   "author": "Pramoedya Ananta Toer",
  ///   "publisher": "Hasta Mitra",
  ///   "publication_year": 2005,
  ///   "category_id": 8,
  ///   "rack_location": "Rak-A1",
  ///   "sinopsis": "...",
  ///   "stock": 5,
  ///   "cover_image": "https://example.com/covers/bumi-manusia.jpg"
  /// }
  Map<String, dynamic> toApiPayload() {
    return {
      'isbn': isbn,
      'title': title,
      'author': author.isNotEmpty ? author : authorsFormatted,
      'publisher': publisher,
      'publication_year': resolvedPublicationYear,
      'category_id': categoryId,
      'rack_location': rackLocation,
      'sinopsis': resolvedSinopsis,
      'stock': stock,
      'cover_image': resolvedCoverImage,
    };
  }

  Book copyWith({
    String? id,
    String? isbn,
    String? isbn10,
    String? isbn13,
    String? title,
    String? subtitle,
    String? author,
    List<String>? authors,
    String? publisher,
    String? publishedDate,
    int? publicationYear,
    int? categoryId,
    String? rackLocation,
    int? stock,
    String? coverImage,
    String? description,
    String? sinopsis,
    int? pageCount,
    List<String>? categories,
    String? language,
    String? thumbnailUrl,
    DateTime? scannedAt,
    String? syncStatus,
    String? notes,
  }) {
    return Book(
      id: id ?? this.id,
      isbn: isbn ?? this.isbn,
      isbn10: isbn10 ?? this.isbn10,
      isbn13: isbn13 ?? this.isbn13,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      author: author ?? this.author,
      authors: authors ?? this.authors,
      publisher: publisher ?? this.publisher,
      publishedDate: publishedDate ?? this.publishedDate,
      publicationYear: publicationYear ?? this.publicationYear,
      categoryId: categoryId ?? this.categoryId,
      rackLocation: rackLocation ?? this.rackLocation,
      stock: stock ?? this.stock,
      coverImage: coverImage ?? this.coverImage,
      description: description ?? this.description,
      sinopsis: sinopsis ?? this.sinopsis,
      pageCount: pageCount ?? this.pageCount,
      categories: categories ?? this.categories,
      language: language ?? this.language,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      scannedAt: scannedAt ?? this.scannedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isbn': isbn,
      'isbn10': isbn10,
      'isbn13': isbn13,
      'title': title,
      'subtitle': subtitle,
      'author': author,
      'authors': authors,
      'publisher': publisher,
      'publishedDate': publishedDate,
      'publicationYear': publicationYear,
      'categoryId': categoryId,
      'rackLocation': rackLocation,
      'stock': stock,
      'coverImage': coverImage,
      'description': description,
      'sinopsis': resolvedSinopsis,
      'pageCount': pageCount,
      'categories': categories,
      'language': language,
      'thumbnailUrl': thumbnailUrl,
      'scannedAt': scannedAt.toIso8601String(),
      'syncStatus': syncStatus,
      'notes': notes,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    final rawAuthors = (map['authors'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];

    final singleAuthor = map['author'] as String? ??
        (rawAuthors.isNotEmpty ? rawAuthors.join(', ') : '');

    return Book(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      isbn: map['isbn'] as String? ?? '',
      isbn10: map['isbn10'] as String?,
      isbn13: map['isbn13'] as String?,
      title: map['title'] as String? ?? 'Untitled Book',
      subtitle: map['subtitle'] as String? ?? '',
      author: singleAuthor,
      authors: rawAuthors.isNotEmpty
          ? rawAuthors
          : (singleAuthor.isNotEmpty ? [singleAuthor] : const []),
      publisher: map['publisher'] as String? ?? '',
      publishedDate: map['publishedDate'] as String? ?? '',
      publicationYear: map['publicationYear'] is int
          ? map['publicationYear'] as int
          : (map['publication_year'] is int
              ? map['publication_year'] as int
              : int.tryParse(map['publicationYear']?.toString() ??
                  map['publication_year']?.toString() ??
                  '')),
      categoryId: map['categoryId'] is int
          ? map['categoryId'] as int
          : (map['category_id'] is int
              ? map['category_id'] as int
              : (int.tryParse(map['categoryId']?.toString() ??
                      map['category_id']?.toString() ??
                      '') ??
                  8)),
      rackLocation: map['rackLocation'] as String? ??
          map['rack_location'] as String? ??
          'Rak-A1',
      stock: map['stock'] is int
          ? map['stock'] as int
          : (int.tryParse(map['stock']?.toString() ?? '') ?? 5),
      coverImage: map['coverImage'] as String? ??
          map['cover_image'] as String? ??
          map['thumbnailUrl'] as String?,
      description: map['description'] as String? ??
          map['sinopsis'] as String? ??
          '',
      sinopsis: map['sinopsis'] as String? ??
          map['description'] as String? ??
          '',
      pageCount: map['pageCount'] is int
          ? map['pageCount'] as int
          : int.tryParse(map['pageCount']?.toString() ?? ''),
      categories: (map['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      language: map['language'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String? ??
          map['cover_image'] as String? ??
          map['coverImage'] as String?,
      scannedAt: map['scannedAt'] != null
          ? DateTime.tryParse(map['scannedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      syncStatus: map['syncStatus'] as String? ?? 'pending',
      notes: map['notes'] as String? ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory Book.fromJson(String source) =>
      Book.fromMap(json.decode(source) as Map<String, dynamic>);
}

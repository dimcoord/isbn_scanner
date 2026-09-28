import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scanner_buku/main.dart';
import 'package:scanner_buku/models/book.dart';
import 'package:scanner_buku/models/api_config.dart';
import 'package:scanner_buku/services/book_fetch_service.dart';
import 'package:scanner_buku/services/api_sender_service.dart';
import 'package:scanner_buku/services/history_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Book Model Tests', () {
    test('Book serializes to and from Map accurately', () {
      final book = Book(
        id: '123',
        isbn: '9780132350884',
        isbn10: '0132350882',
        isbn13: '9780132350884',
        title: 'Clean Code',
        subtitle: 'A Handbook of Agile Software Craftsmanship',
        authors: const ['Robert C. Martin'],
        publisher: 'Prentice Hall',
        publishedDate: '2008-08-01',
        description: 'Even bad code can function.',
        pageCount: 464,
        categories: const ['Computers'],
        language: 'en',
        thumbnailUrl: 'https://example.com/cover.jpg',
        scannedAt: DateTime(2026, 9, 24, 12, 0),
        syncStatus: 'pending',
        notes: 'Shelf A1',
      );

      final map = book.toMap();
      final fromMap = Book.fromMap(map);

      expect(fromMap.id, '123');
      expect(fromMap.title, 'Clean Code');
      expect(fromMap.authors, ['Robert C. Martin']);
      expect(fromMap.authorsFormatted, 'Robert C. Martin');
      expect(fromMap.primaryIsbn, '9780132350884');
      expect(fromMap.pageCount, 464);
      expect(fromMap.notes, 'Shelf A1');
    });

    test('Clean ISBN strips hyphens and whitespace correctly', () {
      expect(BookFetchService.cleanIsbn('978-0-13-235088-4'), '9780132350884');
      expect(BookFetchService.cleanIsbn(' 0 13 235088 2 '), '0132350882');
      expect(BookFetchService.cleanIsbn('0-201-63361-2'), '0201633612');
      expect(BookFetchService.cleanIsbn('0-19-853453-1'), '0198534531');
    });

    test('isLikelyIndonesianIsbn detects Indonesian publisher prefixes', () {
      expect(BookFetchService.isLikelyIndonesianIsbn('978-602-412-518-9'), isTrue);
      expect(BookFetchService.isLikelyIndonesianIsbn('978-623-03-0453-8'), isTrue);
      expect(BookFetchService.isLikelyIndonesianIsbn('978-979-3062-79-2'), isTrue);
      expect(BookFetchService.isLikelyIndonesianIsbn('602-063-317-9'), isTrue);
      expect(BookFetchService.isLikelyIndonesianIsbn('978-0-13-235088-4'), isFalse);
    });

    test('formatAuthorName formats LASTNAME, Firstname and all-caps correctly', () {
      expect(
        BookFetchService.formatAuthorName('MANAMPIRING, Henry'),
        'Henry Manampiring',
      );
      expect(
        BookFetchService.formatAuthorName('CLEAR, JAMES'),
        'James Clear',
      );
      expect(
        BookFetchService.formatAuthorName('Tere Liye'),
        'Tere Liye',
      );
    });

    test('unescapeHtml decodes hex, numeric, and named entities', () {
      expect(
        BookFetchService.unescapeHtml('Filosofi&#x2B;Teras&#x3A;&#x2B;Filsafat'),
        'Filosofi+Teras:+Filsafat',
      );
    });
  });

  group('ApiConfig and ApiSenderService Tests', () {
    test('Resolved headers prepend Bearer when missing', () {
      const config = ApiConfig(
        endpointUrl: 'https://example.com/books',
        authToken: 'secret_token_123',
        customHeaders: {'X-Custom-Key': '12345'},
      );

      final headers = config.getResolvedHeaders();
      expect(headers['Content-Type'], 'application/json');
      expect(headers['Authorization'], 'Bearer secret_token_123');
      expect(headers['X-Custom-Key'], '12345');
    });

    test('buildPayload respects payloadRootKey wrapper', () {
      final sender = ApiSenderService();
      final book = Book(
        id: '1',
        isbn: '9780132350884',
        title: 'Clean Code',
        scannedAt: DateTime.now(),
      );

      // Without root key
      final directPayload = sender.buildPayload(
        book,
        const ApiConfig(payloadRootKey: ''),
      );
      expect(directPayload.containsKey('title'), isTrue);
      expect(directPayload['title'], 'Clean Code');

      // With root key 'book'
      final wrappedPayload = sender.buildPayload(
        book,
        const ApiConfig(payloadRootKey: 'book'),
      );
      expect(wrappedPayload.containsKey('book'), isTrue);
      expect((wrappedPayload['book'] as Map)['title'], 'Clean Code');
    });

    test('toApiPayload generates exact JSON format required by user API', () {
      final book = Book(
        id: '1',
        isbn: '9786020332956',
        title: 'Bumi Manusia',
        author: 'Pramoedya Ananta Toer',
        publisher: 'Hasta Mitra',
        publicationYear: 2005,
        categoryId: 8,
        rackLocation: 'Rak-A1',
        stock: 5,
        coverImage: 'https://example.com/covers/bumi-manusia.jpg',
        scannedAt: DateTime(2026, 9, 27),
      );

      final payload = book.toApiPayload();
      expect(payload, {
        'isbn': '9786020332956',
        'title': 'Bumi Manusia',
        'author': 'Pramoedya Ananta Toer',
        'publisher': 'Hasta Mitra',
        'publication_year': 2005,
        'category_id': 8,
        'rack_location': 'Rak-A1',
        'stock': 5,
        'cover_image': 'https://example.com/covers/bumi-manusia.jpg',
      });
    });

    test('Default ApiConfig has correct endpoint and Authorization Bearer header', () {
      const config = ApiConfig();
      expect(config.endpointUrl, 'http://127.0.0.1:8000/api/v1/books/isbn-scan');
      final headers = config.getResolvedHeaders();
      expect(
        headers['Authorization'],
        'Bearer 2|xMfKgP7fOIHLvA7KpVjXl1Ijrg8bt3M1EaimTjtlccc0d98b',
      );
      expect(headers['Accept'], 'application/json');
      expect(headers['Content-Type'], 'application/json');
    });
  });

  group('Widget Navigation Smoke Test', () {
    testWidgets('BookScannerApp loads with bottom navigation destinations', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const BookScannerApp());
      await tester.pump(const Duration(milliseconds: 100));

      // Verify the 3 bottom navigation labels exist
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('API Config'), findsOneWidget);

      // Tap on History tab
      await tester.tap(find.text('History'));
      await tester.pump(const Duration(milliseconds: 300));

      // Should display Scanned Books History title
      expect(find.text('Scanned Books History'), findsOneWidget);
      expect(find.text('No scanned books yet'), findsOneWidget);

      // Tap on API Config tab
      await tester.tap(find.text('API Config'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));

      // Should display API Endpoint Settings title
      expect(find.text('API Endpoint Settings'), findsOneWidget);
      expect(find.byTooltip('Save Settings'), findsOneWidget);
    });
  });

  group('HistoryService Tests', () {
    test('saveBook, updateSyncStatus, and deleteBook work correctly', () async {
      final history = HistoryService();
      await history.clearAll();

      final book1 = Book(
        id: 'book_1',
        isbn: '9780132350884',
        title: 'Clean Code',
        scannedAt: DateTime.now(),
        syncStatus: 'pending',
      );

      await history.saveBook(book1);
      expect(history.books.length, 1);
      expect(history.books.first.title, 'Clean Code');
      expect(history.books.first.syncStatus, 'pending');

      await history.updateSyncStatus('book_1', 'sent');
      expect(history.books.first.syncStatus, 'sent');

      await history.deleteBook('book_1');
      expect(history.books.isEmpty, isTrue);
    });
  });
}


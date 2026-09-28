import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/book.dart';

class HistoryService extends ChangeNotifier {
  static const String _keyHistory = 'scanned_books_history';

  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  List<Book> _books = [];
  bool _isLoaded = false;

  List<Book> get books => List.unmodifiable(_books);
  bool get isLoaded => _isLoaded;

  Future<void> init() async {
    if (_isLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_keyHistory) ?? [];

    _books = jsonList
        .map((itemStr) {
          try {
            return Book.fromJson(itemStr);
          } catch (_) {
            return null;
          }
        })
        .whereType<Book>()
        .toList();

    // Sort newest first
    _books.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> saveBook(Book book) async {
    await init();
    final index = _books.indexWhere((b) => b.id == book.id);
    if (index >= 0) {
      _books[index] = book;
    } else {
      _books.insert(0, book);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> updateSyncStatus(String bookId, String status) async {
    await init();
    final index = _books.indexWhere((b) => b.id == bookId);
    if (index >= 0) {
      _books[index] = _books[index].copyWith(syncStatus: status);
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteBook(String bookId) async {
    await init();
    _books.removeWhere((b) => b.id == bookId);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await init();
    _books.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = _books.map((b) => b.toJson()).toList();
    await prefs.setStringList(_keyHistory, stringList);
  }
}

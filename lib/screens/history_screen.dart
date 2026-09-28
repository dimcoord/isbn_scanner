import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/history_service.dart';
import 'book_review_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  String _selectedFilter = 'All'; // 'All', 'Sent', 'Pending / Failed'

  @override
  void initState() {
    super.initState();
    _historyService.init();
  }

  List<Book> _filterBooks(List<Book> all) {
    if (_selectedFilter == 'Sent') {
      return all.where((b) => b.syncStatus == 'sent').toList();
    } else if (_selectedFilter == 'Pending / Failed') {
      return all.where((b) => b.syncStatus != 'sent').toList();
    }
    return all;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent':
        return Colors.green;
      case 'failed':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return Icons.check_circle;
      case 'failed':
        return Icons.error;
      case 'pending':
      default:
        return Icons.hourglass_top;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanned Books History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear History',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All History?'),
                  content: const Text(
                    'This will remove all saved books from local history. This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await _historyService.clearAll();
              }
            },
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _historyService,
        builder: (context, _) {
          final allBooks = _historyService.books;
          final books = _filterBooks(allBooks);

          return Column(
            children: [
              // Filter Chips
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('All', allBooks.length),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Sent',
                      allBooks.where((b) => b.syncStatus == 'sent').length,
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      'Pending / Failed',
                      allBooks.where((b) => b.syncStatus != 'sent').length,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // List of Books
              Expanded(
                child: books.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              allBooks.isEmpty
                                  ? 'No scanned books yet'
                                  : 'No books matching "$_selectedFilter"',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              allBooks.isEmpty
                                  ? 'Scan a book barcode to get started'
                                  : 'Try selecting a different filter above',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: books.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final book = books[index];
                          final statusColor = _getStatusColor(book.syncStatus);

                          return Dismissible(
                            key: Key(book.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Colors.red,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              _historyService.deleteBook(book.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Removed "${book.title}"'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  width: 45,
                                  height: 60,
                                  color: Colors.grey.shade200,
                                  child: book.thumbnailUrl != null &&
                                          book.thumbnailUrl!.isNotEmpty
                                      ? Image.network(
                                          book.thumbnailUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              const Icon(Icons.book, color: Colors.grey),
                                        )
                                      : const Icon(Icons.book, color: Colors.grey),
                                ),
                              ),
                              title: Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    book.authorsFormatted,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ISBN: ${book.primaryIsbn}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getStatusIcon(book.syncStatus),
                                        size: 14,
                                        color: statusColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        book.syncStatus.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(book.scannedAt),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => BookReviewScreen(
                                      initialBook: book,
                                      fetchSource: 'History',
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    final isSelected = _selectedFilter == label;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = label);
        }
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

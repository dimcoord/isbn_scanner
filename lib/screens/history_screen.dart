import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/api_config.dart';
import '../models/book.dart';
import '../services/api_sender_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'book_review_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();
  final ApiSenderService _apiSenderService = ApiSenderService();

  String _selectedFilter = 'Semua'; // 'Semua', 'Terkirim', 'Tertunda', 'Gagal'
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isBatchSyncing = false;

  @override
  void initState() {
    super.initState();
    _historyService.init();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Book> _filterAndSearchBooks(List<Book> all) {
    // 1. Filter by Status
    var list = all;
    if (_selectedFilter == 'Terkirim') {
      list = all.where((b) => b.syncStatus == 'sent').toList();
    } else if (_selectedFilter == 'Tertunda') {
      list = all.where((b) => b.syncStatus == 'pending').toList();
    } else if (_selectedFilter == 'Gagal') {
      list = all.where((b) => b.syncStatus == 'failed').toList();
    }

    // 2. Filter by Search Query
    if (_searchQuery.isNotEmpty) {
      list = list.where((b) {
        final title = b.title.toLowerCase();
        final isbn = b.primaryIsbn.toLowerCase();
        final author = b.authorsFormatted.toLowerCase();
        final sinopsis = b.resolvedSinopsis.toLowerCase();
        return title.contains(_searchQuery) ||
            isbn.contains(_searchQuery) ||
            author.contains(_searchQuery) ||
            sinopsis.contains(_searchQuery);
      }).toList();
    }

    return list;
  }

  Future<void> _batchSyncPending() async {
    final unsynced = _historyService.books
        .where((b) => b.syncStatus != 'sent')
        .toList();

    if (unsynced.isEmpty) return;

    final config = await ApiConfig.load();
    if (!config.isConfigured) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Endpoint API belum dikonfigurasi. Atur di tab API Config.'),
          backgroundColor: AppColors.statusPending,
        ),
      );
      return;
    }

    setState(() => _isBatchSyncing = true);
    HapticFeedback.mediumImpact();

    int successCount = 0;
    int failCount = 0;

    for (final book in unsynced) {
      final res = await _apiSenderService.sendBook(book, config);
      if (res.isSuccess) {
        successCount++;
        await _historyService.updateSyncStatus(book.id, 'sent');
      } else {
        failCount++;
        await _historyService.updateSyncStatus(book.id, 'failed');
      }
    }

    if (!mounted) return;
    setState(() => _isBatchSyncing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sinkronisasi selesai: $successCount berhasil, $failCount gagal.',
        ),
        backgroundColor:
            failCount == 0 ? AppColors.statusSent : AppColors.statusPending,
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'sent':
        return AppColors.statusSent;
      case 'failed':
        return AppColors.statusFailed;
      case 'pending':
      default:
        return AppColors.statusPending;
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'sent':
        return AppColors.statusSentBg;
      case 'failed':
        return AppColors.statusFailedBg;
      case 'pending':
      default:
        return AppColors.statusPendingBg;
    }
  }

  Color _getStatusBorderColor(String status) {
    switch (status) {
      case 'sent':
        return AppColors.statusSentBorder;
      case 'failed':
        return AppColors.statusFailedBorder;
      case 'pending':
      default:
        return AppColors.statusPendingBorder;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'sent':
        return Icons.check_circle_rounded;
      case 'failed':
        return Icons.error_rounded;
      case 'pending':
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'sent':
        return 'TERKIRIM';
      case 'failed':
        return 'GAGAL';
      case 'pending':
      default:
        return 'TERTUNDA';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSearchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                cursorColor: AppColors.primary,
                decoration: const InputDecoration(
                  hintText: 'Cari judul, penulis, atau ISBN...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
                  border: InputBorder.none,
                ),
              )
            : const Text('Scanned Books History'),
        actions: [
          IconButton(
            icon: Icon(_isSearchOpen ? Icons.close : Icons.search),
            tooltip: _isSearchOpen ? 'Tutup Pencarian' : 'Cari Buku',
            onPressed: () {
              setState(() {
                if (_isSearchOpen) {
                  _searchController.clear();
                  _searchQuery = '';
                  _isSearchOpen = false;
                } else {
                  _isSearchOpen = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear History',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All History?'),
                  content: const Text(
                    'Seluruh riwayat hasil scan di perangkat ini akan dibersihkan. Tindakan ini tidak dapat dibatalkan.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.statusFailed,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Hapus Semua'),
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
          final books = _filterAndSearchBooks(allBooks);
          final sentCount = allBooks.where((b) => b.syncStatus == 'sent').length;
          final pendingCount = allBooks.where((b) => b.syncStatus == 'pending').length;
          final failedCount = allBooks.where((b) => b.syncStatus == 'failed').length;
          final unsyncedCount = pendingCount + failedCount;

          return Column(
            children: [
              // 1. Top 3 Summary Stats Cards (Matching Mockup Screen 3)
              Container(
                color: AppColors.surface,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: [
                    // Card 1: Total Scanned
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Total Scan',
                        value: '${allBooks.length}',
                        unit: 'Buku',
                        icon: Icons.menu_book_rounded,
                        color: AppColors.primary,
                        bgColor: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Card 2: Sent to Web
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Terkirim',
                        value: '$sentCount',
                        unit: 'Sukses',
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.statusSent,
                        bgColor: AppColors.statusSentBg,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Card 3: Pending / Failed
                    Expanded(
                      child: _buildSummaryCard(
                        title: 'Tertunda',
                        value: '$unsyncedCount',
                        unit: 'Antrean',
                        icon: Icons.hourglass_empty_rounded,
                        color: AppColors.statusPending,
                        bgColor: AppColors.statusPendingBg,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Filter Tabs (Matching Mockup "Today | This week | All | Archive" with underline indicator)
              Container(
                color: AppColors.surface,
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildTabItem('Semua', allBooks.length),
                          _buildTabItem('Terkirim', sentCount),
                          _buildTabItem('Tertunda', pendingCount),
                          _buildTabItem('Gagal', failedCount),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),
                  ],
                ),
              ),

              // 3. Batch Sync Floating Alert Bar (When unsynced books exist)
              if (unsyncedCount > 0)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.statusPendingBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.statusPendingBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        color: AppColors.statusPending,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$unsyncedCount buku belum tersinkronkan ke Web',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        child: FilledButton.icon(
                          onPressed: _isBatchSyncing ? null : _batchSyncPending,
                          icon: _isBatchSyncing
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.sync, size: 14),
                          label: Text(
                            _isBatchSyncing ? 'Mengirim...' : 'Kirim Semua',
                            style: const TextStyle(fontSize: 11),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.statusPending,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 4. List of Scanned Books (Matching Mockup Screen 3 Rows)
              Expanded(
                child: books.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: const BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.menu_book_outlined,
                                size: 48,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              allBooks.isEmpty
                                  ? 'No scanned books yet'
                                  : 'Tidak ada buku yang cocok',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              allBooks.isEmpty
                                  ? 'Pindai barcode buku untuk memulai pendataan'
                                  : 'Coba ubah kata kunci pencarian atau tab filter',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: books.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 2),
                        itemBuilder: (context, index) {
                          final book = books[index];
                          final statusColor = _getStatusColor(book.syncStatus);

                          return Dismissible(
                            key: Key(book.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppColors.statusFailed,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            onDismissed: (_) {
                              _historyService.deleteBook(book.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Menghapus "${book.title}"'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(8),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 44,
                                    height: 62,
                                    color: AppColors.primaryLight,
                                    child: book.thumbnailUrl != null &&
                                            book.thumbnailUrl!.isNotEmpty
                                        ? Image.network(
                                            book.thumbnailUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) => const Icon(
                                              Icons.menu_book,
                                              color: AppColors.primary,
                                              size: 22,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.menu_book,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                  ),
                                ),
                                title: Text(
                                  book.title.isNotEmpty
                                      ? book.title
                                      : 'Judul Belum Diisi',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 3),
                                    Text(
                                      book.authorsFormatted.isNotEmpty
                                          ? book.authorsFormatted
                                          : 'Penulis Tidak Diketahui',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'ISBN: ${book.primaryIsbn}${book.pageCount != null && book.pageCount! > 0 ? ' • ${book.pageCount} hlm' : ''} • ${_formatDate(book.scannedAt)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontFamily: 'monospace',
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (book.resolvedSinopsis.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        book.resolvedSinopsis,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStatusBgColor(book.syncStatus),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _getStatusBorderColor(book.syncStatus),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getStatusIcon(book.syncStatus),
                                            size: 11,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _getStatusLabel(book.syncStatus),
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.textMuted,
                                      size: 18,
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BookReviewScreen(
                                        initialBook: book,
                                        fetchSource: 'Riwayat',
                                      ),
                                    ),
                                  );
                                },
                              ),
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

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int count) {
    final isSelected = _selectedFilter == label;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.primaryDark : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}j lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

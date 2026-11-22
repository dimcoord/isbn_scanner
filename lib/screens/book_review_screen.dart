import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/api_config.dart';
import '../models/book.dart';
import '../services/api_sender_service.dart';
import '../services/history_service.dart';
import '../theme/app_theme.dart';
import 'api_settings_screen.dart';

class BookReviewScreen extends StatefulWidget {
  final Book initialBook;
  final String fetchSource;

  const BookReviewScreen({
    super.key,
    required this.initialBook,
    this.fetchSource = 'Google Books',
  });

  @override
  State<BookReviewScreen> createState() => _BookReviewScreenState();
}

class _BookReviewScreenState extends State<BookReviewScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _isbnController;
  late TextEditingController _titleController;
  late TextEditingController _authorController;
  late TextEditingController _publisherController;
  late TextEditingController _yearController;
  late TextEditingController _pageCountController;
  late TextEditingController _categoryIdController;
  late TextEditingController _rackLocationController;
  late TextEditingController _stockController;
  late TextEditingController _coverImageController;
  late TextEditingController _sinopsisController;
  late TextEditingController _notesController;

  late ApiConfig _apiConfig;
  bool _isLoadingConfig = true;
  bool _isSending = false;

  final ApiSenderService _apiSenderService = ApiSenderService();
  final HistoryService _historyService = HistoryService();

  @override
  void initState() {
    super.initState();
    final book = widget.initialBook;

    _isbnController = TextEditingController(text: book.primaryIsbn);
    _titleController = TextEditingController(text: book.title);
    _authorController = TextEditingController(text: book.author.isNotEmpty ? book.author : book.authorsFormatted);
    _publisherController = TextEditingController(text: book.publisher);
    _yearController = TextEditingController(text: book.resolvedPublicationYear.toString());
    _pageCountController = TextEditingController(
      text: book.pageCount != null && book.pageCount! > 0 ? book.pageCount.toString() : '',
    );
    _categoryIdController = TextEditingController(text: book.categoryId.toString());
    _rackLocationController = TextEditingController(text: book.rackLocation);
    _stockController = TextEditingController(text: book.stock.toString());
    _coverImageController = TextEditingController(text: book.resolvedCoverImage);
    _sinopsisController = TextEditingController(text: book.resolvedSinopsis);
    _notesController = TextEditingController(text: book.notes);

    _loadApiConfig();
  }

  Future<void> _loadApiConfig() async {
    final config = await ApiConfig.load();
    if (mounted) {
      setState(() {
        _apiConfig = config;
        _isLoadingConfig = false;
        // If initial book didn't have custom values, use config defaults
        if (_categoryIdController.text.trim().isEmpty || _categoryIdController.text == '0') {
          _categoryIdController.text = config.defaultCategoryId.toString();
        }
        if (_rackLocationController.text.trim().isEmpty) {
          _rackLocationController.text = config.defaultRackLocation;
        }
        if (_stockController.text.trim().isEmpty || _stockController.text == '0') {
          _stockController.text = config.defaultStock.toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _isbnController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _publisherController.dispose();
    _yearController.dispose();
    _pageCountController.dispose();
    _categoryIdController.dispose();
    _rackLocationController.dispose();
    _stockController.dispose();
    _coverImageController.dispose();
    _sinopsisController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Book _collectEditedBook({String syncStatus = 'pending'}) {
    final authorText = _authorController.text.trim();
    final year = int.tryParse(_yearController.text.trim()) ??
        widget.initialBook.resolvedPublicationYear;
    final catId = int.tryParse(_categoryIdController.text.trim()) ??
        widget.initialBook.categoryId;
    final stock = int.tryParse(_stockController.text.trim()) ??
        widget.initialBook.stock;
    final cover = _coverImageController.text.trim();
    final sinopsisText = _sinopsisController.text.trim();
    final pageCount = int.tryParse(_pageCountController.text.trim());

    return widget.initialBook.copyWith(
      isbn: _isbnController.text.trim(),
      title: _titleController.text.trim(),
      author: authorText,
      authors: authorText.isNotEmpty ? [authorText] : widget.initialBook.authors,
      publisher: _publisherController.text.trim(),
      publishedDate: year.toString(),
      publicationYear: year,
      categoryId: catId,
      rackLocation: _rackLocationController.text.trim(),
      stock: stock,
      coverImage: cover,
      thumbnailUrl: cover,
      description: sinopsisText,
      sinopsis: sinopsisText,
      pageCount: pageCount,
      notes: _notesController.text.trim(),
      syncStatus: syncStatus,
    );
  }

  Future<void> _saveDraftOnly() async {
    final book = _collectEditedBook(syncStatus: 'pending');
    await _historyService.saveBook(book);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Book saved to local history as draft.'),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop(book);
  }

  Future<void> _sendToApi() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_apiConfig.isConfigured) {
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('API Endpoint Not Configured'),
          content: const Text(
            'Target API endpoint URL is invalid or not configured yet. Would you like to configure it now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Configure API'),
            ),
          ],
        ),
      );

      if (goToSettings == true && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ApiSettingsScreen()),
        );
        _loadApiConfig();
      }
      return;
    }

    setState(() => _isSending = true);

    final currentBook = _collectEditedBook(syncStatus: 'pending');
    final result = await _apiSenderService.sendBook(currentBook, _apiConfig);

    final finalBook = currentBook.copyWith(
      syncStatus: result.isSuccess ? 'sent' : 'failed',
    );
    await _historyService.saveBook(finalBook);

    if (!mounted) return;
    setState(() => _isSending = false);

    if (result.isSuccess) {
      _showSuccessDialog(finalBook, result);
    } else {
      _showErrorDialog(finalBook, result);
    }
  }

  void _showSuccessDialog(Book book, ApiSendResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline, color: AppColors.statusSent, size: 52),
        title: const Text('Berhasil Terkirim!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${book.title}" berhasil disimpan dan dikirim ke server perpustakaan.',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusSentBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.statusSentBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: ${result.statusCode ?? 200} OK',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusSent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Endpoint: ${_apiConfig.httpMethod} ${_apiConfig.endpointUrl}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(book);
            },
            child: const Text('Selesai'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(book);
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Buku Baru'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(Book book, ApiSendResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: AppColors.statusFailed, size: 52),
        title: const Text('Gagal Mengirim Data'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.errorMessage ?? 'Terjadi kesalahan saat menghubungi server API.',
                style: const TextStyle(color: AppColors.statusFailed, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'Endpoint: ${_apiConfig.httpMethod} ${_apiConfig.endpointUrl}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (_apiConfig.endpointUrl.contains('127.0.0.1') ||
                  _apiConfig.endpointUrl.contains('localhost')) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.statusPendingBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.statusPendingBorder),
                  ),
                  child: const Text(
                    '💡 Tips Emulator: Jika menggunakan Android Emulator, gunakan "10.0.2.2" sebagai pengganti "127.0.0.1", atau jalankan "adb reverse tcp:8000 tcp:8000".',
                    style: TextStyle(fontSize: 11, color: AppColors.statusPending),
                  ),
                ),
              ],
              if (result.responseBody != null && result.responseBody!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Respon Server:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    result.responseBody!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _sendToApi();
            },
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.initialBook;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Data Buku'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Simpan Draft Saja',
            onPressed: _isSending ? null : _saveDraftOnly,
          ),
        ],
      ),
      body: _isLoadingConfig
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Book Card Header with cover
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 80,
                              height: 115,
                              color: AppColors.primaryLight,
                              child: _coverImageController.text.isNotEmpty
                                  ? Image.network(
                                      _coverImageController.text,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Icon(Icons.menu_book, size: 36, color: AppColors.primary),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.menu_book, size: 36, color: AppColors.primary),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title.isNotEmpty ? book.title : '(Judul Belum Diisi)',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book.authorsFormatted.isNotEmpty ? book.authorsFormatted : 'Penulis tidak diketahui',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.primary.withAlpha(60)),
                                      ),
                                      child: Text(
                                        'ISBN: ${book.primaryIsbn}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                    ),
                                    if (book.pageCount != null && book.pageCount! > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.primary.withAlpha(60)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.auto_stories, size: 11, color: AppColors.primaryDark),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${book.pageCount} hlm',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.background,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.cloud_done, size: 12, color: AppColors.primary),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.fetchSource,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Destination API Endpoint Indicator Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_upload_outlined, size: 20, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Target API Perpustakaan:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Text(
                                '${_apiConfig.httpMethod} ${_apiConfig.endpointUrl}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDarker,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ApiSettingsScreen(),
                              ),
                            );
                            _loadApiConfig();
                          },
                          child: const Text('Ubah'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Text(
                    'Informasi Buku',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ISBN
                  TextFormField(
                    controller: _isbnController,
                    decoration: const InputDecoration(
                      labelText: 'Nomor ISBN *',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'ISBN wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Judul Buku *',
                      prefixIcon: Icon(Icons.title),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Judul buku wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  // Author
                  TextFormField(
                    controller: _authorController,
                    decoration: const InputDecoration(
                      labelText: 'Penulis / Pengarang *',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Penulis wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  // Publisher
                  TextFormField(
                    controller: _publisherController,
                    decoration: const InputDecoration(
                      labelText: 'Penerbit',
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Year & Page Count
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _yearController,
                          decoration: const InputDecoration(
                            labelText: 'Tahun Terbit *',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Wajib diisi';
                            if (int.tryParse(v.trim()) == null) return 'Harus angka';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _pageCountController,
                          decoration: const InputDecoration(
                            labelText: 'Jumlah Halaman',
                            hintText: 'Contoh: 320',
                            prefixIcon: Icon(Icons.auto_stories_outlined),
                            suffixText: 'hlm',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Sinopsis Buku
                  TextFormField(
                    controller: _sinopsisController,
                    decoration: const InputDecoration(
                      labelText: 'Sinopsis Buku',
                      hintText: 'Ringkasan cerita atau sinopsis buku...',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                    minLines: 3,
                    maxLines: 6,
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Inventaris & Penempatan Rak',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Category ID, Rack Location, Stock
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryIdController,
                          decoration: const InputDecoration(
                            labelText: 'ID Kategori *',
                            prefixIcon: Icon(Icons.category),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Wajib';
                            if (int.tryParse(v.trim()) == null) return 'Angka';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _rackLocationController,
                          decoration: const InputDecoration(
                            labelText: 'Lokasi Rak *',
                            prefixIcon: Icon(Icons.shelves),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Wajib' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          decoration: const InputDecoration(
                            labelText: 'Stok *',
                            prefixIcon: Icon(Icons.inventory_2),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Wajib';
                            if (int.tryParse(v.trim()) == null) return 'Angka';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Cover Image URL
                  TextFormField(
                    controller: _coverImageController,
                    decoration: InputDecoration(
                      labelText: 'URL Sampul Buku (Cover Image)',
                      prefixIcon: const Icon(Icons.image),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Preview gambar',
                        onPressed: () => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Custom Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Khusus (Opsional)',
                      prefixIcon: Icon(Icons.notes),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 20),

                  // Live JSON Payload Preview Box
                  ExpansionTile(
                    title: const Text(
                      'Preview Payload JSON',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    leading: const Icon(Icons.code, size: 20, color: AppColors.primary),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          const JsonEncoder.withIndent('  ')
                              .convert(_collectEditedBook().toApiPayload()),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Actions
                  FilledButton.icon(
                    onPressed: _isSending ? null : _sendToApi,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: Text(
                      _isSending
                          ? 'Mengirim ke Server...'
                          : 'Konfirmasi & Kirim ke Server',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSending ? null : _saveDraftOnly,
                    icon: const Icon(Icons.save_outlined, color: AppColors.primaryDark),
                    label: const Text(
                      'Simpan Sebagai Draft Lokal',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}

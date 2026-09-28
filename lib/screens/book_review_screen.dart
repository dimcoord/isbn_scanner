import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/api_config.dart';
import '../models/book.dart';
import '../services/api_sender_service.dart';
import '../services/history_service.dart';
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
  late TextEditingController _categoryIdController;
  late TextEditingController _rackLocationController;
  late TextEditingController _stockController;
  late TextEditingController _coverImageController;
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
    _categoryIdController = TextEditingController(text: book.categoryId.toString());
    _rackLocationController = TextEditingController(text: book.rackLocation);
    _stockController = TextEditingController(text: book.stock.toString());
    _coverImageController = TextEditingController(text: book.resolvedCoverImage);
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
    _categoryIdController.dispose();
    _rackLocationController.dispose();
    _stockController.dispose();
    _coverImageController.dispose();
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
        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 52),
        title: const Text('Successfully Sent!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${book.title}" was successfully submitted to your API.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Status: ${result.statusCode ?? 200} OK',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Endpoint: ${_apiConfig.httpMethod} ${_apiConfig.endpointUrl}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
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
            child: const Text('Done'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(book);
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan Next Book'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(Book book, ApiSendResult result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 52),
        title: const Text('Failed to Send'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                result.errorMessage ?? 'An error occurred while connecting to the API.',
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'Endpoint: ${_apiConfig.httpMethod} ${_apiConfig.endpointUrl}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              if (_apiConfig.endpointUrl.contains('127.0.0.1') ||
                  _apiConfig.endpointUrl.contains('localhost')) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Text(
                    '💡 Emulator Tip: If using the Android Emulator, change "127.0.0.1" to "10.0.2.2" in API Settings, or run "adb reverse tcp:8000 tcp:8000".',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
              ],
              if (result.responseBody != null && result.responseBody!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Response Body:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
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
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _sendToApi();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = widget.initialBook;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Book Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Save Draft Only',
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
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 80,
                              height: 115,
                              color: Colors.grey.shade200,
                              child: _coverImageController.text.isNotEmpty
                                  ? Image.network(
                                      _coverImageController.text,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Center(
                                        child: Icon(Icons.book, size: 40, color: Colors.grey),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.book, size: 40, color: Colors.grey),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  book.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  book.authorsFormatted,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.black87,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Chip(
                                      label: Text(
                                        'ISBN: ${book.primaryIsbn}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                    ),
                                    Chip(
                                      avatar: const Icon(Icons.cloud_done, size: 14),
                                      label: Text(
                                        widget.fetchSource,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
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
                      color: theme.colorScheme.primaryContainer.withAlpha(50),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withAlpha(80),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.output, size: 20, color: Colors.blueAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Target API Endpoint:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              Text(
                                '${_apiConfig.httpMethod} ${_apiConfig.endpointUrl}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
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
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Book Details',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ISBN
                  TextFormField(
                    controller: _isbnController,
                    decoration: const InputDecoration(
                      labelText: 'ISBN *',
                      prefixIcon: Icon(Icons.numbers),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'ISBN is required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title *',
                      prefixIcon: Icon(Icons.title),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Author
                  TextFormField(
                    controller: _authorController,
                    decoration: const InputDecoration(
                      labelText: 'Author *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Author is required' : null,
                  ),
                  const SizedBox(height: 12),

                  // Publisher & Year
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _publisherController,
                          decoration: const InputDecoration(
                            labelText: 'Publisher',
                            prefixIcon: Icon(Icons.business),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _yearController,
                          decoration: const InputDecoration(
                            labelText: 'Year *',
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Year is required';
                            if (int.tryParse(v.trim()) == null) return 'Invalid year';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Inventory & Shelf Placement',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Category ID, Rack Location, Stock
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _categoryIdController,
                          decoration: const InputDecoration(
                            labelText: 'Category ID *',
                            prefixIcon: Icon(Icons.category),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (int.tryParse(v.trim()) == null) return 'Must be int';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _rackLocationController,
                          decoration: const InputDecoration(
                            labelText: 'Rack Location *',
                            prefixIcon: Icon(Icons.shelves),
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          decoration: const InputDecoration(
                            labelText: 'Stock *',
                            prefixIcon: Icon(Icons.inventory_2),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (int.tryParse(v.trim()) == null) return 'Must be int';
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
                      labelText: 'Cover Image URL',
                      prefixIcon: const Icon(Icons.image),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Preview image',
                        onPressed: () => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Custom Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (Optional)',
                      prefixIcon: Icon(Icons.notes),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),

                  const SizedBox(height: 20),

                  // Live JSON Payload Preview Box
                  ExpansionTile(
                    title: const Text(
                      'Preview JSON Payload',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    leading: const Icon(Icons.code, size: 20),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Text(
                          const JsonEncoder.withIndent('  ')
                              .convert(_collectEditedBook().toApiPayload()),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
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
                          ? 'Sending to API...'
                          : 'Confirm & Send to API',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isSending ? null : _saveDraftOnly,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Locally (Don\'t Send Yet)'),
                    style: OutlinedButton.styleFrom(
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

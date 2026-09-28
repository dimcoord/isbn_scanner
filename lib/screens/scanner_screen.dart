import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/book.dart';
import '../models/api_config.dart';
import '../services/book_fetch_service.dart';
import 'book_review_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  late MobileScannerController _scannerController;
  final BookFetchService _fetchService = BookFetchService();

  bool _isProcessing = false;
  bool _isTorchOn = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _handleBarcodeScanned(value.trim());
        break;
      }
    }
  }

  Future<void> _handleBarcodeScanned(String rawBarcode) async {
    final clean = BookFetchService.cleanIsbn(rawBarcode);
    if (clean.length < 8) {
      // Not a valid book code (ISBN-10, ISBN-13, EAN-13, EAN-8)
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Fetching Book Details...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ISBN: $clean',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final config = await ApiConfig.load();
    final result = await _fetchService.fetchBookByIsbn(
      clean,
      googleApiKey: config.googleBooksApiKey,
    );

    // Dismiss loading dialog
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (!mounted) return;

    if (result.isSuccess && result.book != null) {
      // Pause camera while reviewing
      await _scannerController.stop();
      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookReviewScreen(
            initialBook: result.book!,
            fetchSource: result.source,
          ),
        ),
      );

      // Resume camera when returning
      if (mounted) {
        await _scannerController.start();
        setState(() => _isProcessing = false);
      }
    } else {
      // Book not found online
      _promptManualEntry(clean);
    }
  }

  Future<void> _promptManualEntry(String isbn) async {
    final proceedManual = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Book Not Found'),
        content: Text(
          'Could not find online details for ISBN "$isbn". Would you like to create the entry manually?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enter Manually'),
          ),
        ],
      ),
    );

    if (proceedManual == true && mounted) {
      await _scannerController.stop();
      if (!mounted) return;

      final manualBook = Book(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        isbn: isbn,
        isbn13: isbn.length == 13 ? isbn : null,
        isbn10: isbn.length == 10 ? isbn : null,
        title: '',
        scannedAt: DateTime.now(),
        syncStatus: 'pending',
      );

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookReviewScreen(
            initialBook: manualBook,
            fetchSource: 'Manual Entry',
          ),
        ),
      );

      if (mounted) {
        await _scannerController.start();
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _showManualIsbnDialog() async {
    final controller = TextEditingController();
    final isbn = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual ISBN Lookup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a 10 or 13 digit ISBN to fetch book data without camera scanning:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.text,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. 9780132350884',
                labelText: 'ISBN Code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(controller.text.trim());
            },
            child: const Text('Lookup'),
          ),
        ],
      ),
    );

    if (isbn != null && isbn.isNotEmpty) {
      _handleBarcodeScanned(isbn);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.75;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ISBN Barcode Scanner'),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Toggle Flashlight',
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Switch Camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard),
            tooltip: 'Enter ISBN Manually',
            onPressed: _showManualIsbnDialog,
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Camera Stream
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Camera initialization failed: ${error.errorCode.name}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Ensure camera permission is granted or use the manual ISBN input button below.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _showManualIsbnDialog,
                        icon: const Icon(Icons.keyboard),
                        label: const Text('Enter ISBN Manually'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Viewfinder Cutout Overlay
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withAlpha(160),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: scanAreaSize * 0.7,
                    width: scanAreaSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Viewfinder Target Box Corners & Animated Laser Line
          SizedBox(
            width: scanAreaSize,
            height: scanAreaSize * 0.7,
            child: Stack(
              children: [
                // Corner Borders
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withAlpha(200), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                // Animated Laser Line
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, child) {
                    return Positioned(
                      top: (scanAreaSize * 0.7 - 4) * _animController.value,
                      left: 8,
                      right: 8,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withAlpha(200),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Bottom Prompt & Manual Button
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(180),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code, color: Colors.white70, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Align book barcode / ISBN inside box',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _showManualIsbnDialog,
                  icon: const Icon(Icons.edit),
                  label: const Text('Type ISBN Manually'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

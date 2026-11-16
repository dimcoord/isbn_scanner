import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/book.dart';
import '../models/api_config.dart';
import '../services/book_fetch_service.dart';
import '../theme/app_theme.dart';
import 'api_settings_screen.dart';
import 'book_review_screen.dart';
import 'splash_screen.dart';

class ScannerScreen extends StatefulWidget {
  final bool isActive;

  const ScannerScreen({
    super.key,
    this.isActive = true,
  });

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late MobileScannerController _scannerController;
  final BookFetchService _fetchService = BookFetchService();

  bool _isProcessing = false;
  bool _isTorchOn = false;
  double _currentZoom = 1.0;
  ApiConfig? _apiConfig;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (widget.isActive) {
      _animController.repeat(reverse: true);
    }

    _loadConfig();
  }

  @override
  void didUpdateWidget(ScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _animController.repeat(reverse: true);
        _scannerController.start();
      } else {
        _animController.stop();
        _scannerController.stop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!widget.isActive) return;

    if (state == AppLifecycleState.resumed) {
      _scannerController.start();
      _animController.repeat(reverse: true);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _scannerController.stop();
      _animController.stop();
    }
  }

  Future<void> _loadConfig() async {
    final cfg = await ApiConfig.load();
    if (mounted) {
      setState(() => _apiConfig = cfg);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!widget.isActive || _isProcessing) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _handleBarcodeScanned(value.trim());
        break;
      }
    }
  }

  Future<void> _setZoom(double zoom) async {
    try {
      await _scannerController.setZoomScale(zoom == 1.0 ? 0.0 : 0.5);
      HapticFeedback.selectionClick();
      setState(() => _currentZoom = zoom);
    } catch (_) {
      setState(() => _currentZoom = zoom);
    }
  }

  Future<void> _handleBarcodeScanned(String rawBarcode) async {
    final clean = BookFetchService.cleanIsbn(rawBarcode);
    if (clean.length < 8) {
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    // Pause camera stream while previewing
    await _scannerController.stop();

    if (!mounted) return;

    // Show Sleek Bottom Sheet Preview
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return _BookPreviewBottomSheet(
          isbn: clean,
          fetchService: _fetchService,
          apiConfig: _apiConfig,
          onReviewBook: (book, source) async {
            Navigator.of(bottomSheetContext).pop();
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BookReviewScreen(
                  initialBook: book,
                  fetchSource: source,
                ),
              ),
            );
          },
          onManualEntry: () async {
            Navigator.of(bottomSheetContext).pop();
            final manualBook = Book(
              id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
              isbn: clean,
              isbn13: clean.length == 13 ? clean : null,
              isbn10: clean.length == 10 ? clean : null,
              title: '',
              scannedAt: DateTime.now(),
              syncStatus: 'pending',
            );
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BookReviewScreen(
                  initialBook: manualBook,
                  fetchSource: 'Manual',
                ),
              ),
            );
          },
          onClose: () {
            Navigator.of(bottomSheetContext).pop();
          },
        );
      },
    );

    // Resume camera when bottom sheet is dismissed
    if (mounted) {
      if (widget.isActive) {
        await _scannerController.start();
      }
      setState(() => _isProcessing = false);
      _loadConfig();
    }
  }

  Future<void> _showManualIsbnDialog() async {
    final controller = TextEditingController();
    final isbn = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Input ISBN Manual', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan 10 atau 13 digit nomor ISBN untuk mencari data buku:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Contoh: 9786020332956',
                labelText: 'Nomor ISBN',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop(controller.text.trim());
            },
            child: const Text('Cari Buku'),
          ),
        ],
      ),
    );

    if (isbn != null && isbn.isNotEmpty) {
      _handleBarcodeScanned(isbn);
    }
  }

  void _showAppInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.local_library_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Perpus Dupat Scanner', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aplikasi pemindai barcode ISBN buku terintegrasi dengan Google Books, Perpustakaan Nasional RI, dan sistem Web Perpus Dupat.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SplashScreen(autoProceed: false),
                  ),
                );
              },
              icon: const Icon(Icons.slideshow_rounded, size: 18),
              label: const Text('Lihat Layar Sambutan / Panduan'),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaWidth = (size.width * 0.72).clamp(210.0, 310.0);
    final scanAreaHeight = (scanAreaWidth * 0.65).clamp(140.0, 210.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Live Feed - 100% Full Screen with BoxFit.cover
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              fit: BoxFit.cover,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off, size: 64, color: Colors.white60),
                        const SizedBox(height: 16),
                        Text(
                          'Kamera tidak aktif: ${error.errorCode.name}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Pastikan izin kamera sudah diberikan atau gunakan tombol input manual di bawah.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _showManualIsbnDialog,
                          icon: const Icon(Icons.keyboard),
                          label: const Text('Input ISBN Manual'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Soft Gradient at Top for Header Legibility (Does NOT black out the camera)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 190,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withAlpha(170),
                      Colors.black.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Soft Gradient at Bottom for Controls Legibility
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 190,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withAlpha(170),
                      Colors.black.withAlpha(0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 4. Viewfinder Brackets & Glowing Laser (Centered on Full Screen Camera)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: scanAreaWidth,
                  height: scanAreaHeight,
                  child: Stack(
                    children: [
                      // Outer subtle border
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.white.withAlpha(60),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                      ),

                      // Inner Vibrant Teal Curved Corner Brackets (Mockup Style)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ViewfinderCornersPainter(
                            color: AppColors.laserGlow,
                            cornerLength: 30.0,
                            strokeWidth: 4.5,
                            borderRadius: 22.0,
                          ),
                        ),
                      ),

                      // Animated Glowing Teal Horizontal Laser Bar
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          final topOffset =
                              (scanAreaHeight - 4) * _animController.value;
                          return Positioned(
                            top: topOffset,
                            left: 10,
                            right: 10,
                            child: Container(
                              height: 3.5,
                              decoration: BoxDecoration(
                                color: AppColors.laserGlow,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.laser.withAlpha(240),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: AppColors.laserGlow,
                                    blurRadius: 4,
                                    spreadRadius: 1,
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
                const SizedBox(height: 12),
                // Helper pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(40)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner, color: AppColors.laserGlow, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Arahkan barcode ISBN buku ke dalam kotak',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. Top Header & 3 Quick Mode Cards (Floating overlay)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Bar
                    Row(
                      children: [
                        // Left Info Button
                        _buildGlassIconButton(
                          icon: Icons.info_outline_rounded,
                          tooltip: 'Tentang Aplikasi',
                          onTap: _showAppInfoDialog,
                        ),
                        // Center Title Tag
                        Expanded(
                          child: Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(150),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withAlpha(40),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.qr_code_scanner, color: AppColors.laserGlow, size: 15),
                                  SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Perpus Dupat Scanner',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Right Switch Camera Button
                        _buildGlassIconButton(
                          icon: Icons.cameraswitch_outlined,
                          tooltip: 'Ganti Kamera',
                          onTap: () => _scannerController.switchCamera(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Top 3 Quick Mode Cards (Matching Mockup: Doc Mode, QR Mode, ID Scanner)
                    Row(
                      children: [
                        // Card 1: Auto Scan ISBN (Active)
                        Expanded(
                          child: _buildTopModeCard(
                            icon: Icons.qr_code_scanner,
                            title: 'Scan ISBN',
                            isActive: true,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Card 2: Manual ISBN Input
                        Expanded(
                          child: _buildTopModeCard(
                            icon: Icons.keyboard_outlined,
                            title: 'Input Manual',
                            isActive: false,
                            onTap: _showManualIsbnDialog,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Card 3: Torch / Flash
                        Expanded(
                          child: _buildTopModeCard(
                            icon: _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            title: _isTorchOn ? 'Flash On' : 'Flash Off',
                            isActive: _isTorchOn,
                            activeColor: const Color(0xFFFBBF24), // Amber
                            onTap: () async {
                              await _scannerController.toggleTorch();
                              setState(() => _isTorchOn = !_isTorchOn);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. Bottom Zoom Pill & Web Server Banner (Matching Mockup Screen 2)
          Positioned(
            bottom: 12,
            left: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Zoom Controls (1.0x / 2.0x Pills)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withAlpha(50)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildZoomButton(1.0, '1.0x'),
                      const SizedBox(width: 4),
                      _buildZoomButton(2.0, '2.0x'),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Web Server Status Card (Matching Mockup "Get Premium Today" Card)
                InkWell(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ApiSettingsScreen(),
                      ),
                    );
                    _loadConfig();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        // Left Shield / Cloud Icon Container
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withAlpha(60),
                            ),
                          ),
                          child: const Icon(
                            Icons.cloud_done_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Center Title & URL Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Koneksi Server Web',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _apiConfig?.endpointUrl.isNotEmpty == true
                                    ? _apiConfig!.endpointUrl
                                    : 'Belum terkonfigurasi (Tap untuk atur)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _apiConfig?.isConfigured == true
                                      ? AppColors.primaryDark
                                      : AppColors.statusPending,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Right Circular Arrow Button (Like Mockup)
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ],
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

  Widget _buildGlassIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(150),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildTopModeCard({
    required IconData icon,
    required String title,
    required bool isActive,
    Color? activeColor,
    required VoidCallback onTap,
  }) {
    final color = activeColor ?? AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(240),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? color : AppColors.border,
            width: isActive ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 19,
              color: isActive ? color : AppColors.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomButton(double zoom, String label) {
    final isSelected = _currentZoom == zoom;

    return InkWell(
      onTap: () => _setZoom(zoom),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// Custom Painter for Mockup-Style Viewfinder Corners
class _ViewfinderCornersPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double borderRadius;

  _ViewfinderCornersPainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final r = borderRadius;
    final l = cornerLength;

    // Top-Left
    final pathTL = Path()
      ..moveTo(0, l)
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..lineTo(l, 0);
    canvas.drawPath(pathTL, paint);

    // Top-Right
    final pathTR = Path()
      ..moveTo(w - l, 0)
      ..lineTo(w - r, 0)
      ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
      ..lineTo(w, l);
    canvas.drawPath(pathTR, paint);

    // Bottom-Left
    final pathBL = Path()
      ..moveTo(0, h - l)
      ..lineTo(0, h - r)
      ..arcToPoint(Offset(r, h), radius: Radius.circular(r))
      ..lineTo(l, h);
    canvas.drawPath(pathBL, paint);

    // Bottom-Right
    final pathBR = Path()
      ..moveTo(w - l, h)
      ..lineTo(w - r, h)
      ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r))
      ..lineTo(w, h - l);
    canvas.drawPath(pathBR, paint);
  }

  @override
  bool shouldRepaint(covariant _ViewfinderCornersPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}

// Sleek Bottom Sheet Preview Widget
class _BookPreviewBottomSheet extends StatefulWidget {
  final String isbn;
  final BookFetchService fetchService;
  final ApiConfig? apiConfig;
  final Function(Book book, String source) onReviewBook;
  final VoidCallback onManualEntry;
  final VoidCallback onClose;

  const _BookPreviewBottomSheet({
    required this.isbn,
    required this.fetchService,
    required this.apiConfig,
    required this.onReviewBook,
    required this.onManualEntry,
    required this.onClose,
  });

  @override
  State<_BookPreviewBottomSheet> createState() =>
      _BookPreviewBottomSheetState();
}

class _BookPreviewBottomSheetState extends State<_BookPreviewBottomSheet> {
  bool _isLoading = true;
  BookFetchResult? _fetchResult;

  @override
  void initState() {
    super.initState();
    _fetchBookData();
  }

  Future<void> _fetchBookData() async {
    final result = await widget.fetchService.fetchBookByIsbn(
      widget.isbn,
      googleApiKey: widget.apiConfig?.googleBooksApiKey,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        _fetchResult = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Grab Handle Pill
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoading) ...[
              // Loading State with Shimmer / Spinner
              Row(
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mencari Data Buku...',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Menghubungi Google Books & Perpusnas RI (${widget.isbn})',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ] else if (_fetchResult?.isSuccess == true &&
                _fetchResult?.book != null) ...[
              // Success State: Book Details Preview
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover Image Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 64,
                      height: 90,
                      color: AppColors.primaryLight,
                      child: _fetchResult!.book!.thumbnailUrl?.isNotEmpty == true
                          ? Image.network(
                              _fetchResult!.book!.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.menu_book,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            )
                          : const Icon(
                              Icons.menu_book,
                              color: AppColors.primary,
                              size: 32,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Metadata Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statusSentBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.statusSentBorder),
                          ),
                          child: Text(
                            'Sumber: ${_fetchResult!.source}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.statusSent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _fetchResult!.book!.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _fetchResult!.book!.authorsFormatted.isNotEmpty
                              ? _fetchResult!.book!.authorsFormatted
                              : 'Penulis Tidak Diketahui',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ISBN: ${widget.isbn}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClose,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: const Text('Scan Lagi'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        widget.onReviewBook(
                          _fetchResult!.book!,
                          _fetchResult!.source,
                        );
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Review & Kirim'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Book Not Found Online
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.statusPendingBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.statusPendingBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.statusPending, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Data Buku Tidak Ditemukan Online',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.statusPending,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ISBN "${widget.isbn}" berhasil terbaca, tetapi metadata belum terdaftar di internet.',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onClose,
                      child: const Text('Tutup'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: widget.onManualEntry,
                      icon: const Icon(Icons.edit_note, size: 20),
                      label: const Text('Input Data Manual'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

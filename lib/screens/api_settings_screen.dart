import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/api_config.dart';
import '../services/api_sender_service.dart';
import '../theme/app_theme.dart';

class ApiSettingsScreen extends StatefulWidget {
  const ApiSettingsScreen({super.key});

  @override
  State<ApiSettingsScreen> createState() => _ApiSettingsScreenState();
}

class _ApiSettingsScreenState extends State<ApiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _urlController;
  late TextEditingController _tokenController;
  late TextEditingController _rootKeyController;
  late TextEditingController _headersController;
  late TextEditingController _googleApiKeyController;
  late TextEditingController _categoryIdController;
  late TextEditingController _rackLocationController;
  late TextEditingController _stockController;
  String _selectedMethod = 'POST';
  bool _isLoading = true;
  bool _isTesting = false;
  bool _isDetecting = false;

  final ApiSenderService _apiSenderService = ApiSenderService();

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _tokenController = TextEditingController();
    _rootKeyController = TextEditingController();
    _headersController = TextEditingController();
    _googleApiKeyController = TextEditingController();
    _categoryIdController = TextEditingController();
    _rackLocationController = TextEditingController();
    _stockController = TextEditingController();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await ApiConfig.load();
    setState(() {
      _urlController.text = config.endpointUrl;
      _selectedMethod = config.httpMethod;
      _tokenController.text = config.authToken;
      _rootKeyController.text = config.payloadRootKey;
      _googleApiKeyController.text = config.googleBooksApiKey;
      _categoryIdController.text = config.defaultCategoryId.toString();
      _rackLocationController.text = config.defaultRackLocation;
      _stockController.text = config.defaultStock.toString();
      _headersController.text = config.customHeaders.isNotEmpty
          ? const JsonEncoder.withIndent('  ').convert(config.customHeaders)
          : '';
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    _tokenController.dispose();
    _rootKeyController.dispose();
    _headersController.dispose();
    _googleApiKeyController.dispose();
    _categoryIdController.dispose();
    _rackLocationController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Map<String, String> _parseCustomHeaders() {
    final text = _headersController.text.trim();
    if (text.isEmpty) return {};
    try {
      final decoded = json.decode(text) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  ApiConfig _buildCurrentConfig() {
    return ApiConfig(
      endpointUrl: _urlController.text.trim(),
      httpMethod: _selectedMethod,
      authToken: _tokenController.text.trim(),
      payloadRootKey: _rootKeyController.text.trim(),
      googleBooksApiKey: _googleApiKeyController.text.trim(),
      defaultCategoryId: int.tryParse(_categoryIdController.text.trim()) ?? 8,
      defaultRackLocation: _rackLocationController.text.trim().isNotEmpty
          ? _rackLocationController.text.trim()
          : 'Rak-A1',
      defaultStock: int.tryParse(_stockController.text.trim()) ?? 5,
      customHeaders: _parseCustomHeaders(),
    );
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final config = _buildCurrentConfig();
    await config.save();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Konfigurasi API berhasil disimpan!'),
          ],
        ),
        backgroundColor: AppColors.primaryDark,
      ),
    );
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isTesting = true);
    final config = _buildCurrentConfig();
    final result = await _apiSenderService.testConnection(config);

    if (!mounted) return;
    setState(() => _isTesting = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.isSuccess ? Icons.check_circle : Icons.error,
              color: result.isSuccess ? AppColors.statusSent : AppColors.statusFailed,
            ),
            const SizedBox(width: 8),
            Text(result.isSuccess ? 'Koneksi Berhasil' : 'Koneksi Gagal'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result.statusCode != null)
                Text(
                  'Status HTTP: ${result.statusCode}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: result.isSuccess ? AppColors.statusSent : AppColors.statusFailed,
                  ),
                ),
              const SizedBox(height: 8),
              if (result.errorMessage != null)
                Text(
                  'Keterangan: ${result.errorMessage}',
                  style: const TextStyle(color: AppColors.statusFailed),
                ),
              if (_urlController.text.contains('127.0.0.1') ||
                  _urlController.text.contains('localhost')) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.statusPendingBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.statusPendingBorder),
                  ),
                  child: const Text(
                    '💡 Tips Emulator: Jika menggunakan Android Emulator, gunakan "10.0.2.2" sebagai pengganti "127.0.0.1" agar dapat mengakses server PC lokal, atau jalankan "adb reverse tcp:8000 tcp:8000".',
                    style: TextStyle(fontSize: 11, color: AppColors.statusPending),
                  ),
                ),
              ],
              if (result.responseBody != null && result.responseBody!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Respon Server:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    result.responseBody!.length > 400
                        ? '${result.responseBody!.substring(0, 400)}...'
                        : result.responseBody!,
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
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAutoDetect() async {
    setState(() => _isDetecting = true);
    final detectedUrl = await ApiSenderService.autoDetectServer(
      extraHosts: [
        _urlController.text,
      ],
    );

    if (!mounted) return;
    setState(() => _isDetecting = false);

    if (detectedUrl != null) {
      setState(() => _urlController.text = detectedUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Server ditemukan: $detectedUrl'),
          backgroundColor: AppColors.statusSent,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Server belum ditemukan. Pastikan HP & Laptop di Wi-Fi yang sama dan jalankan: php artisan serve --host=0.0.0.0',
          ),
          backgroundColor: AppColors.statusPending,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Endpoint Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_rounded, color: AppColors.primary),
            tooltip: 'Save Settings',
            onPressed: _saveConfig,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withAlpha(70)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Atur URL endpoint API backend perpustakaan dan token autentikasi di bawah. Buku yang dipindai akan otomatis dikirim ke endpoint ini.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.primaryDarker, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Endpoint URL
            TextFormField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Target API Endpoint URL *',
                hintText: 'http://${ApiConfig.defaultLanHost}:8000/api/v1/books/isbn-scan',
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _urlController.clear(),
                ),
              ),
              keyboardType: TextInputType.url,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter a valid API URL';
                }
                final uri = Uri.tryParse(val.trim());
                if (uri == null || !uri.hasScheme) {
                  return 'URL must start with http:// or https://';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),

            // Auto-Detect Button for all phones
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isDetecting ? null : _handleAutoDetect,
                icon: _isDetecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(Icons.radar_rounded, size: 18),
                label: Text(
                  _isDetecting
                      ? 'Mencari Server di Jaringan...'
                      : '🔍 Deteksi Otomatis Server Web',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Presets row (Wi-Fi HP, Emulator, Localhost)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.wifi, size: 14, color: AppColors.primary),
                  label: const Text(
                    '📶 Wi-Fi HP (${ApiConfig.defaultLanHost}:8000)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                  ),
                  backgroundColor: AppColors.primaryLight,
                  side: const BorderSide(color: AppColors.primary),
                  onPressed: () {
                    setState(() {
                      _urlController.text = ApiConfig.defaultLanEndpoint;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Endpoint disetel ke IP Wi-Fi laptop (${ApiConfig.defaultLanHost}).'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.phone_android, size: 14, color: AppColors.primary),
                  label: const Text(
                    '10.0.2.2:8000 (Emulator)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                  ),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  onPressed: () {
                    setState(() {
                      _urlController.text = ApiConfig.defaultEmulatorEndpoint;
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.dns, size: 14, color: AppColors.textSecondary),
                  label: const Text(
                    '127.0.0.1:8000 (Localhost PC)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.border),
                  onPressed: () {
                    setState(() {
                      _urlController.text = ApiConfig.defaultEndpoint;
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedMethod,
              decoration: const InputDecoration(
                labelText: 'Metode HTTP',
                prefixIcon: Icon(Icons.http),
              ),
              items: const [
                DropdownMenuItem(value: 'POST', child: Text('POST')),
                DropdownMenuItem(value: 'PUT', child: Text('PUT')),
                DropdownMenuItem(value: 'PATCH', child: Text('PATCH')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedMethod = val);
              },
            ),
            const SizedBox(height: 16),

            // Authorization Token
            TextFormField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Token Otorisasi (Bearer)',
                hintText: 'Bearer 2|xMfKgP7f...',
                prefixIcon: Icon(Icons.key),
                helperText: 'Otomatis menambahkan "Bearer " bila belum ada',
              ),
            ),
            const SizedBox(height: 20),

            // Default Inventory Values Section
            const Text(
              'Nilai Standar Inventaris',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Nilai otomatis saat memindai buku baru (dapat disesuaikan saat review):',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _categoryIdController,
                    decoration: const InputDecoration(
                      labelText: 'ID Kategori',
                      prefixIcon: Icon(Icons.category),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _rackLocationController,
                    decoration: const InputDecoration(
                      labelText: 'Lokasi Rak',
                      prefixIcon: Icon(Icons.shelves),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stok',
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Advanced Settings
            ExpansionTile(
              title: const Text(
                'Konfigurasi Lanjutan',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              leading: const Icon(Icons.settings_suggest, color: AppColors.primary, size: 20),
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rootKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Payload Wrapper Key (Opsional)',
                    hintText: 'Contoh: "book" untuk {"book": {...}}',
                    prefixIcon: Icon(Icons.wrap_text),
                    helperText: 'Kosongkan untuk mengirim JSON langsung di tingkat root',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _headersController,
                  decoration: const InputDecoration(
                    labelText: 'Header Kustom Tambahan (JSON Opsional)',
                    hintText: '{"X-Custom-Header": "value"}',
                    prefixIcon: Icon(Icons.code),
                  ),
                  maxLines: 2,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    try {
                      final decoded = json.decode(val);
                      if (decoded is! Map) return 'Harus objek JSON valid';
                    } catch (e) {
                      return 'Format sintaks JSON tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _googleApiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Google Books API Key (Opsional)',
                    hintText: 'AIzaSy...',
                    prefixIcon: Icon(Icons.vpn_key),
                    helperText: 'Kunci opsional untuk pencarian buku internasional',
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.sensors, color: AppColors.primary),
                    label: Text(_isTesting ? 'Menguji...' : 'Uji Koneksi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan Pengaturan'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 14),
            const Text(
              'Format Payload JSON yang Dikirim ke Endpoint:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                '{\n'
                '  "isbn": "9786020332956",\n'
                '  "title": "Bumi Manusia",\n'
                '  "author": "Pramoedya Ananta Toer",\n'
                '  "publisher": "Hasta Mitra",\n'
                '  "publication_year": 2005,\n'
                '  "category_id": 8,\n'
                '  "rack_location": "Rak-A1",\n'
                '  "stock": 5,\n'
                '  "cover_image": "https://example.com/covers/bumi-manusia.jpg"\n'
                '}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

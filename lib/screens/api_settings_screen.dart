import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/api_config.dart';
import '../services/api_sender_service.dart';

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
            Text('API Configuration saved successfully!'),
          ],
        ),
        backgroundColor: Colors.green,
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
              color: result.isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(result.isSuccess ? 'Connection Success' : 'Connection Failed'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (result.statusCode != null)
                Text(
                  'Status Code: ${result.statusCode}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 8),
              if (result.errorMessage != null)
                Text(
                  'Error: ${result.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                ),
              if (_urlController.text.contains('127.0.0.1') ||
                  _urlController.text.contains('localhost')) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Text(
                    '💡 Emulator Notice: If running in the Android Emulator, change "127.0.0.1" to "10.0.2.2" so the emulator can reach your PC server, or run "adb reverse tcp:8000 tcp:8000".',
                    style: TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                ),
              ],
              if (result.responseBody != null && result.responseBody!.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Server Response:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    result.responseBody!.length > 400
                        ? '${result.responseBody!.substring(0, 400)}...'
                        : result.responseBody!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Endpoint Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
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
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withAlpha(50),
              child: const Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blueAccent),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Set your target API endpoint URL and token below. Scanned books will be sent as JSON to this endpoint.',
                        style: TextStyle(fontSize: 13),
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
                hintText: 'http://127.0.0.1:8000/api/v1/books/isbn-scan',
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
            const SizedBox(height: 8),

            // Presets row
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.computer, size: 14),
                  label: const Text('127.0.0.1:8000', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _urlController.text =
                          'http://127.0.0.1:8000/api/v1/books/isbn-scan';
                    });
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.phone_android, size: 14),
                  label: const Text('10.0.2.2:8000 (Emulator)',
                      style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _urlController.text =
                          'http://10.0.2.2:8000/api/v1/books/isbn-scan';
                    });
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedMethod,
              decoration: const InputDecoration(
                labelText: 'HTTP Method',
                prefixIcon: Icon(Icons.http),
                border: OutlineInputBorder(),
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
                labelText: 'Authorization Token (Bearer)',
                hintText: 'Bearer 2|xMfKgP7f...',
                prefixIcon: Icon(Icons.key),
                border: OutlineInputBorder(),
                helperText: 'Auto-prepends "Bearer " if not present',
              ),
            ),
            const SizedBox(height: 16),

            // Default Inventory Values Section
            Text(
              'Default Inventory Values',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Prefilled values when scanning a new book (can be changed on review):',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _categoryIdController,
                    decoration: const InputDecoration(
                      labelText: 'Category ID',
                      prefixIcon: Icon(Icons.category),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _rackLocationController,
                    decoration: const InputDecoration(
                      labelText: 'Rack Location',
                      prefixIcon: Icon(Icons.shelves),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    decoration: const InputDecoration(
                      labelText: 'Stock',
                      prefixIcon: Icon(Icons.inventory_2),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Advanced Settings
            ExpansionTile(
              title: const Text('Advanced Configurations', style: TextStyle(fontSize: 14)),
              children: [
                const SizedBox(height: 8),
                TextFormField(
                  controller: _rootKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Payload Wrapper Key (Optional)',
                    hintText: 'e.g. "book" for {"book": {...}}',
                    prefixIcon: Icon(Icons.wrap_text),
                    border: OutlineInputBorder(),
                    helperText: 'Leave empty to send JSON directly at root',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _headersController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Extra Headers in JSON (Optional)',
                    hintText: '{"X-Custom-Header": "value"}',
                    prefixIcon: Icon(Icons.code),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return null;
                    try {
                      final decoded = json.decode(val);
                      if (decoded is! Map) return 'Must be a valid JSON object';
                    } catch (e) {
                      return 'Invalid JSON syntax';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _googleApiKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Google Books API Key (Optional)',
                    hintText: 'AIzaSy...',
                    prefixIcon: Icon(Icons.vpn_key),
                    border: OutlineInputBorder(),
                    helperText: 'Optional key for international lookups',
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sensors),
                    label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saveConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('Save Settings'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Payload Format Sent to Your Endpoint:',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
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
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

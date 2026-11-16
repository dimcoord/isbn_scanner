import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

/// Configuration for the target API endpoint where scanned book data will be sent.
class ApiConfig {
  static const String _keyEndpointUrl = 'api_endpoint_url';
  static const String _keyHttpMethod = 'api_http_method';
  static const String _keyAuthToken = 'api_auth_token';
  static const String _keyCustomHeaders = 'api_custom_headers';
  static const String _keyPayloadRootKey = 'api_payload_root_key';
  static const String _keyGoogleBooksApiKey = 'google_books_api_key';
  static const String _keyDefaultCategoryId = 'api_default_category_id';
  static const String _keyDefaultRackLocation = 'api_default_rack_location';
  static const String _keyDefaultStock = 'api_default_stock';

  // Default endpoint and token as configured for the user's book scanning API
  static const String defaultEndpoint = 'http://127.0.0.1:8000/api/v1/books/isbn-scan';
  static const String defaultLanHost = '192.168.1.112';
  static const String defaultLanEndpoint = 'http://192.168.1.112:8000/api/v1/books/isbn-scan';
  static const String defaultEmulatorEndpoint = 'http://10.0.2.2:8000/api/v1/books/isbn-scan';
  static const String defaultAuthToken = 'Bearer 2|xMfKgP7fOIHLvA7KpVjXl1Ijrg8bt3M1EaimTjtlccc0d98b';

  final String endpointUrl;
  final String httpMethod; // 'POST', 'PUT', 'PATCH'
  final String authToken;
  final Map<String, String> customHeaders;
  final String payloadRootKey; // e.g. "book" if payload should be {"book": {...}}, or empty for direct
  final String googleBooksApiKey;
  final int defaultCategoryId;
  final String defaultRackLocation;
  final int defaultStock;

  const ApiConfig({
    this.endpointUrl = defaultEndpoint,
    this.httpMethod = 'POST',
    this.authToken = defaultAuthToken,
    this.customHeaders = const {},
    this.payloadRootKey = '',
    this.googleBooksApiKey = '',
    this.defaultCategoryId = 8,
    this.defaultRackLocation = 'Rak-A1',
    this.defaultStock = 5,
  });

  bool get isConfigured =>
      endpointUrl.trim().isNotEmpty && Uri.tryParse(endpointUrl)?.hasScheme == true;

  /// Extracts the hostname or IP from the endpointUrl
  String get host {
    final uri = Uri.tryParse(endpointUrl);
    return uri?.host ?? '';
  }

  /// Extracts the port from the endpointUrl
  String get port {
    final uri = Uri.tryParse(endpointUrl);
    return (uri?.hasPort == true) ? uri!.port.toString() : '8000';
  }

  /// Extracts the path from the endpointUrl
  String get path {
    final uri = Uri.tryParse(endpointUrl);
    return (uri != null && uri.path.isNotEmpty) ? uri.path : '/api/v1/books/isbn-scan';
  }

  /// Builds a dynamic endpoint URL using the specified host IP
  static String buildEndpoint({
    required String host,
    String port = '8000',
    String path = '/api/v1/books/isbn-scan',
    String scheme = 'http',
  }) {
    final cleanHost = host.trim().replaceAll('http://', '').replaceAll('https://', '');
    return '$scheme://$cleanHost:$port$path';
  }

  /// Suggests the appropriate default endpoint based on device environment
  static String getSuggestedEndpoint() {
    if (kIsWeb) return defaultEndpoint;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        return defaultLanEndpoint;
      }
    } catch (_) {}
    return defaultEndpoint;
  }

  ApiConfig copyWith({
    String? endpointUrl,
    String? httpMethod,
    String? authToken,
    Map<String, String>? customHeaders,
    String? payloadRootKey,
    String? googleBooksApiKey,
    int? defaultCategoryId,
    String? defaultRackLocation,
    int? defaultStock,
  }) {
    return ApiConfig(
      endpointUrl: endpointUrl ?? this.endpointUrl,
      httpMethod: httpMethod ?? this.httpMethod,
      authToken: authToken ?? this.authToken,
      customHeaders: customHeaders ?? this.customHeaders,
      payloadRootKey: payloadRootKey ?? this.payloadRootKey,
      googleBooksApiKey: googleBooksApiKey ?? this.googleBooksApiKey,
      defaultCategoryId: defaultCategoryId ?? this.defaultCategoryId,
      defaultRackLocation: defaultRackLocation ?? this.defaultRackLocation,
      defaultStock: defaultStock ?? this.defaultStock,
    );
  }

  /// Builds the complete HTTP headers map, including Auth and Custom headers
  Map<String, String> getResolvedHeaders() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authToken.trim().isNotEmpty) {
      if (authToken.toLowerCase().startsWith('bearer ') ||
          authToken.toLowerCase().startsWith('basic ')) {
        headers['Authorization'] = authToken.trim();
      } else {
        headers['Authorization'] = 'Bearer ${authToken.trim()}';
      }
    }

    headers.addAll(customHeaders);
    return headers;
  }

  /// Load configuration from SharedPreferences with smart dynamic IP resolution for mobile phones
  static Future<ApiConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_keyEndpointUrl);
    String url;

    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      url = savedUrl.trim();
      // On real mobile devices, 127.0.0.1 cannot reach the developer PC.
      // Automatically upgrade to defaultLanEndpoint so all mobile phones connect out-of-the-box!
      if (!kIsWeb) {
        try {
          if ((Platform.isAndroid || Platform.isIOS) &&
              (url == defaultEndpoint || url.contains('127.0.0.1') || url.contains('localhost'))) {
            url = defaultLanEndpoint;
          }
        } catch (_) {}
      }
    } else {
      url = getSuggestedEndpoint();
    }

    final method = prefs.getString(_keyHttpMethod) ?? 'POST';
    final token = prefs.getString(_keyAuthToken) ?? defaultAuthToken;
    final rootKey = prefs.getString(_keyPayloadRootKey) ?? '';
    final googleKey = prefs.getString(_keyGoogleBooksApiKey) ?? '';
    final catId = prefs.getInt(_keyDefaultCategoryId) ?? 8;
    final rack = prefs.getString(_keyDefaultRackLocation) ?? 'Rak-A1';
    final stock = prefs.getInt(_keyDefaultStock) ?? 5;
    final headersJson = prefs.getString(_keyCustomHeaders);

    Map<String, String> headers = {};
    if (headersJson != null && headersJson.isNotEmpty) {
      try {
        final decoded = json.decode(headersJson) as Map<String, dynamic>;
        headers = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {
        headers = {};
      }
    }

    return ApiConfig(
      endpointUrl: url,
      httpMethod: method,
      authToken: token,
      customHeaders: headers,
      payloadRootKey: rootKey,
      googleBooksApiKey: googleKey,
      defaultCategoryId: catId,
      defaultRackLocation: rack,
      defaultStock: stock,
    );
  }

  /// Save configuration to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEndpointUrl, endpointUrl.trim());
    await prefs.setString(_keyHttpMethod, httpMethod);
    await prefs.setString(_keyAuthToken, authToken.trim());
    await prefs.setString(_keyPayloadRootKey, payloadRootKey.trim());
    await prefs.setString(_keyGoogleBooksApiKey, googleBooksApiKey.trim());
    await prefs.setInt(_keyDefaultCategoryId, defaultCategoryId);
    await prefs.setString(_keyDefaultRackLocation, defaultRackLocation.trim());
    await prefs.setInt(_keyDefaultStock, defaultStock);
    await prefs.setString(_keyCustomHeaders, json.encode(customHeaders));
  }
}

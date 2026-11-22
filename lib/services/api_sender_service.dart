import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/api_config.dart';
import '../models/book.dart';

class ApiSendResult {
  final bool isSuccess;
  final int? statusCode;
  final String? responseBody;
  final String? errorMessage;
  final DateTime sentAt;

  const ApiSendResult({
    required this.isSuccess,
    this.statusCode,
    this.responseBody,
    this.errorMessage,
    required this.sentAt,
  });
}

class ApiSenderService {
  final http.Client _client;

  ApiSenderService({http.Client? client}) : _client = client ?? http.Client();

  /// Prepares the payload dictionary according to the API configuration
  Map<String, dynamic> buildPayload(Book book, ApiConfig config) {
    final bookMap = book.toApiPayload();
    if (config.payloadRootKey.trim().isNotEmpty) {
      return {config.payloadRootKey.trim(): bookMap};
    }
    return bookMap;
  }

  /// Sends a reviewed book to the user's configured API endpoint
  Future<ApiSendResult> sendBook(Book book, ApiConfig config) async {
    final sentAt = DateTime.now();

    if (!config.isConfigured) {
      return ApiSendResult(
        isSuccess: false,
        errorMessage: 'API endpoint URL is invalid or empty. Please configure it in settings.',
        sentAt: sentAt,
      );
    }

    final uri = Uri.tryParse(config.endpointUrl);
    if (uri == null || !uri.hasScheme) {
      return ApiSendResult(
        isSuccess: false,
        errorMessage: 'Invalid URL format: ${config.endpointUrl}',
        sentAt: sentAt,
      );
    }

    final headers = config.getResolvedHeaders();
    final payload = buildPayload(book, config);
    final jsonBody = json.encode(payload);

    try {
      http.Response response;
      final method = config.httpMethod.toUpperCase();

      switch (method) {
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: jsonBody)
              .timeout(const Duration(seconds: 15));
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: jsonBody)
              .timeout(const Duration(seconds: 15));
          break;
        case 'POST':
        default:
          response = await _client
              .post(uri, headers: headers, body: jsonBody)
              .timeout(const Duration(seconds: 15));
          break;
      }

      final is2xx = response.statusCode >= 200 && response.statusCode < 300;
      return ApiSendResult(
        isSuccess: is2xx,
        statusCode: response.statusCode,
        responseBody: response.body,
        errorMessage: is2xx ? null : 'Server returned status ${response.statusCode}',
        sentAt: sentAt,
      );
    } on SocketException catch (e) {
      // Dynamic fallback for real phones: if localhost was targeted, try the active LAN host
      if (config.endpointUrl.contains('127.0.0.1') || config.endpointUrl.contains('localhost')) {
        final fallbackUrl = config.endpointUrl
            .replaceAll('127.0.0.1', ApiConfig.defaultLanHost)
            .replaceAll('localhost', ApiConfig.defaultLanHost);
        final fallbackUri = Uri.tryParse(fallbackUrl);

        if (fallbackUri != null && fallbackUrl != config.endpointUrl) {
          try {
            final fallbackResponse = await _client
                .post(fallbackUri, headers: headers, body: jsonBody)
                .timeout(const Duration(seconds: 10));
            final is2xx = fallbackResponse.statusCode >= 200 && fallbackResponse.statusCode < 300;
            // Persist the working LAN URL so future scans don't need to fallback
            config.copyWith(endpointUrl: fallbackUrl).save();
            return ApiSendResult(
              isSuccess: is2xx,
              statusCode: fallbackResponse.statusCode,
              responseBody: fallbackResponse.body,
              errorMessage: is2xx ? null : 'Server returned status ${fallbackResponse.statusCode}',
              sentAt: sentAt,
            );
          } catch (_) {
            // Fall through to descriptive error below
          }
        }
      }

      return ApiSendResult(
        isSuccess: false,
        errorMessage:
            'Koneksi gagal (${e.message}). Jika menggunakan HP, pastikan HP & Laptop di Wi-Fi yang sama dan ganti 127.0.0.1 dengan IP Wi-Fi laptop (${ApiConfig.defaultLanHost}).',
        sentAt: sentAt,
      );
    } on TimeoutException {
      return ApiSendResult(
        isSuccess: false,
        errorMessage: 'Request timed out after 15 seconds. Please check your API server.',
        sentAt: sentAt,
      );
    } on FormatException catch (e) {
      return ApiSendResult(
        isSuccess: false,
        errorMessage: 'Format error: ${e.message}',
        sentAt: sentAt,
      );
    } catch (e) {
      return ApiSendResult(
        isSuccess: false,
        errorMessage: 'Unexpected error: $e',
        sentAt: sentAt,
      );
    }
  }

  /// Sends a lightweight test ping payload to the API endpoint to verify connectivity
  Future<ApiSendResult> testConnection(ApiConfig config) async {
    final dummyBook = Book(
      id: 'test_connection',
      isbn: '9786020332956',
      title: 'Bumi Manusia',
      author: 'Pramoedya Ananta Toer',
      publisher: 'Hasta Mitra',
      publicationYear: 2005,
      categoryId: config.defaultCategoryId,
      rackLocation: config.defaultRackLocation,
      stock: config.defaultStock,
      coverImage: 'https://example.com/covers/bumi-manusia.jpg',
      sinopsis: 'Bumi Manusia adalah buku pertama dari Tetralogi Buru karya Pramoedya Ananta Toer.',
      scannedAt: DateTime.now(),
      notes: 'API Test Connection',
    );

    return sendBook(dummyBook, config);
  }

  /// Probes candidate hosts to automatically detect the running Laravel server
  static Future<String?> autoDetectServer({
    String port = '8000',
    String path = '/api/v1/books/isbn-scan',
    List<String> extraHosts = const [],
  }) async {
    final candidates = <String>[
      ApiConfig.defaultLanHost, // '192.168.1.112'
      ...extraHosts,
      '10.0.2.2',
      '127.0.0.1',
      'localhost',
    ];

    final client = http.Client();
    try {
      for (final host in candidates) {
        final cleanHost = host.trim().replaceAll('http://', '').replaceAll('https://', '');
        if (cleanHost.isEmpty) continue;
        final candidateUri = Uri.tryParse('http://$cleanHost:$port$path');
        if (candidateUri == null) continue;

        try {
          final res = await client
              .get(candidateUri)
              .timeout(const Duration(milliseconds: 1500));
          if (res.statusCode > 0) {
            return candidateUri.toString();
          }
        } catch (_) {
          // Probe next candidate
        }
      }
    } finally {
      client.close();
    }
    return null;
  }
}

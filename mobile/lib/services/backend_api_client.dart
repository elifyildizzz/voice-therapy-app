import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'auth_service.dart';

class BackendApiException implements Exception {
  const BackendApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackendApiClient {
  BackendApiClient._();

  static final BackendApiClient instance = BackendApiClient._();
  static const String _configuredBackendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );
  static const Duration _requestTimeout = Duration(seconds: 15);

  String get _backendBaseUrl {
    if (_configuredBackendBaseUrl.isNotEmpty) {
      return _configuredBackendBaseUrl;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    try {
      final response = await http
          .get(_buildUri(path), headers: _headers())
          .timeout(_requestTimeout);
      return _decodeOrThrow(response);
    } catch (error) {
      _throwConnectionError(error);
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await http
          .post(
            _buildUri(path),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _decodeOrThrow(response);
    } catch (error) {
      _throwConnectionError(error);
    }
  }

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, Object?> body,
  ) async {
    try {
      final response = await http
          .patch(
            _buildUri(path),
            headers: _headers(),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
      return _decodeOrThrow(response);
    } catch (error) {
      _throwConnectionError(error);
    }
  }

  Uri _buildUri(String path) => Uri.parse('$_backendBaseUrl$path');

  Map<String, String> _headers() {
    final token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty) {
      throw const BackendApiException('Oturum bulunamadı.');
    }

    return <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    final decoded = _decodeObject(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw BackendApiException(_readErrorMessage(decoded, response.statusCode));
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    if (response.statusCode >= 200 && response.statusCode < 300) {
      throw const BackendApiException('Sunucudan beklenmeyen yanıt alındı.');
    }
    return const <String, dynamic>{};
  }

  String _readErrorMessage(Map<String, dynamic> body, int statusCode) {
    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) {
      return detail;
    }
    if (detail is List && detail.isNotEmpty) {
      final firstError = detail.first;
      if (firstError is Map<String, dynamic>) {
        final message = firstError['msg'];
        if (message is String && message.isNotEmpty) {
          return message;
        }
      }
    }

    if (statusCode == 401) {
      return 'Oturum geçersiz veya süresi dolmuş.';
    }
    return 'Sunucu hatası oluştu. Lütfen tekrar deneyin.';
  }

  Never _throwConnectionError(Object error) {
    if (error is BackendApiException) {
      throw error;
    }
    throw const BackendApiException(
      'Backend bağlantısı kurulamadı. Sunucunun çalıştığından emin olun.',
    );
  }
}

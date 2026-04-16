import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show ValueNotifier, kIsWeb;
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import 'local_database.dart';

class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const String _configuredBackendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: '',
  );
  static const Duration _requestTimeout = Duration(seconds: 15);

  final ValueNotifier<AppUser?> currentUserNotifier = ValueNotifier<AppUser?>(
    null,
  );

  bool _initialized = false;
  String? _accessToken;

  AppUser? get currentUser => currentUserNotifier.value;
  String? get accessToken => _accessToken;

  String get _backendBaseUrl {
    if (_configuredBackendBaseUrl.isNotEmpty) {
      return _configuredBackendBaseUrl;
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final database = await LocalDatabase.instance.database;
    final sessionRows = await database.query(
      LocalDatabase.authSessionTable,
      limit: 1,
    );

    if (sessionRows.isNotEmpty) {
      final token = sessionRows.first['access_token'] as String?;
      if (token != null && token.isNotEmpty) {
        _accessToken = token;
        try {
          currentUserNotifier.value = await _fetchCurrentUser();
        } on AuthException {
          await database.delete(LocalDatabase.authSessionTable);
          _accessToken = null;
          currentUserNotifier.value = null;
        }
      }
    }

    _initialized = true;
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cleanFirstName = firstName.trim();
    final cleanLastName = lastName.trim();

    if (!_isValidEmail(normalizedEmail)) {
      throw AuthException('Geçerli bir e-posta adresi girin.');
    }
    if (password.length < 8) {
      throw AuthException('Şifre en az 8 karakter olmalıdır.');
    }
    if (cleanFirstName.isEmpty || cleanLastName.isEmpty) {
      throw AuthException('Ad ve soyad alanları boş bırakılamaz.');
    }

    final response = await _postJson(
      '/auth/register',
      <String, Object?>{
        'email': normalizedEmail,
        'password': password,
        'first_name': cleanFirstName,
        'last_name': cleanLastName,
      },
    );

    return _readUser(response);
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    final response = await _postJson(
      '/auth/login',
      <String, Object?>{
        'email': normalizedEmail,
        'password': password,
      },
    );

    final body = _decodeObject(response);
    final token = body['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw AuthException('Sunucudan oturum bilgisi alınamadı.');
    }

    final user = _readUserFromBody(body);
    _accessToken = token;
    await _persistSession(user.id, token);
    currentUserNotifier.value = user;
    return user;
  }

  Future<void> signOut() async {
    final database = await LocalDatabase.instance.database;
    await database.delete(LocalDatabase.authSessionTable);
    _accessToken = null;
    currentUserNotifier.value = null;
  }

  Future<AppUser> updateCurrentUserProfile({
    required String firstName,
    required String lastName,
    required String email,
  }) async {
    final currentUser = currentUserNotifier.value;
    if (currentUser == null) {
      throw AuthException('Aktif kullanıcı bulunamadı.');
    }

    final cleanFirstName = firstName.trim();
    final cleanLastName = lastName.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (cleanFirstName.isEmpty || cleanLastName.isEmpty) {
      throw AuthException('Ad ve soyad alanları boş bırakılamaz.');
    }
    if (!_isValidEmail(normalizedEmail)) {
      throw AuthException('Geçerli bir e-posta adresi girin.');
    }

    final response = await _patchJson(
      '/auth/me',
      <String, Object?>{
        'email': normalizedEmail,
        'first_name': cleanFirstName,
        'last_name': cleanLastName,
      },
    );

    final updatedUser = _readUser(response);
    currentUserNotifier.value = updatedUser;
    return updatedUser;
  }

  Future<AppUser> _fetchCurrentUser() async {
    final response = await _getJson('/auth/me');
    return _readUser(response);
  }

  Future<http.Response> _getJson(String path) async {
    try {
      final response = await http
          .get(_buildUri(path), headers: _headers())
          .timeout(_requestTimeout);
      _throwIfError(response);
      return response;
    } catch (error) {
      _throwConnectionError(error);
    }
  }

  Future<http.Response> _postJson(
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
      _throwIfError(response);
      return response;
    } catch (error) {
      _throwConnectionError(error);
    }
  }

  Future<http.Response> _patchJson(
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
      _throwIfError(response);
      return response;
    } catch (error) {
      _throwConnectionError(error);
    }
  }

  Uri _buildUri(String path) => Uri.parse('$_backendBaseUrl$path');

  Map<String, String> _headers() {
    final token = _accessToken;
    return <String, String>{
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw AuthException(_readErrorMessage(response));
  }

  Never _throwConnectionError(Object error) {
    if (error is AuthException) {
      throw error;
    }
    throw AuthException(
      'Backend bağlantısı kurulamadı. Sunucunun çalıştığından emin olun.',
    );
  }

  String _readErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
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
      }
    } catch (_) {}

    if (response.statusCode == 409) {
      return 'Bu e-posta ile kayıtlı bir hesap zaten var.';
    }
    if (response.statusCode == 401) {
      return 'E-posta veya şifre hatalı.';
    }
    return 'Sunucu hatası oluştu. Lütfen tekrar deneyin.';
  }

  AppUser _readUser(http.Response response) {
    return _readUserFromBody(_decodeObject(response));
  }

  AppUser _readUserFromBody(Map<String, dynamic> body) {
    final userJson = body['user'];
    if (userJson is! Map<String, dynamic>) {
      throw AuthException('Sunucudan kullanıcı bilgisi alınamadı.');
    }
    return AppUser.fromApi(userJson);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw AuthException('Sunucudan beklenmeyen yanıt alındı.');
    }
    return decoded;
  }

  Future<void> _persistSession(String userId, String accessToken) async {
    final database = await LocalDatabase.instance.database;
    await database.delete(LocalDatabase.authSessionTable);
    await database.insert(
      LocalDatabase.authSessionTable,
      <String, Object?>{
        'user_id': userId,
        'access_token': accessToken,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }
}

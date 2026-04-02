import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

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

  final ValueNotifier<AppUser?> currentUserNotifier = ValueNotifier<AppUser?>(
    null,
  );

  bool _initialized = false;

  AppUser? get currentUser => currentUserNotifier.value;

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
      final userId = sessionRows.first['user_id'] as String?;
      if (userId != null && userId.isNotEmpty) {
        currentUserNotifier.value = await _findUserById(database, userId);
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

    final database = await LocalDatabase.instance.database;
    final existingUser = await _findUserByEmail(database, normalizedEmail);
    if (existingUser != null) {
      throw AuthException('Bu e-posta ile kayıtlı bir hesap zaten var.');
    }

    final user = AppUser(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      email: normalizedEmail,
      firstName: cleanFirstName,
      lastName: cleanLastName,
      passwordHash: _hashPassword(password),
      createdAt: DateTime.now(),
    );

    await database.insert(LocalDatabase.usersTable, user.toDatabase());
    return user;
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final database = await LocalDatabase.instance.database;
    final user = await _findUserByEmail(database, normalizedEmail);

    if (user == null || user.passwordHash != _hashPassword(password)) {
      throw AuthException('E-posta veya şifre hatalı.');
    }

    await _persistSession(database, user.id);
    currentUserNotifier.value = user;
    return user;
  }

  Future<void> signOut() async {
    final database = await LocalDatabase.instance.database;
    await database.delete(LocalDatabase.authSessionTable);
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

    final database = await LocalDatabase.instance.database;
    final existingUser = await _findUserByEmail(database, normalizedEmail);
    if (existingUser != null && existingUser.id != currentUser.id) {
      throw AuthException('Bu e-posta ile kayıtlı bir hesap zaten var.');
    }

    await database.update(
      LocalDatabase.usersTable,
      <String, Object?>{
        'email': normalizedEmail,
        'first_name': cleanFirstName,
        'last_name': cleanLastName,
      },
      where: 'id = ?',
      whereArgs: <Object?>[currentUser.id],
    );

    final updatedUser = await _findUserById(database, currentUser.id);
    if (updatedUser == null) {
      throw AuthException('Profil güncellenemedi, tekrar deneyin.');
    }

    currentUserNotifier.value = updatedUser;
    return updatedUser;
  }

  Future<AppUser?> _findUserByEmail(Database database, String email) async {
    final rows = await database.query(
      LocalDatabase.usersTable,
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return AppUser.fromDatabase(rows.first);
  }

  Future<AppUser?> _findUserById(Database database, String id) async {
    final rows = await database.query(
      LocalDatabase.usersTable,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return AppUser.fromDatabase(rows.first);
  }

  Future<void> _persistSession(Database database, String userId) async {
    await database.delete(LocalDatabase.authSessionTable);
    await database.insert(LocalDatabase.authSessionTable, {
      'user_id': userId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }
}

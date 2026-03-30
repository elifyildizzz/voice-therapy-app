import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/sz_test_record.dart';
import 'auth_service.dart';
import 'local_database.dart';

class SzTestRepository {
  SzTestRepository._();

  static final SzTestRepository instance = SzTestRepository._();
  static const String defaultUserId = 'local-user';

  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Future<Database> get _database async => LocalDatabase.instance.database;

  Future<SzTestRecord> saveRecord({
    String? userId,
    required List<double> sAttempts,
    required List<double> zAttempts,
  }) async {
    final record = SzTestRecord.create(
      userId: userId ?? AuthService.instance.currentUser?.id ?? defaultUserId,
      sAttempts: sAttempts,
      zAttempts: zAttempts,
    );

    final database = await _database;
    final id = await database.insert(
      LocalDatabase.szTestRecordsTable,
      record.toDatabase()..remove('id'),
    );

    final savedRecord = record.copyWith(id: id);
    changes.value += 1;
    return savedRecord;
  }

  Future<SzTestRecord?> fetchLatestRecord({
    String? userId,
  }) async {
    final resolvedUserId =
        userId ?? AuthService.instance.currentUser?.id ?? defaultUserId;
    final database = await _database;
    final rows = await database.query(
      LocalDatabase.szTestRecordsTable,
      where: 'user_id = ?',
      whereArgs: [resolvedUserId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return SzTestRecord.fromDatabase(rows.first);
  }

  Future<List<SzTestRecord>> fetchRecords({
    String? userId,
  }) async {
    final resolvedUserId =
        userId ?? AuthService.instance.currentUser?.id ?? defaultUserId;
    final database = await _database;
    final rows = await database.query(
      LocalDatabase.szTestRecordsTable,
      where: 'user_id = ?',
      whereArgs: [resolvedUserId],
      orderBy: 'created_at DESC',
    );

    return rows.map(SzTestRecord.fromDatabase).toList();
  }
}

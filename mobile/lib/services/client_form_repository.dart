import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/client_form_record.dart';
import 'local_database.dart';

class ClientFormRepository {
  ClientFormRepository._();

  static final ClientFormRepository instance = ClientFormRepository._();
  static const String defaultUserId = 'local-user';

  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Future<Database> get _database async => LocalDatabase.instance.database;

  Future<ClientFormRecord> saveRecord({
    String userId = defaultUserId,
    required int vrqolQ1,
    required int vrqolQ4,
    required int vrqolQ9,
    required int vhiQ3,
    required int vhiQ9,
  }) async {
    final record = ClientFormRecord.create(
      userId: userId,
      vrqolQ1: vrqolQ1,
      vrqolQ4: vrqolQ4,
      vrqolQ9: vrqolQ9,
      vhiQ3: vhiQ3,
      vhiQ9: vhiQ9,
    );

    final database = await _database;
    final id = await database.insert(
      LocalDatabase.clientFormRecordsTable,
      record.toDatabase()..remove('id'),
    );

    final savedRecord = record.copyWith(id: id);
    changes.value += 1;
    return savedRecord;
  }

  Future<ClientFormRecord?> fetchLatestRecord({
    String userId = defaultUserId,
  }) async {
    final database = await _database;
    final rows = await database.query(
      LocalDatabase.clientFormRecordsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return ClientFormRecord.fromDatabase(rows.first);
  }

  Future<List<ClientFormRecord>> fetchRecords({
    String userId = defaultUserId,
  }) async {
    final database = await _database;
    final rows = await database.query(
      LocalDatabase.clientFormRecordsTable,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );

    return rows.map(ClientFormRecord.fromDatabase).toList();
  }
}

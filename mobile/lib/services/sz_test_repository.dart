import 'package:flutter/foundation.dart';

import '../models/sz_test_record.dart';
import 'auth_service.dart';
import 'backend_api_client.dart';

class SzTestRepository {
  SzTestRepository._();

  static final SzTestRepository instance = SzTestRepository._();
  static const String defaultUserId = 'local-user';

  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Future<SzTestRecord> saveRecord({
    String? userId,
    required List<double> sAttempts,
    required List<double> zAttempts,
  }) async {
    final body = await BackendApiClient.instance.postJson(
      '/sz-test-records',
      <String, Object?>{
        's_attempts': sAttempts,
        'z_attempts': zAttempts,
      },
    );

    final recordJson = body['record'];
    if (recordJson is! Map<String, dynamic>) {
      throw const BackendApiException('S/Z testi kaydı okunamadı.');
    }
    final savedRecord = SzTestRecord.fromApi(recordJson);
    changes.value += 1;
    return savedRecord;
  }

  Future<SzTestRecord?> fetchLatestRecord({
    String? userId,
  }) async {
    if (AuthService.instance.currentUser == null) {
      return null;
    }

    final body =
        await BackendApiClient.instance.getJson('/sz-test-records/latest');
    final recordJson = body['record'];
    if (recordJson == null) {
      return null;
    }
    if (recordJson is! Map<String, dynamic>) {
      throw const BackendApiException('S/Z testi kaydı okunamadı.');
    }
    return SzTestRecord.fromApi(recordJson);
  }

  Future<List<SzTestRecord>> fetchRecords({
    String? userId,
  }) async {
    if (AuthService.instance.currentUser == null) {
      return const <SzTestRecord>[];
    }

    final body = await BackendApiClient.instance.getJson('/sz-test-records');
    final recordsJson = body['records'];
    if (recordsJson is! List) {
      throw const BackendApiException('S/Z testi geçmişi okunamadı.');
    }
    return recordsJson
        .whereType<Map<String, dynamic>>()
        .map(SzTestRecord.fromApi)
        .toList();
  }
}

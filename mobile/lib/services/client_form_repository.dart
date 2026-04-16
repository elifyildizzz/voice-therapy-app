import 'package:flutter/foundation.dart';

import '../models/client_form_record.dart';
import 'auth_service.dart';
import 'backend_api_client.dart';

class ClientFormRepository {
  ClientFormRepository._();

  static final ClientFormRepository instance = ClientFormRepository._();
  static const String defaultUserId = 'local-user';

  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  Future<ClientFormRecord> saveRecord({
    String? userId,
    required int vrqolQ1,
    required int vrqolQ4,
    required int vrqolQ9,
    required int vhiQ3,
    required int vhiQ9,
  }) async {
    final body = await BackendApiClient.instance.postJson(
      '/client-form-records',
      <String, Object?>{
        'responses': <String, Object?>{
          'vrqol_q1': vrqolQ1,
          'vrqol_q4': vrqolQ4,
          'vrqol_q9': vrqolQ9,
          'vhi_q3': vhiQ3,
          'vhi_q9': vhiQ9,
        },
      },
    );

    final recordJson = body['record'];
    if (recordJson is! Map<String, dynamic>) {
      throw const BackendApiException('Form kaydı okunamadı.');
    }
    final savedRecord = ClientFormRecord.fromApi(recordJson);
    changes.value += 1;
    return savedRecord;
  }

  Future<ClientFormRecord?> fetchLatestRecord({
    String? userId,
  }) async {
    if (AuthService.instance.currentUser == null) {
      return null;
    }

    final body =
        await BackendApiClient.instance.getJson('/client-form-records/latest');
    final recordJson = body['record'];
    if (recordJson == null) {
      return null;
    }
    if (recordJson is! Map<String, dynamic>) {
      throw const BackendApiException('Form kaydı okunamadı.');
    }
    return ClientFormRecord.fromApi(recordJson);
  }

  Future<List<ClientFormRecord>> fetchRecords({
    String? userId,
  }) async {
    if (AuthService.instance.currentUser == null) {
      return const <ClientFormRecord>[];
    }

    final body =
        await BackendApiClient.instance.getJson('/client-form-records');
    final recordsJson = body['records'];
    if (recordsJson is! List) {
      throw const BackendApiException('Form geçmişi okunamadı.');
    }
    return recordsJson
        .whereType<Map<String, dynamic>>()
        .map(ClientFormRecord.fromApi)
        .toList();
  }
}

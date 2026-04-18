import 'package:flutter/foundation.dart';

import '../models/measurement_record.dart';
import 'auth_service.dart';
import 'backend_api_client.dart';

class MeasurementSaveLimitException implements Exception {
  const MeasurementSaveLimitException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MeasurementRepository {
  MeasurementRepository._();

  static final MeasurementRepository instance = MeasurementRepository._();
  static const String vocalFunctionModule = 'vocal_function';
  static const String breathControlModule = 'breath_control';

  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  List<MeasurementRecord> _cachedRecords = const <MeasurementRecord>[];
  bool _hasLoadedCache = false;
  String? _cachedUserId;

  bool get hasLoadedCache => _hasLoadedCache;

  String? get _currentUserId => AuthService.instance.currentUser?.id;

  Future<int> saveRecord({
    required String module,
    required String exerciseKey,
    required String exerciseTitle,
    required Duration duration,
  }) async {
    final now = DateTime.now();
    final slotCount = peekRecordsForDate(
      clientDate: _formatClientDate(now),
      module: module,
      exerciseKey: exerciseKey,
    ).length;

    try {
      final body = await BackendApiClient.instance.postJson(
        '/measurement-records',
        <String, Object?>{
          'module': module,
          'exercise_key': exerciseKey,
          'exercise_title': exerciseTitle,
          'duration_ms': duration.inMilliseconds,
          'performed_at': now.toIso8601String(),
          'client_date': _formatClientDate(now),
        },
      );

      final recordJson = body['record'];
      if (recordJson is! Map<String, dynamic>) {
        throw const BackendApiException('Olcum kaydi okunamadi.');
      }

      _upsertCachedRecord(MeasurementRecord.fromApi(recordJson));
      changes.value += 1;
      return slotCount + 1;
    } on BackendApiException catch (error) {
      if (error.message == 'Bugün için iki ölçüm zaten kaydedildi.') {
        throw MeasurementSaveLimitException(error.message);
      }
      rethrow;
    }
  }

  Future<List<MeasurementRecord>> fetchRecords({
    bool forceRefresh = false,
  }) async {
    _invalidateCacheIfUserChanged();

    if (AuthService.instance.currentUser == null) {
      return const <MeasurementRecord>[];
    }

    if (_hasLoadedCache && !forceRefresh) {
      return List<MeasurementRecord>.unmodifiable(_cachedRecords);
    }

    final body =
        await BackendApiClient.instance.getJson('/measurement-records');
    final recordsByDayJson = body['records_by_day'];
    if (recordsByDayJson is! Map<String, dynamic>) {
      throw const BackendApiException('Olcum gecmisi okunamadi.');
    }

    final records = <MeasurementRecord>[];
    for (final dayRecords in recordsByDayJson.values) {
      if (dayRecords is! List) {
        continue;
      }
      records.addAll(
        dayRecords
            .whereType<Map<String, dynamic>>()
            .map(MeasurementRecord.fromApi),
      );
    }

    records
        .sort((left, right) => right.performedAt.compareTo(left.performedAt));
    _cachedRecords = List<MeasurementRecord>.unmodifiable(records);
    _cachedUserId = _currentUserId;
    _hasLoadedCache = true;
    return _cachedRecords;
  }

  Future<List<MeasurementRecord>> fetchRecordsForDay(DateTime day) async {
    final records = await fetchRecords();
    return _filterAndSort(
      records,
      clientDate: _formatClientDate(day),
    );
  }

  Future<List<MeasurementRecord>> fetchRecordsForToday({
    required String module,
    required String exerciseKey,
  }) async {
    final records = await fetchRecords();
    return _filterAndSort(
      records,
      clientDate: _formatClientDate(DateTime.now()),
      module: module,
      exerciseKey: exerciseKey,
    );
  }

  List<MeasurementRecord> peekRecords() {
    _invalidateCacheIfUserChanged();
    if (!_hasLoadedCache) {
      return const <MeasurementRecord>[];
    }
    return List<MeasurementRecord>.unmodifiable(_cachedRecords);
  }

  List<MeasurementRecord> peekRecordsForToday({
    required String module,
    required String exerciseKey,
  }) {
    return peekRecordsForDate(
      clientDate: _formatClientDate(DateTime.now()),
      module: module,
      exerciseKey: exerciseKey,
    );
  }

  List<MeasurementRecord> peekRecordsForDate({
    required String clientDate,
    String? module,
    String? exerciseKey,
  }) {
    _invalidateCacheIfUserChanged();
    if (!_hasLoadedCache) {
      return const <MeasurementRecord>[];
    }
    return _filterAndSort(
      _cachedRecords,
      clientDate: clientDate,
      module: module,
      exerciseKey: exerciseKey,
    );
  }

  String _formatClientDate(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  void _invalidateCacheIfUserChanged() {
    final userId = _currentUserId;
    if (_cachedUserId == userId) {
      return;
    }
    _cachedUserId = userId;
    _cachedRecords = const <MeasurementRecord>[];
    _hasLoadedCache = false;
  }

  List<MeasurementRecord> _filterAndSort(
    List<MeasurementRecord> records, {
    required String clientDate,
    String? module,
    String? exerciseKey,
  }) {
    final filtered = records
        .where(
          (record) =>
              record.clientDate == clientDate &&
              (module == null || record.module == module) &&
              (exerciseKey == null || record.exerciseKey == exerciseKey),
        )
        .toList(growable: true)
      ..sort((left, right) => left.performedAt.compareTo(right.performedAt));
    return List<MeasurementRecord>.unmodifiable(filtered);
  }

  void _upsertCachedRecord(MeasurementRecord record) {
    _invalidateCacheIfUserChanged();

    final mutable = _cachedRecords.toList(growable: true);
    final existingIndex = mutable.indexWhere((item) => item.id == record.id);
    if (existingIndex >= 0) {
      mutable[existingIndex] = record;
    } else {
      mutable.add(record);
    }
    mutable
        .sort((left, right) => right.performedAt.compareTo(left.performedAt));
    _cachedRecords = List<MeasurementRecord>.unmodifiable(mutable);
    _cachedUserId = _currentUserId;
    _hasLoadedCache = true;
  }
}

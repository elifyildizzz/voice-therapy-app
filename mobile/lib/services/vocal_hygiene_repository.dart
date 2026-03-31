import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/vocal_hygiene_question.dart';
import '../models/vocal_hygiene_survey_response.dart';
import 'auth_service.dart';
import 'local_database.dart';

class VocalHygieneRepository {
  VocalHygieneRepository._();

  static final VocalHygieneRepository instance = VocalHygieneRepository._();

  static const List<VocalHygieneQuestion> questions = <VocalHygieneQuestion>[
    VocalHygieneQuestion(
      id: 'water',
      title: 'Günlük ne kadar su içiyorsun?',
      type: VocalHygieneQuestionType.singleChoice,
      options: <VocalHygieneOption>[
        VocalHygieneOption(id: '0_1', label: '0-1 litre'),
        VocalHygieneOption(id: '1_2', label: '1-2 litre'),
        VocalHygieneOption(id: '2_plus', label: '2 litre ve üzeri'),
      ],
    ),
    VocalHygieneQuestion(
      id: 'voice_usage',
      title: 'Gün içinde sesini ne kadar yoğun kullanıyorsun?',
      type: VocalHygieneQuestionType.singleChoice,
      options: <VocalHygieneOption>[
        VocalHygieneOption(id: 'low', label: 'Az'),
        VocalHygieneOption(id: 'medium', label: 'Orta'),
        VocalHygieneOption(id: 'high', label: 'Çok fazla'),
      ],
    ),
    VocalHygieneQuestion(
      id: 'noisy_env',
      title: 'Gürültülü ortamlarda konuşmak zorunda kalır mısın?',
      type: VocalHygieneQuestionType.singleChoice,
      options: <VocalHygieneOption>[
        VocalHygieneOption(id: 'no', label: 'Hayır'),
        VocalHygieneOption(id: 'sometimes', label: 'Bazen'),
        VocalHygieneOption(id: 'often', label: 'Sık sık'),
      ],
    ),
    VocalHygieneQuestion(
      id: 'symptoms',
      title: 'Aşağıdakilerden hangilerini yaşıyorsun?',
      type: VocalHygieneQuestionType.multiChoice,
      options: <VocalHygieneOption>[
        VocalHygieneOption(id: 'dryness', label: 'Boğaz kuruluğu'),
        VocalHygieneOption(id: 'hoarseness', label: 'Ses kısıklığı'),
        VocalHygieneOption(id: 'fatigue', label: 'Ses yorgunluğu'),
        VocalHygieneOption(id: 'burning', label: 'Boğazda yanma'),
        VocalHygieneOption(
          id: 'morning_worse',
          label: 'Sabah sesinde kötüleşme',
        ),
        VocalHygieneOption(id: 'none', label: 'Hiçbiri'),
      ],
    ),
    VocalHygieneQuestion(
      id: 'throat_clearing',
      title: 'Boğazını temizleme ihtiyacı ne sıklıkta olur?',
      type: VocalHygieneQuestionType.singleChoice,
      options: <VocalHygieneOption>[
        VocalHygieneOption(id: 'never', label: 'Hiç'),
        VocalHygieneOption(id: 'sometimes', label: 'Ara sıra'),
        VocalHygieneOption(id: 'often', label: 'Sık sık'),
      ],
    ),
    VocalHygieneQuestion(
      id: 'caffeine',
      title: 'Kafein tüketimin nasıl?',
      type: VocalHygieneQuestionType.singleChoice,
      options: <VocalHygieneOption>[
        VocalHygieneOption(id: 'rare', label: 'Nadiren'),
        VocalHygieneOption(id: '1_2', label: 'Günde 1-2'),
        VocalHygieneOption(id: '3_plus', label: 'Günde 3+'),
      ],
    ),
    VocalHygieneQuestion(
      id: 'smoke',
      title: 'Sigara dumanına maruz kalıyor musun?',
      type: VocalHygieneQuestionType.singleChoice,
      options: <VocalHygieneOption>[
        VocalHygieneOption(id: 'no', label: 'Hayır'),
        VocalHygieneOption(id: 'sometimes', label: 'Ara sıra'),
        VocalHygieneOption(id: 'often', label: 'Sık sık'),
      ],
    ),
    VocalHygieneQuestion(
      id: 'talking_time',
      title: 'Gün içinde ne kadar konuşuyorsun?',
      type: VocalHygieneQuestionType.singleChoice,
      options: <VocalHygieneOption>[
        VocalHygieneOption(id: 'low', label: 'Az (1 saatten az)'),
        VocalHygieneOption(id: 'medium', label: 'Orta (1-3 saat)'),
        VocalHygieneOption(id: 'high', label: 'Çok (3+ saat)'),
      ],
    ),
    VocalHygieneQuestion(
      id: 'reflux',
      title: 'Reflü / mide hassasiyeti yaşıyor musun?',
      type: VocalHygieneQuestionType.singleChoice,
      options: <VocalHygieneOption>[
        VocalHygieneOption(id: 'no', label: 'Hayır'),
        VocalHygieneOption(id: 'sometimes', label: 'Bazen'),
        VocalHygieneOption(id: 'often', label: 'Sık sık'),
      ],
    ),
  ];

  Future<Database> get _database async => LocalDatabase.instance.database;

  Future<void> saveResponse(VocalHygieneSurveyResponse response) async {
    final currentUserId = AuthService.instance.currentUser?.id;
    if (currentUserId == null) {
      return;
    }

    final database = await _database;

    await database.insert(
      LocalDatabase.vocalHygieneSurveyTable,
      <String, Object?>{
        'user_id': currentUserId,
        'answers_json': jsonEncode(response.answers),
        'created_at': response.createdAt.millisecondsSinceEpoch,
      },
    );
  }

  Future<VocalHygieneSurveyResponse?> fetchLatestResponse(
      {String? userId}) async {
    final resolvedUserId = userId ?? AuthService.instance.currentUser?.id;
    if (resolvedUserId == null) {
      return null;
    }

    final database = await _database;
    final rows = await database.query(
      LocalDatabase.vocalHygieneSurveyTable,
      where: 'user_id = ?',
      whereArgs: <Object?>[resolvedUserId],
      orderBy: 'created_at DESC',
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    final rawAnswers = jsonDecode(row['answers_json'] as String);
    final answers = <String, List<String>>{};

    if (rawAnswers is Map<String, dynamic>) {
      for (final entry in rawAnswers.entries) {
        final value = entry.value;
        if (value is List) {
          answers[entry.key] =
              value.whereType<String>().toList(growable: false);
        }
      }
    }

    return VocalHygieneSurveyResponse(
      answers: answers,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
    );
  }
}

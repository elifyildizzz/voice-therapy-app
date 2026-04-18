import '../models/vocal_hygiene_question.dart';
import '../models/vocal_hygiene_survey_response.dart';
import 'auth_service.dart';
import 'backend_api_client.dart';

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

  Future<void> saveResponse(VocalHygieneSurveyResponse response) async {
    if (AuthService.instance.currentUser == null) {
      return;
    }

    await BackendApiClient.instance.postJson(
      '/vocal-hygiene/responses',
      <String, Object?>{
        'answers': response.answers,
      },
    );
  }

  Future<VocalHygieneSurveyResponse?> fetchLatestResponse(
      {String? userId}) async {
    if (AuthService.instance.currentUser == null) {
      return null;
    }

    final body = await BackendApiClient.instance
        .getJson('/vocal-hygiene/responses/latest');
    final responseJson = body['response'];
    if (responseJson == null) {
      return null;
    }
    if (responseJson is! Map<String, dynamic>) {
      throw const BackendApiException('Vokal hijyen cevabı okunamadı.');
    }
    return VocalHygieneSurveyResponse.fromApi(responseJson);
  }
}

import 'vocal_hygiene_survey_response.dart';

enum VocalHygieneTopic {
  hydration,
  nutrition,
  voiceUsage,
  environmentalFactors,
  irritants,
  voiceRest,
  throatClearing,
  refluxControl,
}

class VocalHygienePersonalizationResult {
  const VocalHygienePersonalizationResult({
    required this.scores,
    required this.orderedTopics,
    required this.importantTopics,
  });

  final Map<VocalHygieneTopic, int> scores;
  final List<VocalHygieneTopic> orderedTopics;
  final Set<VocalHygieneTopic> importantTopics;
}

class VocalHygienePersonalizer {
  static const List<VocalHygieneTopic> defaultOrder = <VocalHygieneTopic>[
    VocalHygieneTopic.hydration,
    VocalHygieneTopic.nutrition,
    VocalHygieneTopic.voiceUsage,
    VocalHygieneTopic.environmentalFactors,
    VocalHygieneTopic.irritants,
    VocalHygieneTopic.voiceRest,
    VocalHygieneTopic.throatClearing,
    VocalHygieneTopic.refluxControl,
  ];

  static VocalHygienePersonalizationResult evaluate(
    VocalHygieneSurveyResponse response,
  ) {
    final scores = <VocalHygieneTopic, int>{
      for (final topic in defaultOrder) topic: 0,
    };

    final water = response.single('water');
    if (water == '0_1') {
      _add(scores, VocalHygieneTopic.hydration, 4);
      _add(scores, VocalHygieneTopic.nutrition, 1);
    } else if (water == '1_2') {
      _add(scores, VocalHygieneTopic.hydration, 2);
    }

    final voiceUsage = response.single('voice_usage');
    if (voiceUsage == 'high') {
      _add(scores, VocalHygieneTopic.voiceUsage, 3);
      _add(scores, VocalHygieneTopic.voiceRest, 2);
    } else if (voiceUsage == 'medium') {
      _add(scores, VocalHygieneTopic.voiceUsage, 1);
    }

    final noisy = response.single('noisy_env');
    if (noisy == 'often') {
      _add(scores, VocalHygieneTopic.voiceUsage, 2);
      _add(scores, VocalHygieneTopic.voiceRest, 2);
      _add(scores, VocalHygieneTopic.environmentalFactors, 2);
    } else if (noisy == 'sometimes') {
      _add(scores, VocalHygieneTopic.voiceUsage, 1);
      _add(scores, VocalHygieneTopic.voiceRest, 1);
      _add(scores, VocalHygieneTopic.environmentalFactors, 1);
    }

    final symptoms = response.multiple('symptoms').toSet();
    if (symptoms.contains('dryness')) {
      _add(scores, VocalHygieneTopic.throatClearing, 2);
      _add(scores, VocalHygieneTopic.hydration, 1);
    }
    if (symptoms.contains('hoarseness')) {
      _add(scores, VocalHygieneTopic.voiceRest, 2);
      _add(scores, VocalHygieneTopic.voiceUsage, 1);
    }
    if (symptoms.contains('fatigue')) {
      _add(scores, VocalHygieneTopic.voiceRest, 3);
    }
    if (symptoms.contains('burning')) {
      _add(scores, VocalHygieneTopic.refluxControl, 1);
      _add(scores, VocalHygieneTopic.irritants, 1);
    }
    if (symptoms.contains('morning_worse')) {
      _add(scores, VocalHygieneTopic.refluxControl, 2);
    }

    final throatClearing = response.single('throat_clearing');
    if (throatClearing == 'often') {
      _add(scores, VocalHygieneTopic.throatClearing, 3);
      _add(scores, VocalHygieneTopic.voiceRest, 1);
    } else if (throatClearing == 'sometimes') {
      _add(scores, VocalHygieneTopic.throatClearing, 1);
    }

    final caffeine = response.single('caffeine');
    if (caffeine == '3_plus') {
      _add(scores, VocalHygieneTopic.irritants, 3);
      _add(scores, VocalHygieneTopic.nutrition, 1);
    } else if (caffeine == '1_2') {
      _add(scores, VocalHygieneTopic.irritants, 1);
      _add(scores, VocalHygieneTopic.nutrition, 1);
    }

    final smoke = response.single('smoke');
    if (smoke == 'often') {
      _add(scores, VocalHygieneTopic.irritants, 3);
      _add(scores, VocalHygieneTopic.environmentalFactors, 2);
    } else if (smoke == 'sometimes') {
      _add(scores, VocalHygieneTopic.irritants, 1);
      _add(scores, VocalHygieneTopic.environmentalFactors, 1);
    }

    final talking = response.single('talking_time');
    if (talking == 'high') {
      _add(scores, VocalHygieneTopic.voiceUsage, 2);
      _add(scores, VocalHygieneTopic.voiceRest, 1);
    } else if (talking == 'medium') {
      _add(scores, VocalHygieneTopic.voiceUsage, 1);
    }

    final reflux = response.single('reflux');
    if (reflux == 'often') {
      _add(scores, VocalHygieneTopic.refluxControl, 4);
    } else if (reflux == 'sometimes') {
      _add(scores, VocalHygieneTopic.refluxControl, 2);
    }

    final orderedTopics = List<VocalHygieneTopic>.from(defaultOrder)
      ..sort((a, b) {
        final byScore = (scores[b] ?? 0).compareTo(scores[a] ?? 0);
        if (byScore != 0) {
          return byScore;
        }
        return defaultOrder.indexOf(a).compareTo(defaultOrder.indexOf(b));
      });

    final importantTopics = <VocalHygieneTopic>{};
    for (final topic in orderedTopics.take(2)) {
      if ((scores[topic] ?? 0) >= 4) {
        importantTopics.add(topic);
      }
    }

    return VocalHygienePersonalizationResult(
      scores: scores,
      orderedTopics: orderedTopics,
      importantTopics: importantTopics,
    );
  }

  static void _add(
    Map<VocalHygieneTopic, int> scores,
    VocalHygieneTopic topic,
    int points,
  ) {
    scores[topic] = (scores[topic] ?? 0) + points;
  }
}

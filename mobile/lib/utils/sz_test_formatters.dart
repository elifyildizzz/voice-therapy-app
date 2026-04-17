String formatSzSeconds(double value) => '${value.toStringAsFixed(1)} sn';

String formatSzDate(DateTime value, {bool withTime = false}) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();

  if (!withTime) {
    return '$day.$month.$year';
  }

  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day.$month.$year • $hour:$minute';
}

String buildSzRatioNote(double ratio) {
  if (ratio == 0) {
    return 'Oran hesaplanamadı. Sonuç ön değerlendirme amaçlıdır.';
  }

  if (ratio > 1.4) {
    return 'Hesaplanan s/z oranınız (>1.4), ses tellerinizin hava kaçağı yaptığına veya titreşim verimliliğinin azaldığına işaret ediyor olabilir. Ses tellerinizin fiziksel durumunu netleştirmek için bir Kulak Burun Boğaz uzmanına görünmeniz önerilir. Uzman kontrolü gerçekleşene kadar sesinizi zorlamaktan (bağırmak, uzun süre yüksek sesle konuşmak) kaçının.';
  }

  return 's/z oranınız (<1.4) normal sınırlar içerisinde. Bu sonuç, nefes desteğinizin ve ses tellerinizin birbirine uyumlu çalıştığını gösterir. Mevcut ses sağlığınızı korumak için vokal hijyen kurallarına uymaya devam edebilirsiniz.';
}

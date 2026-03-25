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
  if (ratio < 0.9) {
    return 'S ve Z süreleri arasında fark görünüyor. Sonuç ön değerlendirme amaçlıdır.';
  }
  if (ratio <= 1.2) {
    return 'S ve Z süreleri birbirine yakın görünüyor. Sonuç ön değerlendirme amaçlıdır.';
  }
  return 'S süresi, Z süresine göre daha uzun görünüyor. Sonuç ön değerlendirme amaçlıdır.';
}

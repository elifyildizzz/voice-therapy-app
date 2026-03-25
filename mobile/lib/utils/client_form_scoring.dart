int calculateClientFormTotalScore({
  required int vrqolQ1,
  required int vrqolQ4,
  required int vrqolQ9,
  required int vhiQ3,
  required int vhiQ9,
}) {
  return vrqolQ1 + vrqolQ4 + vrqolQ9 + vhiQ3 + vhiQ9;
}

String resolveClientFormResultLabel(int totalScore) {
  if (totalScore <= 4) {
    return 'Düşük düzeyde etkilenim';
  }
  if (totalScore <= 9) {
    return 'Hafif düzeyde etkilenim';
  }
  if (totalScore <= 14) {
    return 'Orta düzeyde etkilenim';
  }
  return 'Yüksek düzeyde etkilenim';
}

String buildClientFormResultNote() {
  return 'Bu sonuç ön değerlendirme amaçlıdır ve klinik değerlendirme yerine geçmez.';
}

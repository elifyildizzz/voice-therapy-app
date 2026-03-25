class ClientFormQuestion {
  const ClientFormQuestion({
    required this.fieldKey,
    required this.prompt,
  });

  final String fieldKey;
  final String prompt;
}

class ClientFormScaleOption {
  const ClientFormScaleOption({
    required this.value,
    required this.label,
  });

  final int value;
  final String label;
}

const List<ClientFormQuestion> clientFormQuestions = [
  ClientFormQuestion(
    fieldKey: 'vrqolQ1',
    prompt:
        'Gürültülü ortamlarda, sesimi duyurmakta veya yüksek sesle konuşmakta güçlük çekiyorum.',
  ),
  ClientFormQuestion(
    fieldKey: 'vrqolQ4',
    prompt:
        'Sesim nedeniyle bazen gerginleşiyor veya hayal kırıklığına uğruyorum.',
  ),
  ClientFormQuestion(
    fieldKey: 'vrqolQ9',
    prompt:
        'Doğru anlaşılması için söylediklerimi tekrar etmek zorunda kalıyorum.',
  ),
  ClientFormQuestion(
    fieldKey: 'vhiQ3',
    prompt: 'İnsanlar bana “Sesin neden böyle?” diye sorar.',
  ),
  ClientFormQuestion(
    fieldKey: 'vhiQ9',
    prompt: 'Konuşurken büyük çaba harcıyorum.',
  ),
];

const List<ClientFormScaleOption> clientFormScaleOptions = [
  ClientFormScaleOption(value: 0, label: 'Yok / Asla'),
  ClientFormScaleOption(value: 1, label: 'Hafif / Nadiren'),
  ClientFormScaleOption(value: 2, label: 'Orta / Bazen'),
  ClientFormScaleOption(value: 3, label: 'Belirgin / Sıklıkla'),
  ClientFormScaleOption(value: 4, label: 'Çok / Her zaman'),
];

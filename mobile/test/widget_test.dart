import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App opens home shell with voice assessment entry',
      (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceTherapyApp());

    expect(find.text('Hoşgeldiniz, İlayda'), findsOneWidget);
    expect(find.text('Ses Değerlendirme Testleri'), findsOneWidget);
  });
}

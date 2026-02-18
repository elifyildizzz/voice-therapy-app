import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App opens voice analyze screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VoiceTherapyApp());

    expect(find.text('Ses Analizi'), findsOneWidget);
    expect(find.text('Ses Kaydı Başlat'), findsOneWidget);
  });
}

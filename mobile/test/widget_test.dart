import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/main.dart';

void main() {
  testWidgets('App opens home shell with voice assessment entry',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VoiceTherapyApp());
    await tester.pumpAndSettle();

    expect(find.text('Hoş geldiniz'), findsOneWidget);
    expect(find.text('Ses Değerlendirme'), findsOneWidget);
  });
}

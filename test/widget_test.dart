import 'package:app_couple_system/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('La pantalla inicial presenta los módulos previstos', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(const CoupleApp());
    expect(find.text('Nuestro espacio'), findsOneWidget);
    expect(find.text('Comidas'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Lugares'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lugares'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Calendario'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Calendario'), findsOneWidget);
    expect(find.textContaining('Próximamente'), findsNothing);
  });
}

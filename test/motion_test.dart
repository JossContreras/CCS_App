import 'package:app_couple_system/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('El arcoíris se mueve y respeta reducir movimiento', (
    tester,
  ) async {
    Widget app(bool reduced) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: const Scaffold(body: RainbowMomentCard()),
      ),
    );
    Color firstColor() =>
        (tester
                    .widget<Container>(
                      find.byKey(const ValueKey('rainbow-card-gradient')),
                    )
                    .decoration!
                as BoxDecoration)
            .gradient!
            .colors
            .first;
    await tester.pumpWidget(app(false));
    final start = firstColor();
    await tester.pump(const Duration(seconds: 1));
    expect(firstColor(), isNot(start));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = firstColor();
    await tester.pump(const Duration(seconds: 1));
    expect(firstColor(), paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(firstColor(), isNot(paused));
    await tester.pumpWidget(app(true));
    final stopped = firstColor();
    await tester.pump(const Duration(seconds: 1));
    expect(firstColor(), stopped);
  });

  testWidgets(
    'La confirmación se muestra y se cierra con movimiento reducido',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showSaveConfirmation(context),
                  child: const Text('Guardar'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(find.byKey(const ValueKey('save-label')), findsOneWidget);
      expect(find.text('Guardado'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 850));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('save-label')), findsNothing);
    },
  );
  testWidgets('La confirmación animada termina automáticamente', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSaveConfirmation(context),
              child: const Text('Guardar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    expect(find.byKey(const ValueKey('save-label')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('save-confirmation-screen'))),
      tester.view.physicalSize / tester.view.devicePixelRatio,
    );
    expect(find.byKey(const ValueKey('save-water-animation')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('save-label')), findsNothing);
  });
}

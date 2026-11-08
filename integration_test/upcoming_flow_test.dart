import 'package:app_couple_system/main.dart';
import 'package:app_couple_system/app_style.dart';
import 'package:app_couple_system/calendar/calendar_screen.dart';
import 'package:app_couple_system/meals/meal_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Inicio abre y actualiza momentos próximos', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final dbPath = path.join(
      await getDatabasesPath(),
      'upcoming_test_${const Uuid().v4()}.db',
    );
    final repo = await SqliteMealRepository.openAt(dbPath);
    final today = DateTime.now();
    CalendarEntry entry(String id, String kind, String title, int offset) =>
        CalendarEntry(
          id: id,
          kind: kind,
          title: title,
          date: DateTime(today.year, today.month, today.day + offset),
          description: '',
        );
    await repo.saveCalendarEntry(
      entry('a', 'reminder', 'Aniversario de prueba', 0),
    );
    await repo.saveCalendarEntry(
      entry('b', 'appointment', 'Salida de prueba', 1),
    );
    await repo.saveCalendarEntry(entry('c', 'reminder', 'Fecha posterior', 2));
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          themeMode: ThemeMode.system,
          onThemeChanged: (_) {},
          repository: repo,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aniversario de prueba'), findsOneWidget);
    expect(find.text('Salida de prueba'), findsOneWidget);
    expect(find.text('Fecha posterior'), findsNothing);
    await tester.tap(find.text('Salida de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle de la cita'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aniversario de prueba'));
    await tester.pumpAndSettle();
    expect(find.textContaining('no se repite automáticamente'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Aniversario actualizado',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Aniversario actualizado'), findsOneWidget);
    await repo.deleteCalendarEntry('a');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Aniversario actualizado'), findsNothing);
    expect(find.text('Fecha posterior'), findsOneWidget);
    await repo.saveCalendarEntry(entry('d', 'appointment', 'Cita de hoy', 0));
    await repo.saveCalendarEntry(entry('e', 'reminder', 'Nota de hoy', 0));
    await tester.pumpWidget(
      MaterialApp(home: CalendarScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    final dayCell = find.byWidgetPredicate(
      (widget) =>
          widget is Semantics &&
          (widget.properties.label?.contains('1 citas, 1 recordatorios') ??
              false),
    );
    expect(dayCell, findsOneWidget);
    expect(
      find.descendant(
        of: dayCell,
        matching: find.byIcon(Icons.favorite_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dayCell, matching: find.byIcon(Icons.circle)),
      findsOneWidget,
    );
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    for (final theme in [AppStyle.theme, AppStyle.darkTheme]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: HomeScreen(
              themeMode: ThemeMode.system,
              onThemeChanged: (_) {},
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.database.close();
    await deleteDatabase(dbPath);
  });
}

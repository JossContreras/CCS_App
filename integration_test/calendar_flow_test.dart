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
  testWidgets('Citas y recordatorios conservan comidas en Android', (
    tester,
  ) async {
    final dbPath = path.join(
      await getDatabasesPath(),
      'calendar_test_${const Uuid().v4()}.db',
    );
    final repo = await SqliteMealRepository.openAt(dbPath);
    await repo.saveMeal(
      Meal(
        id: 'meal',
        name: 'Tacos para vincular',
        date: DateTime.now().subtract(const Duration(days: 1)),
        type: 'Cena',
        ingredients: '',
        categories: [],
        people: ['1'],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: CalendarScreen(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nueva cita'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Salida de prueba',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Salida de prueba'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Salida de prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vincular comida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tacos para vincular'));
    await tester.pumpAndSettle();
    expect(find.text('Actualizar y vincular'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect((await repo.getMealPage()).items.single.appointmentId, isNull);
    await tester.tap(find.text('Tacos para vincular'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vincular'));
    await tester.pumpAndSettle();
    expect((await repo.getMealPage()).items.single.appointmentId, isNotNull);
    await tester.tap(find.byTooltip('Eliminar cita'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect((await repo.getMealPage()).items.single.appointmentId, isNull);
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuevo recordatorio'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Nota de prueba');
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect((await repo.getCalendarEntries()).single.kind, 'reminder');
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.database.close();
    await deleteDatabase(dbPath);
  });
}

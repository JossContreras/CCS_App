import 'dart:io';
import 'package:app_couple_system/meals/meal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  test(
    'Próximos momentos incluye hoy, ordena empates y limita a dos',
    () async {
      final dir = await Directory.systemTemp.createTemp('couple_upcoming_');
      final repo = await SqliteMealRepository.openAt(path.join(dir.path, 'db'));
      final today = DateTime(2026, 11, 8);
      CalendarEntry entry(String id, String kind, int days) => CalendarEntry(
        id: id,
        kind: kind,
        title: id,
        date: today.add(Duration(days: days)),
        description: '',
      );
      expect(await repo.getUpcomingEntries(today: today), isEmpty);
      await repo.saveCalendarEntry(entry('pasado', 'reminder', -1));
      await repo.saveCalendarEntry(entry('b', 'appointment', 0));
      expect((await repo.getUpcomingEntries(today: today)).map((e) => e.id), [
        'b',
      ]);
      await repo.saveCalendarEntry(entry('a', 'reminder', 0));
      await repo.saveCalendarEntry(entry('futuro', 'appointment', 1));
      expect((await repo.getUpcomingEntries(today: today)).map((e) => e.id), [
        'a',
        'b',
      ]);
      await repo.deleteCalendarEntry('a');
      expect((await repo.getUpcomingEntries(today: today)).map((e) => e.id), [
        'b',
        'futuro',
      ]);
      await repo.database.close();
      await dir.delete(recursive: true);
    },
  );
  test(
    'Los vínculos requieren confirmación y conservarán las comidas',
    () async {
      final dir = await Directory.systemTemp.createTemp('couple_calendar_');
      final repo = await SqliteMealRepository.openAt(path.join(dir.path, 'db'));
      const a = MealPlace(
        id: 'a',
        name: 'Parque',
        latitude: 20,
        longitude: -101,
      );
      const b = MealPlace(id: 'b', name: 'Casa', latitude: 20, longitude: -101);
      await repo.savePlace(a);
      await repo.savePlace(b);
      final day = DateTime(2026, 11, 8);
      CalendarEntry entry(String id, DateTime date, String? place) =>
          CalendarEntry(
            id: id,
            kind: 'appointment',
            title: id,
            description: '',
            date: date,
            placeId: place,
          );
      await repo.saveCalendarEntry(entry('cita', day, a.id));
      await repo.saveMeal(
        Meal(
          id: 'meal',
          name: 'Tacos',
          date: day.add(const Duration(days: 1)),
          type: 'Cena',
          ingredients: '',
          categories: [],
          people: ['1'],
          placeId: b.id,
        ),
      );
      await expectLater(
        repo.linkMealToAppointment('meal', 'cita'),
        throwsStateError,
      );
      var meal = (await repo.getMealPage()).items.single;
      expect(meal.appointmentId, isNull);
      expect(meal.placeId, b.id);
      await repo.linkMealToAppointment('meal', 'cita', confirmed: true);
      meal = (await repo.getAppointmentMeals('cita')).items.single;
      expect(meal.placeId, a.id);
      expect(dateKey(meal.date), dateKey(day));
      await expectLater(repo.assignMealToPlace('meal', b.id), throwsStateError);
      expect((await repo.getAppointmentMeals('cita')).items, hasLength(1));
      await repo.saveCalendarEntry(
        entry('cita', day.add(const Duration(days: 2)), a.id),
      );
      meal = (await repo.getMealPage()).items.single;
      expect(meal.appointmentId, isNull);
      expect(meal.placeId, a.id);
      expect(dateKey(meal.date), dateKey(day));
      await repo.saveCalendarEntry(entry('sin lugar', day, null));
      await repo.linkMealToAppointment('meal', 'sin lugar');
      expect(
        (await repo.getAppointmentMeals('sin lugar')).items.single.placeId,
        a.id,
      );
      await repo.deleteCalendarEntry('sin lugar');
      expect((await repo.getMealPage()).items.single.appointmentId, isNull);
      expect(await repo.deleteEmptyPlace(a.id), isFalse);
      await repo.database.close();
      await dir.delete(recursive: true);
    },
  );

  test(
    'Recordatorios, filtros de lugar y ejemplos se conservan sin duplicarse',
    () async {
      final dir = await Directory.systemTemp.createTemp('couple_samples_');
      var repo = await SqliteMealRepository.openAt(path.join(dir.path, 'db'));
      await repo.saveMeal(
        Meal(
          id: 'real',
          name: 'Real',
          date: DateTime(2026, 11, 8),
          type: 'Cena',
          ingredients: '',
          categories: [],
          people: ['1'],
        ),
      );
      await repo.seedSalamancaExamples(now: DateTime(2026, 11, 8));
      final total = await repo.getMealCount();
      final entries = await repo.getCalendarEntries(month: DateTime(2026, 11));
      expect(entries.where((e) => e.kind == 'appointment'), isNotEmpty);
      expect(entries.where((e) => e.kind == 'reminder'), isNotEmpty);
      expect(entries.every((e) => e.isExample), isTrue);
      expect(
        (await repo.getMealPage(
          filter: const MealHistoryFilter(placeId: '__none__'),
        )).items.any((m) => m.id == 'real'),
        isTrue,
      );
      await repo.database.close();
      repo = await SqliteMealRepository.openAt(path.join(dir.path, 'db'));
      await repo.seedSalamancaExamples();
      expect(await repo.getMealCount(), total);
      expect(
        (await repo.getMealPage(
          filter: const MealHistoryFilter(placeId: '__none__'),
        )).items.any((m) => m.id == 'real'),
        isTrue,
      );
      await repo.database.close();
      await dir.delete(recursive: true);
    },
  );
}

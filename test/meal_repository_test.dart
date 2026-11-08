import 'dart:io';
import 'package:app_couple_system/meals/meal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Meal makeMeal(String id, String name, DateTime date) => Meal(
  id: id,
  name: name,
  date: date,
  type: 'Cena',
  ingredients: '',
  categories: [],
  people: ['1'],
);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'Lugares reutilizables y filtros combinados se conservan al reabrir',
    () async {
      final dir = await Directory.systemTemp.createTemp('couple_locations_');
      final file = path.join(dir.path, 'test.db');
      var repo = await SqliteMealRepository.openAt(file);
      const place = MealPlace(
        id: 'place-1',
        name: 'Parque',
        latitude: 19.42,
        longitude: -99.18,
      );
      Meal meal(
        String id,
        int day,
        String type,
        List<String> categories,
        List<String> people, {
        String? placeId,
      }) => Meal(
        id: id,
        name: id,
        date: DateTime(2026, 5, day),
        type: type,
        ingredients: '',
        categories: categories,
        people: people,
        placeId: placeId,
      );
      await repo.saveMeal(
        meal('a', 3, 'Cena', ['Casera'], ['1'], placeId: place.id),
        place: place,
      );
      await repo.saveMeal(
        meal('b', 4, 'Cena', ['Casera'], ['1', '2'], placeId: place.id),
        place: place,
      );
      await repo.saveMeal(meal('c', 5, 'Comida', ['Casera'], ['1']));
      await repo.saveMeal(meal('d', 6, 'Cena', ['Postre'], ['1']));
      final filter = MealHistoryFilter(
        type: 'Cena',
        category: 'Casera',
        start: DateTime(2026, 5, 3),
        end: DateTime(2026, 5, 4),
      );
      expect(
        (await repo.getMealPage(
          person: '1',
          filter: filter,
        )).items.map((m) => m.id),
        ['b', 'a'],
      );
      expect(
        (await repo.getMealPage(
          person: '2',
          filter: filter,
        )).items.map((m) => m.id),
        ['b'],
      );
      expect(await repo.getPlaces(), hasLength(1));
      await repo.database.close();
      repo = await SqliteMealRepository.openAt(file);
      expect((await repo.getPlaces()).single.name, 'Parque');
      expect(
        (await repo.getMealPage()).items.where((m) => m.placeId == place.id),
        hasLength(2),
      );
      await repo.saveMeal(meal('a', 3, 'Cena', ['Casera'], ['1']));
      expect(
        (await repo.getMealPage()).items.firstWhere((m) => m.id == 'a').placeId,
        isNull,
      );
      expect(await repo.getPlaces(), hasLength(1));
      await repo.seedLocationExamples(now: DateTime(2026, 5, 15));
      final count = await repo.getMealCount();
      await repo.seedLocationExamples();
      expect(await repo.getMealCount(), count);
      expect(await repo.getExampleCount(), 15);
      await repo.database.close();
      await dir.delete(recursive: true);
    },
  );

  test('Migración v2 conserva comidas existentes sin asignar ubicación', () async {
    final dir = await Directory.systemTemp.createTemp(
      'couple_location_migration_',
    );
    final file = path.join(dir.path, 'test.db');
    final db = await openDatabase(
      file,
      version: 2,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE meals (id TEXT PRIMARY KEY, name TEXT NOT NULL, name_key TEXT NOT NULL, date TEXT NOT NULL, type TEXT NOT NULL, ingredients TEXT NOT NULL, categories TEXT NOT NULL, people TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE)',
        );
        await db.insert('meals', {
          'id': 'real',
          'name': 'Tacos',
          'name_key': 'tacos',
          'date': '2026-05-03T00:00:00.000',
          'type': 'Cena',
          'ingredients': '',
          'categories': '[]',
          'people': '["1"]',
        });
      },
    );
    await db.close();
    final repo = await SqliteMealRepository.openAt(file);
    expect((await repo.getMealPage()).items.single.name, 'Tacos');
    expect((await repo.getMealPage()).items.single.placeId, isNull);
    expect(await repo.getPlaces(), isEmpty);
    await repo.database.close();
    await dir.delete(recursive: true);
  });

  test(
    'Filtros y sugerencias abarcan registros individuales y compartidos',
    () async {
      final dir = await Directory.systemTemp.createTemp('couple_filters_');
      final repo = await SqliteMealRepository.openAt(
        path.join(dir.path, 'test.db'),
      );
      Future<void> save(String id, String name, List<String> people, int day) =>
          repo.saveMeal(
            Meal(
              id: id,
              name: name,
              date: DateTime(2026, 5, day),
              type: 'Cena',
              ingredients: '',
              categories: [],
              people: people,
            ),
          );
      await save('a', 'Arroz con pollo', ['1'], 1);
      await save('b', 'ARROZ  CON POLLO', ['2'], 2);
      await save('c', 'arroz con pollo', ['1', '2'], 3);
      await save('d', 'Tacos', ['2'], 4);
      expect(await repo.getMealCount(), 4);
      expect(await repo.getMealCount(person: '1'), 2);
      expect(await repo.getMealCount(person: '2'), 3);
      expect(await repo.getMealDays(DateTime(2026, 5), person: '1'), {
        '2026-05-01',
        '2026-05-03',
      });
      expect(
        (await repo.getMealsForDay(
          DateTime(2026, 5, 3),
          person: '2',
        )).single.id,
        'c',
      );
      expect(
        (await repo.getMealsForDay(DateTime(2026, 5, 1), person: '2')),
        isEmpty,
      );
      expect((await repo.getFavorites(person: '1')).single.count, 2);
      expect((await repo.getFavorites(person: '2')).first.count, 2);
      expect(await repo.suggestMealNames('  ARROZ   con  '), [
        'arroz con pollo',
      ]);
      expect(await repo.suggestMealNames('inexistente'), isEmpty);
      for (var i = 0; i < 12; i++) {
        await save('extra-$i', 'Comida $i', ['1'], 8);
      }
      final first = await repo.getMealPage(person: '1');
      final second = await repo.getMealPage(
        after: first.items.last,
        person: '1',
      );
      expect(first.items, hasLength(10));
      expect(second.items, hasLength(4));
      expect(
        [...first.items, ...second.items].every((m) => m.people.contains('1')),
        isTrue,
      );
      expect((await repo.suggestMealNames('comida')).length, 8);
      await repo.seedReviewExamples(now: DateTime(2026, 5, 20));
      final count = await repo.getMealCount();
      expect(await repo.getExampleCount(), 22);
      expect(
        (await repo.getFavorites(
          person: '1',
        )).any((favorite) => favorite.hasExamples),
        isTrue,
      );
      await repo.seedReviewExamples(now: DateTime(2026, 6, 20));
      expect(await repo.getMealCount(), count);
      expect((await repo.getMealPage()).items.any((m) => m.isExample), isTrue);
      await repo.database.close();
      await dir.delete(recursive: true);
    },
  );

  test('Paginación estable y favoritos agrupan todos los registros', () async {
    final dir = await Directory.systemTemp.createTemp('couple_pages_');
    final repo = await SqliteMealRepository.openAt(
      path.join(dir.path, 'test.db'),
    );
    expect((await repo.getMealPage()).items, isEmpty);
    for (var i = 0; i < 10; i++) {
      await repo.saveMeal(
        makeMeal(
          'id-${i.toString().padLeft(2, '0')}',
          i == 0 ? 'Arroz  con pollo' : 'Platillo $i',
          DateTime(2026, 5, 10),
        ),
      );
    }
    expect((await repo.getMealPage()).hasMore, false);
    await repo.saveMeal(
      makeMeal('id-10', 'ARROZ CON POLLO', DateTime(2026, 5, 10)),
    );
    expect((await repo.getMealPage()).hasMore, true);
    for (var i = 11; i < 23; i++) {
      await repo.saveMeal(
        makeMeal(
          'id-$i',
          i == 22 ? ' arroz con pollo ' : 'Platillo $i',
          DateTime(2026, i == 22 ? 4 : 5, 10),
        ),
      );
    }
    final first = await repo.getMealPage();
    final second = await repo.getMealPage(after: first.items.last);
    final third = await repo.getMealPage(after: second.items.last);
    expect(
      [first.items.length, second.items.length, third.items.length],
      [10, 10, 3],
    );
    expect([first.hasMore, second.hasMore, third.hasMore], [true, true, false]);
    final all = [...first.items, ...second.items, ...third.items];
    expect(all.map((m) => m.id).toSet(), hasLength(23));
    expect(await repo.getMealCount(), 23);
    final favorite = (await repo.getFavorites()).first;
    expect(favorite.name, 'ARROZ CON POLLO');
    expect(favorite.count, 3);
    expect(await repo.getMealDays(DateTime(2026, 4)), {'2026-04-10'});
    expect(await repo.getMealDays(DateTime(2026, 5)), {'2026-05-10'});
    expect(await repo.getMealsForDay(DateTime(2026, 5, 10)), hasLength(22));
    await repo.saveMeal(makeMeal('id-10', 'Sopa', DateTime(2026, 5, 10)));
    expect((await repo.getFavorites()).first.count, 2);
    await repo.deleteMeal('id-00');
    expect(await repo.getMealCount(), 22);
    expect(normalizeMealName('  ÁRROZ \t Con  Pollo '), 'árroz con pollo');
    expect(normalizeMealName('Arroz'), isNot(normalizeMealName('Árroz')));
    await repo.database.close();
    await dir.delete(recursive: true);
  });

  test(
    'Migración v1 elimina solo ejemplos y conserva nombres y configuración',
    () async {
      final dir = await Directory.systemTemp.createTemp('couple_migration_');
      final file = path.join(dir.path, 'test.db');
      final db = await openDatabase(
        file,
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE meals (id TEXT PRIMARY KEY, name TEXT NOT NULL, date TEXT NOT NULL, type TEXT NOT NULL, ingredients TEXT NOT NULL, categories TEXT NOT NULL, people TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE)',
          );
          await db.insert('settings', {
            'key': 'names',
            'value': '["Ana","Luis"]',
          });
          await db.insert('settings', {
            'key': 'examples_seeded_v1',
            'value': 'true',
          });
          await db.insert('categories', {'id': 'cat-1', 'name': 'Favorita'});
          for (final pair in [
            ('real', ' ARROZ  Con POLLO '),
            ('demo-meal-v1-1', 'Ejemplo editado'),
            ('demo-meal-v1-25', 'Otro ejemplo'),
            ('demo-meal-v1-999', 'Dato ajeno'),
          ]) {
            await db.insert('meals', {
              'id': pair.$1,
              'name': pair.$2,
              'date': '2026-05-01T00:00:00.000',
              'type': 'Cena',
              'ingredients': '',
              'categories': '[]',
              'people': '["1"]',
            });
          }
        },
      );
      await db.close();
      var repo = await SqliteMealRepository.openAt(file);
      expect((await repo.getMealPage()).items.map((m) => m.id).toSet(), {
        'real',
        'demo-meal-v1-999',
      });
      expect(
        (await repo.database.query(
          'meals',
          where: 'id = ?',
          whereArgs: ['real'],
        )).single['name_key'],
        'arroz con pollo',
      );
      expect(
        (await repo.getFavorites()).any((f) => f.name == ' ARROZ  Con POLLO '),
        isTrue,
      );
      expect(await repo.getNames(), ['Ana', 'Luis']);
      expect(await repo.getCategories(), ['Favorita']);
      await repo.database.close();
      repo = await SqliteMealRepository.openAt(file);
      expect(await repo.getMealCount(), 2);
      await repo.database.close();
      await dir.delete(recursive: true);
    },
  );
}

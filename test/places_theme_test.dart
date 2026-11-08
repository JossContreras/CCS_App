import 'dart:io';
import 'package:app_couple_system/app_style.dart';
import 'package:app_couple_system/main.dart';
import 'package:app_couple_system/meals/meal_repository.dart';
import 'package:app_couple_system/meals/meals_screen.dart';
import 'package:app_couple_system/meals/favorites_screen.dart';
import 'package:app_couple_system/meals/place_picker.dart';
import 'package:app_couple_system/places/places_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'meals_screen_test.dart' show MemoryMeals;

double contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return ((first > second ? first : second) + .05) /
      ((first < second ? first : second) + .05);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('Iconos y colores esenciales tienen contraste suficiente', () {
    Meal meal(String type, [List<String> categories = const []]) => Meal(
      id: 'x',
      name: 'a',
      date: DateTime(2026),
      type: type,
      ingredients: '',
      categories: categories,
      people: const ['1'],
    );
    for (final brightness in Brightness.values) {
      for (final m in [
        meal('Cena'),
        meal('Comida'),
        meal('Desayuno'),
        meal('Aperitivo'),
        meal('Otro'),
        meal('Cena', ['Comida chatarra']),
      ]) {
        final colors = mealIconPalette(m, brightness);
        expect(contrast(colors.$1, colors.$2), greaterThanOrEqualTo(3));
      }
    }
    expect(
      contrast(AppStyle.rose, AppStyle.roseSoft),
      greaterThanOrEqualTo(4.5),
    );
    expect(contrast(AppStyle.rose, AppStyle.peach), greaterThanOrEqualTo(4.5));
    expect(contrast(AppStyle.muted, AppStyle.cream), greaterThanOrEqualTo(4.5));
    expect(
      contrast(const Color(0xFFFFB2C5), const Color(0xFF51313C)),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(const Color(0xFFDDCBD3), const Color(0xFF1D171B)),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('Agrupa lugares cercanos y los separa al acercarse', () {
    final places = [
      const MealPlace(id: '1', name: 'A', latitude: 19.43, longitude: -99.13),
      const MealPlace(id: '2', name: 'B', latitude: 19.431, longitude: -99.131),
    ];
    expect(groupPlaces(places, 4).single, hasLength(2));
    expect(groupPlaces(places, 18), hasLength(2));
  });

  testWidgets('El tema elegido se conserva tras reiniciar', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CoupleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tema de la aplicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const CoupleApp());
    await tester.pumpAndSettle();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets('Contraste de texto en la pantalla inicial en ambos temas', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    SharedPreferences.setMockInitialValues({});
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(const CoupleApp());
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tap(find.byTooltip('Tema de la aplicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oscuro').last);
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets('Contraste de la pantalla de comidas con ambos temas', (
    tester,
  ) async {
    final now = DateTime.now();
    final repo = MemoryMeals([
      Meal(
        id: 'one',
        name: 'Cena compartida',
        date: DateTime(now.year, now.month, now.day),
        type: 'Cena',
        ingredients: '',
        categories: const ['Casera'],
        people: const ['1'],
      ),
    ]);
    final handle = tester.ensureSemantics();
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppStyle.theme,
          darkTheme: AppStyle.darkTheme,
          themeMode: mode,
          home: MealsScreen(repository: repo),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }
    handle.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Contraste de formulario, favoritos y selector de mapa', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = MemoryMeals([
      Meal(
        id: 'one',
        name: 'Tacos',
        date: DateTime.now(),
        type: 'Cena',
        ingredients: '',
        categories: const [],
        people: const ['1'],
      ),
    ]);
    final handle = tester.ensureSemantics();
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final screen in <Widget>[
        MealFormScreen(
          repository: repo,
          names: const ['Ana', 'Luis'],
          initialDate: DateTime.now(),
        ),
        FavoritesScreen(repository: repo, person: null, filterLabel: 'Ambos'),
        const PlacePicker(places: [], showTiles: false),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppStyle.theme,
            darkTheme: AppStyle.darkTheme,
            themeMode: mode,
            home: screen,
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
    }
    handle.dispose();
  });

  test('Migración v3 conserva lugares y protege comidas vinculadas', () async {
    final dir = await Directory.systemTemp.createTemp('places_v3_');
    final file = path.join(dir.path, 'db.sqlite');
    final db = await openDatabase(
      file,
      version: 3,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE places (id TEXT PRIMARY KEY, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE meals (id TEXT PRIMARY KEY, name TEXT NOT NULL, name_key TEXT NOT NULL, date TEXT NOT NULL, type TEXT NOT NULL, ingredients TEXT NOT NULL, categories TEXT NOT NULL, people TEXT NOT NULL, place_id TEXT)',
        );
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE)',
        );
        await db.insert('places', {
          'id': 'p1',
          'name': 'Casa',
          'latitude': 19.4,
          'longitude': -99.1,
        });
        await db.insert('meals', {
          'id': 'm1',
          'name': 'Tacos',
          'name_key': 'tacos',
          'date': '2026-11-01T00:00:00.000',
          'type': 'Cena',
          'ingredients': '',
          'categories': '[]',
          'people': '["1"]',
          'place_id': 'p1',
        });
      },
    );
    await db.close();
    final repo = await SqliteMealRepository.openAt(file);
    final place = (await repo.getPlaces()).single;
    expect(place.name, 'Casa');
    expect(place.address, isEmpty);
    expect((await repo.getPlaceMeals('p1')).items.single.name, 'Tacos');
    expect((await repo.getPlaceCounts())['p1'], 1);
    expect((await repo.getPlaceTypes('p1'))['Cena'], 1);
    expect(await repo.deleteEmptyPlace('p1'), false);
    await repo.savePlace(
      const MealPlace(
        id: 'p1',
        name: 'Casa nueva',
        latitude: 20,
        longitude: -99,
        notes: 'Reuniones',
      ),
    );
    expect((await repo.getPlaceMeals('p1')).items.single.placeId, 'p1');
    await repo.assignMealToPlace('m1', null);
    expect(await repo.deleteEmptyPlace('p1'), true);
    expect((await repo.getMealPage()).items.single.name, 'Tacos');
    await repo.database.close();
    await dir.delete(recursive: true);
  });

  test('Comidas de un lugar se consultan por páginas sin duplicados', () async {
    final dir = await Directory.systemTemp.createTemp('places_page_');
    final repo = await SqliteMealRepository.openAt(
      path.join(dir.path, 'db.sqlite'),
    );
    const place = MealPlace(
      id: 'p',
      name: 'Casa',
      latitude: 19,
      longitude: -99,
    );
    await repo.savePlace(place);
    for (var i = 0; i < 12; i++) {
      await repo.saveMeal(
        Meal(
          id: 'm$i',
          name: 'Comida $i',
          date: DateTime(2026, 5, 1),
          type: 'Cena',
          ingredients: '',
          categories: const [],
          people: const ['1'],
          placeId: place.id,
        ),
      );
    }
    final first = await repo.getPlaceMeals(place.id);
    final second = await repo.getPlaceMeals(place.id, after: first.items.last);
    expect(first.items, hasLength(10));
    expect(first.hasMore, true);
    expect(second.items, hasLength(2));
    expect({
      ...first.items.map((m) => m.id),
      ...second.items.map((m) => m.id),
    }, hasLength(12));
    await repo.database.close();
    await dir.delete(recursive: true);
  });
}

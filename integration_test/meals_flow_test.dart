import 'package:app_couple_system/meals/meal_repository.dart';
import 'package:app_couple_system/meals/meals_screen.dart';
import 'package:app_couple_system/places/places_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Crear y editar lugar confirma después de guardar', (
    tester,
  ) async {
    final dbPath = path.join(
      await getDatabasesPath(),
      'places_save_test_${const Uuid().v4()}.db',
    );
    final repository = await SqliteMealRepository.openAt(dbPath);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaceEditScreen(
                    repository: repository,
                    showMapTiles: false,
                  ),
                ),
              ),
              child: const Text('Nuevo lugar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Nuevo lugar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Casa de prueba');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.tap(find.text('Elegir ubicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir ubicación'));
    await tester.tap(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar ubicación'));
    await tester.tap(find.text('Confirmar ubicación'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar lugar'));
    await tester.tap(find.text('Guardar lugar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('save-label')), findsOneWidget);
    await tester.pumpAndSettle();
    final place = (await repository.getPlaces()).single;
    expect(place.name, 'Casa de prueba');
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaceEditScreen(
                    repository: repository,
                    place: place,
                    showMapTiles: false,
                  ),
                ),
              ),
              child: const Text('Editar lugar'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Editar lugar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Casa editada');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Guardar lugar'));
    await tester.tap(find.text('Guardar lugar'));
    await tester.pumpAndSettle();
    expect((await repository.getPlaces()).single.name, 'Casa editada');
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.database.close();
    await deleteDatabase(dbPath);
  });

  testWidgets('Flujo de comidas con SQLite en Android', (tester) async {
    final dbPath = path.join(
      await getDatabasesPath(),
      'meals_test_${const Uuid().v4()}.db',
    );
    var repository = await SqliteMealRepository.openAt(dbPath);
    await tester.pumpWidget(
      MaterialApp(home: MealsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Añadir comida'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Tacos prueba');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cena'));
    await tester.tap(
      find.ancestor(of: find.text('Cena'), matching: find.byType(ChoiceChip)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Persona 1'));
    await tester.tap(find.text('Persona 2'));
    await tester.ensureVisible(find.text('Nueva categoría'));
    await tester.tap(find.text('Nueva categoría'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Picante');
    await tester.tap(find.text('Añadir').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Guardar comida'));
    await tester.tap(find.text('Guardar comida'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tacos prueba'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Tacos prueba'), findsWidgets);
    expect(
      (await repository.getMealPage()).items.single.people,
      containsAll(['1', '2']),
    );
    expect(
      (await repository.getMealPage()).items.single.categories,
      contains('Picante'),
    );

    await tester.tap(find.text('Tacos prueba').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Tacos editados');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Persona 2'));
    await tester.tap(find.text('Persona 2'));
    await tester.ensureVisible(find.text('Guardar comida'));
    await tester.tap(find.text('Guardar comida'));
    await tester.pumpAndSettle();
    expect(
      (await repository.getMealPage()).items.single.name,
      'Tacos editados',
    );
    expect((await repository.getMealPage()).items.single.people, ['1']);
    await repository.database.close();
    repository = await SqliteMealRepository.openAt(dbPath);
    expect(
      (await repository.getMealPage()).items.single.name,
      'Tacos editados',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MealsScreen(repository: repository),
        key: UniqueKey(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tacos editados'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Tacos editados').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eliminar comida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect((await repository.getMealPage()).items, hasLength(1));
    await tester.tap(find.text('Tacos editados').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eliminar comida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect((await repository.getMealPage()).items, isEmpty);
    await repository.database.close();
    await deleteDatabase(dbPath);
  });

  testWidgets('Filtros, favoritos y sugerencias con ejemplos aislados', (
    tester,
  ) async {
    final dbPath = path.join(
      await getDatabasesPath(),
      'meals_filter_test_${const Uuid().v4()}.db',
    );
    final repository = await SqliteMealRepository.openAt(dbPath);
    await repository.seedReviewExamples();
    await repository.saveNames(['Ana', 'Luis']);
    await tester.pumpWidget(
      MaterialApp(home: MealsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').first);
    await tester.pumpAndSettle();
    expect(find.text('15 comidas guardadas'), findsOneWidget);
    await tester.tap(find.text('Ver favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Los platillos que más se repiten · Ana'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Luis').first);
    await tester.pumpAndSettle();
    expect(find.text('16 comidas guardadas'), findsOneWidget);
    await tester.tap(find.text('Añadir comida'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'TaCoS  de');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('Tacos de pollo'), findsOneWidget);
    await tester.tap(find.text('Tacos de pollo'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Tacos de pollo',
    );
    expect(find.text('Selecciona un tipo para continuar.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.database.close();
    await deleteDatabase(dbPath);
  });

  testWidgets('Asocia un punto manual a una comida guardada', (tester) async {
    final dbPath = path.join(
      await getDatabasesPath(),
      'meals_place_test_${const Uuid().v4()}.db',
    );
    final repository = await SqliteMealRepository.openAt(dbPath);
    await tester.pumpWidget(
      MaterialApp(
        home: MealFormScreen(
          repository: repository,
          names: const ['Ana', 'Luis'],
          initialDate: DateTime.now(),
          showMapTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'Comida con ubicación',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cena'));
    await tester.tap(
      find.ancestor(of: find.text('Cena'), matching: find.byType(ChoiceChip)),
    );
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(of: find.text('Ana'), matching: find.byType(FilterChip)),
    );
    await tester.ensureVisible(find.text('Agregar ubicación'));
    await tester.tap(find.text('Agregar ubicación'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir ubicación'));
    await tester.tap(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar ubicación'));
    await tester.tap(find.text('Confirmar ubicación'));
    await tester.pumpAndSettle();
    expect(await repository.getPlaces(), isEmpty);
    await tester.tap(find.text('Guardar comida'));
    await tester.pumpAndSettle();
    final saved = (await repository.getMealPage()).items.single;
    expect(saved.placeId, isNotNull);
    expect((await repository.getPlaces()).single.id, saved.placeId);
    await repository.database.close();
    await deleteDatabase(dbPath);
  });

  testWidgets('Reasigna comidas y protege un lugar con asociaciones', (
    tester,
  ) async {
    final dbPath = path.join(
      await getDatabasesPath(),
      'places_integration_${const Uuid().v4()}.db',
    );
    final repository = await SqliteMealRepository.openAt(dbPath);
    const first = MealPlace(
      id: 'a',
      name: 'Casa',
      latitude: 19.4,
      longitude: -99.1,
    );
    const second = MealPlace(
      id: 'b',
      name: 'Parque',
      latitude: 19.5,
      longitude: -99.2,
    );
    await repository.savePlace(first);
    await repository.savePlace(second);
    await repository.saveMeal(
      Meal(
        id: 'meal-1',
        name: 'Cena especial',
        date: DateTime.now(),
        type: 'Cena',
        ingredients: '',
        categories: const [],
        people: const ['1'],
        placeId: first.id,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlaceDetailScreen(repository: repository, placeId: second.id),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vincular existente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cena especial'));
    await tester.pumpAndSettle();
    expect(find.text('Cambiar lugar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect((await repository.getMealPage()).items.single.placeId, 'a');
    await tester.tap(find.text('Cena especial'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trasladar'));
    await tester.pumpAndSettle();
    expect((await repository.getMealPage()).items.single.placeId, 'b');
    await tester.tap(find.byTooltip('Eliminar lugar'));
    await tester.pumpAndSettle();
    expect(await repository.getPlaces(), hasLength(2));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Desvincular comida'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desvincular'));
    await tester.pumpAndSettle();
    expect((await repository.getMealPage()).items.single.placeId, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.database.close();
    await deleteDatabase(dbPath);
  });

  testWidgets('Lista de lugares permanece disponible sin teselas', (
    tester,
  ) async {
    final dbPath = path.join(
      await getDatabasesPath(),
      'places_offline_${const Uuid().v4()}.db',
    );
    final repository = await SqliteMealRepository.openAt(dbPath);
    await repository.savePlace(
      const MealPlace(
        id: 'offline',
        name: 'Casa de prueba',
        latitude: 19.4,
        longitude: -99.1,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(home: PlacesScreen(repository: repository, showTiles: false)),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Casa de prueba'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Casa de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle del lugar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.database.close();
    await deleteDatabase(dbPath);
  });
}

import 'dart:async';
import 'package:app_couple_system/meals/meal_repository.dart';
import 'package:app_couple_system/meals/meals_screen.dart';
import 'package:app_couple_system/meals/meal_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class MemoryMeals implements MealRepository {
  MemoryMeals(this.meals);
  final List<Meal> meals;
  @override
  Future<CalendarEntry?> getAppointment(String id) async => null;
  @override
  Future<int> getExampleCount({String? person}) async => meals
      .where(
        (m) => m.isExample && (person == null || m.people.contains(person)),
      )
      .length;
  @override
  Future<MealPage> getMealPage({
    Meal? after,
    String? person,
    MealHistoryFilter? filter,
  }) async {
    final ordered =
        meals
            .where(
              (m) =>
                  (person == null || m.people.contains(person)) &&
                  (filter?.type == null || filter!.type == m.type) &&
                  (filter?.category == null ||
                      m.categories.contains(filter!.category)) &&
                  (filter?.placeId == null ||
                      (filter!.placeId == '__none__'
                          ? m.placeId == null
                          : m.placeId == filter.placeId)) &&
                  (filter?.start == null || !m.date.isBefore(filter!.start!)) &&
                  (filter?.end == null ||
                      !DateTime(
                        m.date.year,
                        m.date.month,
                        m.date.day,
                      ).isAfter(filter!.end!)),
            )
            .toList()
          ..sort((a, b) {
            final order = b.date.compareTo(a.date);
            return order != 0 ? order : b.id.compareTo(a.id);
          });
    final start = after == null
        ? 0
        : ordered.indexWhere((m) => m.id == after.id) + 1;
    final remaining = ordered.skip(start).toList();
    return MealPage(remaining.take(10).toList(), remaining.length > 10);
  }

  @override
  Future<int> getMealCount({String? person}) async =>
      meals.where((m) => person == null || m.people.contains(person)).length;
  @override
  Future<Set<String>> getMealDays(DateTime month, {String? person}) async =>
      meals
          .where(
            (m) =>
                (person == null || m.people.contains(person)) &&
                m.date.year == month.year &&
                m.date.month == month.month,
          )
          .map((m) => dateKey(m.date))
          .toSet();
  @override
  Future<List<Meal>> getMealsForDay(DateTime day, {String? person}) async =>
      meals
          .where(
            (m) =>
                (person == null || m.people.contains(person)) &&
                dateKey(m.date) == dateKey(day),
          )
          .toList();
  @override
  Future<List<MealFavorite>> getFavorites({String? person}) async {
    final counts = <String, int>{};
    for (final m in meals.where(
      (m) => person == null || m.people.contains(person),
    )) {
      counts[m.name] = (counts[m.name] ?? 0) + 1;
    }
    return counts.entries.map((e) => MealFavorite(e.key, e.value)).toList();
  }

  @override
  Future<List<String>> suggestMealNames(String query) async => meals
      .map((m) => m.name)
      .where((n) => normalizeMealName(n).contains(normalizeMealName(query)))
      .toSet()
      .take(8)
      .toList();

  @override
  Future<void> saveMeal(Meal meal, {MealPlace? place}) async {
    meals.removeWhere((m) => m.id == meal.id);
    meals.add(meal);
  }

  @override
  Future<void> deleteMeal(String id) async =>
      meals.removeWhere((m) => m.id == id);
  @override
  Future<List<String>> getNames() async => ['Ana', 'Luis'];
  @override
  Future<void> saveNames(List<String> names) async {}
  @override
  Future<List<String>> getCategories() async => ['Casera'];
  @override
  Future<void> addCategory(String name) async {}
  @override
  Future<List<MealPlace>> getPlaces() async => [];
}

class FailingMeals extends MemoryMeals {
  FailingMeals(super.meals);
  @override
  Future<void> saveMeal(Meal meal, {MealPlace? place}) async =>
      throw StateError('fallo');
}

class DelayedMeals extends MemoryMeals {
  DelayedMeals() : super([]);
  final requests = <String, Completer<List<String>>>{};
  @override
  Future<List<String>> suggestMealNames(String query) =>
      (requests[query] = Completer<List<String>>()).future;
}

class CalendarDelay extends MemoryMeals {
  CalendarDelay() : super([]);
  Completer<List<Meal>>? pending;
  @override
  Future<List<Meal>> getMealsForDay(DateTime day, {String? person}) =>
      pending?.future ?? super.getMealsForDay(day, person: person);
}

void main() {
  testWidgets(
    'El filtro de tipo se aplica solo al historial y puede limpiarse',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = DateUtils.dateOnly(DateTime.now());
      Meal meal(String id, String type) => Meal(
        id: id,
        name: 'Platillo $type',
        date: today,
        type: type,
        ingredients: '',
        categories: ['Casera'],
        people: ['1'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MealsScreen(
            repository: MemoryMeals([meal('1', 'Cena'), meal('2', 'Desayuno')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filtrar historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Todos los tipos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cena').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Platillo Cena'), findsOneWidget);
      expect(find.text('Platillo Desayuno'), findsNothing);
      await tester.tap(find.text('Calendario'));
      await tester.pumpAndSettle();
      expect(find.text('Platillo Desayuno'), findsOneWidget);
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filtros activos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Platillo Desayuno'), findsOneWidget);
    },
  );
  test('Iconos representan tipo y comida chatarra tiene prioridad', () {
    Meal meal(String type, List<String> categories) => Meal(
      id: '1',
      name: 'a',
      date: DateTime(2026),
      type: type,
      ingredients: '',
      categories: categories,
      people: ['1'],
    );
    expect(mealIcon(meal('Cena', [])), Icons.nightlight_round);
    expect(mealIcon(meal('Desayuno', [])), Icons.wb_twilight_rounded);
    expect(
      mealIcon(meal('Cena', ['Comida chatarra'])),
      Icons.lunch_dining_rounded,
    );
  });

  testWidgets(
    'Cambiar día conserva el calendario y posición mientras consulta',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repo = CalendarDelay();
      await tester.pumpWidget(MaterialApp(home: MealsScreen(repository: repo)));
      await tester.pumpAndSettle();
      final target = DateTime.now();
      final day = target.day == 1 ? 2 : 1;
      final label = dayLabel(DateTime(target.year, target.month, day));
      await tester.ensureVisible(find.byTooltip(label));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final before = scrollable.position.pixels;
      repo.pending = Completer<List<Meal>>();
      await tester.tap(find.byTooltip(label));
      await tester.pump();
      expect(find.byType(MealCalendar), findsOneWidget);
      expect(scrollable.position.pixels, before);
      repo.pending!.complete([]);
      await tester.pumpAndSettle();
      expect(scrollable.position.pixels, before);
    },
  );
  testWidgets('Descarta sugerencias atrasadas de búsquedas anteriores', (
    tester,
  ) async {
    final repo = DelayedMeals();
    await tester.pumpWidget(
      MaterialApp(
        home: MealFormScreen(
          repository: repo,
          names: const ['Ana', 'Luis'],
          initialDate: DateTime.now(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'ta');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.byType(TextFormField).first, 'tacos');
    await tester.pump(const Duration(milliseconds: 250));
    repo.requests['tacos']!.complete(['Tacos nuevos']);
    await tester.pump();
    repo.requests['ta']!.complete(['Tarta antigua']);
    await tester.pump();
    expect(find.text('Tacos nuevos'), findsOneWidget);
    expect(find.text('Tarta antigua'), findsNothing);
  });
  testWidgets(
    'Filtra comidas compartidas y abre favoritos para el integrante',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = DateUtils.dateOnly(DateTime.now());
      Meal meal(String id, String name, List<String> people) => Meal(
        id: id,
        name: name,
        date: today,
        type: 'Cena',
        ingredients: '',
        categories: [],
        people: people,
      );
      final repo = MemoryMeals([
        meal('1', 'Solo Ana', ['1']),
        meal('2', 'Solo Luis', ['2']),
        meal('3', 'Compartida', ['1', '2']),
      ]);
      await tester.pumpWidget(MaterialApp(home: MealsScreen(repository: repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana').first);
      await tester.pumpAndSettle();
      expect(find.text('Solo Ana'), findsOneWidget);
      expect(find.text('Compartida'), findsOneWidget);
      expect(find.text('Solo Luis'), findsNothing);
      await tester.tap(find.text('Ver favoritos'));
      await tester.pumpAndSettle();
      expect(
        find.text('Los platillos que más se repiten · Ana'),
        findsOneWidget,
      );
      expect(find.text('Solo Luis'), findsNothing);
    },
  );

  testWidgets('Un error al guardar no muestra confirmación de éxito', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final meal = Meal(
      id: '1',
      name: 'Tacos',
      date: DateTime.now(),
      type: 'Cena',
      ingredients: '',
      categories: [],
      people: ['1'],
    );
    final repo = FailingMeals([meal]);
    await tester.pumpWidget(
      MaterialApp(
        home: MealFormScreen(
          repository: repo,
          names: const ['Ana', 'Luis'],
          initialDate: meal.date,
          meal: meal,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar comida'));
    await tester.pumpAndSettle();
    expect(find.text('No se pudo guardar la comida.'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-label')), findsNothing);
    expect(repo.meals.single.name, 'Tacos');
  });

  testWidgets('Sugerencia solo completa el nombre', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repo = MemoryMeals([
      Meal(
        id: '1',
        name: 'Tacos caseros',
        date: DateTime.now(),
        type: 'Cena',
        ingredients: 'Pollo',
        categories: ['Casera'],
        people: ['1'],
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: MealFormScreen(
          repository: repo,
          names: const ['Ana', 'Luis'],
          initialDate: DateTime.now(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'tacos');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(find.text('Tacos caseros'), findsOneWidget);
    await tester.tap(find.text('Tacos caseros'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      'Tacos caseros',
    );
    expect(find.text('Selecciona un tipo para continuar.'), findsOneWidget);
  });
  testWidgets('Carga más registros y abre favoritos', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime.now();
    final repo = MemoryMeals(
      List.generate(
        11,
        (i) => Meal(
          id: '$i',
          name: 'Comida $i',
          date: now.subtract(Duration(days: i)),
          type: 'Cena',
          ingredients: '',
          categories: [],
          people: ['1'],
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: MealsScreen(repository: repo)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();
    expect(find.text('Comida 10'), findsNothing);
    await tester.ensureVisible(find.text('Cargar más'));
    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();
    expect(find.text('Comida 10'), findsOneWidget);
    expect(find.text('Cargar más'), findsNothing);
    await tester.ensureVisible(find.text('Ver favoritos'));
    await tester.tap(find.text('Ver favoritos'));
    await tester.pumpAndSettle();
    expect(find.text('Sus favoritos'), findsOneWidget);
  });
  testWidgets('Se adapta a pantalla pequeña con texto ampliado', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: MealsScreen(repository: MemoryMeals([])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Calendario filtra comidas y el historial muestra todos los registros',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final today = DateUtils.dateOnly(DateTime.now());
      Meal meal(String id, String name, DateTime date) => Meal(
        id: id,
        name: name,
        date: date,
        type: 'Cena',
        ingredients: '',
        categories: [],
        people: ['1'],
      );
      final repo = MemoryMeals([
        meal('1', 'Pasta', today),
        meal('2', 'Sopa', today),
        meal('3', 'Arroz', DateTime(today.year, today.month - 1, 1)),
      ]);
      Finder cardTitle(String name) => find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == name &&
            widget.style?.fontWeight == FontWeight.w800,
      );
      await tester.pumpWidget(MaterialApp(home: MealsScreen(repository: repo)));
      await tester.pumpAndSettle();
      expect(cardTitle('Pasta'), findsOneWidget);
      expect(cardTitle('Sopa'), findsOneWidget);
      expect(cardTitle('Arroz'), findsNothing);
      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.pumpAndSettle();
      expect(cardTitle('Arroz'), findsOneWidget);
      expect(cardTitle('Pasta'), findsNothing);
      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(cardTitle('Pasta'), findsOneWidget);
      expect(cardTitle('Arroz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

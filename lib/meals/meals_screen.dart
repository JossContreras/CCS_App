import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_style.dart';
import '../motion.dart';
import '../calendar/calendar_screen.dart';
import 'favorites_screen.dart';
import 'meal_calendar.dart';
import 'meal_repository.dart';
import 'place_picker.dart';

String _date(DateTime date) => '${dayLabel(date)} de ${date.year}';
(Color, Color) mealIconPalette(Meal meal, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final icon = mealIcon(meal);
  if (icon == Icons.lunch_dining_rounded) {
    return dark
        ? (Color(0xFFFFC3A6), Color(0xFF5B3023))
        : (Color(0xFF8A321D), Color(0xFFFFE3D3));
  }
  if (meal.type == 'Cena') {
    return dark
        ? (Color(0xFFCDD6FF), Color(0xFF27325C))
        : (Color(0xFF273C74), Color(0xFFE4EAFD));
  }
  if (meal.type == 'Desayuno') {
    return dark
        ? (Color(0xFFFFDE9B), Color(0xFF58431B))
        : (Color(0xFF735000), Color(0xFFFFEDBD));
  }
  if (meal.type == 'Comida') {
    return dark
        ? (Color(0xFFFFC5A8), Color(0xFF603623))
        : (Color(0xFF8A3C12), Color(0xFFFFE5D1));
  }
  if (meal.type == 'Aperitivo') {
    return dark
        ? (Color(0xFFCBE8CA), Color(0xFF294D3A))
        : (Color(0xFF285D42), Color(0xFFE0F1E0));
  }
  return dark
      ? (Color(0xFFE6C7F0), Color(0xFF493352))
      : (Color(0xFF6B3B77), Color(0xFFF1E2F4));
}

IconData mealIcon(Meal meal) {
  if (meal.categories.any(
    (category) => normalizeMealName(category) == 'comida chatarra',
  )) {
    return Icons.lunch_dining_rounded;
  }
  return switch (meal.type) {
    'Desayuno' => Icons.wb_twilight_rounded,
    'Comida' => Icons.wb_sunny_rounded,
    'Cena' => Icons.nightlight_round,
    'Aperitivo' => Icons.cookie_outlined,
    _ => Icons.restaurant_rounded,
  };
}

Duration _motion(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : Duration(milliseconds: 250);

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key, required this.repository});
  final MealRepository repository;
  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  List<Meal> history = [], dayMeals = [];
  List<MealPlace> places = [];
  Set<String> mealDays = {};
  int mealCount = 0, exampleCount = 0;
  bool hasMore = false, loadingMore = false;
  int loadGeneration = 0;
  int calendarGeneration = 0;
  bool dayLoading = false;
  bool monthNeedsRefresh = false;
  String? dayError;
  MealHistoryFilter historyFilter = MealHistoryFilter();
  String? selectedPerson;
  List<String> names = ['Persona 1', 'Persona 2'];
  List<String> filterCategories = [];
  bool loading = true, calendar = true;
  String? error;
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++loadGeneration;
    final calendarRequest = ++calendarGeneration;
    final targetMonth = month;
    final targetDay = selected;
    final person = selectedPerson;
    try {
      final newPage = await widget.repository.getMealPage(
        person: person,
        filter: historyFilter,
      );
      final newCount = await widget.repository.getMealCount(person: person);
      final newExampleCount = await widget.repository.getExampleCount(
        person: person,
      );
      final newDays = await widget.repository.getMealDays(
        targetMonth,
        person: person,
      );
      final newDayMeals = await widget.repository.getMealsForDay(
        targetDay,
        person: person,
      );
      final newNames = await widget.repository.getNames();
      final newPlaces = await widget.repository.getPlaces();
      final newCategories = await widget.repository.getCategories();
      if (mounted && generation == loadGeneration) {
        setState(() {
          history = newPage.items;
          hasMore = newPage.hasMore;
          mealCount = newCount;
          exampleCount = newExampleCount;
          if (calendarRequest == calendarGeneration) {
            mealDays = newDays;
            dayMeals = newDayMeals;
            dayLoading = false;
            dayError = null;
            monthNeedsRefresh = false;
          }
          names = newNames;
          places = newPlaces;
          filterCategories = newCategories;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted && generation == loadGeneration) {
        setState(() {
          loading = false;
          error = 'No se pudieron cargar los datos locales.';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasMore || history.isEmpty) return;
    final generation = loadGeneration;
    setState(() => loadingMore = true);
    try {
      final page = await widget.repository.getMealPage(
        after: history.last,
        person: selectedPerson,
        filter: historyFilter,
      );
      if (mounted && generation == loadGeneration) {
        setState(() {
          history = [...history, ...page.items];
          hasMore = page.hasMore;
        });
      }
    } catch (_) {
      if (generation == loadGeneration) {
        _message('No se pudieron cargar más comidas.');
      }
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  void _selectDay(DateTime value) {
    final changedMonth =
        monthNeedsRefresh ||
        month.year != value.year ||
        month.month != value.month;
    final generation = ++calendarGeneration;
    final person = selectedPerson;
    setState(() {
      selected = value;
      month = DateTime(value.year, value.month);
      dayLoading = true;
      dayError = null;
      if (changedMonth) mealDays = {};
      if (changedMonth) monthNeedsRefresh = true;
    });
    () async {
      try {
        final days = changedMonth
            ? await widget.repository.getMealDays(value, person: person)
            : null;
        final items = await widget.repository.getMealsForDay(
          value,
          person: person,
        );
        if (mounted && generation == calendarGeneration) {
          setState(() {
            if (days != null) {
              mealDays = days;
              monthNeedsRefresh = false;
            }
            dayMeals = items;
            dayLoading = false;
          });
        }
      } catch (_) {
        if (mounted && generation == calendarGeneration) {
          setState(() {
            dayError = 'No se pudieron cargar las comidas del día.';
            dayLoading = false;
          });
        }
      }
    }();
  }

  void _selectPerson(String? person) {
    setState(() {
      selectedPerson = person;
      loading = true;
    });
    _load();
  }

  Future<void> _historyFilters() async {
    final result = await showModalBottomSheet<MealHistoryFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HistoryFilterSheet(
        initial: historyFilter,
        categories: filterCategories,
        places: places,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      historyFilter = result;
      loading = true;
    });
    await _load();
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _editNames() async {
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => _NamesDialog(names: names),
    );
    if (result != null) {
      try {
        await widget.repository.saveNames(result);
        await _load();
      } catch (_) {
        _message('No se pudieron guardar los nombres.');
      }
    }
  }

  Future<void> _openForm([Meal? meal]) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    final result = await Navigator.push<Meal>(
      context,
      MaterialPageRoute(
        builder: (_) => MealFormScreen(
          repository: widget.repository,
          names: names,
          meal: meal,
          initialDate: selected,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        selected = DateUtils.dateOnly(result.date);
        month = DateTime(selected.year, selected.month);
      });
      await _load();
    }
  }

  Future<void> _delete(Meal meal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar comida'),
        content: Text('¿Eliminar «${meal.name}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await widget.repository.deleteMeal(meal.id);
        await _load();
        _message('Comida eliminada');
      } catch (_) {
        _message('No se pudo eliminar la comida.');
      }
    }
  }

  Future<void> _details(Meal meal) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppStyle.resolve(context, AppStyle.cream),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.type.toUpperCase(),
                  style: TextStyle(
                    color: AppStyle.resolve(context, AppStyle.rose),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  meal.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (meal.isExample) ...[
                  SizedBox(height: 8),
                  _tag(
                    'Ejemplo',
                    AppStyle.resolve(context, AppStyle.peach),
                    AppStyle.resolve(context, AppStyle.ink),
                  ),
                ],
                SizedBox(height: 12),
                Text(
                  '${_date(meal.date)} · ${_people(meal)}',
                  style: TextStyle(
                    color: AppStyle.resolve(context, AppStyle.muted),
                  ),
                ),
                if (meal.placeId != null) ...[
                  SizedBox(height: 14),
                  Text(
                    'Ubicación',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    places
                            .where((p) => p.id == meal.placeId)
                            .map(
                              (p) => p.name.isEmpty
                                  ? 'Lugar sin nombre · ${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}'
                                  : p.name,
                            )
                            .firstOrNull ??
                        'Lugar no disponible',
                  ),
                ],
                SizedBox(height: 24),
                Text(
                  'Ingredientes',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  meal.ingredients.isEmpty
                      ? 'Sin ingredientes añadidos'
                      : meal.ingredients,
                ),
                SizedBox(height: 18),
                Text(
                  'Categorías',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                if (meal.categories.isEmpty)
                  Text('Sin categorías')
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: meal.categories
                        .map(
                          (c) => _tag(
                            c,
                            AppStyle.resolve(context, AppStyle.roseSoft),
                            AppStyle.resolve(context, AppStyle.rose),
                          ),
                        )
                        .toList(),
                  ),
                SizedBox(height: 24),
                if (meal.appointmentId != null &&
                    widget.repository is SqliteMealRepository) ...[
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context, 'appointment'),
                    icon: const Icon(Icons.favorite_outline),
                    label: const Text('Ver cita vinculada'),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, 'edit'),
                        icon: Icon(Icons.edit_outlined),
                        label: Text('Editar'),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Eliminar comida',
                      onPressed: () => Navigator.pop(context, 'delete'),
                      icon: Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (action == 'edit') await _openForm(meal);
    if (action == 'delete') await _delete(meal);
    if (action == 'appointment' &&
        mounted &&
        widget.repository is SqliteMealRepository) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentDetailScreen(
            repository: widget.repository as SqliteMealRepository,
            appointmentId: meal.appointmentId!,
          ),
        ),
      );
      if (mounted) await _load();
    }
  }

  String _people(Meal meal) =>
      meal.people.map((p) => p == '1' ? names[0] : names[1]).join(' y ');

  @override
  Widget build(BuildContext context) {
    final visibleMeals = calendar ? dayMeals : history;
    return Scaffold(
      appBar: AppBar(
        title: Text('Nuestro menú'),
        actions: [
          IconButton(
            onPressed: loading || error != null ? null : _editNames,
            icon: Icon(Icons.people_outline_rounded),
            tooltip: 'Configurar integrantes',
          ),
        ],
      ),
      floatingActionButton: loading || error != null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppStyle.resolve(context, AppStyle.rose),
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppStyle.ink
                  : Colors.white,
              onPressed: () => _openForm(),
              icon: Icon(Icons.add),
              label: Text('Añadir comida'),
            ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(error!),
                  TextButton(onPressed: _load, child: Text('Reintentar')),
                ],
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 110),
              children: [
                Text(
                  'Cada comida cuenta',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Un pequeño diario de lo que disfrutan juntos.',
                  style: TextStyle(
                    color: AppStyle.resolve(context, AppStyle.muted),
                  ),
                ),
                SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: Text('Ambos'),
                      selected: selectedPerson == null,
                      onSelected: (_) => _selectPerson(null),
                    ),
                    ChoiceChip(
                      label: Text(names[0]),
                      selected: selectedPerson == '1',
                      onSelected: (_) => _selectPerson('1'),
                    ),
                    ChoiceChip(
                      label: Text(names[1]),
                      selected: selectedPerson == '2',
                      onSelected: (_) => _selectPerson('2'),
                    ),
                  ],
                ),
                if (exampleCount > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      '$exampleCount comidas de ejemplo incluidas en los totales.',
                      style: TextStyle(
                        color: AppStyle.resolve(context, AppStyle.green),
                        fontSize: 12,
                      ),
                    ),
                  ),
                SizedBox(height: 20),
                SoftCard(
                  color: AppStyle.resolve(context, AppStyle.peach),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppStyle.resolve(
                          context,
                          Colors.white,
                        ),
                        foregroundColor: AppStyle.resolve(
                          context,
                          AppStyle.rose,
                        ),
                        child: Icon(Icons.restaurant_rounded),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$mealCount ${mealCount == 1 ? 'comida guardada' : 'comidas guardadas'}',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Sus momentos, plato a plato.',
                              style: TextStyle(
                                color: AppStyle.resolve(
                                  context,
                                  AppStyle.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FavoritesScreen(
                        repository: widget.repository,
                        person: selectedPerson,
                        filterLabel: selectedPerson == null
                            ? 'Ambos'
                            : names[selectedPerson == '1' ? 0 : 1],
                      ),
                    ),
                  ),
                  icon: Icon(Icons.insights_rounded),
                  label: Text('Ver favoritos'),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Su diario',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: AppStyle.resolve(
                        context,
                        AppStyle.rose,
                      ).withValues(alpha: .7),
                      size: 19,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.calendar_month_rounded),
                      label: Text('Calendario'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.view_list_rounded),
                      label: Text('Historial'),
                    ),
                  ],
                  selected: {calendar},
                  onSelectionChanged: (value) =>
                      setState(() => calendar = value.first),
                  showSelectedIcon: false,
                ),
                if (!calendar)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _historyFilters,
                      icon: Icon(Icons.tune_rounded),
                      label: Text(
                        historyFilter.isActive
                            ? 'Filtros activos'
                            : 'Filtrar historial',
                      ),
                    ),
                  ),
                SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: _motion(context),
                  child: calendar
                      ? MealCalendar(
                          key: ValueKey(
                            'calendar-${month.year}-${month.month}',
                          ),
                          month: month,
                          selected: selected,
                          mealDays: mealDays,
                          onMonth: _selectDay,
                          onSelected: _selectDay,
                        )
                      : SizedBox(key: ValueKey('history')),
                ),
                SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        calendar ? dayLabel(selected) : 'Todas las comidas',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      calendar && dayLoading
                          ? ''
                          : calendar
                          ? '${visibleMeals.length} ${visibleMeals.length == 1 ? 'registro' : 'registros'}'
                          : '${visibleMeals.length} ${visibleMeals.length == 1 ? 'mostrado' : 'mostrados'}',
                      style: TextStyle(
                        color: AppStyle.resolve(context, AppStyle.muted),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                if (calendar && dayLoading)
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (calendar && dayError != null)
                  TextButton(
                    onPressed: () => _selectDay(selected),
                    child: Text('$dayError Toca para reintentar.'),
                  )
                else if (visibleMeals.isEmpty)
                  SoftCard(
                    color: AppStyle.resolve(
                      context,
                      AppStyle.roseSoft,
                    ).withValues(alpha: .55),
                    child: Row(
                      children: [
                        Icon(
                          Icons.soup_kitchen_outlined,
                          color: AppStyle.resolve(context, AppStyle.rose),
                          size: 30,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            calendar
                                ? 'Aún no hay comidas para este día. ¡Agrega una!'
                                : historyFilter.isActive
                                ? 'No hay comidas que coincidan con estos filtros.'
                                : 'Todavía no hay comidas. Empiecen con su primer platillo.',
                            style: TextStyle(
                              color: AppStyle.resolve(context, AppStyle.ink),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...visibleMeals.map(
                    (meal) => Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: _MealCard(
                        meal: meal,
                        people: _people(meal),
                        onTap: () => _details(meal),
                      ),
                    ),
                  ),
                if (!calendar && hasMore)
                  Center(
                    child: TextButton.icon(
                      onPressed: loadingMore ? null : _loadMore,
                      icon: Icon(Icons.expand_more),
                      label: Text(loadingMore ? 'Cargando...' : 'Cargar más'),
                    ),
                  ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      size: 16,
                      color: AppStyle.resolve(context, AppStyle.muted),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Guardado solo en este dispositivo',
                        style: TextStyle(
                          color: AppStyle.resolve(context, AppStyle.muted),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                if (calendar)
                  SizedBox(height: MediaQuery.sizeOf(context).height * .45),
              ],
            ),
    );
  }
}

Widget _tag(String text, Color background, Color color) => Container(
  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(
    color: background,
    borderRadius: BorderRadius.circular(30),
  ),
  child: Text(
    text,
    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
  ),
);

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.people,
    required this.onTap,
  });
  final Meal meal;
  final String people;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: AppStyle.resolve(context, Colors.white),
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: mealIconPalette(meal, Theme.of(context).brightness).$2,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                mealIcon(meal),
                color: mealIconPalette(meal, Theme.of(context).brightness).$1,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.name,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${_date(meal.date)} · $people',
                    style: TextStyle(
                      color: AppStyle.resolve(context, AppStyle.muted),
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _tag(
                        meal.type,
                        AppStyle.resolve(context, AppStyle.greenSoft),
                        AppStyle.resolve(context, AppStyle.green),
                      ),
                      if (meal.placeId != null)
                        _tag(
                          'Con ubicación',
                          AppStyle.resolve(context, AppStyle.greenSoft),
                          AppStyle.resolve(context, AppStyle.green),
                        ),
                      if (meal.isExample)
                        _tag(
                          'Ejemplo',
                          AppStyle.resolve(context, AppStyle.peach),
                          AppStyle.resolve(context, AppStyle.ink),
                        ),
                      ...meal.categories.map(
                        (c) => _tag(
                          c,
                          AppStyle.resolve(context, AppStyle.roseSoft),
                          AppStyle.resolve(context, AppStyle.rose),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppStyle.resolve(context, AppStyle.muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _NamesDialog extends StatefulWidget {
  const _NamesDialog({required this.names});
  final List<String> names;
  @override
  State<_NamesDialog> createState() => _NamesDialogState();
}

class _HistoryFilterSheet extends StatefulWidget {
  const _HistoryFilterSheet({
    required this.initial,
    required this.categories,
    required this.places,
  });
  final MealHistoryFilter initial;
  final List<String> categories;
  final List<MealPlace> places;
  @override
  State<_HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<_HistoryFilterSheet> {
  late String type = widget.initial.type ?? '';
  late String category = widget.initial.category ?? '';
  late String place = widget.initial.placeId ?? '';
  late DateTimeRange? range =
      widget.initial.start != null && widget.initial.end != null
      ? DateTimeRange(start: widget.initial.start!, end: widget.initial.end!)
      : null;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtrar historial',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: InputDecoration(labelText: 'Tipo'),
            items: ['', 'Desayuno', 'Comida', 'Cena', 'Aperitivo', 'Otro']
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v.isEmpty ? 'Todos los tipos' : v),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => type = v ?? ''),
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: category,
            decoration: InputDecoration(labelText: 'Categoría'),
            items: ['', ...widget.categories]
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(v.isEmpty ? 'Todas las categorías' : v),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => category = v ?? ''),
          ),
          SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: place,
            decoration: InputDecoration(labelText: 'Lugar'),
            items: [
              DropdownMenuItem(value: '', child: Text('Todos los lugares')),
              DropdownMenuItem(value: '__none__', child: Text('Sin ubicación')),
              ...widget.places.map(
                (p) => DropdownMenuItem(
                  value: p.id,
                  child: Text(p.name.isEmpty ? 'Lugar sin nombre' : p.name),
                ),
              ),
            ],
            onChanged: (v) => setState(() => place = v ?? ''),
          ),
          SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.date_range),
            title: Text('Periodo de fechas'),
            subtitle: Text(
              range == null
                  ? 'Todas las fechas'
                  : '${_date(range!.start)} — ${_date(range!.end)}',
            ),
            onTap: () async {
              final selected = await showDateRangePicker(
                context: context,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100, 12, 31),
                initialDateRange: range,
              );
              if (selected != null && mounted) setState(() => range = selected);
            },
          ),
          if (range != null)
            TextButton(
              onPressed: () => setState(() => range = null),
              child: Text('Quitar periodo'),
            ),
          SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              MealHistoryFilter(
                type: type.isEmpty ? null : type,
                category: category.isEmpty ? null : category,
                placeId: place.isEmpty ? null : place,
                start: range?.start,
                end: range?.end,
              ),
            ),
            child: Text('Aplicar filtros'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, MealHistoryFilter()),
            child: Text('Limpiar filtros'),
          ),
        ],
      ),
    ),
  );
}

class _NamesDialogState extends State<_NamesDialog> {
  late final first = TextEditingController(text: widget.names[0]);
  late final second = TextEditingController(text: widget.names[1]);
  final keyForm = GlobalKey<FormState>();
  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Sus nombres'),
    content: Form(
      key: keyForm,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: first,
            decoration: InputDecoration(labelText: 'Persona 1'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
          ),
          SizedBox(height: 10),
          TextFormField(
            controller: second,
            decoration: InputDecoration(labelText: 'Persona 2'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancelar'),
      ),
      TextButton(
        onPressed: () {
          if (keyForm.currentState!.validate()) {
            Navigator.pop(context, [first.text.trim(), second.text.trim()]);
          }
        },
        child: Text('Guardar'),
      ),
    ],
  );
}

class MealFormScreen extends StatefulWidget {
  const MealFormScreen({
    super.key,
    required this.repository,
    required this.names,
    this.meal,
    required this.initialDate,
    this.showMapTiles = true,
    this.initialPlace,
    this.initialAppointment,
  });
  final MealRepository repository;
  final List<String> names;
  final Meal? meal;
  final DateTime initialDate;
  final bool showMapTiles;
  final MealPlace? initialPlace;
  final CalendarEntry? initialAppointment;
  @override
  State<MealFormScreen> createState() => _MealFormScreenState();
}

class _MealFormScreenState extends State<MealFormScreen> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name, ingredients;
  late DateTime date;
  String? type;
  late Set<String> people, selectedCategories;
  List<String> categories = [];
  List<MealPlace> places = [];
  MealPlace? selectedPlace;
  bool initialPlaceLoaded = false;
  bool loading = true, saving = false;
  int step = 0;
  String? loadError, peopleError;
  List<String> suggestions = [];
  Timer? suggestionTimer;
  int suggestionGeneration = 0;
  static const types = ['Desayuno', 'Comida', 'Cena', 'Aperitivo', 'Otro'];
  static const icons = [
    Icons.wb_twilight_rounded,
    Icons.wb_sunny_outlined,
    Icons.nightlight_round,
    Icons.cookie_outlined,
    Icons.restaurant_rounded,
  ];

  @override
  void initState() {
    super.initState();
    final meal = widget.meal;
    name = TextEditingController(text: meal?.name ?? '');
    ingredients = TextEditingController(text: meal?.ingredients ?? '');
    date = meal?.date ?? widget.initialAppointment?.date ?? widget.initialDate;
    type = meal?.type;
    people = meal == null && widget.initialAppointment != null
        ? {'1', '2'}
        : {...?meal?.people};
    selectedCategories = {...?meal?.categories};
    _loadCategories();
  }

  @override
  void dispose() {
    suggestionTimer?.cancel();
    name.dispose();
    ingredients.dispose();
    super.dispose();
  }

  void _searchNames(String value) {
    suggestionTimer?.cancel();
    final generation = ++suggestionGeneration;
    setState(() => suggestions = []);
    if (normalizeMealName(value).isEmpty) return;
    suggestionTimer = Timer(Duration(milliseconds: 200), () async {
      try {
        final result = await widget.repository.suggestMealNames(value);
        if (mounted && generation == suggestionGeneration && step == 0) {
          setState(() => suggestions = result);
        }
      } catch (_) {
        if (mounted && generation == suggestionGeneration) {
          setState(() => suggestions = []);
        }
      }
    });
  }

  Future<void> _loadCategories() async {
    try {
      final result = await widget.repository.getCategories();
      final loadedPlaces = await widget.repository.getPlaces();
      if (mounted) {
        setState(() {
          categories = result;
          places = loadedPlaces;
          if (!initialPlaceLoaded) {
            selectedPlace =
                widget.initialPlace ??
                loadedPlaces
                    .where((place) => place.id == widget.meal?.placeId)
                    .firstOrNull;
            initialPlaceLoaded = true;
          }
          loading = false;
          loadError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = 'No se pudieron cargar las categorías.';
        });
      }
    }
  }

  Future<void> _addCategory() async {
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _CategoryDialog(),
    );
    if (value == null) return;
    try {
      await widget.repository.addCategory(value);
      await _loadCategories();
      if (!mounted) return;
      final found = categories.where(
        (c) => c.toLowerCase() == value.toLowerCase(),
      );
      if (found.isNotEmpty) setState(() => selectedCategories.add(found.first));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la categoría.')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (saving) return;
    if (people.isEmpty) {
      setState(() => peopleError = 'Selecciona al menos un integrante.');
      return;
    }
    setState(() => saving = true);
    String? appointmentId =
        widget.meal?.appointmentId ?? widget.initialAppointment?.id;
    if (appointmentId != null) {
      final CalendarEntry? appointment;
      try {
        appointment = await widget.repository.getAppointment(appointmentId);
      } catch (_) {
        if (mounted) {
          setState(() => saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo verificar la cita.')),
          );
        }
        return;
      }
      if (!mounted) return;
      if (appointment == null) {
        setState(() => saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('La cita ya no existe.')));
        return;
      }
      final conflict =
          dateKey(date) != dateKey(appointment.date) ||
          (appointment.placeId != null &&
              selectedPlace?.id != appointment.placeId);
      if (conflict) {
        final yes = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Desvincular de la cita'),
            content: Text(
              'La fecha o el lugar ya no coincide con la cita. ¿Guardar la comida sin vincularla?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Desvincular y guardar'),
              ),
            ],
          ),
        );
        if (yes != true || !mounted) {
          if (mounted) setState(() => saving = false);
          return;
        }
        appointmentId = null;
      }
    }
    final meal = Meal(
      id: widget.meal?.id ?? Uuid().v4(),
      name: name.text.trim(),
      date: DateUtils.dateOnly(date),
      type: type!,
      ingredients: ingredients.text.trim(),
      categories: selectedCategories.toList(),
      people: people.toList(),
      placeId: selectedPlace?.id,
      appointmentId: appointmentId,
    );
    try {
      await widget.repository.saveMeal(meal, place: selectedPlace);
      if (mounted) await showSaveConfirmation(context);
      if (mounted) Navigator.pop(context, meal);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la comida.')),
        );
      }
    }
  }

  void _next() {
    final valid = formKey.currentState!.validate();
    if (type == null) setState(() {});
    if (valid && type != null) {
      FocusScope.of(context).unfocus();
      suggestionTimer?.cancel();
      suggestionGeneration++;
      setState(() => step = 1);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: step == 0,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && step == 1) setState(() => step = 0);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.meal == null ? 'Nueva comida' : 'Editar comida'),
        leading: BackButton(
          onPressed: () {
            if (step == 1) {
              setState(() => step = 0);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: loading
          ? Center(child: CircularProgressIndicator())
          : loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loadError!),
                  TextButton(
                    onPressed: _loadCategories,
                    child: Text('Reintentar'),
                  ),
                ],
              ),
            )
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'PASO ${step + 1} DE 2',
                              style: TextStyle(
                                color: AppStyle.resolve(context, AppStyle.rose),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 11,
                              ),
                            ),
                            Spacer(),
                            Text(
                              step == 0 ? 'Lo esencial' : 'Los detalles',
                              style: TextStyle(
                                color: AppStyle.resolve(
                                  context,
                                  AppStyle.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: (step + 1) / 2,
                            minHeight: 6,
                            backgroundColor: AppStyle.resolve(
                              context,
                              AppStyle.roseSoft,
                            ),
                            color: AppStyle.resolve(context, AppStyle.rose),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: _motion(context),
                      child: step == 0
                          ? ListView(
                              key: ValueKey('step1'),
                              padding: EdgeInsets.all(24),
                              children: [
                                Text(
                                  '¿Qué comieron?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 7),
                                Text(
                                  'Empecemos por lo más importante.',
                                  style: TextStyle(
                                    color: AppStyle.resolve(
                                      context,
                                      AppStyle.muted,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 24),
                                Form(
                                  key: formKey,
                                  child: TextFormField(
                                    controller: name,
                                    onChanged: _searchNames,
                                    decoration: InputDecoration(
                                      labelText: 'Nombre del platillo *',
                                      hintText: 'Por ejemplo: tacos de pollo',
                                      prefixIcon: Icon(
                                        Icons.restaurant_rounded,
                                      ),
                                    ),
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Escribe el nombre del platillo'
                                        : null,
                                  ),
                                ),
                                if (suggestions.isNotEmpty) ...[
                                  SizedBox(height: 8),
                                  SoftCard(
                                    padding: EdgeInsets.symmetric(vertical: 4),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: suggestions
                                          .map(
                                            (suggestion) => ListTile(
                                              dense: true,
                                              leading: Icon(
                                                Icons.history,
                                                color: AppStyle.resolve(
                                                  context,
                                                  AppStyle.rose,
                                                ),
                                              ),
                                              title: Text(suggestion),
                                              onTap: () {
                                                suggestionTimer?.cancel();
                                                suggestionGeneration++;
                                                name.text = suggestion;
                                                name.selection =
                                                    TextSelection.collapsed(
                                                      offset: suggestion.length,
                                                    );
                                                FocusScope.of(
                                                  context,
                                                ).unfocus();
                                                setState(
                                                  () => suggestions = [],
                                                );
                                              },
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ],
                                SizedBox(height: 18),
                                SoftCard(
                                  padding: EdgeInsets.zero,
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.calendar_today_rounded,
                                      color: AppStyle.resolve(
                                        context,
                                        AppStyle.rose,
                                      ),
                                    ),
                                    title: Text('Fecha'),
                                    subtitle: Text(_date(date)),
                                    trailing: Icon(Icons.chevron_right),
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: date,
                                        firstDate: DateTime(1900),
                                        lastDate: DateTime(2100),
                                      );
                                      if (picked != null && mounted) {
                                        setState(() => date = picked);
                                      }
                                    },
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  '¿En qué momento?',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Elige un tipo de comida.',
                                  style: TextStyle(
                                    color: AppStyle.resolve(
                                      context,
                                      AppStyle.muted,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List.generate(
                                    types.length,
                                    (i) => ChoiceChip(
                                      avatar: Icon(icons[i], size: 18),
                                      label: Text(types[i]),
                                      selected: type == types[i],
                                      onSelected: (_) =>
                                          setState(() => type = types[i]),
                                    ),
                                  ),
                                ),
                                if (type == null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Text(
                                      'Selecciona un tipo para continuar.',
                                      style: TextStyle(
                                        color: AppStyle.resolve(
                                          context,
                                          AppStyle.muted,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : ListView(
                              key: ValueKey('step2'),
                              padding: EdgeInsets.all(24),
                              children: [
                                Text(
                                  'Un poco más de sabor',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 7),
                                Text(
                                  'Solo falta elegir quiénes disfrutaron este platillo.',
                                  style: TextStyle(
                                    color: AppStyle.resolve(
                                      context,
                                      AppStyle.muted,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 24),
                                Text(
                                  '¿Quiénes comieron? *',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: List.generate(
                                    2,
                                    (i) => FilterChip(
                                      avatar: Icon(
                                        Icons.person_outline_rounded,
                                        size: 18,
                                      ),
                                      label: Text(widget.names[i]),
                                      selected: people.contains('${i + 1}'),
                                      onSelected: (value) => setState(() {
                                        if (value) {
                                          people.add('${i + 1}');
                                        } else {
                                          people.remove('${i + 1}');
                                        }
                                        peopleError = null;
                                      }),
                                    ),
                                  ),
                                ),
                                if (peopleError != null)
                                  Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      peopleError!,
                                      style: TextStyle(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                SizedBox(height: 24),
                                Text(
                                  'Ingredientes',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Opcional · anota lo que quieras recordar.',
                                  style: TextStyle(
                                    color: AppStyle.resolve(
                                      context,
                                      AppStyle.muted,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                TextField(
                                  controller: ingredients,
                                  decoration: InputDecoration(
                                    hintText: 'Ej. arroz, pollo, verduras',
                                  ),
                                  maxLines: 2,
                                ),
                                SizedBox(height: 24),
                                Text(
                                  'Categorías',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Opcional · puedes elegir varias.',
                                  style: TextStyle(
                                    color: AppStyle.resolve(
                                      context,
                                      AppStyle.muted,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ...categories.map(
                                      (category) => FilterChip(
                                        label: Text(category),
                                        selected: selectedCategories.contains(
                                          category,
                                        ),
                                        onSelected: (value) => setState(() {
                                          if (value) {
                                            selectedCategories.add(category);
                                          } else {
                                            selectedCategories.remove(category);
                                          }
                                        }),
                                      ),
                                    ),
                                    ActionChip(
                                      avatar: Icon(Icons.add, size: 18),
                                      label: Text('Nueva categoría'),
                                      onPressed: _addCategory,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 24),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    final result =
                                        await Navigator.push<MealPlace>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PlacePicker(
                                              places: places,
                                              initial: selectedPlace,
                                              showTiles: widget.showMapTiles,
                                            ),
                                          ),
                                        );
                                    if (result != null && mounted) {
                                      setState(() => selectedPlace = result);
                                    }
                                  },
                                  icon: Icon(Icons.add_location_alt_outlined),
                                  label: Text(
                                    selectedPlace == null
                                        ? 'Agregar ubicación'
                                        : 'Cambiar ubicación',
                                  ),
                                ),
                                if (selectedPlace != null)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.place_outlined,
                                      color: AppStyle.resolve(
                                        context,
                                        AppStyle.rose,
                                      ),
                                    ),
                                    title: Text(
                                      selectedPlace!.name.isEmpty
                                          ? 'Lugar sin nombre'
                                          : selectedPlace!.name,
                                    ),
                                    subtitle: Text(
                                      '${selectedPlace!.latitude.toStringAsFixed(4)}, ${selectedPlace!.longitude.toStringAsFixed(4)}',
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Quitar ubicación',
                                      icon: Icon(Icons.close),
                                      onPressed: () =>
                                          setState(() => selectedPlace = null),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 8, 24, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: saving ? null : (step == 0 ? _next : _save),
                        child: Text(
                          saving
                              ? 'Guardando...'
                              : step == 0
                              ? 'Continuar'
                              : 'Guardar comida',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog();
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Nueva categoría'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: 'Nombre'),
        validator: (value) =>
            value == null || value.trim().isEmpty ? 'Escribe un nombre' : null,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancelar'),
      ),
      TextButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(context, controller.text.trim());
          }
        },
        child: Text('Añadir'),
      ),
    ],
  );
}

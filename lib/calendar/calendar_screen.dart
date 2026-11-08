import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../app_style.dart';
import '../motion.dart';
import '../meals/meal_calendar.dart';
import '../meals/meal_repository.dart';
import '../meals/meals_screen.dart';

class CalendarLoader extends StatefulWidget {
  const CalendarLoader({super.key});
  @override
  State<CalendarLoader> createState() => _CalendarLoaderState();
}

class _CalendarLoaderState extends State<CalendarLoader> {
  late Future<SqliteMealRepository> future;
  @override
  void initState() {
    super.initState();
    future = SqliteMealRepository.open();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SqliteMealRepository>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasData) return CalendarScreen(repository: snapshot.data!);
      return Scaffold(
        appBar: AppBar(title: const Text('Calendario')),
        body: Center(
          child: snapshot.hasError
              ? TextButton(
                  onPressed: () =>
                      setState(() => future = SqliteMealRepository.open()),
                  child: const Text('No se pudo abrir. Reintentar'),
                )
              : const CircularProgressIndicator(),
        ),
      );
    },
  );
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.repository});
  final SqliteMealRepository repository;
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);
  List<CalendarEntry> entries = [];
  bool loading = true;
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++generation;
    try {
      final data = await widget.repository.getCalendarEntries(month: month);
      if (mounted && request == generation) {
        setState(() {
          entries = data;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          loading = false;
          error = 'No se pudo cargar el calendario.';
        });
      }
    }
  }

  Future<void> _create(String kind) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarEntryForm(
          repository: widget.repository,
          kind: kind,
          initialDate: selected,
        ),
      ),
    );
    await _load();
  }

  Future<void> _open(CalendarEntry entry) async {
    if (entry.kind == 'appointment') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppointmentDetailScreen(
            repository: widget.repository,
            appointmentId: entry.id,
          ),
        ),
      );
    } else {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CalendarEntryForm(
            repository: widget.repository,
            kind: 'reminder',
            initialDate: entry.date,
            entry: entry,
          ),
        ),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final daily = entries
        .where((entry) => sameDay(entry.date, selected))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(
              child: TextButton(
                onPressed: _load,
                child: Text('$error Reintentar'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                Text(
                  'Sus momentos',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Citas y notas para recordar.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                _EntryCalendar(
                  month: month,
                  selected: selected,
                  entries: entries,
                  onMonth: (value) {
                    setState(() {
                      month = value;
                      selected = DateTime(value.year, value.month, 1);
                    });
                    _load();
                  },
                  onDay: (value) => setState(() => selected = value),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite_rounded,
                          size: 14,
                          color: AppStyle.resolve(context, AppStyle.rose),
                        ),
                        const SizedBox(width: 5),
                        const Text('Citas'),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 8,
                          color: AppStyle.resolve(context, AppStyle.green),
                        ),
                        const SizedBox(width: 5),
                        const Text('Recordatorios'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dayLabel(selected),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Agregar',
                      onSelected: _create,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'appointment',
                          child: Text('Nueva cita'),
                        ),
                        PopupMenuItem(
                          value: 'reminder',
                          child: Text('Nuevo recordatorio'),
                        ),
                      ],
                      child: const Chip(
                        avatar: Icon(Icons.add),
                        label: Text('Agregar'),
                      ),
                    ),
                  ],
                ),
                AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  child: Column(
                    key: ValueKey(dateKey(selected)),
                    children: [
                      if (daily.isEmpty)
                        const SoftCard(
                          child: Text(
                            'No hay citas ni recordatorios para este día.',
                          ),
                        ),
                      ...daily.map(
                        (entry) => Card(
                          child: ListTile(
                            leading: Icon(
                              entry.kind == 'appointment'
                                  ? Icons.favorite_outline
                                  : Icons.notes_outlined,
                            ),
                            title: Text(entry.title),
                            subtitle: Text(
                              '${entry.kind == 'appointment' ? 'Cita' : 'Recordatorio'}${entry.isExample ? ' · Ejemplo' : ''}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _open(entry),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _EntryCalendar extends StatelessWidget {
  const _EntryCalendar({
    required this.month,
    required this.selected,
    required this.entries,
    required this.onMonth,
    required this.onDay,
  });
  final DateTime month, selected;
  final List<CalendarEntry> entries;
  final ValueChanged<DateTime> onMonth, onDay;
  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final offset = first.weekday - 1;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = ((offset + days) / 7).ceil();
    return SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: month.year == 1900 && month.month == 1
                    ? null
                    : () => onMonth(DateTime(month.year, month.month - 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  monthLabel(month),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: month.year == 2100 && month.month == 12
                    ? null
                    : () => onMonth(DateTime(month.year, month.month + 1)),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: [
              'L',
              'M',
              'M',
              'J',
              'V',
              'S',
              'D',
            ].map((e) => Expanded(child: Center(child: Text(e)))).toList(),
          ),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final day = r * 7 + c - offset + 1;
                        if (day < 1 || day > days) {
                          return const SizedBox(height: 48);
                        }
                        final date = DateTime(month.year, month.month, day);
                        final active = sameDay(date, selected);
                        final items = entries.where(
                          (e) => sameDay(e.date, date),
                        );
                        return Semantics(
                          button: true,
                          selected: active,
                          label:
                              '${dayLabel(date)}: ${items.where((e) => e.kind == 'appointment').length} citas, ${items.where((e) => e.kind == 'reminder').length} recordatorios',
                          child: InkWell(
                            onTap: () => onDay(date),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 48,
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: active
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '$day',
                                      style: TextStyle(
                                        color: active
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                            : null,
                                      ),
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (items.any(
                                        (e) => e.kind == 'appointment',
                                      ))
                                        AnimatedScale(
                                          duration:
                                              MediaQuery.disableAnimationsOf(
                                                context,
                                              )
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 220,
                                                ),
                                          scale: active ? 1.25 : 1,
                                          curve: Curves.easeOutBack,
                                          child: Icon(
                                            Icons.favorite_rounded,
                                            size: 9,
                                            color: active
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary
                                                : AppStyle.resolve(
                                                    context,
                                                    AppStyle.rose,
                                                  ),
                                          ),
                                        ),
                                      if (items.any(
                                        (e) => e.kind == 'reminder',
                                      ))
                                        Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: active
                                              ? (Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? AppStyle.green
                                                    : const Color(0xFFB9F3D3))
                                              : AppStyle.resolve(
                                                  context,
                                                  AppStyle.green,
                                                ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class CalendarEntryForm extends StatefulWidget {
  const CalendarEntryForm({
    super.key,
    required this.repository,
    required this.kind,
    required this.initialDate,
    this.entry,
    this.initialPlaceId,
  });
  final SqliteMealRepository repository;
  final String kind;
  final DateTime initialDate;
  final CalendarEntry? entry;
  final String? initialPlaceId;
  @override
  State<CalendarEntryForm> createState() => _CalendarEntryFormState();
}

class _CalendarEntryFormState extends State<CalendarEntryForm> {
  final keyForm = GlobalKey<FormState>();
  late final title = TextEditingController(text: widget.entry?.title ?? '');
  late final description = TextEditingController(
    text: widget.entry?.description ?? '',
  );
  late DateTime date = widget.entry?.date ?? widget.initialDate;
  late String? placeId = widget.entry?.placeId ?? widget.initialPlaceId;
  List<MealPlace> places = [];
  bool loading = true, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repository.getPlaces();
      if (mounted) {
        setState(() {
          places = data;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'No se pudieron cargar los lugares.';
        });
      }
    }
  }

  Future<void> _save() async {
    if (saving) return;
    if (!keyForm.currentState!.validate()) return;
    setState(() => saving = true);
    if (widget.entry != null &&
        widget.kind == 'appointment' &&
        (dateKey(date) != dateKey(widget.entry!.date) ||
            placeId != widget.entry!.placeId)) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambiar la cita'),
          content: const Text(
            'Las comidas vinculadas se desvincularán y conservarán su fecha y lugar. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar cambios'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) {
        if (mounted) setState(() => saving = false);
        return;
      }
    }
    try {
      await widget.repository.saveCalendarEntry(
        CalendarEntry(
          id: widget.entry?.id ?? const Uuid().v4(),
          kind: widget.kind,
          title: title.text.trim(),
          date: date,
          description: description.text.trim(),
          placeId: placeId,
        ),
      );
      if (mounted) await showSaveConfirmation(context);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar. Inténtalo de nuevo.'),
          ),
        );
      }
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar recordatorio'),
        content: const Text('¿Eliminar esta nota?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.repository.deleteCalendarEntry(widget.entry!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No se pudo eliminar.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.entry == null ? 'Nueva' : 'Editar'} ${widget.kind == 'appointment' ? 'cita' : 'nota'}',
      ),
      actions: [
        if (widget.entry != null && widget.kind == 'reminder')
          IconButton(
            tooltip: 'Eliminar recordatorio',
            onPressed: _delete,
            icon: const Icon(Icons.delete_outline),
          ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: TextButton(
              onPressed: _load,
              child: Text('$error Reintentar'),
            ),
          )
        : Form(
            key: keyForm,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (widget.entry?.isExample == true)
                  const Text('Registro de ejemplo'),
                if (widget.kind == 'reminder')
                  const Padding(
                    padding: EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Guarda una fecha importante, como un cumpleaños o aniversario. Es una fecha única y no se repite automáticamente.',
                    ),
                  ),
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Escribe un título'
                      : null,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: description,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: widget.kind == 'appointment'
                        ? '¿Qué hicieron?'
                        : 'Descripción (opcional)',
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Fecha'),
                  subtitle: Text('${dayLabel(date)} de ${date.year}'),
                  onTap: () async {
                    final result = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(1900),
                      lastDate: DateTime(2100, 12, 31),
                    );
                    if (result != null && mounted) {
                      setState(() => date = result);
                    }
                  },
                ),
                DropdownButtonFormField<String>(
                  initialValue: placeId ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Lugar (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Sin lugar')),
                    ...places.map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(
                          p.name.isEmpty ? 'Lugar sin nombre' : p.name,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () =>
                        placeId = value == null || value.isEmpty ? null : value,
                  ),
                ),
                if (widget.kind == 'appointment')
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Esta cita es compartida por ambos integrantes.',
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: saving ? null : _save,
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),
  );
}

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.repository,
    required this.appointmentId,
  });
  final SqliteMealRepository repository;
  final String appointmentId;
  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  CalendarEntry? appointment;
  MealPlace? place;
  List<Meal> meals = [];
  bool loading = true, more = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entry = await widget.repository.getAppointment(
        widget.appointmentId,
      );
      final places = await widget.repository.getPlaces();
      final page = await widget.repository.getAppointmentMeals(
        widget.appointmentId,
      );
      if (mounted) {
        setState(() {
          appointment = entry;
          place = places.where((p) => p.id == entry?.placeId).firstOrNull;
          meals = page.items;
          more = page.hasMore;
          loading = false;
          error = entry == null ? 'La cita ya no existe.' : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'No se pudo cargar la cita.';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (busy || meals.isEmpty || !more) return;
    setState(() => busy = true);
    try {
      final page = await widget.repository.getAppointmentMeals(
        widget.appointmentId,
        after: meals.last,
      );
      if (mounted) {
        setState(() {
          meals = [...meals, ...page.items];
          more = page.hasMore;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudieron cargar las comidas.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarEntryForm(
          repository: widget.repository,
          kind: 'appointment',
          initialDate: appointment!.date,
          entry: appointment,
        ),
      ),
    );
    await _load();
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cita'),
        content: const Text(
          'Las comidas vinculadas se conservarán con su fecha y lugar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await widget.repository.deleteCalendarEntry(widget.appointmentId);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar la cita.')),
        );
      }
    }
  }

  Future<void> _newMeal() async {
    try {
      final names = await widget.repository.getNames();
      if (!mounted || appointment == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MealFormScreen(
            repository: widget.repository,
            names: names,
            initialDate: appointment!.date,
            initialPlace: place,
            initialAppointment: appointment,
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el registro.')),
        );
      }
    }
  }

  Future<void> _link() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AppointmentMealPicker(
          repository: widget.repository,
          appointment: appointment!,
        ),
      ),
    );
    await _load();
  }

  Future<void> _unlink(Meal meal) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular comida'),
        content: Text(
          '¿Quitar «${meal.name}» de esta cita? La comida conservará su fecha y lugar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (yes == true) {
      try {
        await widget.repository.unlinkMealFromAppointment(
          meal.id,
          widget.appointmentId,
        );
        await _load();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo desvincular la comida.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle de la cita'),
      actions: [
        IconButton(
          tooltip: 'Editar cita',
          onPressed: appointment == null ? null : _edit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Eliminar cita',
          onPressed: appointment == null ? null : _delete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: TextButton(
              onPressed: _load,
              child: Text('$error Reintentar'),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                appointment!.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (appointment!.isExample) const Text('Ejemplo'),
              const SizedBox(height: 8),
              Text(
                '${dayLabel(appointment!.date)} de ${appointment!.date.year} · Ambos',
              ),
              const SizedBox(height: 8),
              Text(
                place == null
                    ? 'Sin lugar'
                    : (place!.name.isEmpty ? 'Lugar sin nombre' : place!.name),
              ),
              if (appointment!.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(appointment!.description),
              ],
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _newMeal,
                    icon: const Icon(Icons.add),
                    label: const Text('Nueva comida'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _link,
                    icon: const Icon(Icons.link),
                    label: const Text('Vincular comida'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Comidas de esta cita',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (meals.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text('Todavía no hay comidas vinculadas.'),
                ),
              ...meals.map(
                (meal) => Card(
                  child: ListTile(
                    leading: Icon(mealIcon(meal)),
                    title: Text(meal.name),
                    subtitle: Text(
                      '${meal.type}${meal.isExample ? ' · Ejemplo' : ''}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Desvincular de cita',
                      onPressed: () => _unlink(meal),
                      icon: const Icon(Icons.link_off),
                    ),
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(meal.name),
                        content: Text(
                          '${meal.type}\nIngredientes: ${meal.ingredients.isEmpty ? 'Sin ingredientes' : meal.ingredients}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (more)
                TextButton(
                  onPressed: busy ? null : _loadMore,
                  child: const Text('Cargar más'),
                ),
            ],
          ),
  );
}

class _AppointmentMealPicker extends StatefulWidget {
  const _AppointmentMealPicker({
    required this.repository,
    required this.appointment,
  });
  final SqliteMealRepository repository;
  final CalendarEntry appointment;
  @override
  State<_AppointmentMealPicker> createState() => _AppointmentMealPickerState();
}

class _AppointmentMealPickerState extends State<_AppointmentMealPicker> {
  List<Meal> meals = [];
  bool loading = true, more = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool next = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final page = await widget.repository.getMealPage(
        after: next && meals.isNotEmpty ? meals.last : null,
      );
      if (mounted) {
        setState(() {
          meals = next ? [...meals, ...page.items] : page.items;
          more = page.hasMore;
          loading = false;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'No se pudieron cargar las comidas.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _select(Meal meal) async {
    final entry = widget.appointment;
    if (meal.appointmentId == entry.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta comida ya pertenece a la cita.')),
      );
      return;
    }
    final conflict =
        meal.appointmentId != null ||
        dateKey(meal.date) != dateKey(entry.date) ||
        (entry.placeId != null && meal.placeId != entry.placeId);
    if (conflict) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Actualizar y vincular'),
          content: Text(
            'La comida ajustará su fecha${entry.placeId != null ? ' y lugar' : ''} a esta cita${meal.appointmentId != null ? ' y dejará de pertenecer a su cita anterior' : ''}. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Vincular'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    try {
      await widget.repository.linkMealToAppointment(
        meal.id,
        entry.id,
        confirmed: conflict,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo vincular; verifica si cambió la comida.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Elegir comida')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(
            child: TextButton(
              onPressed: () => _load(),
              child: Text('$error Reintentar'),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (meals.isEmpty) const Text('No hay comidas registradas.'),
              ...meals.map(
                (meal) => Card(
                  child: ListTile(
                    title: Text(meal.name),
                    subtitle: Text(
                      '${dayLabel(meal.date)} · ${meal.type}${meal.appointmentId == null ? '' : ' · vinculada a una cita'}',
                    ),
                    onTap: () => _select(meal),
                  ),
                ),
              ),
              if (more)
                TextButton(
                  onPressed: busy ? null : () => _load(next: true),
                  child: const Text('Cargar más'),
                ),
            ],
          ),
  );
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../app_style.dart';
import '../motion.dart';
import '../meals/meal_repository.dart';
import '../meals/meals_screen.dart';
import '../meals/place_picker.dart';
import '../calendar/calendar_screen.dart';

/// Groups nearby points at a given zoom; the list remains available for overlaps.
List<List<MealPlace>> groupPlaces(List<MealPlace> places, double zoom) {
  final size = 256 * math.pow(2, zoom.floor());
  final groups = <String, List<MealPlace>>{};
  for (final place in places) {
    final lat = place.latitude.clamp(-85.0, 85.0) * math.pi / 180;
    final x = (place.longitude + 180) / 360 * size;
    final y =
        (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * size;
    final key = '${(x / 72).floor()}:${(y / 72).floor()}';
    (groups[key] ??= []).add(place);
  }
  return groups.values.toList();
}

class PlacesLoader extends StatefulWidget {
  const PlacesLoader({super.key});
  @override
  State<PlacesLoader> createState() => _PlacesLoaderState();
}

class _PlacesLoaderState extends State<PlacesLoader> {
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
      if (snapshot.hasData) return PlacesScreen(repository: snapshot.data!);
      return Scaffold(
        appBar: AppBar(title: const Text('Lugares')),
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

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({
    super.key,
    required this.repository,
    this.showTiles = true,
  });
  final SqliteMealRepository repository;
  final bool showTiles;
  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final controller = MapController();
  List<MealPlace> places = [];
  Map<String, int> counts = {};
  bool loading = true, error = false, mapError = false;
  double zoom = 4;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await widget.repository.getPlaces();
      final c = await widget.repository.getPlaceCounts();
      if (mounted) {
        setState(() {
          places = p;
          counts = c;
          loading = false;
          error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = true;
        });
      }
    }
  }

  Future<void> _open(MealPlace place) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlaceDetailScreen(repository: widget.repository, placeId: place.id),
      ),
    );
    await _load();
  }

  Future<void> _create() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlaceEditScreen(repository: widget.repository),
      ),
    );
    await _load();
  }

  void _clusterTap(List<MealPlace> group) {
    if (group.length == 1) {
      _open(group.first);
      return;
    }
    if (zoom >= 18) {
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: group
                .map(
                  (p) => ListTile(
                    title: Text(p.name.isEmpty ? 'Lugar sin nombre' : p.name),
                    onTap: () {
                      Navigator.pop(context);
                      _open(p);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      );
      return;
    }
    final lat =
        group.map((p) => p.latitude).reduce((a, b) => a + b) / group.length;
    final lon =
        group.map((p) => p.longitude).reduce((a, b) => a + b) / group.length;
    controller.move(LatLng(lat, lon), math.min(18, zoom + 2));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lugares')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: loading ? null : _create,
      icon: const Icon(Icons.add_location_alt_outlined),
      label: const Text('Agregar lugar'),
    ),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error
        ? Center(
            child: TextButton(
              onPressed: _load,
              child: const Text(
                'No se pudieron cargar los lugares. Reintentar',
              ),
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
            children: [
              Text(
                'Sus lugares',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Los rincones donde han compartido momentos.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 300,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: controller,
                        options: MapOptions(
                          initialCenter: places.isEmpty
                              ? const LatLng(0, 0)
                              : LatLng(
                                  places.first.latitude,
                                  places.first.longitude,
                                ),
                          initialZoom: places.isEmpty ? 2 : 4,
                          onPositionChanged: (camera, _) {
                            if (camera.zoom.floor() != zoom.floor()) {
                              setState(() => zoom = camera.zoom);
                            }
                          },
                        ),
                        children: [
                          if (widget.showTiles)
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName:
                                  'com.example.app_couple_system',
                              errorTileCallback: (_, _, _) {
                                if (mounted && !mapError) {
                                  WidgetsBinding.instance.addPostFrameCallback((
                                    _,
                                  ) {
                                    if (mounted) {
                                      setState(() => mapError = true);
                                    }
                                  });
                                }
                              },
                            ),
                          MarkerLayer(
                            markers: groupPlaces(places, zoom).map((group) {
                              final lat =
                                  group
                                      .map((p) => p.latitude)
                                      .reduce((a, b) => a + b) /
                                  group.length;
                              final lon =
                                  group
                                      .map((p) => p.longitude)
                                      .reduce((a, b) => a + b) /
                                  group.length;
                              return Marker(
                                point: LatLng(lat, lon),
                                width: 48,
                                height: 48,
                                child: Semantics(
                                  button: true,
                                  label: group.length == 1
                                      ? group.first.name
                                      : '${group.length} lugares',
                                  child: InkWell(
                                    onTap: () => _clusterTap(group),
                                    child: CircleAvatar(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      foregroundColor: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                      child: group.length == 1
                                          ? const Icon(Icons.place)
                                          : Text('${group.length}'),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const RichAttributionWidget(
                            attributions: [
                              TextSourceAttribution(
                                'OpenStreetMap contributors',
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (mapError)
                        Positioned(
                          top: 8,
                          left: 8,
                          right: 8,
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'No se pudo cargar el mapa. Puedes usar la lista.',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Todos los lugares',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (places.isEmpty)
                const SoftCard(
                  child: Text(
                    'Agrega un lugar para empezar a reunir sus recuerdos.',
                  ),
                ),
              ...places.map(
                (place) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(
                        place.name.isEmpty ? 'Lugar sin nombre' : place.name,
                      ),
                      subtitle: Text('${counts[place.id] ?? 0} comidas'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(place),
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}

class PlaceEditScreen extends StatefulWidget {
  const PlaceEditScreen({
    super.key,
    required this.repository,
    this.place,
    this.showMapTiles = true,
  });
  final SqliteMealRepository repository;
  final MealPlace? place;
  final bool showMapTiles;
  @override
  State<PlaceEditScreen> createState() => _PlaceEditScreenState();
}

class _PlaceEditScreenState extends State<PlaceEditScreen> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.place?.name ?? '');
  late final address = TextEditingController(text: widget.place?.address ?? '');
  late final notes = TextEditingController(text: widget.place?.notes ?? '');
  MealPlace? point;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    point = widget.place;
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await Navigator.push<MealPlace>(
      context,
      MaterialPageRoute(
        builder: (_) => PlacePicker(
          places: const [],
          initial: point,
          showTiles: widget.showMapTiles,
        ),
      ),
    );
    if (result != null && mounted) setState(() => point = result);
  }

  Future<void> _save() async {
    if (saving) return;
    if (!form.currentState!.validate()) return;
    if (point == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una ubicación en el mapa.')),
      );
      return;
    }
    setState(() => saving = true);
    final old = widget.place;
    if (old != null &&
        (old.latitude != point!.latitude ||
            old.longitude != point!.longitude)) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambiar coordenadas'),
          content: const Text(
            'El cambio también se reflejará en todas las comidas vinculadas a este lugar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
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
      await widget.repository.savePlace(
        MealPlace(
          id: old?.id ?? const Uuid().v4(),
          name: name.text.trim(),
          latitude: point!.latitude,
          longitude: point!.longitude,
          address: address.text.trim(),
          notes: notes.text.trim(),
        ),
      );
      if (mounted) await showSaveConfirmation(context);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar el lugar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.place == null ? 'Nuevo lugar' : 'Editar lugar'),
    ),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextFormField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Nombre del lugar *'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Escribe un nombre' : null,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: address,
            decoration: const InputDecoration(
              labelText: 'Dirección (opcional)',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Propósito o notas (opcional)',
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.map_outlined),
            label: Text(
              point == null ? 'Elegir ubicación' : 'Cambiar ubicación',
            ),
          ),
          if (point != null)
            Text(
              '${point!.latitude.toStringAsFixed(5)}, ${point!.longitude.toStringAsFixed(5)}',
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving ? null : _save,
            child: const Text('Guardar lugar'),
          ),
        ],
      ),
    ),
  );
}

class PlaceDetailScreen extends StatefulWidget {
  const PlaceDetailScreen({
    super.key,
    required this.repository,
    required this.placeId,
  });
  final SqliteMealRepository repository;
  final String placeId;
  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  MealPlace? place;
  List<Meal> meals = [];
  List<CalendarEntry> appointments = [];
  bool showAppointments = false;
  Map<String, int> types = {};
  bool loading = true, more = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final places = await widget.repository.getPlaces();
      final current = places.where((p) => p.id == widget.placeId).firstOrNull;
      final page = await widget.repository.getPlaceMeals(widget.placeId);
      final summary = await widget.repository.getPlaceTypes(widget.placeId);
      final events = await widget.repository.getCalendarEntries(
        placeId: widget.placeId,
      );
      if (mounted) {
        setState(() {
          place = current;
          meals = page.items;
          more = page.hasMore;
          types = summary;
          appointments = events.where((e) => e.kind == 'appointment').toList();
          loading = false;
          error = current == null ? 'El lugar ya no existe.' : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'No se pudo cargar el lugar.';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (busy || !more || meals.isEmpty) return;
    setState(() => busy = true);
    try {
      final page = await widget.repository.getPlaceMeals(
        widget.placeId,
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
          const SnackBar(content: Text('No se pudieron cargar más comidas.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _newMeal() async {
    try {
      final names = await widget.repository.getNames();
      if (!mounted || place == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MealFormScreen(
            repository: widget.repository,
            names: names,
            initialDate: DateTime.now(),
            initialPlace: place,
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el registro de comida.'),
          ),
        );
      }
    }
  }

  Future<void> _edit() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PlaceEditScreen(repository: widget.repository, place: place),
      ),
    );
    await _load();
  }

  Future<void> _delete() async {
    if (types.values.fold<int>(0, (a, b) => a + b) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Desvincula o reasigna las comidas antes de eliminar este lugar.',
          ),
        ),
      );
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lugar'),
        content: const Text('¿Eliminar este lugar guardado?'),
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
      final deleted = await widget.repository.deleteEmptyPlace(widget.placeId);
      if (!mounted) return;
      if (deleted) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El lugar tiene comidas, citas o recordatorios vinculados.',
            ),
          ),
        );
        await _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el lugar.')),
        );
      }
    }
  }

  Future<void> _unlink(Meal meal) async {
    final appointment = meal.appointmentId == null
        ? null
        : await widget.repository.getAppointment(meal.appointmentId!);
    if (!mounted) return;
    final needsUnlink = appointment?.placeId != null;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desvincular comida'),
        content: Text(
          '¿Quitar la ubicación de «${meal.name}»?${needsUnlink ? ' También se desvinculará de su cita.' : ''}',
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
    if (yes != true) return;
    try {
      await widget.repository.assignMealToPlace(
        meal.id,
        null,
        unlinkAppointment: needsUnlink,
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

  Future<void> _linkExisting() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ChooseMealScreen(
          repository: widget.repository,
          placeId: widget.placeId,
        ),
      ),
    );
    await _load();
  }

  Future<void> _newAppointment() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarEntryForm(
          repository: widget.repository,
          kind: 'appointment',
          initialDate: DateTime.now(),
          initialPlaceId: widget.placeId,
        ),
      ),
    );
    await _load();
  }

  Future<void> _openAppointment(CalendarEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentDetailScreen(
          repository: widget.repository,
          appointmentId: entry.id,
        ),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle del lugar'),
      actions: [
        IconButton(
          tooltip: 'Editar lugar',
          onPressed: place == null ? null : _edit,
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          tooltip: 'Eliminar lugar',
          onPressed: place == null ? null : _delete,
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                place!.name.isEmpty ? 'Lugar sin nombre' : place!.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${place!.latitude.toStringAsFixed(5)}, ${place!.longitude.toStringAsFixed(5)}',
              ),
              if (place!.address.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(place!.address),
              ],
              if (place!.notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(place!.notes),
              ],
              const SizedBox(height: 20),
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${types.values.fold<int>(0, (a, b) => a + b)} comidas vinculadas',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (types.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        types.entries
                            .map((e) => '${e.key}: ${e.value}')
                            .join(' · '),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Comidas'),
                    icon: Icon(Icons.restaurant),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Citas'),
                    icon: Icon(Icons.favorite_outline),
                  ),
                ],
                selected: {showAppointments},
                onSelectionChanged: (value) =>
                    setState(() => showAppointments = value.first),
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              if (!showAppointments)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _newMeal,
                      icon: const Icon(Icons.add),
                      label: const Text('Nueva comida'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _linkExisting,
                      icon: const Icon(Icons.link),
                      label: const Text('Vincular existente'),
                    ),
                  ],
                ),
              if (showAppointments)
                FilledButton.icon(
                  onPressed: _newAppointment,
                  icon: const Icon(Icons.add),
                  label: const Text('Nueva cita'),
                ),
              const SizedBox(height: 20),
              Text(
                showAppointments
                    ? 'Citas en este lugar'
                    : 'Comidas en este lugar',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (!showAppointments && meals.isEmpty)
                const Text('Aún no hay comidas en este lugar.'),
              if (!showAppointments)
                ...meals.map(
                  (meal) => Card(
                    child: ListTile(
                      leading: Icon(mealIcon(meal)),
                      title: Text(meal.name),
                      subtitle: Text(
                        '${meal.type} · ${meal.date.day}/${meal.date.month}/${meal.date.year}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Desvincular comida',
                        onPressed: () => _unlink(meal),
                        icon: const Icon(Icons.link_off),
                      ),
                    ),
                  ),
                ),
              if (!showAppointments && more)
                TextButton(
                  onPressed: busy ? null : _loadMore,
                  child: const Text('Cargar más'),
                ),
              if (showAppointments && appointments.isEmpty)
                const Text('Aún no hay citas en este lugar.'),
              if (showAppointments)
                ...appointments.map(
                  (entry) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.favorite_outline),
                      title: Text(entry.title),
                      subtitle: Text(
                        '${entry.date.day}/${entry.date.month}/${entry.date.year}${entry.isExample ? ' · Ejemplo' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openAppointment(entry),
                    ),
                  ),
                ),
            ],
          ),
  );
}

class _ChooseMealScreen extends StatefulWidget {
  const _ChooseMealScreen({required this.repository, required this.placeId});
  final SqliteMealRepository repository;
  final String placeId;
  @override
  State<_ChooseMealScreen> createState() => _ChooseMealScreenState();
}

class _ChooseMealScreenState extends State<_ChooseMealScreen> {
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
    if (meal.placeId == widget.placeId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta comida ya está en este lugar.')),
      );
      return;
    }
    final appointment = meal.appointmentId == null
        ? null
        : await widget.repository.getAppointment(meal.appointmentId!);
    if (!mounted) return;
    final needsUnlink =
        appointment?.placeId != null && appointment!.placeId != widget.placeId;
    if (meal.placeId != null || needsUnlink) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambiar lugar'),
          content: Text(
            '¿Quieres asignar «${meal.name}» a este lugar?${needsUnlink ? ' También se desvinculará de su cita.' : ''}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Trasladar'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    try {
      await widget.repository.assignMealToPlace(
        meal.id,
        widget.placeId,
        unlinkAppointment: needsUnlink,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo vincular la comida.')),
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
                      '${meal.type} · ${meal.date.day}/${meal.date.month}/${meal.date.year}${meal.placeId == null ? '' : ' · con ubicación'}',
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

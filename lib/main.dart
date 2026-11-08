import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_style.dart';
import 'motion.dart';
import 'meals/meal_repository.dart';
import 'meals/meal_calendar.dart';
import 'meals/meals_screen.dart';
import 'places/places_screen.dart';
import 'calendar/calendar_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode &&
      (const bool.fromEnvironment('LOAD_REVIEW_EXAMPLES') ||
          const bool.fromEnvironment('LOAD_LOCATION_EXAMPLES') ||
          const bool.fromEnvironment('LOAD_SALAMANCA_EXAMPLES'))) {
    final repository = await SqliteMealRepository.open();
    await repository.database.close();
  }
  runApp(CoupleApp());
}

class CoupleApp extends StatefulWidget {
  const CoupleApp({super.key});

  @override
  State<CoupleApp> createState() => _CoupleAppState();
}

class _CoupleAppState extends State<CoupleApp> {
  ThemeMode mode = ThemeMode.system;
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(
        'theme_mode',
      );
      if (mounted && saved != null) {
        setState(
          () => mode = ThemeMode.values.firstWhere(
            (m) => m.name == saved,
            orElse: () => ThemeMode.system,
          ),
        );
      }
    } catch (_) {
      /* Fall back to system when settings are unavailable. */
    }
  }

  Future<void> _setTheme(ThemeMode value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('theme_mode', value.name)) {
        throw StateError('No se pudo guardar el tema');
      }
      if (mounted) setState(() => mode = value);
    } catch (_) {
      if (mounted) {
        messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('No se pudo guardar el tema.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nuestro espacio',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      locale: Locale('es'),
      supportedLocales: [Locale('es')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppStyle.theme.copyWith(pageTransitionsTheme: softPageTransitions),
      darkTheme: AppStyle.darkTheme.copyWith(
        pageTransitionsTheme: softPageTransitions,
      ),
      themeMode: mode,
      home: HomeScreen(themeMode: mode, onThemeChanged: _setTheme),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    this.repository,
  });
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final SqliteMealRepository? repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Future<SqliteMealRepository>? _repository;
  List<CalendarEntry> _upcoming = [];
  bool _loading = true;
  bool _error = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUpcoming();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadUpcoming();
  }

  Future<void> _loadUpcoming() async {
    final generation = ++_generation;
    try {
      final repository = await (_repository ??= widget.repository != null
          ? Future.value(widget.repository!)
          : SqliteMealRepository.open());
      final upcoming = await repository.getUpcomingEntries();
      if (!mounted || generation != _generation) return;
      setState(() {
        _upcoming = upcoming;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      _repository = null;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _loadUpcoming();
  }

  Future<void> _openEntry(CalendarEntry entry) async {
    try {
      final repository = await _repository!;
      if (!mounted) return;
      await _open(
        entry.kind == 'appointment'
            ? AppointmentDetailScreen(
                repository: repository,
                appointmentId: entry.id,
              )
            : CalendarEntryForm(
                repository: repository,
                kind: 'reminder',
                initialDate: entry.date,
                entry: entry,
              ),
      );
    } catch (_) {
      if (mounted) await _loadUpcoming();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppStyle.resolve(context, AppStyle.roseSoft),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppStyle.resolve(context, AppStyle.rose),
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Nuestro espacio',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuButton<ThemeMode>(
                  tooltip: 'Tema de la aplicación',
                  initialValue: widget.themeMode,
                  onSelected: widget.onThemeChanged,
                  icon: Icon(
                    Icons.brightness_6_outlined,
                    color: AppStyle.resolve(context, AppStyle.rose),
                  ),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: ThemeMode.system,
                      child: Text('Seguir sistema'),
                    ),
                    PopupMenuItem(value: ThemeMode.light, child: Text('Claro')),
                    PopupMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
                  ],
                ),
              ],
            ),
            SizedBox(height: 32),
            Text(
              'LOS PEQUEÑOS MOMENTOS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppStyle.resolve(context, AppStyle.rose),
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Todo lo nuestro,\nen un lugar.',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Próximos momentos',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Text('Cargando próximos momentos…')
            else if (_error)
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No se pudieron cargar los próximos momentos.'),
                    TextButton(
                      onPressed: _loadUpcoming,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (_upcoming.isEmpty)
              SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aún no hay momentos próximos. Agreguen una cita o una fecha importante.',
                    ),
                    TextButton.icon(
                      onPressed: () => _open(const CalendarLoader()),
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Ir al calendario'),
                    ),
                  ],
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      _upcoming.length > 1 &&
                      constraints.maxWidth >= 300 &&
                      MediaQuery.textScalerOf(context).scale(1) <= 1.4;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final entry in _upcoming)
                        SizedBox(
                          width: columns
                              ? (constraints.maxWidth - 12) / 2
                              : constraints.maxWidth,
                          child: _UpcomingCard(
                            entry: entry,
                            onTap: () => _openEntry(entry),
                          ),
                        ),
                    ],
                  );
                },
              ),
            SizedBox(height: 28),
            const RainbowMomentCard(),
            SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Explorar',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    'HECHO PARA DOS',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppStyle.resolve(context, AppStyle.muted),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            _ModuleCard(
              icon: Icons.restaurant_rounded,
              title: 'Comidas',
              description: 'Sus platillos, historias y antojos.',
              color: AppStyle.resolve(context, AppStyle.peach),
              onTap: () => _open(const _MealsLoader()),
            ),
            SizedBox(height: 14),
            _ModuleCard(
              icon: Icons.map_rounded,
              title: 'Lugares',
              description: 'Sus lugares y comidas compartidas.',
              color: AppStyle.resolve(context, AppStyle.greenSoft),
              onTap: () => _open(const PlacesLoader()),
            ),
            SizedBox(height: 14),
            _ModuleCard(
              icon: Icons.calendar_month_rounded,
              title: 'Calendario',
              description: 'Fechas y momentos importantes.',
              color: AppStyle.resolve(context, AppStyle.greenSoft),
              onTap: () => _open(const CalendarLoader()),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.entry, required this.onTap});
  final CalendarEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appointment = entry.kind == 'appointment';
    final accent = AppStyle.resolve(
      context,
      appointment ? AppStyle.rose : AppStyle.green,
    );
    return Material(
      color: AppStyle.resolve(
        context,
        appointment ? AppStyle.roseSoft : AppStyle.greenSoft,
      ),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    appointment ? Icons.favorite_rounded : Icons.circle,
                    color: accent,
                    size: appointment ? 18 : 12,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      appointment ? 'Cita' : 'Recordatorio',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${dayLabel(entry.date)} de ${entry.date.year}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (entry.isExample)
                const Text('Ejemplo', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppStyle.resolve(context, Colors.white),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  icon,
                  color: onTap == null
                      ? AppStyle.resolve(context, AppStyle.green)
                      : AppStyle.resolve(context, AppStyle.rose),
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppStyle.resolve(context, AppStyle.muted),
                      ),
                    ),
                    if (onTap == null)
                      Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Próximamente',
                          style: TextStyle(
                            color: AppStyle.resolve(context, AppStyle.green),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppStyle.resolve(context, AppStyle.rose),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MealsLoader extends StatefulWidget {
  const _MealsLoader();
  @override
  State<_MealsLoader> createState() => _MealsLoaderState();
}

class _MealsLoaderState extends State<_MealsLoader> {
  late Future<SqliteMealRepository> repository;
  @override
  void initState() {
    super.initState();
    repository = SqliteMealRepository.open();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SqliteMealRepository>(
    future: repository,
    builder: (context, snapshot) {
      if (snapshot.hasData) return MealsScreen(repository: snapshot.data!);
      return Scaffold(
        appBar: AppBar(title: Text('Comidas')),
        body: Center(
          child: snapshot.hasError
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('No se pudo abrir el almacenamiento local.'),
                    TextButton(
                      onPressed: () => setState(
                        () => repository = SqliteMealRepository.open(),
                      ),
                      child: Text('Reintentar'),
                    ),
                  ],
                )
              : CircularProgressIndicator(),
        ),
      );
    },
  );
}

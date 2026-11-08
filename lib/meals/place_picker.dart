import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';
import '../app_style.dart';
import 'meal_repository.dart';

abstract class CurrentLocationService {
  Future<LatLng> current();
}

class DeviceLocationService implements CurrentLocationService {
  @override
  Future<LatLng> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Activa la ubicación del dispositivo para continuar.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError(
        'Permiso de ubicación denegado. Puedes elegir un punto en el mapa.',
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }
}

class PlacePicker extends StatefulWidget {
  const PlacePicker({
    super.key,
    required this.places,
    this.initial,
    this.locationService,
    this.showTiles = true,
  });
  final List<MealPlace> places;
  final MealPlace? initial;
  final CurrentLocationService? locationService;
  final bool showTiles;
  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  final controller = MapController();
  final name = TextEditingController();
  late final CurrentLocationService service =
      widget.locationService ?? DeviceLocationService();
  LatLng? point;
  MealPlace? reused;
  bool choosing = false, locating = false, mapError = false;
  String? status;
  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      point = LatLng(initial.latitude, initial.longitude);
      reused = initial;
      name.text = initial.name;
    }
  }

  @override
  void dispose() {
    name.dispose();
    controller.dispose();
    super.dispose();
  }

  void _setPoint(LatLng value) {
    setState(() {
      point = value;
      reused = null;
      name.clear();
      choosing = true;
      status = 'Punto seleccionado. Puedes añadir un nombre.';
    });
    controller.move(value, 16);
  }

  Future<void> _current() async {
    setState(() {
      locating = true;
      status = null;
    });
    try {
      final position = await service.current();
      if (mounted) _setPoint(position);
    } catch (error) {
      if (mounted) {
        setState(
          () => status = error is StateError
              ? error.message
              : 'No se pudo obtener la ubicación. Intenta de nuevo o elige un punto.',
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> _reuse() async {
    final selected = await showModalBottomSheet<MealPlace>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text('Lugares guardados')),
            ...widget.places.map(
              (place) => ListTile(
                leading: Icon(Icons.place_outlined),
                title: Text(
                  place.name.isEmpty ? 'Lugar sin nombre' : place.name,
                ),
                subtitle: Text(
                  '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}',
                ),
                onTap: () => Navigator.pop(context, place),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      reused = selected;
      point = LatLng(selected.latitude, selected.longitude);
      name.text = selected.name;
      choosing = false;
      status = 'Lugar guardado seleccionado.';
    });
    controller.move(point!, 16);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Agregar ubicación')),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                    initialCenter: point ?? LatLng(0, 0),
                    initialZoom: point == null ? 2 : 16,
                    onTap: (_, value) {
                      if (choosing) _setPoint(value);
                    },
                  ),
                  children: [
                    if (widget.showTiles)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app_couple_system',
                        errorTileCallback: (tile, error, stack) {
                          if (mounted && !mapError) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => mapError = true);
                            });
                          }
                        },
                      ),
                    if (point != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point!,
                            width: 48,
                            height: 48,
                            child: Icon(
                              Icons.location_on,
                              color: AppStyle.resolve(context, AppStyle.rose),
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                if (mapError)
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Material(
                      color: AppStyle.resolve(context, AppStyle.cream),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'No se pudo cargar el mapa. Revisa tu conexión; la ubicación actual o un lugar guardado siguen disponibles.',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: locating ? null : _current,
                          icon: Icon(Icons.my_location),
                          label: Text(
                            locating ? 'Buscando...' : 'Ubicación actual',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            choosing = true;
                            status = 'Toca el mapa para elegir un punto.';
                          }),
                          icon: Icon(Icons.add_location_alt_outlined),
                          label: Text('Elegir ubicación'),
                        ),
                        if (widget.places.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: _reuse,
                            icon: Icon(Icons.bookmark_outline),
                            label: Text('Lugares guardados'),
                          ),
                      ],
                    ),
                    if (status != null)
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          status!,
                          style: TextStyle(
                            color: AppStyle.resolve(context, AppStyle.muted),
                          ),
                        ),
                      ),
                    if (point != null) ...[
                      SizedBox(height: 10),
                      Text(
                        '${point!.latitude.toStringAsFixed(5)}, ${point!.longitude.toStringAsFixed(5)}',
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: name,
                        readOnly: reused != null,
                        decoration: InputDecoration(
                          labelText: 'Nombre del lugar (opcional)',
                          helperText: reused != null ? 'Lugar guardado' : null,
                        ),
                      ),
                    ],
                    SizedBox(height: 10),
                    FilledButton(
                      onPressed: point == null
                          ? null
                          : () => Navigator.pop(
                              context,
                              reused ??
                                  MealPlace(
                                    id: Uuid().v4(),
                                    name: name.text.trim(),
                                    latitude: point!.latitude,
                                    longitude: point!.longitude,
                                  ),
                            ),
                      child: Text('Confirmar ubicación'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

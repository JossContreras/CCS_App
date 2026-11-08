import 'package:app_couple_system/meals/meal_repository.dart';
import 'package:app_couple_system/meals/place_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

class FakeLocation implements CurrentLocationService {
  FakeLocation({this.denied = false});
  final bool denied;
  @override
  Future<LatLng> current() async {
    if (denied) throw StateError('Permiso denegado');
    return const LatLng(19.42, -99.18);
  }
}

void main() {
  testWidgets('Permiso denegado permite elegir en el mapa y cancelar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: PlacePicker(
          places: const [],
          locationService: FakeLocation(denied: true),
          showTiles: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubicación actual'));
    await tester.pumpAndSettle();
    expect(find.text('Permiso denegado'), findsOneWidget);
    await tester.tap(find.text('Elegir ubicación'));
    await tester.tap(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    expect(find.textContaining('Punto seleccionado'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirmar ubicación'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Obtiene ubicación y permite reutilizar un lugar existente', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const existing = MealPlace(
      id: 'saved',
      name: 'Parque',
      latitude: 19.4,
      longitude: -99.1,
    );
    MealPlace? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.push<MealPlace>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlacePicker(
                      places: const [existing],
                      locationService: FakeLocation(),
                      showTiles: false,
                    ),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubicación actual'));
    await tester.pumpAndSettle();
    expect(find.textContaining('19.42000'), findsOneWidget);
    await tester.tap(find.text('Lugares guardados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parque').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Confirmar ubicación'));
    await tester.tap(find.text('Confirmar ubicación'));
    await tester.pumpAndSettle();
    expect(result?.id, 'saved');
  });
}

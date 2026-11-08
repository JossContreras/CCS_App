import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

const exampleMealIdPrefix = 'demo-meal-v1-';
const reviewExamplePrefix = 'review-example-2026-';
const locationExamplePrefix = 'location-review-v1-';
const salamancaExamplePrefix = 'salamanca-demo-v1-';
String normalizeMealName(String name) =>
    name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class Meal {
  const Meal({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    required this.ingredients,
    required this.categories,
    required this.people,
    this.placeId,
    this.appointmentId,
  });
  final String id, name, type, ingredients;
  final DateTime date;
  final List<String> categories, people;
  final String? placeId;
  final String? appointmentId;
  bool get isExample =>
      id.startsWith(reviewExamplePrefix) ||
      id.startsWith(locationExamplePrefix) ||
      id.startsWith(salamancaExamplePrefix);
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'name_key': normalizeMealName(name),
    'date': date.toIso8601String(),
    'type': type,
    'ingredients': ingredients,
    'categories': jsonEncode(categories),
    'people': jsonEncode(people),
    'place_id': placeId,
    'appointment_id': appointmentId,
  };
  factory Meal.fromMap(Map<String, Object?> map) => Meal(
    id: map['id'] as String,
    name: map['name'] as String,
    date: DateTime.parse(map['date'] as String),
    type: map['type'] as String,
    ingredients: map['ingredients'] as String,
    categories: List<String>.from(
      jsonDecode(map['categories'] as String) as List,
    ),
    people: List<String>.from(jsonDecode(map['people'] as String) as List),
    placeId: map['place_id'] as String?,
    appointmentId: map['appointment_id'] as String?,
  );
}

class CalendarEntry {
  const CalendarEntry({
    required this.id,
    required this.kind,
    required this.title,
    required this.date,
    required this.description,
    this.placeId,
  });
  final String id, kind, title, description;
  final DateTime date;
  final String? placeId;
  bool get isExample => id.startsWith(salamancaExamplePrefix);
  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind,
    'title': title,
    'date': dateKey(date),
    'description': description,
    'place_id': placeId,
  };
  factory CalendarEntry.fromMap(Map<String, Object?> row) => CalendarEntry(
    id: row['id'] as String,
    kind: row['kind'] as String,
    title: row['title'] as String,
    date: DateTime.parse(row['date'] as String),
    description: row['description'] as String,
    placeId: row['place_id'] as String?,
  );
}

class MealPlace {
  const MealPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.notes = '',
  });
  final String id, name;
  final double latitude, longitude;
  final String address, notes;
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'notes': notes,
  };
  factory MealPlace.fromMap(Map<String, Object?> row) => MealPlace(
    id: row['id'] as String,
    name: row['name'] as String,
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    address: row['address'] as String? ?? '',
    notes: row['notes'] as String? ?? '',
  );
}

class MealHistoryFilter {
  const MealHistoryFilter({
    this.type,
    this.category,
    this.start,
    this.end,
    this.placeId,
  });
  final String? type, category;
  final DateTime? start, end;
  final String? placeId;
  bool get isActive =>
      type != null ||
      category != null ||
      start != null ||
      end != null ||
      placeId != null;
}

class MealPage {
  const MealPage(this.items, this.hasMore);
  final List<Meal> items;
  final bool hasMore;
}

class MealFavorite {
  const MealFavorite(this.name, this.count, {this.hasExamples = false});
  final String name;
  final int count;
  final bool hasExamples;
}

abstract class MealRepository {
  Future<MealPage> getMealPage({
    Meal? after,
    String? person,
    MealHistoryFilter? filter,
  });
  Future<int> getMealCount({String? person});
  Future<int> getExampleCount({String? person});
  Future<Set<String>> getMealDays(DateTime month, {String? person});
  Future<List<Meal>> getMealsForDay(DateTime day, {String? person});
  Future<List<MealFavorite>> getFavorites({String? person});
  Future<List<String>> suggestMealNames(String query);
  Future<void> saveMeal(Meal meal, {MealPlace? place});
  Future<List<MealPlace>> getPlaces();
  Future<CalendarEntry?> getAppointment(String id);
  Future<void> deleteMeal(String id);
  Future<List<String>> getNames();
  Future<void> saveNames(List<String> names);
  Future<List<String>> getCategories();
  Future<void> addCategory(String name);
}

class SqliteMealRepository implements MealRepository {
  SqliteMealRepository(this.database);
  final Database database;
  Future<void> seedSalamancaExamples({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final places = [
      const MealPlace(
        id: '${salamancaExamplePrefix}place-1',
        name: 'Parroquia Antigua · Ejemplo',
        latitude: 20.570141,
        longitude: -101.201016,
        address: 'Salamanca, Guanajuato',
        notes: 'Visita cultural ficticia',
      ),
      const MealPlace(
        id: '${salamancaExamplePrefix}place-2',
        name: 'Templo de San Agustín · Ejemplo',
        latitude: 20.56744,
        longitude: -101.19828,
        address: 'Salamanca, Guanajuato',
        notes: 'Punto de demostración',
      ),
      const MealPlace(
        id: '${salamancaExamplePrefix}place-3',
        name: 'Señor del Hospital · Ejemplo',
        latitude: 20.5684293,
        longitude: -101.2003442,
        address: 'Salamanca, Guanajuato',
      ),
      const MealPlace(
        id: '${salamancaExamplePrefix}place-4',
        name: 'Cafetería ficticia · Ejemplo',
        latitude: 20.5691,
        longitude: -101.1996,
        address: 'Centro de Salamanca · punto ficticio',
      ),
    ];
    await database.transaction((txn) async {
      if ((await txn.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['salamanca_examples_v1'],
      )).isNotEmpty) {
        return;
      }
      for (final place in places) {
        await txn.insert('places', place.toMap());
      }
      for (var i = 0; i < 8; i++) {
        final entry = CalendarEntry(
          id: '${salamancaExamplePrefix}event-$i',
          kind: i < 5 ? 'appointment' : 'reminder',
          title: [
            'Paseo cultural',
            'Visita al templo',
            'Café juntos',
            'Tarde de parque',
            'Plan en casa',
            'Recordar aniversario',
            'Anotar una idea',
            'Fecha especial',
          ][i],
          date: DateTime(today.year, today.month, today.day + (i - 3) * 2),
          description: 'Actividad ficticia para explorar la aplicación.',
          placeId: i == 4 || i == 6 ? null : places[i % places.length].id,
        );
        await txn.insert('calendar_entries', entry.toMap());
        if (i < 4) {
          for (var j = 0; j < (i == 0 ? 2 : 1); j++) {
            final meal = Meal(
              id: '${salamancaExamplePrefix}meal-$i-$j',
              name: ['Tacos', 'Enchiladas', 'Café y pan', 'Ensalada'][i],
              date: entry.date,
              type: j == 0 ? 'Comida' : 'Aperitivo',
              ingredients: 'Ingredientes de ejemplo',
              categories: const ['Casera'],
              people: j == 0 ? const ['1', '2'] : const ['1'],
              placeId: entry.placeId,
              appointmentId: entry.id,
            );
            await txn.insert('meals', meal.toMap());
          }
        }
      }
      for (var i = 0; i < 6; i++) {
        final meal = Meal(
          id: '${salamancaExamplePrefix}individual-$i',
          name: ['Gorditas', 'Té', 'Pizza', 'Fruta', 'Sopa', 'Pan dulce'][i],
          date: DateTime(today.year, today.month, today.day - i),
          type: i.isEven ? 'Comida' : 'Aperitivo',
          ingredients: '',
          categories: const [],
          people: i.isEven ? const ['1'] : const ['2'],
          placeId: i == 5 ? null : places[i % places.length].id,
        );
        await txn.insert('meals', meal.toMap());
      }
      await txn.insert('settings', {
        'key': 'salamanca_examples_v1',
        'value': 'true',
      });
    });
  }

  Future<void> seedLocationExamples({DateTime? now}) async {
    final date = now ?? DateTime.now();
    final places = [
      const MealPlace(
        id: 'location-review-place-1',
        name: 'Cafetería de ejemplo',
        latitude: 19.4326,
        longitude: -99.1332,
      ),
      const MealPlace(
        id: 'location-review-place-2',
        name: 'Parque de ejemplo',
        latitude: 19.4204,
        longitude: -99.1818,
      ),
    ];
    final dishes = [
      'Tostadas',
      'Café y pan',
      'Ensalada',
      'Tacos',
      'Pizza',
      'Fruta',
      'Sopa',
      'Galletas',
      'Quesadillas',
      'Hot cakes',
      'Hamburguesa',
      'Arroz',
      'Yogur',
      'Pasta',
      'Helado',
    ];
    final types = ['Desayuno', 'Aperitivo', 'Comida', 'Cena', 'Otro'];
    await database.transaction((txn) async {
      if ((await txn.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['location_examples_seeded_v1'],
      )).isNotEmpty) {
        return;
      }
      for (final place in places) {
        await txn.insert('places', place.toMap());
      }
      for (var i = 0; i < dishes.length; i++) {
        final meal = Meal(
          id: '$locationExamplePrefix${i + 1}',
          name: dishes[i],
          date: DateTime(date.year, date.month, date.day - i),
          type: types[i % types.length],
          ingredients: i.isEven ? 'Ingredientes de ejemplo' : '',
          categories: i == 10
              ? ['Comida chatarra']
              : i.isEven
              ? ['Casera']
              : [],
          people: i % 3 == 0 ? ['1', '2'] : [i.isEven ? '1' : '2'],
          placeId: i < 8 ? places[i % 2].id : null,
        );
        await txn.insert('meals', meal.toMap());
      }
      await txn.insert('settings', {
        'key': 'location_examples_seeded_v1',
        'value': 'true',
      });
    });
  }

  Future<void> seedReviewExamples({DateTime? now}) async {
    final date = now ?? DateTime.now();
    final dishes = <(String, String, List<String>, List<String>, String)>[
      ('Tacos de pollo', 'Comida', ['1', '2'], ['Casera'], 'Pollo, tortilla'),
      ('Pasta al pesto', 'Cena', ['1'], ['Casera'], 'Pasta, albahaca'),
      (
        'Ensalada de frutas',
        'Desayuno',
        ['2'],
        ['Saludable'],
        'Manzana, fresas',
      ),
      ('tacos de pollo', 'Cena', ['1'], ['Casera'], 'Pollo, aguacate'),
      ('Pizza casera', 'Cena', ['1', '2'], ['Casera'], 'Queso, jitomate'),
      ('Avena con manzana', 'Desayuno', ['2'], ['Saludable'], 'Avena, manzana'),
      ('Helado', 'Otro', ['1', '2'], ['Postre'], ''),
      ('Quesadillas', 'Comida', ['2'], ['Casera'], 'Queso, tortilla'),
      ('Pasta al pesto', 'Comida', ['1', '2'], ['Casera'], 'Pasta, albahaca'),
      ('Galletas', 'Aperitivo', ['1'], ['Postre'], ''),
      ('Sopa de verduras', 'Cena', ['2'], ['Saludable'], 'Zanahoria, calabaza'),
      ('Hamburguesa', 'Comida', ['1', '2'], ['Comida chatarra'], ''),
      ('TACOS DE POLLO', 'Cena', ['2'], ['Casera'], 'Pollo, tortilla'),
      ('Arroz con pollo', 'Comida', ['1'], ['Casera'], 'Arroz, pollo'),
      (
        'Yogur con fruta',
        'Desayuno',
        ['1', '2'],
        ['Saludable'],
        'Yogur, fruta',
      ),
      ('Palomitas', 'Aperitivo', ['2'], [], ''),
      ('Enchiladas', 'Comida', ['1', '2'], ['Casera'], 'Pollo, salsa verde'),
      ('Sándwich', 'Desayuno', ['1'], [], 'Pan, queso'),
      ('Pastel', 'Otro', ['2'], ['Postre'], ''),
      ('Pizza casera', 'Cena', ['1', '2'], ['Casera'], ''),
      ('Fruta picada', 'Aperitivo', ['1'], ['Saludable'], 'Mango, sandía'),
      ('Hot cakes', 'Desayuno', ['1', '2'], ['Casera', 'Postre'], ''),
    ];
    await database.transaction((txn) async {
      if ((await txn.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['review_examples_seeded_2026'],
      )).isNotEmpty) {
        return;
      }
      for (var i = 0; i < dishes.length; i++) {
        final row = dishes[i];
        final meal = Meal(
          id: '$reviewExamplePrefix${i + 1}',
          name: row.$1,
          date: DateTime(date.year, date.month, date.day - (i ~/ 2)),
          type: row.$2,
          ingredients: row.$5,
          categories: row.$4,
          people: row.$3,
        );
        await txn.insert('meals', meal.toMap());
      }
      await txn.insert('settings', {
        'key': 'review_examples_seeded_2026',
        'value': 'true',
      });
    });
  }

  static Future<SqliteMealRepository> open() async {
    final repo = await openAt(path.join(await getDatabasesPath(), 'couple.db'));
    if (kDebugMode && const bool.fromEnvironment('LOAD_REVIEW_EXAMPLES')) {
      await repo.seedReviewExamples();
    }
    if (kDebugMode && const bool.fromEnvironment('LOAD_LOCATION_EXAMPLES')) {
      await repo.seedLocationExamples();
    }
    if (kDebugMode && const bool.fromEnvironment('LOAD_SALAMANCA_EXAMPLES')) {
      await repo.seedSalamancaExamples();
    }
    return repo;
  }

  static Future<SqliteMealRepository> openAt(String databasePath) async {
    final db = await openDatabase(
      databasePath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE meals (id TEXT PRIMARY KEY, name TEXT NOT NULL, name_key TEXT NOT NULL, date TEXT NOT NULL, type TEXT NOT NULL, ingredients TEXT NOT NULL, categories TEXT NOT NULL, people TEXT NOT NULL, place_id TEXT, appointment_id TEXT)',
        );
        await _createCalendar(db);
        await db.execute(
          "CREATE TABLE places (id TEXT PRIMARY KEY, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL, address TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '')",
        );
        await db.execute(
          'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE categories (id TEXT PRIMARY KEY, name TEXT NOT NULL COLLATE NOCASE UNIQUE)',
        );
        for (final name in [
          'Postre',
          'Comida chatarra',
          'Casera',
          'Saludable',
        ]) {
          await db.insert('categories', {
            'id': const Uuid().v4(),
            'name': name,
          });
        }
        await _createIndexes(db);
        await db.execute(
          'CREATE INDEX idx_meals_place_date ON meals(place_id, date DESC, id DESC)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Only the exact 25 IDs generated by version 1 are temporary examples.
          final exampleIds = List.generate(
            25,
            (i) => '$exampleMealIdPrefix${i + 1}',
          );
          await db.delete(
            'meals',
            where: 'id IN (${List.filled(exampleIds.length, '?').join(',')})',
            whereArgs: exampleIds,
          );
          await db.execute(
            "ALTER TABLE meals ADD COLUMN name_key TEXT NOT NULL DEFAULT ''",
          );
          final rows = await db.query('meals', columns: ['id', 'name']);
          final batch = db.batch();
          for (final row in rows) {
            batch.update(
              'meals',
              {'name_key': normalizeMealName(row['name'] as String)},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
          await batch.commit(noResult: true);
          await _createIndexes(db);
        }
        if (oldVersion < 3) {
          await db.execute(
            'CREATE TABLE places (id TEXT PRIMARY KEY, name TEXT NOT NULL, latitude REAL NOT NULL, longitude REAL NOT NULL)',
          );
          await db.execute('ALTER TABLE meals ADD COLUMN place_id TEXT');
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE places ADD COLUMN address TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE places ADD COLUMN notes TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_meals_place_date ON meals(place_id, date DESC, id DESC)',
          );
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE meals ADD COLUMN appointment_id TEXT');
          await _createCalendar(db);
        }
      },
    );
    return SqliteMealRepository(db);
  }

  static Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute(
      'CREATE INDEX idx_meals_date_id ON meals(date DESC, id DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_meals_name_key_date ON meals(name_key, date DESC, id DESC)',
    );
  }

  static Future<void> _createCalendar(DatabaseExecutor db) async {
    await db.execute(
      "CREATE TABLE calendar_entries (id TEXT PRIMARY KEY, kind TEXT NOT NULL CHECK(kind IN ('appointment', 'reminder')), title TEXT NOT NULL, date TEXT NOT NULL, description TEXT NOT NULL, place_id TEXT)",
    );
    await db.execute(
      'CREATE INDEX idx_calendar_date ON calendar_entries(date, kind)',
    );
    await db.execute(
      'CREATE INDEX idx_calendar_place ON calendar_entries(place_id, date)',
    );
    await db.execute(
      'CREATE INDEX idx_meals_appointment ON meals(appointment_id, date DESC, id DESC)',
    );
  }

  @override
  Future<MealPage> getMealPage({
    Meal? after,
    String? person,
    MealHistoryFilter? filter,
  }) async {
    final conditions = <String>[];
    final args = <Object>[];
    if (after != null) {
      conditions.add('(date < ? OR (date = ? AND id < ?))');
      args.addAll([
        after.date.toIso8601String(),
        after.date.toIso8601String(),
        after.id,
      ]);
    }
    if (person != null) {
      conditions.add('instr(people, ?) > 0');
      args.add('"$person"');
    }
    if (filter?.type != null) {
      conditions.add('type = ?');
      args.add(filter!.type!);
    }
    if (filter?.category != null) {
      conditions.add('instr(categories, ?) > 0');
      args.add(jsonEncode(filter!.category));
    }
    if (filter?.placeId == '__none__') {
      conditions.add('place_id IS NULL');
    } else if (filter?.placeId != null) {
      conditions.add('place_id = ?');
      args.add(filter!.placeId!);
    }
    if (filter?.start != null) {
      conditions.add('date >= ?');
      args.add(dateKey(filter!.start!));
    }
    if (filter?.end != null) {
      conditions.add('date < ?');
      final end = filter!.end!;
      args.add(dateKey(DateTime(end.year, end.month, end.day + 1)));
    }
    final rows = await database.query(
      'meals',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
      limit: 11,
    );
    return MealPage(rows.take(10).map(Meal.fromMap).toList(), rows.length > 10);
  }

  @override
  Future<int> getMealCount({String? person}) async =>
      Sqflite.firstIntValue(
        await database.rawQuery(
          'SELECT COUNT(*) FROM meals${person == null ? '' : ' WHERE instr(people, ?) > 0'}',
          person == null ? [] : ['"$person"'],
        ),
      ) ??
      0;
  @override
  Future<int> getExampleCount({String? person}) async =>
      Sqflite.firstIntValue(
        await database.rawQuery(
          'SELECT COUNT(*) FROM meals WHERE (instr(id, ?) = 1 OR instr(id, ?) = 1 OR instr(id, ?) = 1)${person == null ? '' : ' AND instr(people, ?) > 0'}',
          [
            reviewExamplePrefix,
            locationExamplePrefix,
            salamancaExamplePrefix,
            if (person != null) '"$person"',
          ],
        ),
      ) ??
      0;
  @override
  Future<Set<String>> getMealDays(DateTime month, {String? person}) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await database.rawQuery(
      'SELECT DISTINCT substr(date, 1, 10) AS day FROM meals WHERE date >= ? AND date < ?${person == null ? '' : ' AND instr(people, ?) > 0'}',
      [dateKey(start), dateKey(end), if (person != null) '"$person"'],
    );
    return rows.map((row) => row['day'] as String).toSet();
  }

  @override
  Future<List<Meal>> getMealsForDay(DateTime day, {String? person}) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return (await database.query(
      'meals',
      where:
          'date >= ? AND date < ?${person == null ? '' : ' AND instr(people, ?) > 0'}',
      whereArgs: [
        dateKey(start),
        dateKey(end),
        if (person != null) '"$person"',
      ],
      orderBy: 'date DESC, id DESC',
    )).map(Meal.fromMap).toList();
  }

  @override
  Future<List<MealFavorite>> getFavorites({String? person}) async {
    final rows = await database.rawQuery(
      '''
      WITH filtered AS (SELECT * FROM meals ${person == null ? '' : 'WHERE instr(people, ?) > 0'})
      SELECT grouped.name_key, grouped.total, grouped.examples,
        (SELECT name FROM filtered AS recent WHERE recent.name_key = grouped.name_key ORDER BY date DESC, id DESC LIMIT 1) AS display_name
      FROM (SELECT name_key, COUNT(*) AS total, MAX(CASE WHEN instr(id, ?) = 1 OR instr(id, ?) = 1 OR instr(id, ?) = 1 THEN 1 ELSE 0 END) AS examples FROM filtered GROUP BY name_key) AS grouped
      ORDER BY grouped.total DESC, grouped.name_key ASC
    ''',
      [
        if (person != null) '"$person"',
        reviewExamplePrefix,
        locationExamplePrefix,
        salamancaExamplePrefix,
      ],
    );
    return rows
        .map(
          (r) => MealFavorite(
            r['display_name'] as String,
            r['total'] as int,
            hasExamples: r['examples'] == 1,
          ),
        )
        .toList();
  }

  @override
  Future<List<String>> suggestMealNames(String query) async {
    final key = normalizeMealName(query);
    if (key.isEmpty) return [];
    final rows = await database.rawQuery(
      '''
      SELECT (SELECT name FROM meals recent WHERE recent.name_key = grouped.name_key ORDER BY date DESC, id DESC LIMIT 1) AS display_name
      FROM (SELECT name_key, MAX(date) AS latest FROM meals WHERE instr(name_key, ?) > 0 GROUP BY name_key) grouped
      ORDER BY grouped.latest DESC, grouped.name_key ASC LIMIT 8
    ''',
      [key],
    );
    return rows.map((row) => row['display_name'] as String).toList();
  }

  @override
  Future<void> saveMeal(Meal meal, {MealPlace? place}) async {
    await database.transaction((txn) async {
      if (place != null) {
        if (meal.placeId != place.id) {
          throw ArgumentError('La ubicación no corresponde a la comida');
        }
        await txn.insert(
          'places',
          place.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      if (meal.appointmentId != null) {
        final records = await txn.query(
          'calendar_entries',
          where: "id = ? AND kind = 'appointment'",
          whereArgs: [meal.appointmentId],
        );
        if (records.isEmpty) throw StateError('La cita ya no existe');
        final appointment = CalendarEntry.fromMap(records.single);
        if (dateKey(meal.date) != dateKey(appointment.date) ||
            (appointment.placeId != null &&
                meal.placeId != appointment.placeId)) {
          throw StateError('La comida no coincide con la cita');
        }
      }
      await txn.insert(
        'meals',
        meal.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<List<MealPlace>> getPlaces() async => (await database.query(
    'places',
    orderBy: 'name COLLATE NOCASE, id',
  )).map(MealPlace.fromMap).toList();

  @override
  Future<CalendarEntry?> getAppointment(String id) async {
    final rows = await database.query(
      'calendar_entries',
      where: "id = ? AND kind = 'appointment'",
      whereArgs: [id],
    );
    return rows.isEmpty ? null : CalendarEntry.fromMap(rows.single);
  }

  Future<List<CalendarEntry>> getCalendarEntries({
    DateTime? month,
    DateTime? day,
    String? placeId,
  }) async {
    final conditions = <String>[];
    final args = <Object>[];
    if (day != null) {
      conditions.add('date = ?');
      args.add(dateKey(day));
    } else if (month != null) {
      conditions.add('date >= ? AND date < ?');
      args.addAll([
        dateKey(DateTime(month.year, month.month)),
        dateKey(DateTime(month.year, month.month + 1)),
      ]);
    }
    if (placeId != null) {
      conditions.add('place_id = ?');
      args.add(placeId);
    }
    return (await database.query(
      'calendar_entries',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'date DESC, id DESC',
    )).map(CalendarEntry.fromMap).toList();
  }

  Future<List<CalendarEntry>> getUpcomingEntries({DateTime? today}) async {
    final rows = await database.query(
      'calendar_entries',
      where: 'date >= ?',
      whereArgs: [dateKey(today ?? DateTime.now())],
      orderBy: 'date ASC, id ASC',
      limit: 2,
    );
    return rows.map(CalendarEntry.fromMap).toList();
  }

  Future<void> saveCalendarEntry(CalendarEntry entry) async {
    if (entry.title.trim().isEmpty ||
        !['appointment', 'reminder'].contains(entry.kind)) {
      throw ArgumentError('Entrada inválida');
    }
    await database.transaction((txn) async {
      if (entry.placeId != null &&
          (await txn.query(
            'places',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [entry.placeId],
          )).isEmpty) {
        throw StateError('El lugar ya no existe');
      }
      final previous = await txn.query(
        'calendar_entries',
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      if (previous.isNotEmpty) {
        final old = CalendarEntry.fromMap(previous.single);
        if (old.kind != entry.kind) {
          throw StateError('No se puede cambiar el tipo de entrada');
        }
        if (entry.kind == 'appointment' &&
            (dateKey(old.date) != dateKey(entry.date) ||
                old.placeId != entry.placeId)) {
          await txn.update(
            'meals',
            {'appointment_id': null},
            where: 'appointment_id = ?',
            whereArgs: [entry.id],
          );
        }
        await txn.update(
          'calendar_entries',
          entry.toMap(),
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      } else {
        await txn.insert('calendar_entries', entry.toMap());
      }
    });
  }

  Future<void> deleteCalendarEntry(String id) async =>
      database.transaction((txn) async {
        await txn.update(
          'meals',
          {'appointment_id': null},
          where: 'appointment_id = ?',
          whereArgs: [id],
        );
        await txn.delete('calendar_entries', where: 'id = ?', whereArgs: [id]);
      });

  Future<MealPage> getAppointmentMeals(
    String appointmentId, {
    Meal? after,
  }) async {
    final rows = await database.query(
      'meals',
      where: after == null
          ? 'appointment_id = ?'
          : 'appointment_id = ? AND (date < ? OR (date = ? AND id < ?))',
      whereArgs: [
        appointmentId,
        if (after != null) ...[
          after.date.toIso8601String(),
          after.date.toIso8601String(),
          after.id,
        ],
      ],
      orderBy: 'date DESC, id DESC',
      limit: 11,
    );
    return MealPage(rows.take(10).map(Meal.fromMap).toList(), rows.length > 10);
  }

  Future<void> linkMealToAppointment(
    String mealId,
    String appointmentId, {
    bool confirmed = false,
  }) async => database.transaction((txn) async {
    final entries = await txn.query(
      'calendar_entries',
      where: "id = ? AND kind = 'appointment'",
      whereArgs: [appointmentId],
    );
    final meals = await txn.query(
      'meals',
      where: 'id = ?',
      whereArgs: [mealId],
    );
    if (entries.isEmpty || meals.isEmpty) {
      throw StateError('La comida o la cita ya no existe');
    }
    final appointment = CalendarEntry.fromMap(entries.single);
    final meal = Meal.fromMap(meals.single);
    final changed =
        (meal.appointmentId != null && meal.appointmentId != appointmentId) ||
        dateKey(meal.date) != dateKey(appointment.date) ||
        (appointment.placeId != null && meal.placeId != appointment.placeId);
    if (changed && !confirmed) {
      throw StateError('La vinculación requiere confirmación');
    }
    await txn.update(
      'meals',
      {
        'appointment_id': appointmentId,
        'date': DateTime(
          appointment.date.year,
          appointment.date.month,
          appointment.date.day,
        ).toIso8601String(),
        if (appointment.placeId != null) 'place_id': appointment.placeId,
      },
      where: 'id = ?',
      whereArgs: [mealId],
    );
  });

  Future<void> unlinkMealFromAppointment(
    String mealId,
    String appointmentId,
  ) async {
    await database.update(
      'meals',
      {'appointment_id': null},
      where: 'id = ? AND appointment_id = ?',
      whereArgs: [mealId, appointmentId],
    );
  }

  Future<void> savePlace(MealPlace place) async {
    if (place.name.trim().isEmpty) {
      throw ArgumentError('El nombre es obligatorio');
    }
    await database.transaction((txn) async {
      final updated = await txn.update(
        'places',
        place.toMap(),
        where: 'id = ?',
        whereArgs: [place.id],
      );
      if (updated == 0) await txn.insert('places', place.toMap());
    });
  }

  Future<Map<String, int>> getPlaceCounts() async {
    final rows = await database.rawQuery(
      'SELECT place_id, COUNT(*) AS total FROM meals WHERE place_id IS NOT NULL GROUP BY place_id',
    );
    return {
      for (final row in rows) row['place_id'] as String: row['total'] as int,
    };
  }

  Future<Map<String, int>> getPlaceTypes(String placeId) async {
    final rows = await database.rawQuery(
      'SELECT type, COUNT(*) AS total FROM meals WHERE place_id = ? GROUP BY type ORDER BY total DESC, type',
      [placeId],
    );
    return {for (final row in rows) row['type'] as String: row['total'] as int};
  }

  Future<MealPage> getPlaceMeals(String placeId, {Meal? after}) async {
    final rows = await database.query(
      'meals',
      where: after == null
          ? 'place_id = ?'
          : 'place_id = ? AND (date < ? OR (date = ? AND id < ?))',
      whereArgs: [
        placeId,
        if (after != null) ...[
          after.date.toIso8601String(),
          after.date.toIso8601String(),
          after.id,
        ],
      ],
      orderBy: 'date DESC, id DESC',
      limit: 11,
    );
    return MealPage(rows.take(10).map(Meal.fromMap).toList(), rows.length > 10);
  }

  Future<void> assignMealToPlace(
    String mealId,
    String? placeId, {
    bool unlinkAppointment = false,
  }) async {
    await database.transaction((txn) async {
      if (placeId != null &&
          (await txn.query(
            'places',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [placeId],
          )).isEmpty) {
        throw StateError('El lugar ya no existe');
      }
      final meals = await txn.query(
        'meals',
        where: 'id = ?',
        whereArgs: [mealId],
      );
      if (meals.isEmpty) throw StateError('La comida ya no existe');
      final appointmentId = meals.single['appointment_id'] as String?;
      if (appointmentId != null && !unlinkAppointment) {
        final records = await txn.query(
          'calendar_entries',
          where: 'id = ?',
          whereArgs: [appointmentId],
        );
        final appointmentPlace = records.isEmpty
            ? null
            : records.single['place_id'] as String?;
        if (appointmentPlace != null && appointmentPlace != placeId) {
          throw StateError('La comida está vinculada a una cita');
        }
      }
      final changed = await txn.update(
        'meals',
        {'place_id': placeId, if (unlinkAppointment) 'appointment_id': null},
        where: 'id = ?',
        whereArgs: [mealId],
      );
      if (changed == 0) throw StateError('La comida ya no existe');
    });
  }

  Future<bool> deleteEmptyPlace(String placeId) =>
      database.transaction((txn) async {
        final count =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM meals WHERE place_id = ?',
                [placeId],
              ),
            ) ??
            0;
        if (count != 0) return false;
        final entries =
            Sqflite.firstIntValue(
              await txn.rawQuery(
                'SELECT COUNT(*) FROM calendar_entries WHERE place_id = ?',
                [placeId],
              ),
            ) ??
            0;
        if (entries != 0) return false;
        await txn.delete('places', where: 'id = ?', whereArgs: [placeId]);
        return true;
      });

  @override
  Future<void> deleteMeal(String id) async {
    await database.delete('meals', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<String>> getNames() async {
    final rows = await database.query(
      'settings',
      where: 'key = ?',
      whereArgs: ['names'],
    );
    return rows.isEmpty
        ? ['Persona 1', 'Persona 2']
        : List<String>.from(jsonDecode(rows.first['value'] as String) as List);
  }

  @override
  Future<void> saveNames(List<String> names) async {
    await database.insert('settings', {
      'key': 'names',
      'value': jsonEncode(names),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<List<String>> getCategories() async => (await database.query(
    'categories',
    orderBy: 'name COLLATE NOCASE',
  )).map((row) => row['name'] as String).toList();
  @override
  Future<void> addCategory(String name) async {
    await database.insert('categories', {
      'id': const Uuid().v4(),
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

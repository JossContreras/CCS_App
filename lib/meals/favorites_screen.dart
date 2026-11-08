import 'package:flutter/material.dart';
import '../app_style.dart';
import 'meal_repository.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({
    super.key,
    required this.repository,
    required this.person,
    required this.filterLabel,
  });
  final MealRepository repository;
  final String? person;
  final String filterLabel;
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<MealFavorite>> favorites;
  @override
  void initState() {
    super.initState();
    favorites = widget.repository.getFavorites(person: widget.person);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Sus favoritos')),
    body: FutureBuilder<List<MealFavorite>>(
      future: favorites,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No se pudieron cargar los favoritos.'),
                TextButton(
                  onPressed: () => setState(
                    () => favorites = widget.repository.getFavorites(
                      person: widget.person,
                    ),
                  ),
                  child: Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Sin favoritos para ${widget.filterLabel}. Agrega comidas para descubrirlos.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 32),
          itemCount: entries.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Text(
                  'Los platillos que más se repiten · ${widget.filterLabel}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppStyle.resolve(context, AppStyle.muted),
                  ),
                ),
              );
            }
            final entry = entries[i - 1];
            return Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SoftCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppStyle.resolve(
                            context,
                            AppStyle.roseSoft,
                          ),
                          foregroundColor: AppStyle.resolve(
                            context,
                            AppStyle.rose,
                          ),
                          child: Text('$i'),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.name,
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              if (entry.hasExamples)
                                Text(
                                  'Incluye ejemplos',
                                  style: TextStyle(
                                    color: AppStyle.resolve(
                                      context,
                                      AppStyle.green,
                                    ),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          '${entry.count} ${entry.count == 1 ? 'vez' : 'veces'}',
                          style: TextStyle(
                            color: AppStyle.resolve(context, AppStyle.muted),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: entry.count / entries.first.count,
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
            );
          },
        );
      },
    ),
  );
}

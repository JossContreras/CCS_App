# App Couple System

Aplicación móvil privada para organizar información compartida de una pareja. La planificación inicial se encuentra en [docs/requisitos-funcionales.md](docs/requisitos-funcionales.md).

## Estado

La aplicación incluye un módulo de comidas con calendario mensual de comidas, historial, registro en dos pasos, edición, eliminación, categorías personalizadas, integrantes configurables y frecuencia de platillos. La información se guarda en SQLite en el dispositivo y funciona sin conexión. No se comparte ni sincroniza con el otro teléfono; desinstalar la aplicación puede eliminar estos datos. El calendario de recordatorios sigue pendiente. «Nuestro espacio» es un nombre provisional.

El historial carga diez registros por página, ordenados por fecha de comida más reciente. La pantalla de favoritos agrupa nombres ignorando mayúsculas y diferencias de espacios, sin modificar el texto original. Al abrir Comidas en la versión actual, una migración retira los 25 registros temporales de ejemplo de la versión anterior, incluso si se editaron; los registros reales se conservan.

El filtro por integrante incluye las comidas compartidas en las que participa esa persona y se aplica al calendario, historial y favoritos. Al escribir un platillo se sugieren nombres del historial sin cambiar los demás campos.

Cada comida puede asociarse opcionalmente a un lugar reutilizable. La ubicación solo se solicita al pulsar «Ubicación actual»; también se puede seleccionar un punto manualmente. El mapa usa OpenStreetMap y requiere conexión para descargar sus imágenes; la información guardada permanece en SQLite. Los filtros de tipo, categoría y periodo se aplican al historial.

La sección Lugares ofrece un mapa con agrupación de marcadores y una lista disponible sin conexión. Permite guardar lugares con dirección y notas, consultar sus comidas, añadir otras nuevas o asociar registros existentes. Un lugar con comidas vinculadas no se puede eliminar. La apariencia puede seguir el sistema o elegirse en claro u oscuro desde el inicio.

Para cargar una sola vez los ejemplos etiquetados de revisión en un emulador de desarrollo, ejecutar `flutter run -d emulator-5554 --dart-define=LOAD_REVIEW_EXAMPLES=true`. La carga no reemplaza datos existentes y no ocurre en compilaciones de producción. Los ejemplos permanecen en el dispositivo hasta que se eliminen.

Para agregar una sola vez los 15 ejemplos de ubicaciones en un emulador de desarrollo, usar `flutter run -d emulator-5554 --dart-define=LOAD_LOCATION_EXAMPLES=true`. Estos ejemplos se suman a los existentes y algunos comparten lugares ficticios.

## Ejecutar

Con Flutter instalado y un dispositivo o emulador disponible:

```sh
flutter pub get
flutter run
```

Para revisar el código y ejecutar la prueba inicial:

```sh
flutter analyze
flutter test
```

Se generaron plataformas Android e iOS. Para compilar y ejecutar iOS se necesita un entorno macOS con Xcode. La base de datos en línea, la migración de datos locales y el mecanismo de acceso compartido siguen pendientes de decisión.

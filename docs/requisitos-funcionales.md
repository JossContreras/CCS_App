# Documento de planificación — Aplicación para pareja

## 1. Propósito del proyecto

Desarrollar una aplicación móvil privada para que una pareja registre, consulte y organice información compartida de su vida cotidiana de una forma más sencilla que una hoja de cálculo. La aplicación será de uso interno, estará disponible desde los dispositivos móviles de ambos integrantes y no se publicará como producto para terceros.

En este documento, «privada» o «de uso interno» describe quiénes utilizarán la aplicación y cómo se distribuirá. La primera versión de comidas funciona sin conexión y guarda información en SQLite en cada dispositivo. Una base de datos en línea compartida se estudiará en una fase posterior.

El sistema busca centralizar información y recuerdos relevantes —como comidas, salidas, eventos, fechas importantes y mensajes generales— para facilitar su consulta posterior. Se desea poder registrar la mayor variedad de información útil posible, incorporándola de manera gradual.

## 2. Usuarios y alcance inicial

| Elemento | Definición |
| --- | --- |
| Usuarios | Dos integrantes de la pareja. |
| Roles | No se contemplan roles complejos. Los permisos concretos de cada usuario están pendientes de definición. |
| Plataforma | Aplicación móvil. |
| Distribución | Privada y de acceso controlado; no se planea publicarla al público general. |
| Responsable del proyecto | El solicitante estará a cargo del proyecto. Las actividades concretas de aprobación y mantenimiento están pendientes de definición. |

## 3. Objetivos

### Objetivo general

Facilitar el registro y acceso a información compartida de la pareja desde el móvil, sin requerir conocimientos de herramientas como Excel.

### Objetivos específicos

- Mantener un historial de comidas individuales y compartidas para analizar lo consumido y apoyar la planificación de próximas comidas.
- Registrar recordatorios, notas y fechas importantes en un calendario.
- Ofrecer una interfaz central, clara y basada en iconos para acceder a cada función.
- Conservar la información disponible para ambos usuarios mediante una base de datos en línea.

## 4. Alcance funcional

### Primera versión (MVP)

#### RF-01. Pantalla principal

El sistema deberá contar con una pantalla de inicio que muestre, mediante iconos o accesos visuales, las funciones disponibles de la aplicación.

#### RF-02. Registro de comidas

El sistema deberá permitir registrar comidas individuales de cualquiera de los dos integrantes y comidas compartidas, identificando a quién corresponde cada registro.

Cada registro contempla nombre del platillo, fecha, tipo de comida, ingredientes, categorías y participantes. Son obligatorios el nombre, la fecha, el tipo y al menos un integrante; ingredientes y categorías son opcionales.

#### RF-03. Historial y consulta de comidas

El sistema deberá permitir consultar el historial de comidas registradas.

#### RF-04. Análisis básico de alimentación

El sistema deberá permitir analizar el historial de comidas, incluyendo la identificación de los platillos consumidos con mayor frecuencia, para ayudar a planificar próximas comidas. Las demás métricas y la forma de presentar los resultados se definirán durante el análisis.

#### RF-05. Calendario de recordatorios

El sistema deberá incluir un calendario en el que sea posible agregar notas, recordatorios y fechas importantes.

#### RF-06. Consulta de recordatorios

El sistema deberá permitir consultar los eventos y notas registrados por fecha.

#### RF-07. Modificación y eliminación de comidas

El sistema deberá permitir editar y eliminar registros de comidas existentes, además de crearlos y consultarlos. Los permisos y la confirmación de eliminación quedan pendientes de definir.

#### RF-08. Categorías de comidas

El sistema permite asignar varias categorías a una comida y añadir categorías personalizadas. El tipo indica el momento o propósito (desayuno, comida, cena, aperitivo u otro); las categorías describen el platillo, por ejemplo, postre o comida chatarra.

### Funciones previstas para fases posteriores

Estas funciones son candidatas para una segunda fase y no forman parte del compromiso inicial:

- Registro de citas, salidas y lugares visitados.
- Obtención o registro de ubicación y visualización de lugares en un mapa.
- Extensión de la clasificación por categorías a los demás tipos de registro; las categorías de comidas forman parte del MVP.
- Álbum diario de fotografías temporales, inspirado en el formato de instantáneas, sin replicar aplicaciones de terceros.
- Notificaciones para recordatorios y fechas relevantes.
- Personalización de avatares.

### Función por priorizar

- Mensajes generales compartidos: el solicitante los mencionó como parte de la idea general, pero aún no se ha definido su alcance ni en qué fase se incorporarán.

## 5. Datos a administrar

El sistema se diseñará para poder crecer y almacenar diferentes tipos de información compartida. Inicialmente se consideran:

| Tipo de información | Uso inicial |
| --- | --- |
| Comidas | Historial y análisis de alimentación. |
| Fechas importantes | Eventos a recordar. |
| Recordatorios y notas | Actividades, pendientes o información contextual por fecha. |
| Mensajes generales | Función y fase de incorporación por concretar. |
| Lugares y citas | Función futura. |
| Fotografías diarias | Función futura. |

Los campos definitivos, periodos de conservación y reglas de edición o eliminación se definirán durante el diseño de cada módulo.

En comidas se guardan nombre del platillo, fecha, tipo, ingredientes, categorías e integrantes. Los nombres de los dos integrantes son configurables y los registros pueden pertenecer a varias categorías.

## 6. Flujo de uso inicial

El flujo detallado se definirá durante el diseño, pero se establece el siguiente recorrido base:

1. La persona abre la aplicación móvil.
2. Accede desde la pantalla principal al módulo de comidas o al calendario.
3. Registra o consulta la información requerida.
4. En la etapa local, la información queda guardada únicamente en el dispositivo utilizado. El acceso desde ambos dispositivos requerirá una futura sincronización.

## 7. Requisitos no funcionales y restricciones

| Área | Decisión inicial |
| --- | --- |
| Tecnologías de aplicación | Flutter para desarrollo y diseño de la aplicación móvil. |
| Base de datos | Pendiente de decisión. Supabase es la propuesta inicial por ofrecer una base de datos en línea y adecuada para un volumen bajo de usuarios. |
| Disponibilidad | Se busca que la base de datos en línea esté disponible en todo momento para ambos usuarios; la disponibilidad efectiva dependerá del servicio elegido y de la conexión. |
| Autenticación | No se requiere inicio de sesión en esta etapa. Esta decisión deberá revisarse antes de habilitar el uso compartido en dispositivos distintos. |
| Seguridad | Se propone usar variables de entorno para la configuración y las credenciales, sin incorporarlas directamente al código fuente ni al repositorio. El manejo seguro se definirá según el servicio elegido. |
| Costo | Se utilizarán herramientas y servicios gratuitos. Cualquier servicio de pago deberá justificarse previamente por necesidad real. |
| Volumen esperado | Bajo: dos usuarios y una cantidad controlada de información. |

## 8. Reglas de negocio

Las reglas de negocio específicas aún están pendientes y se definirán conforme se diseñen los módulos. Como mínimo, se deberán concretar antes de desarrollar cada función:

- Campos obligatorios y validaciones de cada registro.
- Quién puede crear, modificar o eliminar información compartida.
- Forma de identificar los dispositivos o usuarios si no se implementa inicio de sesión.
- Gestión de registros duplicados o editados.
- Política de conservación y eliminación de fotografías, datos y recordatorios.
- Privacidad y permisos de ubicación, cámara y notificaciones cuando se incorporen esas capacidades.

## 9. Seguridad y privacidad

Aunque actualmente no se han identificado datos sensibles, los registros de una pareja pueden contener información privada. Por ello, antes de implementar sincronización en línea se deberá definir un mecanismo de acceso que impida que terceros consulten o modifiquen la información.

Se propone utilizar variables de entorno para la configuración y las credenciales durante el desarrollo y evitar incluir secretos en el repositorio. En una aplicación móvil, las variables incorporadas en la compilación pueden extraerse: por sí solas no protegen secretos. Se deberá distinguir la configuración pública de las claves privilegiadas y definir controles de acceso del lado del servidor antes de conectar la base de datos.

## 10. Referencias funcionales

Se tomarán como referencias para analizar patrones y funciones útiles, sin copiar su diseño ni comportamiento de forma literal, las siguientes aplicaciones:

- Nido / HomeOS
- Splitwise
- Nipto
- Cozi
- Life360

El solicitante indica que anteriormente se realizó un análisis de aplicaciones para parejas. Estas referencias podrán revisarse para identificar formas pertinentes de organizar información compartida, recordatorios, actividades y ubicaciones. Sus hallazgos concretos no están incluidos aún en este documento.

## 11. Criterios de éxito y validación

Los criterios de éxito y aceptación serán definidos por el equipo de pruebas. Se proponen los siguientes puntos como base para su revisión, sujetos a validación:

- Registrar una comida desde la aplicación móvil.
- Consultar el historial de comidas.
- Registrar comidas individuales y compartidas, y editar o eliminar registros de comidas.
- Clasificar comidas por categoría y consultar cuáles son las más frecuentes.
- Agregar una fecha importante, nota o recordatorio en el calendario.
- Consultar los elementos guardados en el calendario.
- Acceder de forma sencilla a los módulos desde la pantalla principal.

## 12. Decisiones pendientes

- Elegir y configurar la base de datos en línea (Supabase u otra alternativa gratuita).
- Definir la futura sincronización y la migración de datos locales a la base compartida.
- Definir si se requerirá autenticación, PIN, código compartido u otro mecanismo de acceso entre ambos dispositivos.
- Revisar la lista inicial de tipos y categorías de comidas conforme se utilice el módulo.
- Definir análisis de comidas adicionales a la frecuencia y cómo se presentarán.
- Diseñar la estructura de pantallas y navegación posterior a la pantalla principal.
- Determinar las reglas de negocio de cada módulo.
- Priorizar las funciones de la segunda fase.
- Definir el alcance y la fase de los mensajes generales compartidos.
- Definir las responsabilidades concretas de aprobación y mantenimiento del proyecto.
- Especificar los casos de prueba y criterios finales de aceptación.

## 13. Etapa local: citas, recordatorios y lugares

- Las comidas, los lugares y las citas son registros independientes. Una comida puede pertenecer a una cita y una cita puede reunir varias comidas. Las citas representan actividades compartidas por ambos integrantes.
- Una cita tiene título, fecha, descripción y lugar opcional. Al vincular una comida con otra fecha o con un lugar distinto al de una cita situada, se solicita confirmación para actualizar la comida. Una cita sin lugar no modifica el lugar de la comida. Trasladar una comida de otra cita también requiere confirmación.
- Al modificar la fecha o el lugar de una cita, o al eliminarla, sus comidas se desvinculan y conservan sus datos. Cambiar una comida vinculada de forma incompatible requiere confirmar su desvinculación.
- El calendario presenta citas y recordatorios, que son notas fechadas con lugar opcional. Los recordatorios no emiten notificaciones automáticas en esta etapa.
- El detalle de un lugar permite consultar citas y comidas, crear ambas y vincular comidas existentes. Un lugar con comidas, citas o recordatorios no puede eliminarse hasta desvincular o reasignar sus registros.
- El historial de comidas admite filtros combinables por integrante, tipo, categoría, periodo y lugar, incluido «Sin ubicación».
- Los datos permanecen en SQLite local. La sincronización, el acceso simultáneo desde dos dispositivos y las notificaciones quedan pendientes.

Para revisión, la compilación de depuración admite `--dart-define=LOAD_SALAMANCA_EXAMPLES=true`. La carga es única, conserva los datos existentes y etiqueta los registros ficticios. Los puntos de referencia se basan en [Parroquia Antigua](https://es.wikipedia.org/wiki/Parroquia_Antigua_%28Salamanca%29), [Templo de San Agustín](https://mapcarta.com/W584802694) y [Señor del Hospital](https://es.wikipedia.org/wiki/Parroquia_del_Se%C3%B1or_del_Hospital_%28Salamanca%29); las actividades, comidas y cafetería son ficticias.


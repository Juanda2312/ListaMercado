# Lista Mercado — Plan de Implementación

> **Para agentes:** SUB-SKILL REQUERIDO: usar superpowers:subagent-driven-development (recomendado) o superpowers:executing-plans para implementar este plan tarea por tarea. Los pasos usan casillas (`- [ ]`) para seguimiento.

**Objetivo:** App Flutter 100% local para Android que gestiona productos, supermercados y una lista de mercado con totales por supermercado, distribuida como APK por sideload.

**Arquitectura:** Tres modelos simples persistidos como JSON en `shared_preferences`; tres `ChangeNotifier` (Provider) que son la única fuente de verdad y se avisan entre sí mediante callbacks para las eliminaciones en cascada; la lógica de agrupación y totales vive en funciones puras testeables, fuera de la UI. Navegación con `NavigationBar` de 3 pestañas.

**Stack:** Flutter estable (Dart con null safety), `provider`, `shared_preferences`. Sin otras dependencias (ni `intl`, ni `uuid`, ni `hive`).

**Spec:** sección "Requisitos" de este mismo archivo.

**Versiones:** 1.0.0 = MVP (Tareas 0–10). 1.0.1 = total general y presupuesto en la barra de la lista (Tarea 11). 1.0.2 = descuento / precio temporal al añadir y editar productos de la lista (Tareas 12–16).

## Restricciones globales

- Solo Android (`--platforms android`). Sin internet, sin API, sin permiso `INTERNET` en el APK release.
- Dependencias de producción permitidas: `provider` y `shared_preferences`. Nada más.
- Todos los textos visibles al usuario en español.
- Identificadores de código (clases, variables, archivos) en inglés.
- Nombre de producto obligatorio; supermercado y precio opcionales.
- Tachar es solo un indicador visual: los productos tachados **siguen sumando** en los totales.
- Todo "tachar" es reversible (tacha y destacha).
- Acciones masivas (tachar todos, tachar los de un supermercado, limpiar lista) piden confirmación.
- Añadir a la lista un producto que **ya está en ella** pide confirmación antes de sumar la cantidad.
- Total por supermercado: los productos sin precio no suman; si hay alguno, el total se muestra como `TOTAL + (?)`.
- Productos sin supermercado van a la columna **Otros**.
- Cada supermercado es una **columna** de la tabla de la lista.
- Dependencia de desarrollo permitida: flutter_launcher_icons (solo para generar el ícono; no entra en el APK).
- El descuento es opcional: sin descuento, todo se comporta exactamente como en 1.0.1. No se añaden dependencias.

## Flujo de ramas (git)

Dos ramas permanentes y una temporal por cada función:

- **`main`**: solo versiones publicadas. Cada commit de `main` es un release y lleva su tag (`v1.0.2`). Nunca se trabaja directamente en ella.
- **`develop`**: rama de integración. Aquí se juntan las funciones terminadas; siempre debe pasar `flutter analyze` y `flutter test`. Nunca se trabaja directamente en ella (salvo la creación inicial).
- **`feature/<nombre>`**: rama temporal que sale de `develop`, lleva un commit por tarea y vuelve a `develop` con merge `--no-ff`; después se borra. Ejemplo: `feature/discount-1.0.2`. Correcciones urgentes sobre una versión ya publicada: `fix/<nombre>` desde `main`, que se fusiona en `main` (con tag) y también en `develop`.

Comandos:

```bash
# Una sola vez: crear develop desde main
git checkout main && git pull
git checkout -b develop
git push -u origin develop

# Empezar una función
git checkout develop && git pull
git checkout -b feature/<nombre>

# Durante la función: un commit por tarea
git add <archivos>
git commit -m "feat: ..."

# Terminar la función (analyze y test en verde antes de fusionar)
git checkout develop && git pull
git merge --no-ff feature/<nombre> -m "merge: feature/<nombre> into develop"
git push origin develop
git branch -d feature/<nombre>
git push origin --delete feature/<nombre>   # solo si la rama se subió

# Publicar una versión (desde develop con todo en verde y la versión subida en pubspec.yaml)
git checkout main && git pull
git merge --no-ff develop -m "release: v<X.Y.Z>"
git tag -a v<X.Y.Z> -m "Versión <X.Y.Z>"
git push origin main --tags
git checkout develop
git merge main          # normalmente es un avance rápido; mantiene develop al día
git push origin develop
```

Reglas: el APK y el release de GitHub se generan siempre desde `main` ya etiquetada; los mensajes de commit van en inglés (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`); no se hace `push --force` sobre `main` ni `develop`.

## Requisitos (resumen)

**P1 – Productos:** pantalla con nombre, supermercado y precio. Añadir, modificar, eliminar, buscar (con filtro por supermercado) y añadir a la lista con cantidad (si el producto ya está en la lista, pide confirmación para sumar).
**P2 – Supermercados:** pantalla con solo el nombre. Añadir, modificar, eliminar.
**P3 – Lista de mercado:** lista (nombre, supermercado, cantidad, precio unitario, total) y tabla por supermercados (columna Otros). Modificar cantidad; tachar/destachar un producto (sincronizado entre lista y tabla); tachar/destachar todos los de un supermercado; tachar/destachar todos; limpiar la lista; quitar un solo producto de la lista (deslizando la fila, con opción de deshacer); botón en cada producto que abre su edición (acceso directo a P1).
**P3 – Barra superior (v1.0.1):** total general de la lista (`TOTAL + (?)` si hay productos sin precio) y presupuesto opcional; restante = presupuesto − total, mostrado como `RESTANTE - (?)` si hay productos sin precio, en verde si ≥ 0 y en rojo si es negativo. El presupuesto se guarda en `ShoppingListProvider` (`budget_v1`) y no se borra al limpiar la lista.
**P1/P3 – Descuento (v1.0.2):** al añadir un producto a la lista, además de la cantidad se puede indicar un descuento opcional como **% de descuento** o como **precio final** (dos campos complementarios: al llenar uno, el otro se calcula y se rellena solo). Se puede añadir, modificar o quitar después desde P3 (vista Lista y vista Por supermercado). Los totales y el presupuesto usan el precio con descuento.

## Decisiones de diseño (cerradas)

- **Un producto aparece una sola vez en la lista.** Añadirlo de nuevo suma la cantidad, **previa confirmación del usuario** (el diálogo muestra la cantidad actual y el total resultante). Por eso `ShoppingItem` se identifica por `productId` (sin id propio).
- **La confirmación vive en la UI, no en el provider.** `ShoppingListProvider.addProduct` siempre suma; es la pantalla de productos la que consulta `quantityOf` y decide si pregunta antes de llamarlo.
- **El precio base vive solo en `Product`; el descuento vive en `ShoppingItem` (v1.0.2).** La lista lee el precio base vigente del producto y no guarda copia de él. `ShoppingItem.tempPrice` (`double?`) es el precio final con descuento de esa entrada; el porcentaje no se guarda, se calcula contra el precio base. Precio efectivo = `tempPrice ?? product.price`.
- **Eliminar un producto** lo quita también de la lista. **Eliminar un supermercado** NO borra productos: pasan a "sin supermercado" (columna Otros).
- **Quitar un producto de la lista** (deslizar la fila) solo lo saca de la lista: el producto sigue existiendo en P1. No pide confirmación previa, pero muestra un `SnackBar` con "Deshacer" que lo restaura con su cantidad y estado de tachado originales.
- **Acciones masivas de tachado alternan:** si todos los del alcance ya están tachados, los destacha; si no, los tacha todos.
- **Nombres de supermercado únicos** (sin distinguir mayúsculas ni tildes). Nombres de producto pueden repetirse (misma "Leche" en dos supermercados).
- **Cantidad mínima 1**, entera. Al estar en 1, el botón "−" no hace nada.
- **Precio:** vacío = sin precio; debe ser > 0. Acepta `,` o `.` como decimal; un punto seguido de exactamente 3 dígitos (`12.500`) se interpreta como separador de miles. Se muestra como `$12.500` (miles con punto, decimales con coma solo si los hay, máximo 2).
- **La tabla de P3** es un conjunto de columnas con scroll horizontal (una por supermercado con productos, `Otros` al final). Lista y tabla son dos pestañas internas de P3 que leen el mismo `ShoppingListProvider`, por eso el tachado y la eliminación se sincronizan solos.
- **IDs:** `DateTime.now().microsecondsSinceEpoch.toString()`.
- **Total general y presupuesto (v1.0.1):** el total general suma todas las filas con precio (las tachadas también cuentan, igual que en los totales por supermercado). El presupuesto vive en `ShoppingListProvider` (no hay provider nuevo, así `AppProviders` y los `MultiProvider` no cambian), se guarda en `shared_preferences` con la clave `budget_v1` (un `double`), es opcional y debe ser > 0 (mismas reglas de parseo que el precio). "Limpiar lista" no lo borra. El restante se muestra solo si hay presupuesto: verde si ≥ 0, rojo si < 0; con productos sin precio lleva el sufijo ` - (?)`.
- **Descuento / precio temporal (v1.0.2):**
  - Dos campos complementarios en un widget reutilizable (`DiscountFields`): al editar el % se calcula el precio final y viceversa; si el campo editado queda vacío o inválido, el otro se vacía. Ambos son opcionales.
  - Validación: % en (0, 100); precio final > 0 y **menor** que el precio base. Mensaje de error: `Descuento inválido` (el precio final reutiliza `Precio inválido` si no se puede parsear). Se parsean con las reglas de `parsePrice`. Resultados redondeados a 2 decimales; el % se muestra con máximo 2 decimales (`15%`, `12,5%`).
  - Producto sin precio base: el campo % se deshabilita y solo se puede indicar el precio final; ese precio cuenta como precio (la fila ya no suma `(?)`).
  - Al añadir un producto que ya está en la lista: si el diálogo trae descuento, reemplaza el `tempPrice` actual (el mensaje de confirmación lo menciona); si no trae, se conserva el existente.
  - Si el precio base del producto se edita después y el `tempPrice` deja de ser menor que él, el `tempPrice` se conserva tal cual y simplemente no se muestra porcentaje.
  - `restoreItem` ("Deshacer") conserva el `tempPrice`. "Limpiar lista" lo borra junto con los ítems.
  - Persistencia: `tempPrice` es opcional en el JSON de `shopping_items_v1`; si falta o es inválido se lee como `null` sin descartar el ítem.

## Arquitectura

```
UI (screens/, widgets/)            context.watch / context.read
        │
Providers (providers/)             ChangeNotifier, única fuente de verdad en memoria
        │           ▲
        │           └── callbacks onRemoved (cascadas) cableados en AppProviders.create
        ▼
LocalStorage (data/)               shared_preferences, JSON por colección
Lógica pura (logic/, utils/)       búsqueda, agrupación/totales, parseo y formato de precios, cálculo de descuentos
```

- Los providers cargan sincrónicamente en su constructor (`SharedPreferences` ya está abierto en `main`) y persisten tras cada mutación.
- Las pantallas nunca tocan `LocalStorage` ni calculan totales: leen providers y llaman funciones de `logic/`.
- Cascadas: `SupermarketsProvider.onRemoved → ProductsProvider.clearSupermarket`; `ProductsProvider.onRemoved → ShoppingListProvider.removeProduct`. Se cablean una sola vez en `AppProviders.create`.

## Árbol de `lib/`

```
lib/
├── main.dart                         # abre LocalStorage, crea AppProviders, runApp
├── app.dart                          # ListaMercadoApp: MaterialApp + MultiProvider(.value) + tema
├── app_providers.dart                # AppProviders.create(LocalStorage): crea y cablea los 3 providers
├── models/
│   ├── supermarket.dart
│   ├── product.dart
│   └── shopping_item.dart            # incluye tempPrice opcional (v1.0.2)
├── data/
│   └── local_storage.dart            # load/save JSON de las 3 colecciones + presupuesto
├── providers/
│   ├── supermarkets_provider.dart
│   ├── products_provider.dart
│   └── shopping_list_provider.dart   # lista + presupuesto + precio temporal
├── logic/
│   ├── product_search.dart           # searchProducts + kNoSupermarketFilter
│   └── list_grouping.dart            # ListRow, SupermarketSection, ListTotal, buildRows, buildSections, buildTotal
├── utils/
│   ├── price_format.dart             # parsePrice, validatePriceInput, formatPrice
│   ├── discount.dart                 # priceFromPercent, percentFromPrice, parsePercent, validatePercentInput, formatPercent
│   └── text_normalize.dart           # normalizeText
├── screens/
│   ├── home_shell.dart               # NavigationBar + IndexedStack (P1, P2, P3)
│   ├── products_screen.dart          # P1 (diálogo de añadir a la lista con cantidad y descuento)
│   ├── product_form_screen.dart      # alta/edición de producto (usada por P1 y por el atajo de P3)
│   ├── supermarkets_screen.dart      # P2
│   └── shopping_list_screen.dart     # P3 (barra con total/presupuesto, TabBar: Lista | Por supermercado + acciones masivas)
└── widgets/
    ├── confirm_dialog.dart
    ├── quantity_stepper.dart
    ├── discount_fields.dart          # campos % / precio final complementarios (alta y edición)
    ├── shopping_list_view.dart       # pestaña "Lista" (con deslizar para quitar y editar descuento)
    └── shopping_table_view.dart      # pestaña "Por supermercado" (columnas)

test/                                 # espejo de lib/: models_test, local_storage_test, price_format_test,
                                      # discount_test, product_search_test, providers_test, list_grouping_test,
                                      # app_providers_test, y widget tests de pantallas (incl. discount_fields_test)
```

## Review Focus

Entradas/condiciones que el spec implica pero no detalla; cada una tiene su test en la tarea indicada.

1. **Nombre vacío o solo espacios** (producto o supermercado) → se rechaza, nunca se guarda. (Tareas 4 y 8)
2. **Precio mal escrito:** `1,5`, `12.500`, `-3`, `0`, `abc`, vacío → interpretados según las decisiones de diseño; inválidos muestran error en el formulario. (Tarea 3 y 8)
3. **Eliminaciones en cascada:** borrar un producto que está en la lista lo quita de la lista; borrar un supermercado con productos los manda a Otros sin perderlos. (Tareas 4, 5 y 7)
4. **Almacenamiento vacío o corrupto** (primer arranque, JSON dañado, ítem de lista cuyo producto ya no existe) → la app abre con datos vacíos o salta el elemento dañado, sin crashear. (Tareas 2 y 6)
5. **Añadir dos veces el mismo producto a la lista** → una sola fila con cantidades sumadas, nunca duplicados; la segunda vez pide confirmación y, si se cancela, la cantidad existente no cambia. (Tareas 5 y 8)
6. **Quitar un producto de la lista** no borra el producto del catálogo, actualiza totales y tabla, y "Deshacer" lo restaura con su cantidad y tachado originales, sin duplicar si el producto fue añadido de nuevo entre tanto. (Tareas 5 y 9)
7. **Presupuesto:** valor inválido, cero o negativo no se guarda; un valor corrupto en almacenamiento se ignora (sin presupuesto); el restante cambia de verde a rojo exactamente al pasar de ≥ 0 a < 0; "Limpiar lista" no lo borra. (Tarea 11)
8. **Descuento:** % de 0, negativo, ≥ 100 o precio final ≥ precio base → inválido y no se guarda; los dos campos nunca quedan inconsistentes entre sí; sin precio base solo funciona el precio final y la fila deja de contar como sin precio; un `tempPrice` corrupto en almacenamiento se ignora sin perder el ítem; editar el precio base por debajo del `tempPrice` no rompe la pantalla; "Deshacer" restaura el descuento. (Tareas 12–15)

---

### Tarea 0: Scaffold del proyecto

**Archivos:**
- Crear: proyecto Flutter en la raíz del repo, `.gitignore` estándar de Flutter (+ `android/key.properties`, `*.jks`)
- Modificar: `pubspec.yaml`, `android/app/src/main/AndroidManifest.xml` (label)
- Eliminar: `test/widget_test.dart` (plantilla del contador)

**Interfaces:**
- Produce: proyecto que compila y pasa `flutter analyze`; paquete `lista_mercado`.

- [ ] **Paso 1:** `flutter create --org com.listamercado --platforms android --project-name lista_mercado .`
- [ ] **Paso 2:** `flutter pub add provider shared_preferences`
- [ ] **Paso 3:** Poner `android:label="Lista Mercado"` en el `AndroidManifest.xml` principal; borrar `test/widget_test.dart`.
- [ ] **Paso 4:** Reemplazar `lib/main.dart` por un `main()` mínimo que haga `runApp(const MaterialApp(home: Scaffold()))`.
- [ ] **Paso 5:** Ejecutar `flutter analyze`. Esperado: `No issues found!`
- [ ] **Paso 6:** Commit: `chore: scaffold flutter android project`

---

### Tarea 1: Modelos

**Archivos:**
- Crear: `lib/models/supermarket.dart`, `lib/models/product.dart`, `lib/models/shopping_item.dart`
- Test: `test/models_test.dart`

**Interfaces:**
- Produce:
  - `class Supermarket { final String id; final String name; const Supermarket({required this.id, required this.name}); Map<String, dynamic> toJson(); factory Supermarket.fromJson(Map<String, dynamic> json); }`
  - `class Product { final String id; final String name; final String? supermarketId; final double? price; const Product({required this.id, required this.name, this.supermarketId, this.price}); Map<String, dynamic> toJson(); factory Product.fromJson(Map<String, dynamic> json); }`
  - `class ShoppingItem { final String productId; final int quantity; final bool checked; const ShoppingItem({required this.productId, this.quantity = 1, this.checked = false}); ShoppingItem copyWith({int? quantity, bool? checked}); Map<String, dynamic> toJson(); factory ShoppingItem.fromJson(Map<String, dynamic> json); }`
  - `fromJson` lanza `FormatException` si falta un campo obligatorio (`id`, `name`, `productId`) o tiene tipo incorrecto.

- [ ] **Paso 1: Test que falla** (`models_test.dart`):
  - `product round-trips with null supermarketId and price`: `Product.fromJson(p.toJson())` conserva `id`, `name` y deja `supermarketId`/`price` en `null`.
  - `product round-trips with price 12500.5`: precio igual tras el round-trip.
  - `shopping item defaults to quantity 1 and unchecked`.
  - `shopping item copyWith changes only given fields`.
  - `fromJson throws FormatException when name is missing` (producto y supermercado).
- [ ] **Paso 2:** `flutter test test/models_test.dart` → FALLA (archivos no existen).
- [ ] **Paso 3:** Implementar las tres clases con las firmas de arriba.
- [ ] **Paso 4:** `flutter test test/models_test.dart` → PASA.
- [ ] **Paso 5:** Commit: `feat: add data models with json serialization`

---

### Tarea 2: LocalStorage

**Archivos:**
- Crear: `lib/data/local_storage.dart`
- Test: `test/local_storage_test.dart`

**Interfaces:**
- Consume: modelos de la Tarea 1.
- Produce:
  - `class LocalStorage { LocalStorage(SharedPreferences prefs); static Future<LocalStorage> open(); List<Supermarket> loadSupermarkets(); List<Product> loadProducts(); List<ShoppingItem> loadShoppingItems(); Future<void> saveSupermarkets(List<Supermarket> v); Future<void> saveProducts(List<Product> v); Future<void> saveShoppingItems(List<ShoppingItem> v); }`
  - Claves: `supermarkets_v1`, `products_v1`, `shopping_items_v1`; cada una guarda un `String` con una lista JSON.

- [ ] **Paso 1: Test que falla** (usar `SharedPreferences.setMockInitialValues`):
  - `loads empty lists on first launch` (sin claves).
  - `save then load returns same products`.
  - `corrupt json string yields empty list, no throw` (valor `'{no es json'`). **(Review Focus 4)**
  - `malformed entries are skipped, valid ones kept` (lista JSON con un elemento sin `name` y otro válido → 1 resultado). **(Review Focus 4)**
- [ ] **Paso 2:** `flutter test test/local_storage_test.dart` → FALLA.
- [ ] **Paso 3:** Implementar `LocalStorage`. Cada `load*` envuelve `jsonDecode` en `try/catch` y descarta elementos que lancen `FormatException`.
- [ ] **Paso 4:** `flutter test test/local_storage_test.dart` → PASA.
- [ ] **Paso 5:** Commit: `feat: add shared_preferences local storage`

---

### Tarea 3: Utilidades de texto, precio y búsqueda

**Archivos:**
- Crear: `lib/utils/text_normalize.dart`, `lib/utils/price_format.dart`, `lib/logic/product_search.dart`
- Test: `test/price_format_test.dart`, `test/product_search_test.dart`

**Interfaces:**
- Consume: `Product`.
- Produce:
  - `String normalizeText(String s)` → minúsculas, sin espacios en los extremos, sin tildes (`á é í ó ú ü`; la `ñ` se conserva).
  - `double? parsePrice(String raw)` → `null` si vacío, inválido o ≤ 0.
  - `String? validatePriceInput(String? raw)` → `null` si vacío o válido; si no, `'Precio inválido'`.
  - `String formatPrice(double value)` → ver decisión de diseño.
  - `const String kNoSupermarketFilter = '__none__';`
  - `List<Product> searchProducts(List<Product> products, {String query = '', String? supermarketFilter})` → `supermarketFilter == null` = todos; `kNoSupermarketFilter` = solo sin supermercado; otro valor = ese `supermarketId`. Coincidencia por `normalizeText(name).contains(normalizeText(query))`. Resultado ordenado por nombre normalizado.

- [ ] **Paso 1: Test que falla:**
  - `normalizeText('  ÉXITO ') == 'exito'`; `normalizeText('Piña') == 'piña'`.
  - `parsePrice('1,5') == 1.5`; `parsePrice('1.5') == 1.5`; `parsePrice('12.500') == 12500`; `parsePrice('1.234.567') == 1234567`; `parsePrice('12.500,5') == 12500.5`. **(Review Focus 2)**
  - `parsePrice('') == null`; `parsePrice('   ') == null`; `parsePrice('abc') == null`; `parsePrice('-3') == null`; `parsePrice('0') == null`. **(Review Focus 2)**
  - `validatePriceInput('') == null`; `validatePriceInput('abc') == 'Precio inválido'`; `validatePriceInput('0') == 'Precio inválido'`.
  - `formatPrice(12500) == '\$12.500'`; `formatPrice(999) == '\$999'`; `formatPrice(1234567.5) == '\$1.234.567,5'`; `formatPrice(2.25) == '\$2,25'`.
  - `searchProducts`: `'lec'` encuentra "Leche"; `'cafe'` encuentra "Café"; filtro por id de supermercado devuelve solo esos; `kNoSupermarketFilter` devuelve solo los sin supermercado; consulta vacía devuelve todos ordenados por nombre.
- [ ] **Paso 2:** `flutter test test/price_format_test.dart test/product_search_test.dart` → FALLA.
- [ ] **Paso 3:** Implementar. Para `parsePrice`: quitar espacios; si coincide con `^\d{1,3}(\.\d{3})+(,\d+)?$` tratar los puntos como miles; en otro caso reemplazar `,` por `.` y usar `double.tryParse`; descartar ≤ 0.
- [ ] **Paso 4:** Ejecutar los mismos tests → PASAN.
- [ ] **Paso 5:** Commit: `feat: add text normalization, price parsing/formatting and product search`

---

### Tarea 4: SupermarketsProvider y ProductsProvider

**Archivos:**
- Crear: `lib/providers/supermarkets_provider.dart`, `lib/providers/products_provider.dart`
- Test: `test/providers_test.dart` (grupos `supermarkets` y `products`)

**Interfaces:**
- Consume: `LocalStorage`, modelos, `normalizeText`.
- Produce:
  - `class SupermarketsProvider extends ChangeNotifier { SupermarketsProvider({required LocalStorage storage, void Function(String supermarketId)? onRemoved}); List<Supermarket> get supermarkets; Supermarket? byId(String? id); Future<bool> add(String name); Future<bool> rename(String id, String name); Future<void> remove(String id); }` — `supermarkets` ordenados por nombre normalizado, no modificable. `add`/`rename` devuelven `false` (sin cambios) si el nombre recortado está vacío o ya existe otro igual según `normalizeText`.
  - `class ProductsProvider extends ChangeNotifier { ProductsProvider({required LocalStorage storage, void Function(String productId)? onRemoved}); List<Product> get products; Product? byId(String id); Future<Product> add({required String name, String? supermarketId, double? price}); Future<void> update(Product product); Future<void> remove(String id); Future<void> clearSupermarket(String supermarketId); }` — `add` recorta el nombre y lanza `ArgumentError` si queda vacío; `update` reemplaza el producto con el mismo `id`; `clearSupermarket` deja `supermarketId = null` solo en los productos de ese supermercado.
  - Ambos cargan desde `storage` en el constructor, persisten y llaman `notifyListeners()` tras cada mutación.

- [ ] **Paso 1: Test que falla:**
  - supermercados: `add trims name`; `add blank returns false and keeps list unchanged` **(RF1)**; `add duplicate ignoring case and accents returns false` (`'Éxito'` vs `'exito'`); `rename to existing name returns false`; `remove calls onRemoved with the id`; `state persists: new provider on same storage sees data`; `notifies listeners on add`.
  - productos: `add trims name and stores optional fields`; `add blank name throws ArgumentError` **(RF1)**; `add allows duplicate names`; `update persists price change`; `remove calls onRemoved with the id`; `clearSupermarket nulls only matching products` **(RF3)**; `state persists across instances`.
- [ ] **Paso 2:** `flutter test test/providers_test.dart` → FALLA.
- [ ] **Paso 3:** Implementar ambos providers con las firmas de arriba.
- [ ] **Paso 4:** `flutter test test/providers_test.dart` → PASA.
- [ ] **Paso 5:** Commit: `feat: add supermarkets and products providers`

---

### Tarea 5: ShoppingListProvider

**Archivos:**
- Crear: `lib/providers/shopping_list_provider.dart`
- Modificar: `test/providers_test.dart` (grupo `shopping list`)

**Interfaces:**
- Consume: `LocalStorage`, `ShoppingItem`.
- Produce: `class ShoppingListProvider extends ChangeNotifier { ShoppingListProvider({required LocalStorage storage}); List<ShoppingItem> get items; int? quantityOf(String productId); bool contains(String productId); Future<void> addProduct(String productId, int quantity); Future<void> setQuantity(String productId, int quantity); Future<void> toggleChecked(String productId); Future<void> toggleCheckedFor(Iterable<String> productIds); Future<void> removeProduct(String productId); Future<void> restoreItem(ShoppingItem item); Future<void> clear(); }`
  - `quantityOf`: cantidad actual del producto en la lista, o `null` si no está. `contains`: `quantityOf(productId) != null`. Son de solo lectura y no notifican; la UI los usa para decidir si pide confirmación antes de sumar.
  - `addProduct`: si ya existe, suma cantidades; `quantity < 1` se trata como 1. **Siempre suma sin preguntar:** la confirmación es responsabilidad de la UI (Tarea 8).
  - `setQuantity`: mínimo 1; ignora ids que no están en la lista.
  - `toggleCheckedFor`: considera solo los ids presentes en la lista; si todos están tachados los destacha, si no los tacha todos.
  - `removeProduct`: quita solo ese ítem; si el id no está en la lista, no hace nada (ni notifica). Lo usan la cascada de eliminación de productos y el deslizar-para-quitar de P3.
  - `restoreItem`: reinserta un `ShoppingItem` tal cual (cantidad y `checked` originales), para "Deshacer". Si ya hay un ítem con ese `productId`, no hace nada (nunca duplica).

- [ ] **Paso 1: Test que falla:**
  - `addProduct twice sums quantities into one item` (2 + 3 → un ítem con 5). **(RF5)**
  - `addProduct with quantity 0 stores 1`.
  - `quantityOf returns null when absent and the current quantity when present`; `contains reflects membership`. **(RF5)**
  - `setQuantity(0) clamps to 1`; `setQuantity on unknown id does nothing`.
  - `toggleChecked twice returns to unchecked`; `checked keeps quantity`.
  - `toggleCheckedFor with mixed state checks all; second call unchecks all`.
  - `toggleCheckedFor ignores ids not in the list`.
  - `removeProduct removes only that item` **(RF3, RF6)**; `removeProduct on unknown id does nothing and does not notify` **(RF6)**; `clear empties the list`.
  - `restoreItem re-adds an item with its original quantity and checked state` **(RF6)**; `restoreItem does nothing if the product is already in the list` **(RF6)**.
  - `state persists across instances`.
- [ ] **Paso 2:** `flutter test test/providers_test.dart` → FALLA en el grupo nuevo.
- [ ] **Paso 3:** Implementar `ShoppingListProvider`.
- [ ] **Paso 4:** `flutter test test/providers_test.dart` → PASA.
- [ ] **Paso 5:** Commit: `feat: add shopping list provider`

---

### Tarea 6: Agrupación y totales

**Archivos:**
- Crear: `lib/logic/list_grouping.dart`
- Test: `test/list_grouping_test.dart`

**Interfaces:**
- Consume: `Product`, `Supermarket`, `ShoppingItem`, `formatPrice`, `normalizeText`.
- Produce:
  - `class ListRow { final Product product; final ShoppingItem item; const ListRow(this.product, this.item); double? get unitPrice; double? get lineTotal; }` — `unitPrice = product.price`; `lineTotal = price * quantity` o `null` sin precio.
  - `class SupermarketSection { final String title; final String? supermarketId; final List<ListRow> rows; double get total; bool get hasUnpriced; String get totalLabel; }` — `total` suma solo filas con precio (tachadas incluidas); `totalLabel` = `formatPrice(total)` o `'${formatPrice(total)} + (?)'` si `hasUnpriced`.
  - `List<ListRow> buildRows(List<ShoppingItem> items, List<Product> products)` — omite ítems cuyo producto no existe; ordena por nombre normalizado.
  - `List<SupermarketSection> buildSections(List<ListRow> rows, List<Supermarket> supermarkets)` — supermercados por nombre, solo los que tienen filas; sección `Otros` (`supermarketId == null`) al final y solo si tiene filas; un producto cuyo `supermarketId` ya no existe va a `Otros`.

- [ ] **Paso 1: Test que falla:**
  - `section total sums priced rows times quantity`: 2×1000 + 1×500 → `total == 2500`, `totalLabel == '\$2.500'`.
  - `unpriced row is excluded and marks label with (?)`: 2×1000 + fila sin precio → `total == 2000`, `hasUnpriced`, `totalLabel == '\$2.000 + (?)'`.
  - `section with only unpriced rows labels '\$0 + (?)'`.
  - `checked rows still count in total`.
  - `product without supermarket goes to Otros, which is last`.
  - `product pointing to a missing supermarket goes to Otros`. **(RF4)**
  - `empty sections are omitted`.
  - `buildRows skips items whose product no longer exists`. **(RF4)**
- [ ] **Paso 2:** `flutter test test/list_grouping_test.dart` → FALLA.
- [ ] **Paso 3:** Implementar con las firmas de arriba.
- [ ] **Paso 4:** `flutter test test/list_grouping_test.dart` → PASA.
- [ ] **Paso 5:** Commit: `feat: add list grouping and totals logic`

---

### Tarea 7: Cableado, shell de navegación y P2 (Supermercados)

**Archivos:**
- Crear: `lib/app_providers.dart`, `lib/app.dart`, `lib/screens/home_shell.dart`, `lib/screens/supermarkets_screen.dart`, `lib/widgets/confirm_dialog.dart`
- Modificar: `lib/main.dart`
- Test: `test/app_providers_test.dart`, `test/supermarkets_screen_test.dart`

**Interfaces:**
- Consume: los tres providers (Tareas 4 y 5), `LocalStorage.open()`.
- Produce:
  - `class AppProviders { final SupermarketsProvider supermarkets; final ProductsProvider products; final ShoppingListProvider shoppingList; factory AppProviders.create(LocalStorage storage); }` — crea `ShoppingListProvider`, luego `ProductsProvider(onRemoved: shoppingList.removeProduct)`, luego `SupermarketsProvider(onRemoved: products.clearSupermarket)`.
  - `class ListaMercadoApp extends StatelessWidget { const ListaMercadoApp({super.key, required AppProviders providers}); }` — `MultiProvider` con `ChangeNotifierProvider.value` de los tres.
  - `class HomeShell extends StatefulWidget` — `NavigationBar` con destinos "Productos", "Supermercados", "Lista"; `IndexedStack` para conservar estado. Mientras P1 y P3 no existan, usan `Placeholder`.
  - `Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirmLabel = 'Confirmar'})` → `true` solo si se pulsa el botón de confirmar; cancelar o tocar fuera → `false`.
  - `class SupermarketsScreen extends StatelessWidget` — lista de nombres, FAB "Añadir", cada fila con editar y eliminar; añadir/renombrar con diálogo de texto; eliminar con `confirmDialog` cuyo mensaje aclara que los productos no se borran.

- [ ] **Paso 1: Test que falla:**
  - `app_providers_test`: `removing a supermarket clears it from its products` y `removing a product removes it from the shopping list` usando `AppProviders.create` sobre `SharedPreferences` simulado. **(RF3)**
  - `supermarkets_screen_test`: `shows added supermarket name`; `blank name in dialog shows error and does not add` **(RF1)**; `delete asks confirmation and cancel keeps the supermarket`.
- [ ] **Paso 2:** `flutter test test/app_providers_test.dart test/supermarkets_screen_test.dart` → FALLA.
- [ ] **Paso 3:** Implementar `AppProviders`, `ListaMercadoApp`, `HomeShell`, `confirmDialog` y `SupermarketsScreen`; `main()` hace `WidgetsFlutterBinding.ensureInitialized()`, `LocalStorage.open()`, `runApp(ListaMercadoApp(...))`.
- [ ] **Paso 4:** Ejecutar los tests → PASAN. Ejecutar `flutter analyze` → sin issues.
- [ ] **Paso 5:** Verificación manual: `flutter run`, añadir/editar/eliminar un supermercado, cerrar la app por completo y reabrir → los datos persisten.
- [ ] **Paso 6:** Commit: `feat: add app wiring, navigation shell and supermarkets screen`

---

### Tarea 8: P1 — Productos (pantalla, formulario, buscar/filtrar, añadir a la lista)

**Archivos:**
- Crear: `lib/screens/products_screen.dart`, `lib/screens/product_form_screen.dart`, `lib/widgets/quantity_stepper.dart`
- Modificar: `lib/screens/home_shell.dart` (reemplazar el placeholder de P1)
- Test: `test/products_screen_test.dart`, `test/product_form_screen_test.dart`

**Interfaces:**
- Consume: `ProductsProvider`, `SupermarketsProvider`, `ShoppingListProvider` (incluye `quantityOf`/`contains`/`addProduct`), `searchProducts`, `kNoSupermarketFilter`, `validatePriceInput`, `parsePrice`, `formatPrice`, `confirmDialog`.
- Produce:
  - `class QuantityStepper extends StatelessWidget { const QuantityStepper({super.key, required int value, required ValueChanged<int> onChanged}); }` — "−" deshabilitado en 1; "+" siempre activo.
  - `class ProductFormScreen extends StatefulWidget { const ProductFormScreen({super.key, String? productId}); }` — `productId == null` = alta; si no, edición del producto existente. Campos: nombre (obligatorio, validador rechaza vacío/solo espacios), supermercado (`DropdownButtonFormField`, opción "Sin supermercado"), precio (teclado numérico, `validatePriceInput`). Guardar cierra la pantalla (`Navigator.pop`).
  - `class ProductsScreen extends StatelessWidget` — campo de búsqueda + dropdown de filtro ("Todos", cada supermercado, "Sin supermercado"); `ListView` de productos (título = nombre; subtítulo = supermercado y/o precio solo si existen); por fila: botón "añadir a la lista" y menú con "Editar" (abre `ProductFormScreen(productId: ...)`) y "Eliminar" (con `confirmDialog` que avisa que también se quitará de la lista); FAB "Añadir producto".
  - **Flujo de "añadir a la lista":**
    1. Se abre el diálogo con `QuantityStepper` (valor inicial 1). Cancelar → no pasa nada.
    2. Al aceptar con cantidad `n`, se consulta `ShoppingListProvider.quantityOf(productId)`.
    3. Si es `null` (el producto no está en la lista) → `addProduct(productId, n)` directamente, sin preguntar.
    4. Si no es `null` (ya está con cantidad `actual`) → `confirmDialog` con título "Producto ya en la lista", mensaje `"<nombre>" ya está en la lista con cantidad <actual>. ¿Sumar <n> más para un total de <actual + n>?` y `confirmLabel: 'Sumar'`. Solo si devuelve `true` se llama `addProduct(productId, n)`; si devuelve `false` la cantidad existente queda intacta.
  - Llaves para tests: `Key('product-tile-<id>')`, `Key('add-to-list-<id>')`.

- [ ] **Paso 1: Test que falla:**
  - `product_form_screen_test`: `blank or whitespace name shows error and does not save` **(RF1)**; `price 'abc' shows 'Precio inválido'` **(RF2)**; `valid form with only a name saves a product without supermarket or price`; `editing preloads existing values`.
  - `products_screen_test`: `search 'cafe' shows 'Café' and hides others`; `supermarket filter shows only that supermarket's products`; `'Sin supermercado' filter shows only unassigned products`; `add-to-list dialog with quantity 3 adds item with quantity 3 and no confirmation when the product is not in the list`; `delete confirmation cancel keeps product, confirm removes it and its list item`.
  - `products_screen_test` (confirmación al sumar) **(RF5)**:
    - `adding a product already in the list asks to confirm and the message shows current quantity and resulting total` (lista con 2, añadir 3 → el diálogo menciona 2 y 5).
    - `cancelling the sum confirmation keeps the existing quantity unchanged` (sigue en 2).
    - `confirming the sum updates the single list item to the summed quantity` (queda un solo ítem con 5).
    - `cancelling the quantity dialog itself does not ask for confirmation and changes nothing`.
- [ ] **Paso 2:** `flutter test test/product_form_screen_test.dart test/products_screen_test.dart` → FALLA.
- [ ] **Paso 3:** Implementar los tres archivos. Nombres largos: `Text(..., maxLines: 2, overflow: TextOverflow.ellipsis)` para que nunca desborden en pantallas pequeñas. En el flujo de "añadir a la lista", usar `if (!context.mounted) return;` después de cada `await` de diálogo antes de volver a usar `context`.
- [ ] **Paso 4:** Ejecutar los tests → PASAN. `flutter analyze` → sin issues.
- [ ] **Paso 5:** Verificación manual: crear productos (con y sin supermercado/precio), buscar con y sin tilde, filtrar, añadir a la lista con cantidad, **volver a añadir el mismo producto y comprobar el diálogo de confirmación (aceptar y cancelar)**, editar, eliminar.
- [ ] **Paso 6:** Commit: `feat: add products screen, form, search/filter and add-to-list with sum confirmation`

---

### Tarea 9: P3 — Lista de mercado (lista, tabla, tachado, cantidades, quitar uno, acciones masivas)

**Archivos:**
- Crear: `lib/screens/shopping_list_screen.dart`, `lib/widgets/shopping_list_view.dart`, `lib/widgets/shopping_table_view.dart`
- Modificar: `lib/screens/home_shell.dart` (reemplazar el placeholder de P3)
- Test: `test/shopping_list_screen_test.dart`

**Interfaces:**
- Consume: `ShoppingListProvider` (incluye `removeProduct` y `restoreItem`), `ProductsProvider`, `SupermarketsProvider`, `buildRows`, `buildSections`, `formatPrice`, `QuantityStepper`, `confirmDialog`, `ProductFormScreen`.
- Produce:
  - `class ShoppingListScreen extends StatelessWidget` — `TabBar` "Lista" | "Por supermercado"; `AppBar` con menú: "Tachar/Destachar todos" y "Limpiar lista", ambos con `confirmDialog`; estado vacío con texto "La lista está vacía".
  - `class ShoppingListView extends StatelessWidget` — una fila por `ListRow`: nombre, supermercado, `QuantityStepper`, precio unitario (o "—" sin precio), total de línea (o "—"), botón editar (`Navigator.push` a `ProductFormScreen(productId: ...)`). Tocar la fila alterna el tachado.
    - **Quitar un solo producto:** cada fila va envuelta en un `Dismissible` (`direction: DismissDirection.endToStart`, `key: Key('dismiss-<productId>')`) con fondo rojo e icono de papelera. Al completar el deslizamiento se llama `ShoppingListProvider.removeProduct(productId)` (el producto **no** se elimina de P1) y se muestra un `SnackBar` "«<nombre>» quitado de la lista" con acción "Deshacer", que llama `ShoppingListProvider.restoreItem(item)` con el `ShoppingItem` capturado antes de quitarlo (cantidad y tachado originales). Antes de mostrar el nuevo `SnackBar`, llamar `ScaffoldMessenger.of(context).hideCurrentSnackBar()` para que no se acumulen.
  - `class ShoppingTableView extends StatelessWidget` — `SingleChildScrollView` horizontal con una columna de ancho fijo (160) por `SupermarketSection`: encabezado con el título y un menú "Tachar/Destachar todos de este supermercado" (con `confirmDialog`), celdas con nombre, `cantidad × precio` y botón editar, y pie con `section.totalLabel`. Tocar una celda alterna el tachado. La tabla no tiene deslizar: refleja automáticamente los productos quitados desde la pestaña "Lista".
  - Tachado = `TextDecoration.lineThrough` + color atenuado; nunca cambia totales.
  - Llaves para tests: `Key('row-name-<productId>')` (lista), `Key('cell-name-<productId>')` (tabla), `Key('section-total-<title>')`, `Key('dismiss-<productId>')` (fila deslizable).

- [ ] **Paso 1: Test que falla:**
  - `tapping a row in the list view strikes the name in both list and table views` (la decoración `lineThrough` aparece en `row-name-` y en `cell-name-`); tocarla de nuevo la quita en ambas.
  - `striking an item does not change the section total`.
  - `section with an unpriced product shows '+ (?)' in its total label`.
  - `unassigned products appear in the 'Otros' column`.
  - `quantity '+' updates line total and section total`.
  - `strike-all for one supermarket asks confirmation; cancel changes nothing; confirm strikes only that supermarket's items; repeating it unstrikes them`.
  - `strike-all asks confirmation and toggles every item`.
  - `clear list: cancel keeps items, confirm empties the list and shows 'La lista está vacía'`.
  - `edit button opens the product form preloaded with that product`.
  - Quitar un solo producto **(RF6)** (usar `tester.drag(find.byKey(Key('dismiss-<id>')), const Offset(-500, 0))` seguido de `pumpAndSettle`):
    - `swiping a row removes only that product from the list view and the table view`.
    - `swiping a row does not delete the product from the products catalog`.
    - `removing a product updates the section total and drops the section if it becomes empty`.
    - `removing the last item shows 'La lista está vacía'`.
    - `swipe shows a SnackBar with 'Deshacer'; tapping it restores the item with its original quantity and checked state`.
    - `swiping a checked item then undoing keeps it checked`.
- [ ] **Paso 2:** `flutter test test/shopping_list_screen_test.dart` → FALLA.
- [ ] **Paso 3:** Implementar los tres archivos; las vistas leen `buildRows`/`buildSections` en cada `build` (sin estado duplicado). En `ShoppingListView`, capturar el `ShoppingItem` (`row.item`) en el `onDismissed` antes de llamar `removeProduct`, para poder restaurarlo.
- [ ] **Paso 4:** `flutter test test/shopping_list_screen_test.dart` → PASA. Luego `flutter test` completo → todo en verde.
- [ ] **Paso 5:** Verificación manual en dispositivo: tachar desde la lista y ver la tabla; tachar desde la tabla y ver la lista; acciones masivas; **deslizar un producto para quitarlo (y probar "Deshacer"), confirmar que sigue existiendo en la pantalla de Productos**; límites de pantalla pequeña (nombres largos, 5+ supermercados con scroll horizontal).
- [ ] **Paso 6:** Commit: `feat: add shopping list screen with list/table views, swipe-to-remove and bulk actions`

---

### Tarea 10: Pulido y APK release (v1.0.0)

**Archivos:**
- Modificar: `android/app/build.gradle(.kts)` (firma release), `android/.gitignore`
- Crear: `android/key.properties` (NO se commitea), keystore fuera del repo

**Interfaces:**
- Consume: app completa.
- Produce: `build/app/outputs/flutter-apk/app-release.apk` firmado con un keystore propio.

- [ ] **Paso 1:** Generar un keystore con `keytool -genkey -v -keystore ~/lista-mercado.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lista`; guardar una copia de respaldo y la contraseña. (Si se pierde, el usuario final tendrá que desinstalar para poder actualizar la app.)
- [ ] **Paso 2:** Crear `android/key.properties` (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`) y configurar `signingConfigs.release` en el archivo gradle generado; confirmar que `key.properties` y `*.jks` están en `.gitignore`.
- [ ] **Paso 3:** `flutter test` y `flutter analyze` → todo en verde.
- [ ] **Paso 4:** `flutter build apk --release` → genera `app-release.apk`.
- [ ] **Paso 5:** Verificar permisos: `aapt dump permissions build/app/outputs/flutter-apk/app-release.apk` → no incluye `android.permission.INTERNET`.
- [ ] **Paso 6:** Instalar con `adb install -r build/app/outputs/flutter-apk/app-release.apk` y recorrer la lista de humo: crear 2 supermercados y 4 productos (uno sin precio, uno sin supermercado) → añadir a la lista → **volver a añadir uno ya presente y confirmar el diálogo de suma** → tachar/destachar desde ambas vistas → **deslizar un producto para quitarlo y deshacer** → verificar `TOTAL + (?)` → cerrar la app desde recientes y reabrir → todo persiste.
- [ ] **Paso 7:** Commit: `chore: configure release signing`

---

### Tarea 11: Total general y presupuesto en la barra de la lista (v1.0.1)

**Archivos:**
- Modificar: `lib/data/local_storage.dart`, `lib/providers/shopping_list_provider.dart`, `lib/logic/list_grouping.dart`, `lib/screens/shopping_list_screen.dart`, `pubspec.yaml` (versión `1.0.1+2`)
- Test: `test/list_grouping_test.dart`, `test/providers_test.dart` (grupo `shopping list`), `test/shopping_list_screen_test.dart`

**Interfaces:**
- Consume: `ShoppingListProvider`, `buildRows`, `formatPrice`, `parsePrice`.
- Produce:
  - `LocalStorage`: clave `budget_v1`; `double? loadBudget()` (devuelve `null` si no existe, no es número, no es finito o es ≤ 0); `Future<void> saveBudget(double? value)` (`null` borra la clave).
  - `ShoppingListProvider`: `double? get budget` (cargado en el constructor) y `Future<void> setBudget(double? value)`; `null` quita el presupuesto; valores no positivos o no finitos se ignoran. `clear()` no toca el presupuesto.
  - `class ListTotal { final double total; final bool hasUnpriced; String get label; double remaining(double budget); bool isOverBudget(double budget); String remainingLabel(double budget); }` — `label` = `formatPrice(total)` o `'${formatPrice(total)} + (?)'`; `remainingLabel` = restante formateado (negativo como `-$700`) más `' - (?)'` si `hasUnpriced`.
  - `ListTotal buildTotal(List<ListRow> rows)` — suma las filas con precio (tachadas incluidas) y marca `hasUnpriced` si alguna no tiene precio.
  - `ShoppingListScreen`: el título de la `AppBar` pasa a ser una columna con `Total: <label>` (`Key('list-total')`) y, solo si hay presupuesto, `Presupuesto <monto> · Restante: <remainingLabel>` (`Key('list-budget')`), con el restante en verde si ≥ 0 y en rojo si < 0 (tonos más claros en tema oscuro). Nuevo botón de cartera (`Key('budget-button')`) en las acciones que abre un diálogo (`Key('budget-input')`) con "Cancelar", "Quitar" (solo si ya hay presupuesto) y "Guardar"; un monto inválido deja el diálogo abierto con el error `Precio inválido`.

- [ ] **Paso 1: Test que falla:**
  - `buildTotal sums all priced rows and flags unpriced`: 2×1000 + fila sin precio → `total == 2000`, `label == '\$2.000 + (?)'`, `remainingLabel(5000) == '\$3.000 - (?)'`, `isOverBudget(5000) == false`.
  - `buildTotal negative remaining and no unpriced`: 6×1000 con presupuesto 5000 → `remainingLabel(5000) == '-\$1.000'`, `isOverBudget(5000) == true`.
  - `budget persists, can be removed, and survives clear`. **(RF7)**
  - `setBudget ignores non-positive values`. **(RF7)**
  - Pantalla (datos de prueba: total `$4.700 + (?)`): `app bar shows the grand total with (?)` y no hay `list-budget`; `budget above total shows green remaining` (5.000 → `$300 - (?)`); `budget below total shows red negative remaining` (4000 → `-$700 - (?)`); `invalid budget keeps dialog open; Quitar removes it`. **(RF7)**
- [ ] **Paso 2:** `flutter test` → FALLA en los tests nuevos.
- [ ] **Paso 3:** Implementar. Ajustar `toolbarHeight` de la `AppBar` (72) para que quepan las dos líneas. Los textos usan `maxLines: 1` y `TextOverflow.ellipsis`.
- [ ] **Paso 4:** `flutter test` completo → verde; `flutter analyze` → sin issues.
- [ ] **Paso 5:** Verificación manual: añadir productos con y sin precio → ver `Total: $X + (?)`; fijar un presupuesto mayor (verde) y uno menor (rojo con `-`); quitar el presupuesto; limpiar la lista y confirmar que el presupuesto se conserva; cerrar la app desde recientes y reabrir → persiste. Probar en tema oscuro.
- [ ] **Paso 6:** Subir la versión a `1.0.1+2` en `pubspec.yaml` y compilar el release como en la Tarea 10 (mismo keystore, para conservar los datos al actualizar).
- [ ] **Paso 7:** Commit: `feat: add list grand total and budget with remaining in app bar`

---

### Tarea 12: Modelo y lógica de descuento (v1.0.2)

**Archivos:**
- Crear: `lib/utils/discount.dart`
- Modificar: `lib/models/shopping_item.dart`, `lib/logic/list_grouping.dart`
- Test: `test/discount_test.dart`, `test/models_test.dart`, `test/list_grouping_test.dart`

**Interfaces:**
- Consume: `parsePrice`, `formatPrice`, `ShoppingItem`, `ListRow`.
- Produce:
  - `double? priceFromPercent(double base, double percent)` → `null` si `base <= 0`, `percent` fuera de (0, 100) o el resultado redondeado es ≤ 0; si no, `base * (1 - percent/100)` a 2 decimales.
  - `double? percentFromPrice(double base, double price)` → `null` si `base <= 0`, `price <= 0` o `price >= base`; si no, `(1 - price/base) * 100` a 2 decimales.
  - `double? parsePercent(String raw)` → usa `parsePrice` y devuelve `null` si el valor no está en (0, 100).
  - `String? validatePercentInput(String? raw)` → `null` si vacío o válido; si no, `'Descuento inválido'`.
  - `String formatPercent(double value)` → `15%`, `12,5%` (máximo 2 decimales, coma decimal, sin ceros finales).
  - `ShoppingItem`: campo `final double? tempPrice`; `copyWith({int? quantity, bool? checked, double? tempPrice, bool clearTempPrice = false})`; `toJson` incluye `tempPrice`; `fromJson` lee `tempPrice` como `null` si falta o no es un número positivo y finito (nunca lanza por este campo).
  - `ListRow`: `unitPrice = item.tempPrice ?? product.price`; `double? get basePrice => product.price`; `bool get hasDiscount => item.tempPrice != null`; `double? get discountPercent` (vía `percentFromPrice`, `null` si no aplica). `lineTotal` usa `unitPrice`. Como `SupermarketSection.hasUnpriced` y `buildTotal` ya se basan en `unitPrice`, una fila con `tempPrice` cuenta como "con precio".

- [ ] **Paso 1: Test que falla:**
  - `discount_test`: `priceFromPercent(10000, 15) == 8500`; `percentFromPrice(10000, 8500) == 15`; `percentFromPrice(10000, 9000) == 10`; límites: `percent` 0, 100, -5 → `null`; `price` igual o mayor al base → `null`; `base` 0 → `null`; redondeo a 2 decimales; `formatPercent(15) == '15%'`, `formatPercent(12.5) == '12,5%'`; `validatePercentInput('') == null`, `'abc'` y `'100'` → `'Descuento inválido'`. **(RF8)**
  - `models_test`: `tempPrice` round-trip; ausente → `null`; `tempPrice` de tipo incorrecto o ≤ 0 → `null` sin lanzar excepción; `copyWith(clearTempPrice: true)` lo quita; `copyWith` sin `tempPrice` lo conserva. **(RF8)**
  - `list_grouping_test`: fila con `tempPrice` usa ese precio en `lineTotal`; fila sin precio base pero con `tempPrice` no marca `(?)` ni en la sección ni en `buildTotal`; `discountPercent` es `null` si `tempPrice >= basePrice`. **(RF8)**
- [ ] **Paso 2:** `flutter test test/discount_test.dart test/models_test.dart test/list_grouping_test.dart` → FALLA.
- [ ] **Paso 3:** Implementar.
- [ ] **Paso 4:** Mismos tests → PASAN; `flutter test` completo en verde (los tests de 1.0.1 no deben cambiar).
- [ ] **Paso 5:** Commit: `feat: add temporary price to shopping items and discount utils`

---

### Tarea 13: ShoppingListProvider con precio temporal

**Archivos:**
- Modificar: `lib/providers/shopping_list_provider.dart`
- Test: `test/providers_test.dart` (grupo `shopping list`)

**Interfaces:**
- Consume: `ShoppingItem.tempPrice`.
- Produce:
  - `Future<void> addProduct(String productId, int quantity, {double? tempPrice})` → si `tempPrice != null` (y es > 0 y finito) reemplaza el del ítem (nuevo o existente); si es `null`, conserva el existente. Sigue sumando cantidades sin preguntar.
  - `Future<void> setTempPrice(String productId, double? value)` → `null` quita el descuento; valores no positivos o no finitos se ignoran; ids que no están en la lista se ignoran (sin notificar).
  - `restoreItem` ya conserva `tempPrice` porque reinserta el `ShoppingItem` tal cual.

- [ ] **Paso 1: Test que falla:**
  - `addProduct with tempPrice stores it on a new item`.
  - `addProduct without tempPrice keeps the existing tempPrice when summing`.
  - `addProduct with tempPrice replaces the existing one`.
  - `setTempPrice sets, changes and removes the discount`; `setTempPrice ignores non-positive values and unknown ids (no notify)`.
  - `tempPrice persists across instances`.
  - `restoreItem keeps the tempPrice`. **(RF8)**
- [ ] **Paso 2:** `flutter test test/providers_test.dart` → FALLA en los tests nuevos.
- [ ] **Paso 3:** Implementar.
- [ ] **Paso 4:** `flutter test test/providers_test.dart` → PASA.
- [ ] **Paso 5:** Commit: `feat: support temporary price in shopping list provider`

---

### Tarea 14: Descuento al añadir a la lista

**Archivos:**
- Crear: `lib/widgets/discount_fields.dart`
- Modificar: `lib/screens/products_screen.dart`
- Test: `test/discount_fields_test.dart`, `test/products_screen_test.dart`

**Interfaces:**
- Consume: `priceFromPercent`, `percentFromPrice`, `parsePercent`, `parsePrice`, `validatePercentInput`, `validatePriceInput`, `formatPercent`, `formatPrice`, `ShoppingListProvider.addProduct`.
- Produce:
  - `class DiscountFields extends StatefulWidget { const DiscountFields({super.key, required double? basePrice, double? initialTempPrice, required ValueChanged<double?> onChanged}); }` — dos campos: `%` (`Key('discount-percent')`) y `Precio final` (`Key('discount-price')`). Editar uno calcula y rellena el otro (con una bandera interna para evitar bucles); si el campo editado queda vacío o inválido, el otro se vacía y `onChanged(null)`. Sin `basePrice`, el campo % queda deshabilitado con la ayuda "Sin precio: indica el precio final". Muestra el error en el campo que corresponda. `onChanged` entrega el precio final válido o `null`. Con `initialTempPrice` precarga ambos campos.
  - `_QuantityDialog` recibe el producto, muestra `QuantityStepper` + `DiscountFields` (opcional; dejarlo vacío no cambia nada) y devuelve `({int quantity, double? tempPrice})`. El botón "Añadir" se deshabilita mientras algún campo sea inválido.
  - Flujo: si el producto ya está en la lista y el diálogo trae `tempPrice`, el mensaje de confirmación añade `Se aplicará el precio temporal <precio>.`; si no, el mensaje no cambia. Tras confirmar se llama `addProduct(productId, n, tempPrice: tempPrice)`.

- [ ] **Paso 1: Test que falla:**
  - `discount_fields_test`: escribir `15` en % con base 10000 → precio final `8500`; escribir `8500` en precio → % `15%`; vaciar un campo vacía el otro; `abc` y `100` muestran `Descuento inválido`; precio final ≥ base muestra error; sin precio base el campo % está deshabilitado y el precio final funciona. **(RF8)**
  - `products_screen_test`: añadir con descuento por % guarda el `tempPrice` correcto; añadir con precio final guarda el `tempPrice`; añadir sin tocar los campos no guarda descuento (comportamiento 1.0.1 intacto); producto ya en la lista + descuento → el diálogo de suma lo menciona y al confirmar reemplaza el `tempPrice`; sin descuento nuevo se conserva el existente.
- [ ] **Paso 2:** `flutter test test/discount_fields_test.dart test/products_screen_test.dart` → FALLA.
- [ ] **Paso 3:** Implementar. Usar `if (!context.mounted) return;` después de cada `await`.
- [ ] **Paso 4:** Tests → PASAN. `flutter test` completo en verde; `flutter analyze` sin issues.
- [ ] **Paso 5:** Verificación manual: añadir con %, con precio final y sin descuento; producto sin precio base; volver a añadir uno ya presente con y sin descuento.
- [ ] **Paso 6:** Commit: `feat: add discount fields to the add-to-list dialog`

---

### Tarea 15: Editar el descuento desde la lista de mercado

**Archivos:**
- Modificar: `lib/widgets/shopping_list_view.dart`, `lib/widgets/shopping_table_view.dart`
- Test: `test/shopping_list_screen_test.dart`

**Interfaces:**
- Consume: `DiscountFields`, `ShoppingListProvider.setTempPrice`, `ListRow` (`hasDiscount`, `basePrice`, `discountPercent`), `formatPercent`, `formatPrice`.
- Produce:
  - Vista **Lista**: botón de descuento por fila (`Key('edit-discount-<productId>')`, icono `Icons.sell_outlined`) que abre un diálogo con `DiscountFields` precargado y acciones "Cancelar", "Quitar" (solo si ya hay descuento) y "Guardar". Si la fila tiene descuento, muestra el precio base tachado, el precio con descuento y `-<porcentaje>` (este último solo si `discountPercent != null`). El total de línea usa el precio efectivo.
  - Vista **Por supermercado**: botón equivalente (`Key('discount-cell-<productId>')`, `iconSize: 20`, `VisualDensity.compact`) junto al botón de editar; `_columnWidth` pasa de 160 a 184. La línea `cantidad × precio` muestra el precio efectivo y, si hay descuento, `(-<porcentaje>)`.
  - Guardar llama `setTempPrice(productId, valor)`; Quitar llama `setTempPrice(productId, null)`. Los totales por supermercado, el total general y el presupuesto se actualizan solos.

- [ ] **Paso 1: Test que falla:**
  - `discount button on a list row opens the dialog; saving a % sets tempPrice and updates line total, section total, grand total and remaining budget`. **(RF8)**
  - `editing an existing discount preloads both fields; Quitar removes it and restores the base price`.
  - `product without base price: discount via final price makes the row stop counting as (?)`.
  - `the table cell shows the discounted price and the discount button works there too`.
  - `swiping a row with discount and tapping Deshacer restores the discount`.
  - `striking an item with discount does not change totals`.
- [ ] **Paso 2:** `flutter test test/shopping_list_screen_test.dart` → FALLA en los tests nuevos.
- [ ] **Paso 3:** Implementar.
- [ ] **Paso 4:** `flutter test` completo → verde; `flutter analyze` → sin issues.
- [ ] **Paso 5:** Verificación manual en dispositivo y en tema oscuro: añadir, modificar y quitar descuento en ambas vistas; ver cómo cambian los totales y el restante del presupuesto; cerrar la app desde recientes y reabrir → persiste; pantalla pequeña (nombre largo + dos botones en la celda).
- [ ] **Paso 6:** Commit: `feat: edit discount from the shopping list and table views`

---

### Tarea 16: Release v1.0.2

**Archivos:**
- Modificar: `pubspec.yaml` (versión `1.0.2+3`)

**Interfaces:**
- Consume: app completa con las Tareas 12–15.
- Produce: `build/app/outputs/flutter-apk/app-release.apk` firmado con el mismo keystore que 1.0.1, y un release `v1.0.2` en GitHub con `ListaMercado.apk`.

- [ ] **Paso 1:** En `feature/discount-1.0.2`, subir la versión a `1.0.2+3` en `pubspec.yaml`.
- [ ] **Paso 2:** `dart format .`, `flutter analyze` y `flutter test` → todo en verde.
- [ ] **Paso 3:** Commit: `chore: bump version to 1.0.2`. Fusionar la función en `develop` (`--no-ff`) y borrar la rama temporal, según "Flujo de ramas".
- [ ] **Paso 4:** Fusionar `develop` en `main` (`--no-ff`) y crear el tag `v1.0.2`, según "Flujo de ramas".
- [ ] **Paso 5:** Desde `main`: `flutter build apk --release` (mismo keystore, para conservar los datos al actualizar).
- [ ] **Paso 6:** Verificar que no hay permiso `INTERNET` (`aapt dump permissions`) y la firma (`apksigner verify --print-certs`).
- [ ] **Paso 7:** `adb install -r build/app/outputs/flutter-apk/app-release.apk` sobre la 1.0.1 y comprobar que los datos antiguos se conservan y que la lista existente abre sin descuentos; recorrer la lista de humo con descuentos (añadir con %, con precio final, editar y quitar desde la lista y la tabla, verificar totales y presupuesto, cerrar y reabrir).
- [ ] **Paso 8:** Copiar el APK como `ListaMercado.apk` (sin commitearlo), crear el release `v1.0.2` en GitHub adjuntándolo y volver a `develop` (`git checkout develop && git merge main`).

---

## Convenciones de trabajo

- Ramas: `main` (solo releases con tag) y `develop` (integración); cada función en su rama `feature/<nombre>` desde `develop` (ver "Flujo de ramas (git)").
- Un commit por tarea (mensajes en inglés, estilo `feat:`/`chore:`/`fix:`).
- `dart format .` y `flutter analyze` limpios antes de cada commit.
- Los widgets leen estado con `context.watch<T>()` y ejecutan acciones con `context.read<T>()`.
- No añadir dependencias ni funciones fuera del MVP sin actualizar este archivo primero.

## Autorrevisión del plan

- **Cobertura del spec:** P1 (Tarea 8), P2 (Tarea 7), P3 (Tarea 9); buscar con filtro (3 y 8); añadir a lista con cantidad y confirmación al sumar sobre un producto existente (5 y 8); modificar cantidad (9); tachar uno/supermercado/todos, reversibles y sincronizados (5 y 9); limpiar con confirmación (9); quitar un solo producto con deslizar y deshacer (5 y 9); atajo de edición (9); totales con `+ (?)` y columna Otros (6 y 9); total general y presupuesto con restante verde/rojo (11); persistencia (2, 4, 5, 10, 11); APK sin Play Store (10).
- **Cobertura v1.0.2:** campos complementarios % / precio final y su validación (12 y 14); precio temporal por ítem y persistencia (12 y 13); añadir con descuento y reemplazo al sumar (14); modificar o quitar desde la lista y la tabla (15); totales y presupuesto con precio efectivo (12 y 15); release (16).
- **Brecha anterior resuelta:** ya existe una función para quitar un solo producto de la lista (deslizar la fila en P3, Tarea 9, apoyada en `ShoppingListProvider.removeProduct` y `restoreItem` de la Tarea 5).
- **Brecha conocida:** la pestaña "Por supermercado" no tiene gesto de quitar (las celdas ya llevan nombre, cantidad × precio y botones de edición y descuento); para quitar un producto hay que hacerlo desde la pestaña "Lista". Si se quiere, añadir una opción "Quitar de la lista" en un menú de la celda reutilizando `removeProduct`.
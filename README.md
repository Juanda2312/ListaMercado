# Lista Mercado

App Android 100% local para organizar las compras del mercado: gestiona productos y supermercados, y arma una lista de compras con totales por supermercado. No usa internet ni cuentas; todo se guarda en el teléfono.

## Funciones

- **Productos:** nombre (obligatorio), supermercado y precio (opcionales). Añadir, editar, eliminar, buscar (sin distinguir mayúsculas ni tildes) y filtrar por supermercado.
- **Supermercados:** solo el nombre, sin repetidos. Al eliminar uno, sus productos pasan a "Otros".
- **Lista de mercado:**
  - Vista **Lista** (cantidad, precio unitario y total por producto) y vista **Por supermercado** (una columna por supermercado y una columna **Otros**).
  - Tachar y destachar un producto, los de un supermercado o todos; el tachado se sincroniza entre ambas vistas y no cambia los totales.
  - Cambiar cantidades, limpiar la lista y quitar un producto deslizando la fila (con opción de deshacer).
  - Si un supermercado tiene productos sin precio, su total se muestra como `$X + (?)`.
  - Añadir un producto que ya está en la lista pide confirmación antes de sumar la cantidad.
  - **Total y presupuesto (v1.0.1):** la barra superior muestra el total general de la lista (`$X + (?)` si hay productos sin precio). Con el icono de cartera se fija un presupuesto opcional y la barra muestra el restante (presupuesto − total), como `$RESTANTE - (?)` si hay productos sin precio. El restante se ve en verde si es positivo o cero y en rojo si es negativo. El presupuesto se conserva al limpiar la lista y se puede cambiar o quitar cuando se quiera.

## Descargar e instalar

El APK firmado está en la sección [Releases](../../releases) de este repositorio. Descarga `ListaMercado.apk` desde *Assets*, ábrelo en el teléfono y, si Android lo pide, permite instalar apps de esa fuente. Si aparece un aviso de Play Protect, toca **Instalar de todos modos**.

Cada versión nueva se instala encima de la anterior y conserva los datos, siempre que esté firmada con el mismo keystore.

## Tecnología

- Flutter (Dart con null safety), solo Android.
- Estado con `provider`; persistencia con `shared_preferences` (JSON).
- Sin otras dependencias de producción.
- Dev dependency: `flutter_launcher_icons`, solo para generar el ícono (`dart run flutter_launcher_icons`). No entra en el APK.

## Estructura

```
lib/
├── main.dart, app.dart, app_providers.dart
├── models/      # Supermarket, Product, ShoppingItem
├── data/        # LocalStorage (shared_preferences)
├── providers/   # SupermarketsProvider, ProductsProvider, ShoppingListProvider (incluye el presupuesto)
├── logic/       # búsqueda, agrupación y totales (funciones puras)
├── utils/       # parseo/formato de precios, normalización de texto
├── screens/     # Productos, formulario, Supermercados, Lista
└── widgets/     # diálogo de confirmación, selector de cantidad, vistas de lista y tabla
assets/icon/     # imágenes fuente del ícono de la app
test/            # espejo de lib/
```

El detalle del diseño y del plan de implementación está en [`CLAUDE.md`](CLAUDE.md).

## Desarrollo

```bash
flutter pub get
flutter run          # con un dispositivo o emulador Android conectado
flutter analyze
flutter test
```

## Generar el APK release

Antes de compilar una versión nueva, sube el número en `pubspec.yaml` (por ejemplo `1.0.1+2`). El número tras el `+` debe ser siempre mayor que el anterior, o Android rechazará la actualización.

El APK se firma con un keystore propio que **no** está en el repositorio.

1. Crea el keystore una sola vez (fuera del repo):

   ```bash
   keytool -genkey -v -keystore ~/lista-mercado.jks -keyalg RSA -keysize 2048 -validity 10000 -alias lista
   ```

2. Crea `android/key.properties` (está en `.gitignore`):

   ```properties
   storePassword=TU_CONTRASEÑA
   keyPassword=TU_CONTRASEÑA
   keyAlias=lista
   storeFile=C:/Users/TU_USUARIO/lista-mercado.jks
   ```

   Usa `/` en la ruta, también en Windows.

3. Compila:

   ```bash
   flutter build apk --release
   ```

   El resultado queda en `build/app/outputs/flutter-apk/app-release.apk`.

4. Instala en un teléfono con depuración USB:

   ```bash
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

   Si ya hay una versión instalada con otra firma (por ejemplo, una debug), desinstálala antes con `adb uninstall com.listamercado.lista_mercado`.

5. Para publicar, copia el APK como `ListaMercado.apk` y adjúntalo a un nuevo [release](../../releases/new) con una etiqueta como `v1.0.1`.

> Guarda una copia del `.jks` y de su contraseña en un lugar seguro. Si se pierden, no se podrá actualizar la app instalada sin desinstalarla (y se borran sus datos locales).

El APK release no declara el permiso `INTERNET`. Se puede comprobar con `aapt dump permissions` y la firma con `apksigner verify --print-certs`, ambos en `<Android SDK>/build-tools/<versión>/`.

## Convenciones

- Textos visibles en español; identificadores de código en inglés.
- Un commit por tarea, con mensajes estilo `feat:` / `fix:` / `chore:`.
- `dart format .` y `flutter analyze` limpios antes de cada commit.
- No añadir dependencias ni funciones fuera del MVP sin actualizar `CLAUDE.md` primero.
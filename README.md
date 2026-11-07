# Lista Mercado

App de Android para armar la lista del mercado y saber cuánto vas a gastar en cada supermercado antes de salir de casa. Funciona sin internet y no te pide cuenta.

<!-- Capturas: lista, por supermercado, presupuesto, tema oscuro -->

## Cómo se usa

### La primera vez

1. **Crea tus supermercados.** En la pestaña *Supermercados*, añade los que uses.
2. **Crea tus productos.** En *Productos*, añade cada uno con su nombre. El supermercado y el precio los pones si quieres.
3. **Arma la lista.** Cuando vayas a hacer mercado, toca el carrito de cada producto y mándalo a la lista con su cantidad (y un descuento, si lo hay). Si quieres controlar el gasto, fija un presupuesto con el icono de cartera en la pestaña *Lista*.
4. **En el mercado,** ve tachando lo que compras. La lista se puede ver normal o *Por supermercado*, con una columna por tienda y su total.
5. **Al terminar,** tienes dos caminos. Con *Limpiar lista* empiezas de cero la próxima vez. Si tus compras se repiten, usa *Tachar/Destachar todos* para dejar todo sin tachar y quita deslizando solo lo que esta vez no necesites.

### Las siguientes veces

Tus productos y supermercados ya están, así que casi todo se reduce a los pasos 3, 4 y 5. Entra a *Productos*, añade a la lista lo que necesites, y si la lista anterior se parece a la de hoy, reutilízala destachándola. El presupuesto se conserva al limpiar la lista, no tienes que ponerlo cada vez.

¿Encontraste algo que no está en tu catálogo? Créalo desde *Productos* en cualquier momento y añádelo a la lista.

## Lo que trae

- **Presupuesto.** Es opcional. La app te dice cuánto te queda: en verde mientras alcanza, en rojo cuando te pasas.
- **Descuentos.** Escribes el porcentaje o el precio final y la app calcula el otro. Solo vale para esa lista, el precio del producto no cambia.
- **Productos sin precio.** El total te lo avisa con `$X + (?)` en vez de contarlos como gratis.
- **Tachar no resta.** Lo tachado sigue sumando en el total. Sirve para marcar lo que ya compraste, nada más.
- **Quitar un producto.** Desliza la fila. Si te equivocas, aparece el botón de deshacer.
- **Tema claro u oscuro**, según lo que tenga tu teléfono.

## Tus datos

Todo se guarda en tu teléfono. La app ni siquiera tiene permiso para conectarse a internet.

## Instalar

Es solo para Android y no está en Google Play, así que se instala con el archivo APK.

1. Entra a [Releases](../../releases) y descarga `ListaMercado.apk`.
2. Ábrelo. Si Android lo pide, permite instalar apps de esa fuente.
3. Si sale un aviso de Play Protect, toca *Instalar de todos modos*.

Ese aviso aparece porque la app no viene de la tienda, no porque tenga algo raro.

Para actualizar, descarga el APK nuevo e instálalo encima: no pierdes nada. Si desinstalas la app, sí se borran tus datos, porque solo existen en tu teléfono.

## Novedades

- **1.0.3:** modo oscuro, tarjetas que se adaptan a la pantalla y barra de progreso del presupuesto.
- **1.0.2:** descuentos por porcentaje o por precio final.
- **1.0.1:** total general y presupuesto con restante.

## ¿Algo falla o te falta algo?

Cuéntame en [Issues](../../issues).

<sub>Si eres desarrollador, los detalles técnicos están en [`CLAUDE.md`](CLAUDE.md).</sub>
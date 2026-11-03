import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/app_providers.dart';
import 'package:lista_mercado/data/local_storage.dart';
import 'package:lista_mercado/providers/products_provider.dart';
import 'package:lista_mercado/providers/shopping_list_provider.dart';
import 'package:lista_mercado/providers/supermarkets_provider.dart';
import 'package:lista_mercado/screens/product_form_screen.dart';
import 'package:lista_mercado/screens/shopping_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Datos de prueba (cantidad × precio):
/// Ara:   Leche 2×1000, Pan 1×500          -> $2.500
/// Éxito: Café 1×sin precio, Arroz 1×2000  -> $2.000 + (?)
/// Otros: Sal 1×200                        -> $200
Future<AppProviders> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final app = AppProviders.create(LocalStorage(prefs));

  await app.supermarkets.add('Ara');
  await app.supermarkets.add('Éxito');
  final ara = app.supermarkets.supermarkets.firstWhere((s) => s.name == 'Ara');
  final exito = app.supermarkets.supermarkets.firstWhere(
    (s) => s.name == 'Éxito',
  );

  final leche = await app.products.add(
    name: 'Leche',
    supermarketId: ara.id,
    price: 1000,
  );
  final pan = await app.products.add(
    name: 'Pan',
    supermarketId: ara.id,
    price: 500,
  );
  final cafe = await app.products.add(name: 'Café', supermarketId: exito.id);
  final arroz = await app.products.add(
    name: 'Arroz',
    supermarketId: exito.id,
    price: 2000,
  );
  final sal = await app.products.add(name: 'Sal', price: 200);

  await app.shoppingList.addProduct(leche.id, 2);
  await app.shoppingList.addProduct(pan.id, 1);
  await app.shoppingList.addProduct(cafe.id, 1);
  await app.shoppingList.addProduct(arroz.id, 1);
  await app.shoppingList.addProduct(sal.id, 1);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SupermarketsProvider>.value(
          value: app.supermarkets,
        ),
        ChangeNotifierProvider<ProductsProvider>.value(value: app.products),
        ChangeNotifierProvider<ShoppingListProvider>.value(
          value: app.shoppingList,
        ),
      ],
      child: const MaterialApp(home: ShoppingListScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

String _id(AppProviders app, String name) =>
    app.products.products.firstWhere((p) => p.name == name).id;

bool _checked(AppProviders app, String name) => app.shoppingList.items
    .firstWhere((i) => i.productId == _id(app, name))
    .checked;

TextDecoration? _decoration(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).style?.decoration;

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

Future<void> _goToTable(WidgetTester tester) async {
  await tester.tap(find.text('Por supermercado'));
  await tester.pumpAndSettle();
}

Future<void> _goToList(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(Tab, 'Lista'));
  await tester.pumpAndSettle();
}

Future<void> _openListMenu(WidgetTester tester, String item) async {
  await tester.tap(find.byKey(const Key('list-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(item));
  await tester.pumpAndSettle();
}

Future<void> _swipe(WidgetTester tester, String productId) async {
  await tester.drag(
    find.byKey(Key('dismiss-$productId')),
    const Offset(-500, 0),
  );
  await tester.pumpAndSettle();
}

final _confirm = find.widgetWithText(FilledButton, 'Confirmar');

void main() {
  group('descuento desde la lista', () {
    final percentField = find.byKey(const Key('discount-percent'));
    final priceField = find.byKey(const Key('discount-price'));
    final save = find.widgetWithText(FilledButton, 'Guardar');

    Future<void> openFromList(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(Key('edit-discount-$id')));
      await tester.pumpAndSettle();
    }

    Future<void> openFromTable(WidgetTester tester, String id) async {
      await tester.tap(find.byKey(Key('discount-cell-$id')));
      await tester.pumpAndSettle();
    }

    testWidgets('saving a % updates line, section, grand total and remaining '
        'budget', (tester) async {
      final app = await _pump(tester);
      final id = _id(app, 'Leche');
      await app.shoppingList.setBudget(5000);
      await tester.pumpAndSettle();

      await openFromList(tester, id);
      await tester.enterText(percentField, '10');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(
        app.shoppingList.items.firstWhere((i) => i.productId == id).tempPrice,
        900,
      );
      expect(_text(tester, Key('row-total-$id')), '\$1.800');
      expect(find.textContaining('-10%', findRichText: true), findsOneWidget);
      expect(_text(tester, const Key('list-total')), 'Total: \$4.500 + (?)');
      expect(
        find.textContaining('\$500 - (?)', findRichText: true),
        findsOneWidget,
      );
      await _goToTable(tester);
      expect(_text(tester, const Key('section-total-Ara')), '\$2.300');
    });

    testWidgets(
      'editing preloads both fields; Quitar restores the base price',
      (tester) async {
        final app = await _pump(tester);
        final id = _id(app, 'Leche');
        await app.shoppingList.setTempPrice(id, 900);
        await tester.pumpAndSettle();

        await openFromList(tester, id);
        expect(tester.widget<TextField>(priceField).controller!.text, '900');
        expect(tester.widget<TextField>(percentField).controller!.text, '10');

        await tester.tap(find.text('Quitar'));
        await tester.pumpAndSettle();

        expect(
          app.shoppingList.items.firstWhere((i) => i.productId == id).tempPrice,
          isNull,
        );
        expect(_text(tester, Key('row-total-$id')), '\$2.000');
      },
    );

    testWidgets('Quitar is hidden without a discount and Guardar is disabled '
        'while empty or invalid', (tester) async {
      final app = await _pump(tester);
      await openFromList(tester, _id(app, 'Leche'));

      expect(find.text('Quitar'), findsNothing);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.enterText(percentField, '100');
      await tester.pump();
      expect(find.text('Descuento inválido'), findsOneWidget);
      expect(tester.widget<FilledButton>(save).onPressed, isNull);

      await tester.enterText(percentField, '20');
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
    });

    testWidgets('product without base price: a final price stops counting it '
        'as (?)', (tester) async {
      final app = await _pump(tester);
      final id = _id(app, 'Café');

      await openFromList(tester, id);
      expect(tester.widget<TextField>(percentField).enabled, isFalse);
      await tester.enterText(priceField, '1500');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(_text(tester, Key('row-total-$id')), '\$1.500');
      expect(_text(tester, const Key('list-total')), 'Total: \$6.200');
      await _goToTable(tester);
      expect(_text(tester, const Key('section-total-Éxito')), '\$3.500');
    });

    testWidgets('the table cell shows the discounted price and its button '
        'works', (tester) async {
      final app = await _pump(tester);
      final id = _id(app, 'Leche');
      await app.shoppingList.setTempPrice(id, 900);
      await _goToTable(tester);
      expect(find.text('2 × \$900 (-10%)'), findsOneWidget);

      await openFromTable(tester, id);
      await tester.enterText(percentField, '20');
      await tester.pump();
      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(find.text('2 × \$800 (-20%)'), findsOneWidget);
      expect(_text(tester, const Key('section-total-Ara')), '\$2.100');
    });

    testWidgets('swiping a row with discount and tapping Deshacer restores '
        'the discount', (tester) async {
      final app = await _pump(tester);
      final id = _id(app, 'Leche');
      await app.shoppingList.setTempPrice(id, 900);
      await tester.pumpAndSettle();

      await _swipe(tester, id);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();

      expect(
        app.shoppingList.items.firstWhere((i) => i.productId == id).tempPrice,
        900,
      );
      expect(_text(tester, Key('row-total-$id')), '\$1.800');
    });

    testWidgets('striking an item with discount does not change totals', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _id(app, 'Leche');
      await app.shoppingList.setTempPrice(id, 900);
      await tester.pumpAndSettle();
      expect(_text(tester, const Key('list-total')), 'Total: \$4.500 + (?)');

      await tester.tap(find.byKey(Key('row-name-$id')));
      await tester.pumpAndSettle();

      expect(_checked(app, 'Leche'), isTrue);
      expect(_text(tester, const Key('list-total')), 'Total: \$4.500 + (?)');
      await _goToTable(tester);
      expect(_text(tester, const Key('section-total-Ara')), '\$2.300');
    });
  });
  group('tachado', () {
    testWidgets(
      'tapping a row strikes the name in both views; again unstrikes',
      (tester) async {
        final app = await _pump(tester);
        final id = _id(app, 'Leche');

        await tester.tap(find.byKey(Key('row-name-$id')));
        await tester.pumpAndSettle();
        expect(
          _decoration(tester, Key('row-name-$id')),
          TextDecoration.lineThrough,
        );
        await _goToTable(tester);
        expect(
          _decoration(tester, Key('cell-name-$id')),
          TextDecoration.lineThrough,
        );

        await _goToList(tester);
        await tester.tap(find.byKey(Key('row-name-$id')));
        await tester.pumpAndSettle();
        expect(_decoration(tester, Key('row-name-$id')), TextDecoration.none);
        await _goToTable(tester);
        expect(_decoration(tester, Key('cell-name-$id')), TextDecoration.none);
      },
    );

    testWidgets('tapping a table cell strikes it in the list view too', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _id(app, 'Pan');

      await _goToTable(tester);
      await tester.tap(find.byKey(Key('cell-name-$id')));
      await tester.pumpAndSettle();
      expect(
        _decoration(tester, Key('cell-name-$id')),
        TextDecoration.lineThrough,
      );

      await _goToList(tester);
      expect(
        _decoration(tester, Key('row-name-$id')),
        TextDecoration.lineThrough,
      );
    });

    testWidgets('striking an item does not change the section total', (
      tester,
    ) async {
      final app = await _pump(tester);
      await _goToTable(tester);
      expect(_text(tester, const Key('section-total-Ara')), '\$2.500');

      await tester.tap(find.byKey(Key('cell-name-${_id(app, 'Leche')}')));
      await tester.pumpAndSettle();

      expect(_checked(app, 'Leche'), isTrue);
      expect(_text(tester, const Key('section-total-Ara')), '\$2.500');
    });
  });

  group('tabla', () {
    testWidgets("section with an unpriced product shows '+ (?)' in its total", (
      tester,
    ) async {
      await _pump(tester);
      await _goToTable(tester);
      expect(_text(tester, const Key('section-total-Éxito')), '\$2.000 + (?)');
      expect(_text(tester, const Key('section-total-Ara')), '\$2.500');
    });

    Size cardSize(WidgetTester tester) => tester.getSize(
      find
          .ancestor(
            of: find.byKey(const Key('section-total-Ara')),
            matching: find.byType(Card),
          )
          .first,
    );

    testWidgets('column width is 280 on a wide screen and 80 % of it on a '
        'narrow one', (tester) async {
      await _pump(tester); // 800 px
      await _goToTable(tester);
      expect(cardSize(tester).width, 280);

      tester.view.physicalSize = const Size(360, 640);
      await tester.pumpAndSettle();
      expect(cardSize(tester).width, 288);
    });

    testWidgets('section header shows the product count', (tester) async {
      await _pump(tester);
      await _goToTable(tester);
      expect(find.text('2 productos'), findsNWidgets(2)); // Ara y Éxito
      expect(find.text('1 producto'), findsOneWidget); // Otros
    });

    testWidgets('long product name does not overflow at 360×640 and 150 % '
        'text', (tester) async {
      final app = await _pump(tester);
      tester.view.physicalSize = const Size(360, 640);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final p = await app.products.add(
        name: 'Queso campesino semidescremado extra largo ' * 3,
        price: 12500,
      );
      await app.shoppingList.addProduct(p.id, 3, tempPrice: 9000);
      await tester.pumpAndSettle();
      await _goToTable(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets("unassigned products appear in the 'Otros' column", (
      tester,
    ) async {
      final app = await _pump(tester);
      await _goToTable(tester);
      expect(find.text('Otros'), findsOneWidget);
      expect(find.byKey(Key('cell-name-${_id(app, 'Sal')}')), findsOneWidget);
      expect(_text(tester, const Key('section-total-Otros')), '\$200');
    });
  });

  group('cantidades', () {
    testWidgets("quantity '+' updates line total and section total", (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _id(app, 'Leche');
      expect(_text(tester, Key('row-total-$id')), '\$2.000');

      await tester.tap(
        find.descendant(
          of: find.byKey(Key('list-row-$id')),
          matching: find.byTooltip('Aumentar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(app.shoppingList.quantityOf(id), 3);
      expect(_text(tester, Key('row-total-$id')), '\$3.000');
      await _goToTable(tester);
      expect(_text(tester, const Key('section-total-Ara')), '\$3.500');
    });

    testWidgets("quantity '−' is disabled at 1", (tester) async {
      final app = await _pump(tester);
      final id = _id(app, 'Pan');
      final minus = find.descendant(
        of: find.byKey(Key('list-row-$id')),
        matching: find.widgetWithIcon(IconButton, Icons.remove),
      );
      expect(tester.widget<IconButton>(minus).onPressed, isNull);
    });
  });

  group('acciones masivas', () {
    testWidgets(
      'strike-all for one supermarket: cancel changes nothing; confirm '
      'strikes only that supermarket; repeating unstrikes',
      (tester) async {
        final app = await _pump(tester);
        await _goToTable(tester);

        Future<void> openSectionAction() async {
          await tester.tap(find.byKey(const Key('section-menu-Ara')));
          await tester.pumpAndSettle();
          await tester.tap(
            find.text('Tachar/Destachar todos de este supermercado'),
          );
          await tester.pumpAndSettle();
        }

        await openSectionAction();
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(app.shoppingList.items.any((i) => i.checked), isFalse);

        await openSectionAction();
        await tester.tap(_confirm);
        await tester.pumpAndSettle();
        expect(_checked(app, 'Leche'), isTrue);
        expect(_checked(app, 'Pan'), isTrue);
        expect(_checked(app, 'Café'), isFalse);
        expect(_checked(app, 'Arroz'), isFalse);
        expect(_checked(app, 'Sal'), isFalse);

        await openSectionAction();
        await tester.tap(_confirm);
        await tester.pumpAndSettle();
        expect(app.shoppingList.items.any((i) => i.checked), isFalse);
      },
    );

    testWidgets('strike-all asks confirmation and toggles every item', (
      tester,
    ) async {
      final app = await _pump(tester);

      await _openListMenu(tester, 'Tachar/Destachar todos');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(app.shoppingList.items.any((i) => i.checked), isFalse);

      await _openListMenu(tester, 'Tachar/Destachar todos');
      await tester.tap(_confirm);
      await tester.pumpAndSettle();
      expect(app.shoppingList.items.every((i) => i.checked), isTrue);

      await _openListMenu(tester, 'Tachar/Destachar todos');
      await tester.tap(_confirm);
      await tester.pumpAndSettle();
      expect(app.shoppingList.items.any((i) => i.checked), isFalse);
    });

    testWidgets("clear list: cancel keeps items, confirm empties and shows "
        "'La lista está vacía'", (tester) async {
      final app = await _pump(tester);

      await _openListMenu(tester, 'Limpiar lista');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(app.shoppingList.items.length, 5);

      await _openListMenu(tester, 'Limpiar lista');
      await tester.tap(find.widgetWithText(FilledButton, 'Limpiar'));
      await tester.pumpAndSettle();
      expect(app.shoppingList.items, isEmpty);
      expect(find.text('La lista está vacía'), findsOneWidget);
      // Los productos siguen en el catálogo.
      expect(app.products.products.length, 5);
    });
  });

  group('atajo de edición', () {
    testWidgets('edit button opens the product form preloaded', (tester) async {
      final app = await _pump(tester);
      await tester.tap(find.byKey(Key('edit-product-${_id(app, 'Leche')}')));
      await tester.pumpAndSettle();

      expect(find.byType(ProductFormScreen), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Leche'), findsOneWidget);
    });

    testWidgets('table cell edit button opens the form too', (tester) async {
      final app = await _pump(tester);
      await _goToTable(tester);
      await tester.tap(find.byKey(Key('edit-cell-${_id(app, 'Pan')}')));
      await tester.pumpAndSettle();

      expect(find.byType(ProductFormScreen), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Pan'), findsOneWidget);
    });
  });

  group('total y presupuesto', () {
    Color? colorOf(WidgetTester tester) {
      final t = tester.widget<Text>(find.byKey(const Key('list-budget')));
      return (t.textSpan! as TextSpan).children!.last.style!.color;
    }

    LinearProgressIndicator bar(WidgetTester tester) =>
        tester.widget<LinearProgressIndicator>(
          find.byKey(const Key('budget-progress')),
        );

    Future<void> setBudget(WidgetTester tester, String value) async {
      await tester.tap(find.byKey(const Key('budget-button')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('budget-input')), value);
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
    }

    testWidgets('summary shows the grand total with (?)', (tester) async {
      await _pump(tester);
      expect(_text(tester, const Key('list-total')), 'Total: \$4.700 + (?)');
      expect(find.byKey(const Key('list-budget')), findsNothing);
      expect(find.byKey(const Key('budget-progress')), findsNothing);
    });

    testWidgets('progress bar value is total / budget', (tester) async {
      await _pump(tester);
      await setBudget(tester, '10000');
      expect(bar(tester).value, 0.47);
    });

    testWidgets('progress bar is capped at 1 and turns red when over budget', (
      tester,
    ) async {
      await _pump(tester);
      await setBudget(tester, '4000');
      expect(bar(tester).value, 1.0);
      expect(bar(tester).color, Colors.red.shade700);
    });

    testWidgets('progress bar is green while within budget', (tester) async {
      await _pump(tester);
      await setBudget(tester, '5000');
      expect(bar(tester).color, Colors.green.shade700);
    });

    testWidgets('empty list still shows the summary with \$0 and the empty '
        'message', (tester) async {
      final app = await _pump(tester);
      await app.shoppingList.clear();
      await tester.pumpAndSettle();
      expect(_text(tester, const Key('list-total')), 'Total: \$0');
      expect(find.text('La lista está vacía'), findsOneWidget);
    });

    testWidgets('budget above total shows green remaining', (tester) async {
      await _pump(tester);
      await setBudget(tester, '5.000');
      expect(
        find.textContaining('\$300 - (?)', findRichText: true),
        findsOneWidget,
      );
      expect(colorOf(tester), Colors.green.shade700);
    });

    testWidgets('budget below total shows red negative remaining', (
      tester,
    ) async {
      await _pump(tester);
      await setBudget(tester, '4000');
      expect(
        find.textContaining('-\$700 - (?)', findRichText: true),
        findsOneWidget,
      );
      expect(colorOf(tester), Colors.red.shade700);
    });

    testWidgets('invalid budget keeps dialog open; Quitar removes it', (
      tester,
    ) async {
      final app = await _pump(tester);
      await setBudget(tester, 'abc');
      expect(find.text('Precio inválido'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('budget-input')), '5000');
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await tester.pumpAndSettle();
      expect(app.shoppingList.budget, 5000);

      await tester.tap(find.byKey(const Key('budget-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar'));
      await tester.pumpAndSettle();
      expect(app.shoppingList.budget, isNull);
      expect(find.byKey(const Key('list-budget')), findsNothing);
    });
  });

  group('quitar un solo producto (deslizar)', () {
    testWidgets(
      'swiping a row removes only that product from list view and table view',
      (tester) async {
        final app = await _pump(tester);
        final id = _id(app, 'Leche');

        await _swipe(tester, id);

        expect(find.byKey(Key('row-name-$id')), findsNothing);
        expect(find.byKey(Key('row-name-${_id(app, 'Pan')}')), findsOneWidget);
        expect(app.shoppingList.items.length, 4);

        await _goToTable(tester);
        expect(find.byKey(Key('cell-name-$id')), findsNothing);
        expect(find.byKey(Key('cell-name-${_id(app, 'Pan')}')), findsOneWidget);
      },
    );

    testWidgets('swiping a row does not delete the product from the catalog', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _id(app, 'Leche');
      await _swipe(tester, id);

      expect(app.products.byId(id), isNotNull);
      expect(app.products.products.length, 5);
    });

    testWidgets(
      'removing a product updates the section total and drops the section '
      'if it becomes empty',
      (tester) async {
        final app = await _pump(tester);

        await _swipe(tester, _id(app, 'Leche'));
        await _goToTable(tester);
        expect(_text(tester, const Key('section-total-Ara')), '\$500');

        await _goToList(tester);
        await _swipe(tester, _id(app, 'Pan'));
        await _goToTable(tester);
        expect(find.byKey(const Key('section-total-Ara')), findsNothing);
        expect(find.byKey(const Key('section-total-Éxito')), findsOneWidget);
      },
    );

    testWidgets("removing the last item shows 'La lista está vacía'", (
      tester,
    ) async {
      final app = await _pump(tester);
      for (final name in ['Pan', 'Café', 'Arroz', 'Sal']) {
        await app.shoppingList.removeProduct(_id(app, name));
      }
      await tester.pumpAndSettle();

      await _swipe(tester, _id(app, 'Leche'));

      expect(find.text('La lista está vacía'), findsOneWidget);
      expect(app.shoppingList.items, isEmpty);
    });

    testWidgets(
      "swipe shows a SnackBar with 'Deshacer'; tapping it restores the item "
      'with its original quantity',
      (tester) async {
        final app = await _pump(tester);
        final id = _id(app, 'Leche');

        await _swipe(tester, id);
        expect(find.text('«Leche» quitado de la lista'), findsOneWidget);
        expect(app.shoppingList.contains(id), isFalse);

        await tester.tap(find.text('Deshacer'));
        await tester.pumpAndSettle();

        expect(app.shoppingList.quantityOf(id), 2);
        expect(find.byKey(Key('row-name-$id')), findsOneWidget);
        expect(app.shoppingList.items.length, 5);
      },
    );

    testWidgets('swiping a checked item then undoing keeps it checked', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _id(app, 'Leche');
      await app.shoppingList.toggleChecked(id);
      await tester.pumpAndSettle();

      await _swipe(tester, id);
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();

      expect(_checked(app, 'Leche'), isTrue);
      expect(
        _decoration(tester, Key('row-name-$id')),
        TextDecoration.lineThrough,
      );
    });

    testWidgets('undo does not duplicate if the product was added again', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _id(app, 'Leche');

      await _swipe(tester, id);
      await app.shoppingList.addProduct(id, 1);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();

      expect(app.shoppingList.items.where((i) => i.productId == id).length, 1);
      expect(app.shoppingList.quantityOf(id), 1);
    });
  });
}

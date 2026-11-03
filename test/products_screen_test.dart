import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/app_providers.dart';
import 'package:lista_mercado/data/local_storage.dart';
import 'package:lista_mercado/providers/products_provider.dart';
import 'package:lista_mercado/providers/shopping_list_provider.dart';
import 'package:lista_mercado/providers/supermarkets_provider.dart';
import 'package:lista_mercado/screens/product_form_screen.dart';
import 'package:lista_mercado/screens/products_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppProviders> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final app = AppProviders.create(LocalStorage(prefs));

  await app.supermarkets.add('Ara');
  await app.supermarkets.add('Éxito');
  final ara = app.supermarkets.supermarkets.firstWhere((s) => s.name == 'Ara');
  final exito = app.supermarkets.supermarkets.firstWhere(
    (s) => s.name == 'Éxito',
  );
  await app.products.add(name: 'Leche', supermarketId: ara.id, price: 4000);
  await app.products.add(name: 'Café', supermarketId: exito.id);
  await app.products.add(name: 'Pan');

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
      child: const MaterialApp(home: ProductsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

String _idOf(AppProviders app, String name) =>
    app.products.products.firstWhere((p) => p.name == name).id;

Future<void> _openAddDialog(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('add-to-list-$id')));
  await tester.pumpAndSettle();
}

Future<void> _increase(WidgetTester tester, int times) async {
  for (var i = 0; i < times; i++) {
    await tester.tap(find.byTooltip('Aumentar'));
    await tester.pump();
  }
}

final _dialogAdd = find.widgetWithText(FilledButton, 'Añadir');

void main() {
  group('búsqueda y filtros', () {
    testWidgets("search 'cafe' shows 'Café' and hides others", (tester) async {
      await _pump(tester);
      expect(find.text('Leche'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('product-search')), 'cafe');
      await tester.pumpAndSettle();

      expect(find.text('Café'), findsOneWidget);
      expect(find.text('Leche'), findsNothing);
      expect(find.text('Pan'), findsNothing);
    });

    testWidgets('search without results shows an empty message', (
      tester,
    ) async {
      await _pump(tester);
      await tester.enterText(find.byKey(const Key('product-search')), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados'), findsOneWidget);
    });

    testWidgets("supermarket filter shows only that supermarket's products", (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('product-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ara').last);
      await tester.pumpAndSettle();

      expect(find.text('Leche'), findsOneWidget);
      expect(find.text('Café'), findsNothing);
      expect(find.text('Pan'), findsNothing);
    });

    testWidgets("'Sin supermercado' filter shows only unassigned products", (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('product-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin supermercado').last);
      await tester.pumpAndSettle();

      expect(find.text('Pan'), findsOneWidget);
      expect(find.text('Leche'), findsNothing);
      expect(find.text('Café'), findsNothing);
    });

    testWidgets('subtitle shows supermarket and price only when they exist', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Ara · \$4.000'), findsOneWidget);
    });
  });

  group('añadir a la lista', () {
    testWidgets('quantity 3 adds item with quantity 3 and no confirmation when '
        'the product is not in the list', (tester) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Leche');

      await _openAddDialog(tester, id);
      await _increase(tester, 2);
      await tester.tap(_dialogAdd);
      await tester.pumpAndSettle();

      expect(find.text('Producto ya en la lista'), findsNothing);
      expect(app.shoppingList.items.length, 1);
      expect(app.shoppingList.quantityOf(id), 3);
    });

    testWidgets('quantity dialog starts at 1 and minus is disabled at 1', (
      tester,
    ) async {
      final app = await _pump(tester);
      await _openAddDialog(tester, _idOf(app, 'Leche'));

      expect(find.text('1'), findsOneWidget);
      final minus = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove),
      );
      expect(minus.onPressed, isNull);

      await _increase(tester, 1);
      final minusAfter = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.remove),
      );
      expect(minusAfter.onPressed, isNotNull);
    });

    testWidgets(
      'adding a product already in the list asks to confirm and the message '
      'shows current quantity and resulting total',
      (tester) async {
        final app = await _pump(tester);
        final id = _idOf(app, 'Leche');
        await app.shoppingList.addProduct(id, 2);

        await _openAddDialog(tester, id);
        await _increase(tester, 2);
        await tester.tap(_dialogAdd);
        await tester.pumpAndSettle();

        expect(find.text('Producto ya en la lista'), findsOneWidget);
        expect(find.textContaining('cantidad 2'), findsOneWidget);
        expect(find.textContaining('total de 5'), findsOneWidget);
        // Todavía no se ha sumado nada.
        expect(app.shoppingList.quantityOf(id), 2);
      },
    );

    testWidgets('cancelling the sum confirmation keeps the existing quantity', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Leche');
      await app.shoppingList.addProduct(id, 2);

      await _openAddDialog(tester, id);
      await _increase(tester, 2);
      await tester.tap(_dialogAdd);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(app.shoppingList.quantityOf(id), 2);
      expect(app.shoppingList.items.length, 1);
    });

    testWidgets('confirming the sum updates the single list item', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Leche');
      await app.shoppingList.addProduct(id, 2);

      await _openAddDialog(tester, id);
      await _increase(tester, 2);
      await tester.tap(_dialogAdd);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Sumar'));
      await tester.pumpAndSettle();

      expect(app.shoppingList.items.length, 1);
      expect(app.shoppingList.quantityOf(id), 5);
    });

    testWidgets(
      'cancelling the quantity dialog does not ask for confirmation and '
      'changes nothing',
      (tester) async {
        final app = await _pump(tester);
        final id = _idOf(app, 'Leche');
        await app.shoppingList.addProduct(id, 2);

        await _openAddDialog(tester, id);
        await _increase(tester, 2);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(find.text('Producto ya en la lista'), findsNothing);
        expect(app.shoppingList.quantityOf(id), 2);
      },
    );
  });
  group('descuento al añadir', () {
    final percentField = find.byKey(const Key('discount-percent'));
    final priceField = find.byKey(const Key('discount-price'));

    testWidgets('percent discount stores the computed tempPrice', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Leche');

      await _openAddDialog(tester, id);
      await tester.enterText(percentField, '25');
      await tester.pump();
      expect(tester.widget<TextField>(priceField).controller!.text, '3000');
      await tester.tap(_dialogAdd);
      await tester.pumpAndSettle();

      expect(app.shoppingList.items.single.tempPrice, 3000);
    });

    testWidgets('final price discount stores the tempPrice', (tester) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Leche');

      await _openAddDialog(tester, id);
      await tester.enterText(priceField, '3600');
      await tester.pump();
      expect(tester.widget<TextField>(percentField).controller!.text, '10');
      await tester.tap(_dialogAdd);
      await tester.pumpAndSettle();

      expect(app.shoppingList.items.single.tempPrice, 3600);
    });

    testWidgets('leaving the discount empty stores no tempPrice', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Leche');

      await _openAddDialog(tester, id);
      await tester.tap(_dialogAdd);
      await tester.pumpAndSettle();

      expect(app.shoppingList.items.single.tempPrice, isNull);
    });

    testWidgets('an invalid discount disables Añadir', (tester) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Leche');

      await _openAddDialog(tester, id);
      await tester.enterText(percentField, '100');
      await tester.pump();

      expect(find.text('Descuento inválido'), findsOneWidget);
      expect(tester.widget<FilledButton>(_dialogAdd).onPressed, isNull);
      expect(app.shoppingList.items, isEmpty);

      await tester.enterText(percentField, '');
      await tester.pump();
      expect(tester.widget<FilledButton>(_dialogAdd).onPressed, isNotNull);
    });

    testWidgets('product without a base price only accepts a final price', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Pan');

      await _openAddDialog(tester, id);
      expect(tester.widget<TextField>(percentField).enabled, isFalse);
      await tester.enterText(priceField, '500');
      await tester.pump();
      await tester.tap(_dialogAdd);
      await tester.pumpAndSettle();

      expect(app.shoppingList.items.single.tempPrice, 500);
    });

    testWidgets('product already in the list: the confirmation mentions the '
        'new temporary price and replaces the old one', (tester) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Leche');
      await app.shoppingList.addProduct(id, 2, tempPrice: 3600);

      await _openAddDialog(tester, id);
      await _increase(tester, 1);
      await tester.enterText(percentField, '25');
      await tester.pump();
      await tester.tap(_dialogAdd);
      await tester.pumpAndSettle();

      expect(find.textContaining('precio temporal'), findsOneWidget);
      expect(find.textContaining('\$3.000'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sumar'));
      await tester.pumpAndSettle();

      expect(app.shoppingList.quantityOf(id), 4);
      expect(app.shoppingList.items.single.tempPrice, 3000);
    });

    testWidgets('product already in the list without a new discount keeps '
        'the existing one', (tester) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Leche');
      await app.shoppingList.addProduct(id, 2, tempPrice: 3600);

      await _openAddDialog(tester, id);
      await tester.tap(_dialogAdd);
      await tester.pumpAndSettle();

      expect(find.textContaining('precio temporal'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Sumar'));
      await tester.pumpAndSettle();

      expect(app.shoppingList.quantityOf(id), 3);
      expect(app.shoppingList.items.single.tempPrice, 3600);
    });
  });

  group('editar y eliminar', () {
    testWidgets('edit menu opens the form preloaded with that product', (
      tester,
    ) async {
      final app = await _pump(tester);
      final id = _idOf(app, 'Leche');

      await tester.tap(find.byKey(Key('product-menu-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();

      expect(find.byType(ProductFormScreen), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Leche'), findsOneWidget);
    });

    testWidgets(
      'delete confirmation cancel keeps product, confirm removes it and '
      'its list item',
      (tester) async {
        final app = await _pump(tester);
        final id = _idOf(app, 'Leche');
        await app.shoppingList.addProduct(id, 2);

        // Cancelar
        await tester.tap(find.byKey(Key('product-menu-$id')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();
        expect(find.textContaining('lista de mercado'), findsOneWidget);
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();

        expect(app.products.byId(id), isNotNull);
        expect(app.shoppingList.contains(id), isTrue);
        expect(find.text('Leche'), findsOneWidget);

        // Confirmar
        await tester.tap(find.byKey(Key('product-menu-$id')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Eliminar'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
        await tester.pumpAndSettle();

        expect(app.products.byId(id), isNull);
        expect(app.shoppingList.contains(id), isFalse);
        expect(find.text('Leche'), findsNothing);
      },
    );
  });
}

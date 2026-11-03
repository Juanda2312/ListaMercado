import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/app_providers.dart';
import 'package:lista_mercado/data/local_storage.dart';
import 'package:lista_mercado/providers/products_provider.dart';
import 'package:lista_mercado/providers/shopping_list_provider.dart';
import 'package:lista_mercado/providers/supermarkets_provider.dart';
import 'package:lista_mercado/screens/product_form_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Monta una pantalla "base" con un botón que abre el formulario, para que
/// `Navigator.pop` tenga una ruta a la cual volver.
Future<AppProviders> _openForm(
  WidgetTester tester, {
  Future<String?> Function(AppProviders app)? seed,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final app = AppProviders.create(LocalStorage(prefs));
  final productId = seed == null ? null : await seed(app);

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
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductFormScreen(productId: productId),
                ),
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
  return app;
}

final _name = find.byKey(const Key('product-name'));
final _price = find.byKey(const Key('product-price'));
final _save = find.byKey(const Key('product-save'));

void main() {
  testWidgets('blank or whitespace name shows error and does not save', (
    tester,
  ) async {
    final app = await _openForm(tester);

    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(app.products.products, isEmpty);

    await tester.enterText(_name, '    ');
    await tester.tap(_save);
    await tester.pumpAndSettle();
    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(app.products.products, isEmpty);
    expect(find.byType(ProductFormScreen), findsOneWidget);
  });

  testWidgets("price 'abc' shows 'Precio inválido'", (tester) async {
    final app = await _openForm(tester);

    await tester.enterText(_name, 'Leche');
    await tester.enterText(_price, 'abc');
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(find.text('Precio inválido'), findsOneWidget);
    expect(app.products.products, isEmpty);
  });

  testWidgets("price '0' and '-3' are rejected", (tester) async {
    final app = await _openForm(tester);

    await tester.enterText(_name, 'Leche');
    for (final bad in ['0', '-3']) {
      await tester.enterText(_price, bad);
      await tester.tap(_save);
      await tester.pumpAndSettle();
      expect(find.text('Precio inválido'), findsOneWidget);
    }
    expect(app.products.products, isEmpty);
  });

  testWidgets(
    'valid form with only a name saves a product without supermarket or price',
    (tester) async {
      final app = await _openForm(tester);

      await tester.enterText(_name, '  Leche ');
      await tester.tap(_save);
      await tester.pumpAndSettle();

      final p = app.products.products.single;
      expect(p.name, 'Leche');
      expect(p.supermarketId, isNull);
      expect(p.price, isNull);
      expect(find.byType(ProductFormScreen), findsNothing);
    },
  );

  testWidgets("price '12.500' is saved as 12500", (tester) async {
    final app = await _openForm(tester);

    await tester.enterText(_name, 'Queso');
    await tester.enterText(_price, '12.500');
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(app.products.products.single.price, 12500);
  });

  testWidgets('selecting a supermarket saves it', (tester) async {
    final app = await _openForm(
      tester,
      seed: (app) async {
        await app.supermarkets.add('Ara');
        return null;
      },
    );

    await tester.enterText(_name, 'Leche');
    await tester.tap(find.byKey(const Key('product-supermarket')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ara').last);
    await tester.pumpAndSettle();
    await tester.tap(_save);
    await tester.pumpAndSettle();

    expect(
      app.products.products.single.supermarketId,
      app.supermarkets.supermarkets.single.id,
    );
  });

  testWidgets('editing preloads existing values and saves changes', (
    tester,
  ) async {
    late String productId;
    final app = await _openForm(
      tester,
      seed: (a) async {
        await a.supermarkets.add('Ara');
        final p = await a.products.add(
          name: 'Leche',
          supermarketId: a.supermarkets.supermarkets.single.id,
          price: 12500.5,
        );
        productId = p.id;
        return p.id;
      },
    );

    expect(find.widgetWithText(TextFormField, 'Leche'), findsOneWidget);
    expect(tester.widget<TextFormField>(_price).controller!.text, '12500,5');
    expect(find.text('Ara'), findsWidgets);

    await tester.enterText(_name, 'Leche entera');
    await tester.tap(_save);
    await tester.pumpAndSettle();

    final p = app.products.byId(productId)!;
    expect(p.name, 'Leche entera');
    expect(p.price, 12500.5);
    expect(p.supermarketId, isNotNull);
    expect(app.products.products.length, 1);
  });

  testWidgets(
    'clearing the price while editing saves a product without price',
    (tester) async {
      late String productId;
      final app = await _openForm(
        tester,
        seed: (a) async {
          final p = await a.products.add(name: 'Leche', price: 1000);
          productId = p.id;
          return p.id;
        },
      );

      await tester.enterText(_price, '');
      await tester.tap(_save);
      await tester.pumpAndSettle();

      expect(app.products.byId(productId)!.price, isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/app_providers.dart';
import 'package:lista_mercado/data/local_storage.dart';
import 'package:lista_mercado/providers/products_provider.dart';
import 'package:lista_mercado/providers/shopping_list_provider.dart';
import 'package:lista_mercado/providers/supermarkets_provider.dart';
import 'package:lista_mercado/screens/supermarkets_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppProviders> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final app = AppProviders.create(LocalStorage(prefs));
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
      child: const MaterialApp(home: SupermarketsScreen()),
    ),
  );
  return app;
}

final _confirmAdd = find.widgetWithText(FilledButton, 'Añadir');

void main() {
  testWidgets('shows empty state when there are no supermarkets', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Aún no hay supermercados'), findsOneWidget);
  });

  testWidgets('shows added supermarket name', (tester) async {
    final app = await _pump(tester);

    await tester.tap(find.byKey(const Key('add-supermarket')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Éxito');
    await tester.tap(_confirmAdd);
    await tester.pumpAndSettle();

    expect(find.text('Éxito'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(app.supermarkets.supermarkets.single.name, 'Éxito');
  });

  testWidgets('blank name in dialog shows error and does not add', (
    tester,
  ) async {
    final app = await _pump(tester);

    await tester.tap(find.byKey(const Key('add-supermarket')));
    await tester.pumpAndSettle();
    await tester.tap(_confirmAdd);
    await tester.pumpAndSettle();

    expect(find.text('El nombre no puede estar vacío'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(app.supermarkets.supermarkets, isEmpty);

    await tester.enterText(find.byType(TextField), '    ');
    await tester.tap(_confirmAdd);
    await tester.pumpAndSettle();

    expect(find.text('El nombre no puede estar vacío'), findsOneWidget);
    expect(app.supermarkets.supermarkets, isEmpty);
  });

  testWidgets('duplicate name shows error and does not add', (tester) async {
    final app = await _pump(tester);
    await app.supermarkets.add('Éxito');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-supermarket')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'exito');
    await tester.tap(_confirmAdd);
    await tester.pumpAndSettle();

    expect(
      find.text('Ya existe un supermercado con ese nombre'),
      findsOneWidget,
    );
    expect(app.supermarkets.supermarkets.length, 1);
  });

  testWidgets('cancel in the name dialog adds nothing', (tester) async {
    final app = await _pump(tester);

    await tester.tap(find.byKey(const Key('add-supermarket')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ara');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(app.supermarkets.supermarkets, isEmpty);
  });

  testWidgets('edit renames the supermarket', (tester) async {
    final app = await _pump(tester);
    await app.supermarkets.add('Ara');
    await tester.pumpAndSettle();
    final id = app.supermarkets.supermarkets.single.id;

    await tester.tap(find.byKey(Key('edit-supermarket-$id')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Ara'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'D1');
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(find.text('D1'), findsOneWidget);
    expect(find.text('Ara'), findsNothing);
  });

  testWidgets('delete asks confirmation and cancel keeps the supermarket', (
    tester,
  ) async {
    final app = await _pump(tester);
    await app.supermarkets.add('Ara');
    await tester.pumpAndSettle();
    final id = app.supermarkets.supermarkets.single.id;

    await tester.tap(find.byKey(Key('delete-supermarket-$id')));
    await tester.pumpAndSettle();
    expect(find.textContaining('no se borran'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Ara'), findsOneWidget);
    expect(app.supermarkets.supermarkets.length, 1);
  });

  testWidgets('confirming delete removes it and keeps its products', (
    tester,
  ) async {
    final app = await _pump(tester);
    await app.supermarkets.add('Ara');
    final id = app.supermarkets.supermarkets.single.id;
    final milk = await app.products.add(name: 'Leche', supermarketId: id);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('delete-supermarket-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(find.text('Ara'), findsNothing);
    expect(app.supermarkets.supermarkets, isEmpty);
    expect(app.products.byId(milk.id), isNotNull);
    expect(app.products.byId(milk.id)!.supermarketId, isNull);
  });
}

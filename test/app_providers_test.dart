import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/app_providers.dart';
import 'package:lista_mercado/data/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppProviders app;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    app = AppProviders.create(LocalStorage(prefs));
  });

  test('removing a supermarket clears it from its products', () async {
    await app.supermarkets.add('Ara');
    final sId = app.supermarkets.supermarkets.single.id;
    final milk = await app.products.add(
      name: 'Leche',
      supermarketId: sId,
      price: 1000,
    );
    final bread = await app.products.add(name: 'Pan');

    await app.supermarkets.remove(sId);

    expect(app.products.products.length, 2);
    expect(app.products.byId(milk.id)!.supermarketId, isNull);
    expect(app.products.byId(milk.id)!.price, 1000);
    expect(app.products.byId(bread.id), isNotNull);
  });

  test('removing a supermarket does not touch the shopping list', () async {
    await app.supermarkets.add('Ara');
    final sId = app.supermarkets.supermarkets.single.id;
    final milk = await app.products.add(name: 'Leche', supermarketId: sId);
    await app.shoppingList.addProduct(milk.id, 2);

    await app.supermarkets.remove(sId);

    expect(app.shoppingList.quantityOf(milk.id), 2);
  });

  test('removing a product removes it from the shopping list', () async {
    final milk = await app.products.add(name: 'Leche');
    final bread = await app.products.add(name: 'Pan');
    await app.shoppingList.addProduct(milk.id, 2);
    await app.shoppingList.addProduct(bread.id, 1);

    await app.products.remove(milk.id);

    expect(app.shoppingList.contains(milk.id), isFalse);
    expect(app.shoppingList.contains(bread.id), isTrue);
  });

  test('removing a product that is not in the list is harmless', () async {
    final milk = await app.products.add(name: 'Leche');
    await app.products.remove(milk.id);
    expect(app.shoppingList.items, isEmpty);
  });
}

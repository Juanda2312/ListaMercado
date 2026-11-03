import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/data/local_storage.dart';
import 'package:lista_mercado/models/product.dart';
import 'package:lista_mercado/models/shopping_item.dart';
import 'package:lista_mercado/models/supermarket.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LocalStorage> _storageWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  final prefs = await SharedPreferences.getInstance();
  return LocalStorage(prefs);
}

void main() {
  test('loads empty lists on first launch', () async {
    final storage = await _storageWith({});
    expect(storage.loadSupermarkets(), isEmpty);
    expect(storage.loadProducts(), isEmpty);
    expect(storage.loadShoppingItems(), isEmpty);
  });

  test('save then load returns same products', () async {
    final storage = await _storageWith({});
    await storage.saveProducts(const [
      Product(id: '1', name: 'Leche', supermarketId: 's1', price: 4200.5),
      Product(id: '2', name: 'Pan'),
    ]);
    final loaded = storage.loadProducts();
    expect(loaded.length, 2);
    expect(loaded[0].name, 'Leche');
    expect(loaded[0].supermarketId, 's1');
    expect(loaded[0].price, 4200.5);
    expect(loaded[1].supermarketId, isNull);
    expect(loaded[1].price, isNull);
  });

  test('save then load returns same supermarkets and shopping items', () async {
    final storage = await _storageWith({});
    await storage.saveSupermarkets(const [
      Supermarket(id: 's1', name: 'Éxito'),
    ]);
    await storage.saveShoppingItems(const [
      ShoppingItem(productId: '1', quantity: 3, checked: true),
    ]);
    expect(storage.loadSupermarkets().single.name, 'Éxito');
    final item = storage.loadShoppingItems().single;
    expect(item.quantity, 3);
    expect(item.checked, isTrue);
  });

  test('state persists across LocalStorage instances', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await LocalStorage(prefs).saveProducts(const [Product(id: '1', name: 'A')]);
    expect(LocalStorage(prefs).loadProducts().single.id, '1');
  });

  test('corrupt json string yields empty list, no throw', () async {
    final storage = await _storageWith({
      'supermarkets_v1': '{no es json',
      'products_v1': '{no es json',
      'shopping_items_v1': '{no es json',
    });
    expect(storage.loadSupermarkets(), isEmpty);
    expect(storage.loadProducts(), isEmpty);
    expect(storage.loadShoppingItems(), isEmpty);
  });

  test('valid json that is not a list yields empty list', () async {
    final storage = await _storageWith({'products_v1': '{"a": 1}'});
    expect(storage.loadProducts(), isEmpty);
  });

  test('malformed entries are skipped, valid ones kept', () async {
    final storage = await _storageWith({
      'products_v1': '[{"id":"1"}, 42, {"id":"2","name":"Pan"}]',
    });
    final loaded = storage.loadProducts();
    expect(loaded.length, 1);
    expect(loaded.single.name, 'Pan');
  });
}

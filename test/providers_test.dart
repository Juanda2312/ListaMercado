import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/data/local_storage.dart';
import 'package:lista_mercado/models/product.dart';
import 'package:lista_mercado/providers/products_provider.dart';
import 'package:lista_mercado/providers/supermarkets_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lista_mercado/models/shopping_item.dart';
import 'package:lista_mercado/providers/shopping_list_provider.dart';

Future<LocalStorage> _newStorage() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return LocalStorage(prefs);
}

void main() {
  group('supermarkets', () {
    late LocalStorage storage;

    setUp(() async {
      storage = await _newStorage();
    });

    test('add trims name', () async {
      final p = SupermarketsProvider(storage: storage);
      expect(await p.add('  Éxito  '), isTrue);
      expect(p.supermarkets.single.name, 'Éxito');
    });

    test('add blank returns false and keeps list unchanged', () async {
      final p = SupermarketsProvider(storage: storage);
      expect(await p.add(''), isFalse);
      expect(await p.add('   '), isFalse);
      expect(p.supermarkets, isEmpty);
    });

    test('add duplicate ignoring case and accents returns false', () async {
      final p = SupermarketsProvider(storage: storage);
      expect(await p.add('Éxito'), isTrue);
      expect(await p.add('exito'), isFalse);
      expect(await p.add(' ÉXITO '), isFalse);
      expect(p.supermarkets.length, 1);
    });

    test('rename changes the name', () async {
      final p = SupermarketsProvider(storage: storage);
      await p.add('Ara');
      final id = p.supermarkets.single.id;
      expect(await p.rename(id, '  D1 '), isTrue);
      expect(p.byId(id)!.name, 'D1');
    });

    test('rename to existing name returns false', () async {
      final p = SupermarketsProvider(storage: storage);
      await p.add('Ara');
      await p.add('D1');
      final ara = p.supermarkets.firstWhere((s) => s.name == 'Ara');
      expect(await p.rename(ara.id, 'd1'), isFalse);
      expect(p.byId(ara.id)!.name, 'Ara');
    });

    test('rename to a different casing of its own name is allowed', () async {
      final p = SupermarketsProvider(storage: storage);
      await p.add('ara');
      final id = p.supermarkets.single.id;
      expect(await p.rename(id, 'Ara'), isTrue);
      expect(p.byId(id)!.name, 'Ara');
    });

    test('rename blank or unknown id returns false', () async {
      final p = SupermarketsProvider(storage: storage);
      await p.add('Ara');
      final id = p.supermarkets.single.id;
      expect(await p.rename(id, '  '), isFalse);
      expect(await p.rename('nope', 'X'), isFalse);
    });

    test(
      'supermarkets are sorted by normalized name and unmodifiable',
      () async {
        final p = SupermarketsProvider(storage: storage);
        await p.add('Olímpica');
        await p.add('Éxito');
        await p.add('Ara');
        expect(p.supermarkets.map((s) => s.name), ['Ara', 'Éxito', 'Olímpica']);
        expect(
          () => p.supermarkets.add(p.supermarkets.first),
          throwsUnsupportedError,
        );
      },
    );

    test('remove deletes it and calls onRemoved with the id', () async {
      final removed = <String>[];
      final p = SupermarketsProvider(storage: storage, onRemoved: removed.add);
      await p.add('Ara');
      final id = p.supermarkets.single.id;
      await p.remove(id);
      expect(p.supermarkets, isEmpty);
      expect(removed, [id]);
    });

    test(
      'remove unknown id does nothing and does not call onRemoved',
      () async {
        final removed = <String>[];
        final p = SupermarketsProvider(
          storage: storage,
          onRemoved: removed.add,
        );
        await p.remove('nope');
        expect(removed, isEmpty);
      },
    );

    test('state persists: new provider on same storage sees data', () async {
      final a = SupermarketsProvider(storage: storage);
      await a.add('Ara');
      final b = SupermarketsProvider(storage: storage);
      expect(b.supermarkets.single.name, 'Ara');
    });

    test('notifies listeners on add', () async {
      final p = SupermarketsProvider(storage: storage);
      var calls = 0;
      p.addListener(() => calls++);
      await p.add('Ara');
      expect(calls, 1);
    });
  });

  group('products', () {
    late LocalStorage storage;

    setUp(() async {
      storage = await _newStorage();
    });

    test('add trims name and stores optional fields', () async {
      final p = ProductsProvider(storage: storage);
      final created = await p.add(
        name: '  Leche ',
        supermarketId: 's1',
        price: 4200,
      );
      expect(created.name, 'Leche');
      expect(created.supermarketId, 's1');
      expect(created.price, 4200);
      expect(p.byId(created.id), isNotNull);
    });

    test('add with only a name leaves supermarket and price null', () async {
      final p = ProductsProvider(storage: storage);
      final created = await p.add(name: 'Pan');
      expect(created.supermarketId, isNull);
      expect(created.price, isNull);
    });

    test('add blank name throws ArgumentError', () async {
      final p = ProductsProvider(storage: storage);
      expect(() => p.add(name: ''), throwsArgumentError);
      expect(() => p.add(name: '   '), throwsArgumentError);
      expect(p.products, isEmpty);
    });

    test('add allows duplicate names with distinct ids', () async {
      final p = ProductsProvider(storage: storage);
      final a = await p.add(name: 'Leche', supermarketId: 's1');
      final b = await p.add(name: 'Leche', supermarketId: 's2');
      expect(p.products.length, 2);
      expect(a.id, isNot(b.id));
    });

    test('update persists price change', () async {
      final p = ProductsProvider(storage: storage);
      final created = await p.add(name: 'Leche', price: 4000);
      await p.update(
        Product(
          id: created.id,
          name: created.name,
          supermarketId: created.supermarketId,
          price: 5000,
        ),
      );
      expect(p.byId(created.id)!.price, 5000);
      final reloaded = ProductsProvider(storage: storage);
      expect(reloaded.byId(created.id)!.price, 5000);
    });

    test('update with blank name throws ArgumentError', () async {
      final p = ProductsProvider(storage: storage);
      final created = await p.add(name: 'Leche');
      expect(
        () => p.update(Product(id: created.id, name: '  ')),
        throwsArgumentError,
      );
      expect(p.byId(created.id)!.name, 'Leche');
    });

    test('update unknown id does nothing', () async {
      final p = ProductsProvider(storage: storage);
      await p.update(const Product(id: 'nope', name: 'X'));
      expect(p.products, isEmpty);
    });

    test('remove deletes it and calls onRemoved with the id', () async {
      final removed = <String>[];
      final p = ProductsProvider(storage: storage, onRemoved: removed.add);
      final created = await p.add(name: 'Leche');
      await p.remove(created.id);
      expect(p.products, isEmpty);
      expect(removed, [created.id]);
    });

    test('clearSupermarket nulls only matching products', () async {
      final p = ProductsProvider(storage: storage);
      final a = await p.add(name: 'Leche', supermarketId: 's1', price: 1000);
      final b = await p.add(name: 'Pan', supermarketId: 's2');
      final c = await p.add(name: 'Sal');
      await p.clearSupermarket('s1');
      expect(p.byId(a.id)!.supermarketId, isNull);
      expect(p.byId(a.id)!.price, 1000);
      expect(p.byId(a.id)!.name, 'Leche');
      expect(p.byId(b.id)!.supermarketId, 's2');
      expect(p.byId(c.id)!.supermarketId, isNull);
    });

    test('state persists across instances', () async {
      final a = ProductsProvider(storage: storage);
      await a.add(name: 'Leche', price: 4200);
      final b = ProductsProvider(storage: storage);
      expect(b.products.single.name, 'Leche');
      expect(b.products.single.price, 4200);
    });

    test('notifies listeners on add', () async {
      final p = ProductsProvider(storage: storage);
      var calls = 0;
      p.addListener(() => calls++);
      await p.add(name: 'Leche');
      expect(calls, 1);
    });
  });

  group('shopping list', () {
    late LocalStorage storage;
    late ShoppingListProvider list;

    setUp(() async {
      storage = await _newStorage();
      list = ShoppingListProvider(storage: storage);
    });

    test('addProduct twice sums quantities into one item', () async {
      await list.addProduct('p1', 2);
      await list.addProduct('p1', 3);
      expect(list.items.length, 1);
      expect(list.items.single.quantity, 5);
    });

    test('addProduct with quantity 0 stores 1', () async {
      await list.addProduct('p1', 0);
      expect(list.quantityOf('p1'), 1);
    });

    test('addProduct with negative quantity stores 1', () async {
      await list.addProduct('p1', -4);
      expect(list.quantityOf('p1'), 1);
    });

    test(
      'quantityOf returns null when absent and the quantity when present',
      () async {
        expect(list.quantityOf('p1'), isNull);
        await list.addProduct('p1', 3);
        expect(list.quantityOf('p1'), 3);
      },
    );

    test('contains reflects membership', () async {
      expect(list.contains('p1'), isFalse);
      await list.addProduct('p1', 1);
      expect(list.contains('p1'), isTrue);
    });

    test('quantityOf and contains do not notify', () async {
      await list.addProduct('p1', 1);
      var calls = 0;
      list.addListener(() => calls++);
      list.quantityOf('p1');
      list.contains('p1');
      expect(calls, 0);
    });

    test('setQuantity changes the quantity', () async {
      await list.addProduct('p1', 1);
      await list.setQuantity('p1', 7);
      expect(list.quantityOf('p1'), 7);
    });

    test('setQuantity(0) clamps to 1', () async {
      await list.addProduct('p1', 4);
      await list.setQuantity('p1', 0);
      expect(list.quantityOf('p1'), 1);
    });

    test('setQuantity on unknown id does nothing', () async {
      var calls = 0;
      list.addListener(() => calls++);
      await list.setQuantity('nope', 3);
      expect(list.items, isEmpty);
      expect(calls, 0);
    });

    test('toggleChecked twice returns to unchecked', () async {
      await list.addProduct('p1', 1);
      await list.toggleChecked('p1');
      expect(list.items.single.checked, isTrue);
      await list.toggleChecked('p1');
      expect(list.items.single.checked, isFalse);
    });

    test('checked keeps quantity', () async {
      await list.addProduct('p1', 4);
      await list.toggleChecked('p1');
      expect(list.items.single.quantity, 4);
    });

    test(
      'toggleCheckedFor with mixed state checks all; second call unchecks all',
      () async {
        await list.addProduct('p1', 1);
        await list.addProduct('p2', 1);
        await list.toggleChecked('p1');
        await list.toggleCheckedFor(['p1', 'p2']);
        expect(list.items.every((i) => i.checked), isTrue);
        await list.toggleCheckedFor(['p1', 'p2']);
        expect(list.items.every((i) => !i.checked), isTrue);
      },
    );

    test('toggleCheckedFor ignores ids not in the list', () async {
      await list.addProduct('p1', 1);
      await list.toggleCheckedFor(['p1', 'ghost']);
      expect(list.items.single.checked, isTrue);
      expect(list.items.length, 1);
    });

    test(
      'toggleCheckedFor with no ids present does nothing and does not notify',
      () async {
        await list.addProduct('p1', 1);
        var calls = 0;
        list.addListener(() => calls++);
        await list.toggleCheckedFor(['ghost']);
        await list.toggleCheckedFor([]);
        expect(list.items.single.checked, isFalse);
        expect(calls, 0);
      },
    );

    test('toggleCheckedFor only touches the given ids', () async {
      await list.addProduct('p1', 1);
      await list.addProduct('p2', 1);
      await list.toggleCheckedFor(['p1']);
      expect(list.items.firstWhere((i) => i.productId == 'p1').checked, isTrue);
      expect(
        list.items.firstWhere((i) => i.productId == 'p2').checked,
        isFalse,
      );
    });

    test('removeProduct removes only that item', () async {
      await list.addProduct('p1', 1);
      await list.addProduct('p2', 2);
      await list.removeProduct('p1');
      expect(list.items.map((i) => i.productId), ['p2']);
    });

    test(
      'removeProduct on unknown id does nothing and does not notify',
      () async {
        await list.addProduct('p1', 1);
        var calls = 0;
        list.addListener(() => calls++);
        await list.removeProduct('nope');
        expect(list.items.length, 1);
        expect(calls, 0);
      },
    );

    test('clear empties the list', () async {
      await list.addProduct('p1', 1);
      await list.addProduct('p2', 1);
      await list.clear();
      expect(list.items, isEmpty);
    });

    test('items is unmodifiable', () async {
      await list.addProduct('p1', 1);
      expect(
        () => list.items.add(const ShoppingItem(productId: 'x')),
        throwsUnsupportedError,
      );
    });

    test('restoreItem re-adds an item with its original quantity and checked state', () async {
      await list.addProduct('p1', 4);
      await list.toggleChecked('p1');
      final captured = list.items.single;
      await list.removeProduct('p1');
      expect(list.contains('p1'), isFalse);

      await list.restoreItem(captured);
      expect(list.items.single.productId, 'p1');
      expect(list.items.single.quantity, 4);
      expect(list.items.single.checked, isTrue);
    });

    test(
      'restoreItem does nothing if the product is already in the list',
      () async {
        await list.addProduct('p1', 4);
        final captured = list.items.single;
        await list.removeProduct('p1');
        await list.addProduct('p1', 1);

        var calls = 0;
        list.addListener(() => calls++);
        await list.restoreItem(captured);

        expect(list.items.length, 1);
        expect(list.quantityOf('p1'), 1);
        expect(calls, 0);
      },
    );

    test('state persists across instances', () async {
      await list.addProduct('p1', 3);
      await list.toggleChecked('p1');
      final reloaded = ShoppingListProvider(storage: storage);
      expect(reloaded.items.single.productId, 'p1');
      expect(reloaded.items.single.quantity, 3);
      expect(reloaded.items.single.checked, isTrue);
    });

    test('notifies listeners on mutation', () async {
      var calls = 0;
      list.addListener(() => calls++);
      await list.addProduct('p1', 1);
      await list.setQuantity('p1', 2);
      await list.toggleChecked('p1');
      expect(calls, 3);
    });
    test('budget persists, can be removed, and survives clear', () async {
      expect(list.budget, isNull);
      await list.setBudget(5000);
      await list.addProduct('p1', 1);
      await list.clear();
      expect(ShoppingListProvider(storage: storage).budget, 5000);
      await list.setBudget(null);
      expect(ShoppingListProvider(storage: storage).budget, isNull);
    });

    test('setBudget ignores non-positive values', () async {
      await list.setBudget(5000);
      await list.setBudget(0);
      await list.setBudget(-1);
      expect(list.budget, 5000);
    });
  });
}

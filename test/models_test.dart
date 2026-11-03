import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/models/product.dart';
import 'package:lista_mercado/models/shopping_item.dart';
import 'package:lista_mercado/models/supermarket.dart';

void main() {
  group('Supermarket', () {
    test('round-trips through json', () {
      const s = Supermarket(id: '1', name: 'Éxito');
      final copy = Supermarket.fromJson(s.toJson());
      expect(copy.id, '1');
      expect(copy.name, 'Éxito');
    });

    test('fromJson throws FormatException when name is missing', () {
      expect(() => Supermarket.fromJson({'id': '1'}), throwsFormatException);
    });

    test('fromJson throws FormatException on wrong type', () {
      expect(
        () => Supermarket.fromJson({'id': '1', 'name': 5}),
        throwsFormatException,
      );
    });
  });

  group('Product', () {
    test('round-trips with null supermarketId and price', () {
      const p = Product(id: '1', name: 'Leche');
      final copy = Product.fromJson(p.toJson());
      expect(copy.id, '1');
      expect(copy.name, 'Leche');
      expect(copy.supermarketId, isNull);
      expect(copy.price, isNull);
    });

    test('round-trips with price 12500.5', () {
      const p = Product(
        id: '2',
        name: 'Queso',
        supermarketId: 's1',
        price: 12500.5,
      );
      final copy = Product.fromJson(p.toJson());
      expect(copy.supermarketId, 's1');
      expect(copy.price, 12500.5);
    });

    test('integer price in json is read as double', () {
      final p = Product.fromJson({'id': '1', 'name': 'Pan', 'price': 3000});
      expect(p.price, 3000.0);
    });

    test('fromJson throws FormatException when name is missing', () {
      expect(() => Product.fromJson({'id': '1'}), throwsFormatException);
    });

    test('fromJson throws FormatException when price has wrong type', () {
      expect(
        () => Product.fromJson({'id': '1', 'name': 'Pan', 'price': 'caro'}),
        throwsFormatException,
      );
    });
  });

  group('ShoppingItem', () {
    test('defaults to quantity 1 and unchecked', () {
      const item = ShoppingItem(productId: 'p1');
      expect(item.quantity, 1);
      expect(item.checked, isFalse);
    });

    test('tempPrice defaults to null and round-trips through json', () {
      const plain = ShoppingItem(productId: 'p1');
      expect(plain.tempPrice, isNull);
      expect(plain.toJson().containsKey('tempPrice'), isFalse);

      const item = ShoppingItem(productId: 'p1', tempPrice: 8500);
      expect(ShoppingItem.fromJson(item.toJson()).tempPrice, 8500);
    });

    test('fromJson reads a missing or invalid tempPrice as null', () {
      for (final bad in [null, 'caro', 0, -5, double.infinity]) {
        final item = ShoppingItem.fromJson({
          'productId': 'p1',
          'tempPrice': bad,
        });
        expect(item.productId, 'p1');
        expect(item.tempPrice, isNull, reason: '$bad');
      }
      expect(ShoppingItem.fromJson({'productId': 'p1'}).tempPrice, isNull);
      expect(
        ShoppingItem.fromJson({'productId': 'p1', 'tempPrice': 8500}).tempPrice,
        8500.0,
      );
    });

    test('copyWith keeps tempPrice unless changed or cleared', () {
      const item = ShoppingItem(productId: 'p1', tempPrice: 8500);
      expect(item.copyWith(quantity: 2).tempPrice, 8500);
      expect(item.copyWith(tempPrice: 7000).tempPrice, 7000);
      expect(item.copyWith(clearTempPrice: true).tempPrice, isNull);
    });

    test('copyWith changes only given fields', () {
      const item = ShoppingItem(productId: 'p1', quantity: 2);
      final changed = item.copyWith(checked: true);
      expect(changed.productId, 'p1');
      expect(changed.quantity, 2);
      expect(changed.checked, isTrue);

      final changedQty = changed.copyWith(quantity: 5);
      expect(changedQty.quantity, 5);
      expect(changedQty.checked, isTrue);
    });

    test('round-trips through json', () {
      const item = ShoppingItem(productId: 'p1', quantity: 3, checked: true);
      final copy = ShoppingItem.fromJson(item.toJson());
      expect(copy.productId, 'p1');
      expect(copy.quantity, 3);
      expect(copy.checked, isTrue);
    });

    test('fromJson throws FormatException when productId is missing', () {
      expect(
        () => ShoppingItem.fromJson({'quantity': 1}),
        throwsFormatException,
      );
    });
  });
}

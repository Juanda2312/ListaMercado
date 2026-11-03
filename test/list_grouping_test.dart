import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/logic/list_grouping.dart';
import 'package:lista_mercado/models/product.dart';
import 'package:lista_mercado/models/shopping_item.dart';
import 'package:lista_mercado/models/supermarket.dart';

ListRow _row(Product p, {int quantity = 1, bool checked = false}) => ListRow(
  p,
  ShoppingItem(productId: p.id, quantity: quantity, checked: checked),
);

void main() {
  const ara = Supermarket(id: 's1', name: 'Ara');
  const exito = Supermarket(id: 's2', name: 'Éxito');

  group('ListRow', () {
    test('unitPrice and lineTotal use product price times quantity', () {
      final r = _row(
        const Product(id: 'p1', name: 'Leche', price: 1000),
        quantity: 3,
      );
      expect(r.unitPrice, 1000);
      expect(r.lineTotal, 3000);
    });

    test('tempPrice overrides the base price in unitPrice and lineTotal', () {
      const r = ListRow(
        Product(id: 'p1', name: 'Leche', price: 10000),
        ShoppingItem(productId: 'p1', quantity: 2, tempPrice: 8500),
      );
      expect(r.basePrice, 10000);
      expect(r.unitPrice, 8500);
      expect(r.lineTotal, 17000);
      expect(r.hasDiscount, isTrue);
      expect(r.discountPercent, 15);
    });

    test(
      'discountPercent is null without discount, base price or when not lower',
      () {
        const noDiscount = ListRow(
          Product(id: 'p1', name: 'Leche', price: 10000),
          ShoppingItem(productId: 'p1'),
        );
        const noBase = ListRow(
          Product(id: 'p1', name: 'Leche'),
          ShoppingItem(productId: 'p1', tempPrice: 500),
        );
        const notLower = ListRow(
          Product(id: 'p1', name: 'Leche', price: 400),
          ShoppingItem(productId: 'p1', tempPrice: 500),
        );
        expect(noDiscount.discountPercent, isNull);
        expect(noDiscount.hasDiscount, isFalse);
        expect(noBase.discountPercent, isNull);
        expect(noBase.unitPrice, 500);
        expect(notLower.discountPercent, isNull);
        expect(notLower.unitPrice, 500);
      },
    );

    test('without price both are null', () {
      final r = _row(const Product(id: 'p1', name: 'Leche'), quantity: 3);
      expect(r.unitPrice, isNull);
      expect(r.lineTotal, isNull);
    });
  });

  group('SupermarketSection', () {
    test('section total sums priced rows times quantity', () {
      final sections = buildSections(
        [
          _row(
            const Product(
              id: 'p1',
              name: 'Leche',
              supermarketId: 's1',
              price: 1000,
            ),
            quantity: 2,
          ),
          _row(
            const Product(
              id: 'p2',
              name: 'Pan',
              supermarketId: 's1',
              price: 500,
            ),
          ),
        ],
        [ara],
      );
      expect(sections.single.total, 2500);
      expect(sections.single.hasUnpriced, isFalse);
      expect(sections.single.totalLabel, '\$2.500');
    });

    test('row with tempPrice but no base price counts as priced', () {
      final sections = buildSections(
        [
          const ListRow(
            Product(id: 'p1', name: 'Pan', supermarketId: 's1'),
            ShoppingItem(productId: 'p1', quantity: 2, tempPrice: 500),
          ),
        ],
        [ara],
      );
      expect(sections.single.total, 1000);
      expect(sections.single.hasUnpriced, isFalse);
      expect(sections.single.totalLabel, '\$1.000');
    });

    test('unpriced row is excluded and marks label with (?)', () {
      final sections = buildSections(
        [
          _row(
            const Product(
              id: 'p1',
              name: 'Leche',
              supermarketId: 's1',
              price: 1000,
            ),
            quantity: 2,
          ),
          _row(const Product(id: 'p2', name: 'Pan', supermarketId: 's1')),
        ],
        [ara],
      );
      expect(sections.single.total, 2000);
      expect(sections.single.hasUnpriced, isTrue);
      expect(sections.single.totalLabel, '\$2.000 + (?)');
    });

    test("section with only unpriced rows labels '\$0 + (?)'", () {
      final sections = buildSections(
        [_row(const Product(id: 'p1', name: 'Pan', supermarketId: 's1'))],
        [ara],
      );
      expect(sections.single.total, 0);
      expect(sections.single.totalLabel, '\$0 + (?)');
    });

    test('checked rows still count in total', () {
      final sections = buildSections(
        [
          _row(
            const Product(
              id: 'p1',
              name: 'Leche',
              supermarketId: 's1',
              price: 1000,
            ),
            quantity: 2,
            checked: true,
          ),
        ],
        [ara],
      );
      expect(sections.single.total, 2000);
    });
  });

  group('buildTotal', () {
    test('sums all priced rows and flags unpriced', () {
      final t = buildTotal([
        _row(const Product(id: 'p1', name: 'Leche', price: 1000), quantity: 2),
        _row(const Product(id: 'p2', name: 'Pan')),
      ]);
      expect(t.total, 2000);
      expect(t.label, '\$2.000 + (?)');
      expect(t.remainingLabel(5000), '\$3.000 - (?)');
      expect(t.isOverBudget(5000), isFalse);
    });

    test('discounted rows use the temp price and do not flag unpriced', () {
      final t = buildTotal([
        const ListRow(
          Product(id: 'p1', name: 'Leche', price: 10000),
          ShoppingItem(productId: 'p1', quantity: 2, tempPrice: 8500),
        ),
        const ListRow(
          Product(id: 'p2', name: 'Pan'),
          ShoppingItem(productId: 'p2', tempPrice: 500),
        ),
      ]);
      expect(t.total, 17500);
      expect(t.hasUnpriced, isFalse);
      expect(t.label, '\$17.500');
    });

    test('negative remaining and no unpriced', () {
      final t = buildTotal([
        _row(const Product(id: 'p1', name: 'Leche', price: 1000), quantity: 6),
      ]);
      expect(t.remainingLabel(5000), '-\$1.000');
      expect(t.isOverBudget(5000), isTrue);
    });
  });

  group('buildSections', () {
    test('supermarkets are ordered by name, Otros is last', () {
      final sections = buildSections(
        [
          _row(const Product(id: 'p1', name: 'Sal')),
          _row(const Product(id: 'p2', name: 'Leche', supermarketId: 's2')),
          _row(const Product(id: 'p3', name: 'Pan', supermarketId: 's1')),
        ],
        [exito, ara],
      );
      expect(sections.map((s) => s.title), ['Ara', 'Éxito', 'Otros']);
      expect(sections.last.supermarketId, isNull);
      expect(sections.last.rows.single.product.id, 'p1');
    });

    test('product without supermarket goes to Otros, which is last', () {
      final sections = buildSections(
        [_row(const Product(id: 'p1', name: 'Sal'))],
        [ara],
      );
      expect(sections.single.title, 'Otros');
    });

    test('product pointing to a missing supermarket goes to Otros', () {
      final sections = buildSections(
        [_row(const Product(id: 'p1', name: 'Sal', supermarketId: 'borrado'))],
        [ara],
      );
      expect(sections.single.title, 'Otros');
      expect(sections.single.supermarketId, isNull);
      expect(sections.single.rows.single.product.id, 'p1');
    });

    test('empty sections are omitted', () {
      final sections = buildSections(
        [_row(const Product(id: 'p1', name: 'Pan', supermarketId: 's1'))],
        [ara, exito],
      );
      expect(sections.map((s) => s.title), ['Ara']);
    });

    test('no rows yields no sections', () {
      expect(buildSections([], [ara, exito]), isEmpty);
    });

    test('rows keep the order they were given within a section', () {
      final sections = buildSections(
        [
          _row(const Product(id: 'p1', name: 'Arroz', supermarketId: 's1')),
          _row(const Product(id: 'p2', name: 'Leche', supermarketId: 's1')),
        ],
        [ara],
      );
      expect(sections.single.rows.map((r) => r.product.name), [
        'Arroz',
        'Leche',
      ]);
    });
  });

  group('buildRows', () {
    test('skips items whose product no longer exists', () {
      final rows = buildRows(
        const [
          ShoppingItem(productId: 'p1'),
          ShoppingItem(productId: 'fantasma'),
        ],
        const [Product(id: 'p1', name: 'Leche')],
      );
      expect(rows.length, 1);
      expect(rows.single.product.id, 'p1');
    });

    test('orders by normalized name', () {
      final rows = buildRows(
        const [
          ShoppingItem(productId: 'p1'),
          ShoppingItem(productId: 'p2'),
          ShoppingItem(productId: 'p3'),
        ],
        const [
          Product(id: 'p1', name: 'Pan'),
          Product(id: 'p2', name: 'Café'),
          Product(id: 'p3', name: 'arroz'),
        ],
      );
      expect(rows.map((r) => r.product.name), ['arroz', 'Café', 'Pan']);
    });

    test('row carries the item quantity and checked state', () {
      final rows = buildRows(
        const [ShoppingItem(productId: 'p1', quantity: 4, checked: true)],
        const [Product(id: 'p1', name: 'Leche', price: 100)],
      );
      expect(rows.single.item.quantity, 4);
      expect(rows.single.item.checked, isTrue);
      expect(rows.single.lineTotal, 400);
    });
  });
}

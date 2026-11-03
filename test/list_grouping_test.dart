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

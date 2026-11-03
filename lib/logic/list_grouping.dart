import '../models/product.dart';
import '../models/shopping_item.dart';
import '../models/supermarket.dart';
import '../utils/discount.dart';
import '../utils/price_format.dart';
import '../utils/text_normalize.dart';

class ListRow {
  final Product product;
  final ShoppingItem item;

  const ListRow(this.product, this.item);

  /// Precio base del producto (sin descuento).
  double? get basePrice => product.price;

  /// Precio efectivo: el precio temporal si existe; si no, el del producto.
  double? get unitPrice => item.tempPrice ?? product.price;

  bool get hasDiscount => item.tempPrice != null;

  /// Porcentaje de descuento contra el precio base; `null` si no hay
  /// descuento, no hay precio base o el precio temporal no es menor que él.
  double? get discountPercent {
    final base = product.price;
    final temp = item.tempPrice;
    if (base == null || temp == null) return null;
    return percentFromPrice(base, temp);
  }

  double? get lineTotal {
    final price = unitPrice;
    return price == null ? null : price * item.quantity;
  }
}

class SupermarketSection {
  final String title;
  final String? supermarketId;
  final List<ListRow> rows;

  const SupermarketSection({
    required this.title,
    required this.supermarketId,
    required this.rows,
  });

  /// Suma solo las filas con precio. Las tachadas también cuentan.
  double get total {
    var sum = 0.0;
    for (final row in rows) {
      sum += row.lineTotal ?? 0;
    }
    return sum;
  }

  bool get hasUnpriced => rows.any((r) => r.unitPrice == null);

  String get totalLabel =>
      hasUnpriced ? '${formatPrice(total)} + (?)' : formatPrice(total);
}

const String kOthersTitle = 'Otros';

List<ListRow> buildRows(List<ShoppingItem> items, List<Product> products) {
  final byId = {for (final p in products) p.id: p};
  final rows = <ListRow>[];
  for (final item in items) {
    final product = byId[item.productId];
    if (product == null) continue;
    rows.add(ListRow(product, item));
  }
  rows.sort((a, b) {
    final byName = normalizeText(a.product.name)
        .compareTo(normalizeText(b.product.name));
    return byName != 0 ? byName : a.product.id.compareTo(b.product.id);
  });
  return rows;
}

List<SupermarketSection> buildSections(
  List<ListRow> rows,
  List<Supermarket> supermarkets,
) {
  final sorted = [...supermarkets]
    ..sort((a, b) => normalizeText(a.name).compareTo(normalizeText(b.name)));
  final knownIds = {for (final s in sorted) s.id};

  final sections = <SupermarketSection>[];
  for (final s in sorted) {
    final sectionRows = rows
        .where((r) => r.product.supermarketId == s.id)
        .toList();
    if (sectionRows.isEmpty) continue;
    sections.add(
      SupermarketSection(title: s.name, supermarketId: s.id, rows: sectionRows),
    );
  }

  final others = rows
      .where((r) => !knownIds.contains(r.product.supermarketId))
      .toList();
  if (others.isNotEmpty) {
    sections.add(
      SupermarketSection(
        title: kOthersTitle,
        supermarketId: null,
        rows: others,
      ),
    );
  }

  return sections;
}

class ListTotal {
  final double total;
  final bool hasUnpriced;

  const ListTotal(this.total, this.hasUnpriced);

  String get label =>
      hasUnpriced ? '${formatPrice(total)} + (?)' : formatPrice(total);

  double remaining(double budget) => budget - total;

  bool isOverBudget(double budget) => remaining(budget) < 0;

  String remainingLabel(double budget) {
    final r = remaining(budget);
    final base = r < 0 ? '-${formatPrice(-r)}' : formatPrice(r);
    return hasUnpriced ? '$base - (?)' : base;
  }
}

ListTotal buildTotal(List<ListRow> rows) {
  var sum = 0.0;
  var unpriced = false;
  for (final row in rows) {
    final line = row.lineTotal;
    if (line == null) {
      unpriced = true;
    } else {
      sum += line;
    }
  }
  return ListTotal(sum, unpriced);
}

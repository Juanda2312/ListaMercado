import '../models/product.dart';
import '../utils/text_normalize.dart';

const String kNoSupermarketFilter = '__none__';

List<Product> searchProducts(
  List<Product> products, {
  String query = '',
  String? supermarketFilter,
}) {
  final q = normalizeText(query);

  final filtered = products.where((p) {
    if (supermarketFilter == kNoSupermarketFilter) {
      if (p.supermarketId != null) return false;
    } else if (supermarketFilter != null) {
      if (p.supermarketId != supermarketFilter) return false;
    }
    return normalizeText(p.name).contains(q);
  }).toList();

  filtered.sort(
    (a, b) => normalizeText(a.name).compareTo(normalizeText(b.name)),
  );
  return filtered;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/logic/product_search.dart';
import 'package:lista_mercado/models/product.dart';

void main() {
  const leche = Product(id: '1', name: 'Leche', supermarketId: 's1');
  const cafe = Product(id: '2', name: 'Café', supermarketId: 's2');
  const pan = Product(id: '3', name: 'Pan');
  const arroz = Product(id: '4', name: 'Arroz', supermarketId: 's1');
  final all = [leche, cafe, pan, arroz];

  test("'lec' finds Leche", () {
    final r = searchProducts(all, query: 'lec');
    expect(r.map((p) => p.name), ['Leche']);
  });

  test("'cafe' finds Café", () {
    final r = searchProducts(all, query: 'cafe');
    expect(r.map((p) => p.name), ['Café']);
  });

  test('accented query matches unaccented name', () {
    final r = searchProducts(all, query: 'CAFÉ');
    expect(r.map((p) => p.name), ['Café']);
  });

  test('supermarket filter returns only that supermarket', () {
    final r = searchProducts(all, supermarketFilter: 's1');
    expect(r.map((p) => p.name), ['Arroz', 'Leche']);
  });

  test('kNoSupermarketFilter returns only unassigned products', () {
    final r = searchProducts(all, supermarketFilter: kNoSupermarketFilter);
    expect(r.map((p) => p.name), ['Pan']);
  });

  test('query and filter combine', () {
    // Sin filtro, 'a' coincide con Arroz, Café y Pan.
    final unfiltered = searchProducts(all, query: 'a');
    expect(unfiltered.map((p) => p.name), ['Arroz', 'Café', 'Pan']);

    // Con filtro s1 solo queda Arroz.
    final r = searchProducts(all, query: 'a', supermarketFilter: 's1');
    expect(r.map((p) => p.name), ['Arroz']);

    // Café existe, pero no en s1.
    final none = searchProducts(all, query: 'cafe', supermarketFilter: 's1');
    expect(none, isEmpty);
  });

  test('empty query returns all sorted by normalized name', () {
    final r = searchProducts(all);
    expect(r.map((p) => p.name), ['Arroz', 'Café', 'Leche', 'Pan']);
  });

  test('does not mutate the input list', () {
    final input = [pan, arroz];
    searchProducts(input);
    expect(input.first.name, 'Pan');
  });
}

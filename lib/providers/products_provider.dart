import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/local_storage.dart';
import '../models/product.dart';

class ProductsProvider extends ChangeNotifier {
  ProductsProvider({required LocalStorage storage, this._onRemoved})
    : _storage = storage,
      _items = storage.loadProducts();

  final LocalStorage _storage;
  final void Function(String productId)? _onRemoved;
  List<Product> _items;

  List<Product> get products => UnmodifiableListView(_items);

  Product? byId(String id) {
    for (final p in _items) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<Product> add({
    required String name,
    String? supermarketId,
    double? price,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(name, 'name', 'El nombre no puede estar vacío');
    }
    final product = Product(
      id: _newId(),
      name: trimmed,
      supermarketId: supermarketId,
      price: price,
    );
    _items = [..._items, product];
    await _persistAndNotify();
    return product;
  }

  Future<void> update(Product product) async {
    final trimmed = product.name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(
        product.name,
        'name',
        'El nombre no puede estar vacío',
      );
    }
    if (byId(product.id) == null) return;
    final clean = Product(
      id: product.id,
      name: trimmed,
      supermarketId: product.supermarketId,
      price: product.price,
    );
    _items = [
      for (final p in _items)
        if (p.id == clean.id) clean else p,
    ];
    await _persistAndNotify();
  }

  Future<void> remove(String id) async {
    if (byId(id) == null) return;
    _items = _items.where((p) => p.id != id).toList();
    await _persistAndNotify();
    _onRemoved?.call(id);
  }

  Future<void> clearSupermarket(String supermarketId) async {
    if (!_items.any((p) => p.supermarketId == supermarketId)) return;
    _items = [
      for (final p in _items)
        if (p.supermarketId == supermarketId)
          Product(id: p.id, name: p.name, supermarketId: null, price: p.price)
        else
          p,
    ];
    await _persistAndNotify();
  }

  String _newId() {
    var n = DateTime.now().microsecondsSinceEpoch;
    while (_items.any((p) => p.id == n.toString())) {
      n++;
    }
    return n.toString();
  }

  Future<void> _persistAndNotify() async {
    await _storage.saveProducts(_items);
    notifyListeners();
  }
}

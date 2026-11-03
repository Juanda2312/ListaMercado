import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/local_storage.dart';
import '../models/shopping_item.dart';

class ShoppingListProvider extends ChangeNotifier {
  ShoppingListProvider({required LocalStorage storage})
    : _storage = storage,
      _items = storage.loadShoppingItems(),
      _budget = storage.loadBudget();

  final LocalStorage _storage;
  List<ShoppingItem> _items;
  double? _budget;
  double? get budget => _budget;

  /// `null` quita el presupuesto. Valores no positivos se ignoran.
  Future<void> setBudget(double? value) async {
    if (value != null && !(value > 0 && value.isFinite)) return;
    _budget = value;
    notifyListeners();
    await _storage.saveBudget(value);
  }

  List<ShoppingItem> get items => UnmodifiableListView(_items);

  int? quantityOf(String productId) {
    final index = _indexOf(productId);
    return index == -1 ? null : _items[index].quantity;
  }

  bool contains(String productId) => quantityOf(productId) != null;

  /// Siempre suma sin preguntar: la confirmación es responsabilidad de la UI.
  ///
  /// Si [tempPrice] es válido (> 0 y finito) reemplaza el precio temporal del
  /// ítem (nuevo o existente); si es `null` o inválido, conserva el existente.
  Future<void> addProduct(
    String productId,
    int quantity, {
    double? tempPrice,
  }) async {
    final qty = quantity < 1 ? 1 : quantity;
    final temp = _validTempPrice(tempPrice);
    final index = _indexOf(productId);
    if (index == -1) {
      _items = [
        ..._items,
        ShoppingItem(productId: productId, quantity: qty, tempPrice: temp),
      ];
    } else {
      final current = _items[index];
      _replaceAt(
        index,
        current.copyWith(quantity: current.quantity + qty, tempPrice: temp),
      );
    }
    await _persistAndNotify();
  }

  Future<void> setQuantity(String productId, int quantity) async {
    final index = _indexOf(productId);
    if (index == -1) return;
    _replaceAt(
      index,
      _items[index].copyWith(quantity: quantity < 1 ? 1 : quantity),
    );
    await _persistAndNotify();
  }

  /// `null` quita el descuento. Valores no positivos o no finitos y productos
  /// que no están en la lista se ignoran (sin notificar).
  Future<void> setTempPrice(String productId, double? value) async {
    if (value != null && _validTempPrice(value) == null) return;
    final index = _indexOf(productId);
    if (index == -1) return;
    final current = _items[index];
    _replaceAt(
      index,
      value == null
          ? current.copyWith(clearTempPrice: true)
          : current.copyWith(tempPrice: value),
    );
    await _persistAndNotify();
  }

  Future<void> toggleChecked(String productId) async {
    final index = _indexOf(productId);
    if (index == -1) return;
    final current = _items[index];
    _replaceAt(index, current.copyWith(checked: !current.checked));
    await _persistAndNotify();
  }

  /// Si todos los ids presentes en la lista están tachados, los destacha;
  /// si no, los tacha todos. Ignora ids que no están en la lista.
  Future<void> toggleCheckedFor(Iterable<String> productIds) async {
    final ids = productIds.toSet();
    final scope = _items.where((i) => ids.contains(i.productId)).toList();
    if (scope.isEmpty) return;
    final newValue = !scope.every((i) => i.checked);
    _items = [
      for (final i in _items)
        if (ids.contains(i.productId)) i.copyWith(checked: newValue) else i,
    ];
    await _persistAndNotify();
  }

  Future<void> removeProduct(String productId) async {
    if (_indexOf(productId) == -1) return;
    _items = _items.where((i) => i.productId != productId).toList();
    await _persistAndNotify();
  }

  /// Reinserta el ítem tal cual (para "Deshacer"), incluido su precio
  /// temporal. Nunca duplica.
  Future<void> restoreItem(ShoppingItem item) async {
    if (_indexOf(item.productId) != -1) return;
    _items = [..._items, item];
    await _persistAndNotify();
  }

  Future<void> clear() async {
    if (_items.isEmpty) return;
    _items = [];
    await _persistAndNotify();
  }

  int _indexOf(String productId) =>
      _items.indexWhere((i) => i.productId == productId);

  void _replaceAt(int index, ShoppingItem item) {
    _items = [
      for (var i = 0; i < _items.length; i++)
        if (i == index) item else _items[i],
    ];
  }

  static double? _validTempPrice(double? value) =>
      value != null && value > 0 && value.isFinite ? value : null;

  Future<void> _persistAndNotify() {
    notifyListeners();
    return _storage.saveShoppingItems(_items);
  }
}

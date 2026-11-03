import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../models/shopping_item.dart';
import '../models/supermarket.dart';

class LocalStorage {
  static const _supermarketsKey = 'supermarkets_v1';
  static const _productsKey = 'products_v1';
  static const _shoppingItemsKey = 'shopping_items_v1';

  final SharedPreferences _prefs;

  LocalStorage(SharedPreferences prefs) : _prefs = prefs;

  static Future<LocalStorage> open() async {
    return LocalStorage(await SharedPreferences.getInstance());
  }

  List<Supermarket> loadSupermarkets() =>
      _load(_supermarketsKey, Supermarket.fromJson);

  List<Product> loadProducts() => _load(_productsKey, Product.fromJson);

  List<ShoppingItem> loadShoppingItems() =>
      _load(_shoppingItemsKey, ShoppingItem.fromJson);

  Future<void> saveSupermarkets(List<Supermarket> v) =>
      _save(_supermarketsKey, v.map((e) => e.toJson()).toList());

  Future<void> saveProducts(List<Product> v) =>
      _save(_productsKey, v.map((e) => e.toJson()).toList());

  Future<void> saveShoppingItems(List<ShoppingItem> v) =>
      _save(_shoppingItemsKey, v.map((e) => e.toJson()).toList());

  List<T> _load<T>(String key, T Function(Map<String, dynamic> json) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return [];
    }
    if (decoded is! List) return [];

    final result = <T>[];
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        result.add(fromJson(Map<String, dynamic>.from(entry)));
      } on FormatException {
        continue;
      }
    }
    return result;
  }

  Future<void> _save(String key, List<Map<String, dynamic>> data) async {
    await _prefs.setString(key, jsonEncode(data));
  }
}

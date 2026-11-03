import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../data/local_storage.dart';
import '../models/supermarket.dart';
import '../utils/text_normalize.dart';

class SupermarketsProvider extends ChangeNotifier {
  SupermarketsProvider({required LocalStorage storage, this._onRemoved})
    : _storage = storage,
      _items = _sorted(storage.loadSupermarkets());

  final LocalStorage _storage;
  final void Function(String supermarketId)? _onRemoved;
  List<Supermarket> _items;

  List<Supermarket> get supermarkets => UnmodifiableListView(_items);

  Supermarket? byId(String? id) {
    if (id == null) return null;
    for (final s in _items) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<bool> add(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || _nameTaken(trimmed, exceptId: null)) return false;
    _items = _sorted([..._items, Supermarket(id: _newId(), name: trimmed)]);
    await _persistAndNotify();
    return true;
  }

  Future<bool> rename(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || byId(id) == null) return false;
    if (_nameTaken(trimmed, exceptId: id)) return false;
    _items = _sorted([
      for (final s in _items)
        if (s.id == id) Supermarket(id: id, name: trimmed) else s,
    ]);
    await _persistAndNotify();
    return true;
  }

  Future<void> remove(String id) async {
    if (byId(id) == null) return;
    _items = _items.where((s) => s.id != id).toList();
    await _persistAndNotify();
    _onRemoved?.call(id);
  }

  bool _nameTaken(String name, {required String? exceptId}) {
    final target = normalizeText(name);
    return _items.any(
      (s) => s.id != exceptId && normalizeText(s.name) == target,
    );
  }

  String _newId() {
    var n = DateTime.now().microsecondsSinceEpoch;
    while (_items.any((s) => s.id == n.toString())) {
      n++;
    }
    return n.toString();
  }

  Future<void> _persistAndNotify() async {
    await _storage.saveSupermarkets(_items);
    notifyListeners();
  }

  static List<Supermarket> _sorted(List<Supermarket> list) {
    final copy = [...list];
    copy.sort((a, b) => normalizeText(a.name).compareTo(normalizeText(b.name)));
    return copy;
  }
}

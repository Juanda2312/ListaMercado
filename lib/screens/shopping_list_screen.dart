import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/list_grouping.dart';
import '../providers/products_provider.dart';
import '../providers/shopping_list_provider.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/shopping_list_view.dart';
import '../widgets/shopping_table_view.dart';

enum _ListAction { toggleAll, clear }

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ShoppingListProvider>().items;
    final products = context.watch<ProductsProvider>().products;
    final rows = buildRows(items, products);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lista de mercado'),
          actions: [
            PopupMenuButton<_ListAction>(
              key: const Key('list-menu'),
              enabled: rows.isNotEmpty,
              onSelected: (action) {
                switch (action) {
                  case _ListAction.toggleAll:
                    _toggleAll(context, rows);
                  case _ListAction.clear:
                    _clear(context);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _ListAction.toggleAll,
                  child: Text('Tachar/Destachar todos'),
                ),
                PopupMenuItem(
                  value: _ListAction.clear,
                  child: Text('Limpiar lista'),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lista'),
              Tab(text: 'Por supermercado'),
            ],
          ),
        ),
        body: rows.isEmpty
            ? const Center(child: Text('La lista está vacía'))
            : const TabBarView(
                children: [ShoppingListView(), ShoppingTableView()],
              ),
      ),
    );
  }

  Future<void> _toggleAll(BuildContext context, List<ListRow> rows) async {
    final list = context.read<ShoppingListProvider>();
    final allChecked = rows.every((r) => r.item.checked);
    final ids = rows.map((r) => r.product.id).toList();

    final confirmed = await confirmDialog(
      context,
      title: allChecked ? 'Destachar todos' : 'Tachar todos',
      message: allChecked
          ? '¿Destachar todos los productos de la lista?'
          : '¿Tachar todos los productos de la lista?',
    );
    if (!confirmed) return;
    await list.toggleCheckedFor(ids);
  }

  Future<void> _clear(BuildContext context) async {
    final list = context.read<ShoppingListProvider>();
    final confirmed = await confirmDialog(
      context,
      title: 'Limpiar lista',
      message:
          '¿Quitar todos los productos de la lista? '
          'Los productos no se borran del catálogo.',
      confirmLabel: 'Limpiar',
    );
    if (!confirmed) return;
    await list.clear();
  }
}

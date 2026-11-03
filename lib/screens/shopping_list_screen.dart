import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/list_grouping.dart';
import '../providers/products_provider.dart';
import '../providers/shopping_list_provider.dart';
import '../utils/price_format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/shopping_list_view.dart';
import '../widgets/shopping_table_view.dart';

enum _ListAction { toggleAll, clear }

class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ShoppingListProvider>();
    final products = context.watch<ProductsProvider>().products;
    final rows = buildRows(list.items, products);
    final total = buildTotal(rows);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          title: _TotalsTitle(total: total, budget: list.budget),
          actions: [
            IconButton(
              key: const Key('budget-button'),
              tooltip: 'Presupuesto',
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () => _editBudget(context),
            ),
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

  Future<void> _editBudget(BuildContext context) async {
    final list = context.read<ShoppingListProvider>();
    final result = await showDialog<({double? value})>(
      context: context,
      builder: (_) => _BudgetDialog(initial: list.budget),
    );
    if (result == null) return; // cancelado
    await list.setBudget(result.value);
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

class _TotalsTitle extends StatelessWidget {
  const _TotalsTitle({required this.total, required this.budget});

  final ListTotal total;
  final double? budget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final budget = this.budget;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total: ${total.label}',
          key: const Key('list-total'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        if (budget != null)
          Text.rich(
            key: const Key('list-budget'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            TextSpan(
              style: theme.textTheme.bodySmall,
              children: [
                TextSpan(text: 'Presupuesto ${formatPrice(budget)} · Restante: '),
                TextSpan(
                  text: total.remainingLabel(budget),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: total.isOverBudget(budget)
                        ? (dark ? Colors.red.shade300 : Colors.red.shade700)
                        : (dark ? Colors.green.shade300 : Colors.green.shade700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({required this.initial});

  final double? initial;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: switch (widget.initial) {
      null => '',
      final v when v == v.truncateToDouble() => v.toInt().toString(),
      final v => v.toString().replaceAll('.', ','),
    },
  );
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _save() {
    final value = parsePrice(_ctrl.text);
    if (value == null) {
      setState(() => _error = 'Precio inválido');
      return;
    }
    Navigator.of(context).pop((value: value));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Presupuesto'),
      content: TextField(
        key: const Key('budget-input'),
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Monto',
          prefixText: '\$ ',
          errorText: _error,
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (widget.initial != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop((value: null)),
            child: const Text('Quitar'),
          ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
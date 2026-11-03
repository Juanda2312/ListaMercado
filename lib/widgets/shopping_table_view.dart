import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/list_grouping.dart';
import '../providers/products_provider.dart';
import '../providers/shopping_list_provider.dart';
import '../providers/supermarkets_provider.dart';
import '../screens/product_form_screen.dart';
import '../utils/price_format.dart';
import 'confirm_dialog.dart';

const double _columnWidth = 160;

class ShoppingTableView extends StatelessWidget {
  const ShoppingTableView({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ShoppingListProvider>().items;
    final products = context.watch<ProductsProvider>().products;
    final supermarkets = context.watch<SupermarketsProvider>().supermarkets;
    final sections = buildSections(buildRows(items, products), supermarkets);

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final section in sections) _SectionColumn(section: section),
          ],
        ),
      ),
    );
  }
}

class _SectionColumn extends StatelessWidget {
  const _SectionColumn({required this.section});

  final SupermarketSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: _columnWidth,
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      section.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  PopupMenuButton<int>(
                    key: Key('section-menu-${section.title}'),
                    tooltip: 'Opciones',
                    onSelected: (_) => _toggleSection(context),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 0,
                        child: Text(
                          'Tachar/Destachar todos de este supermercado',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final row in section.rows) _Cell(row: row),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                section.totalLabel,
                key: Key('section-total-${section.title}'),
                style: theme.textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSection(BuildContext context) async {
    final list = context.read<ShoppingListProvider>();
    final allChecked = section.rows.every((r) => r.item.checked);
    final ids = section.rows.map((r) => r.product.id).toList();

    final confirmed = await confirmDialog(
      context,
      title: allChecked ? 'Destachar productos' : 'Tachar productos',
      message: allChecked
          ? '¿Destachar todos los productos de "${section.title}"?'
          : '¿Tachar todos los productos de "${section.title}"?',
    );
    if (!confirmed) return;
    await list.toggleCheckedFor(ids);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.row});

  final ListRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = row.product;
    final checked = row.item.checked;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final unit = row.unitPrice;

    return InkWell(
      onTap: () =>
          context.read<ShoppingListProvider>().toggleChecked(product.id),
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    key: Key('cell-name-${product.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: checked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: checked ? muted : null,
                    ),
                  ),
                  Text(
                    '${row.item.quantity} × ${unit == null ? '—' : formatPrice(unit)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: checked ? muted : null,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: Key('edit-cell-${product.id}'),
              tooltip: 'Editar producto',
              visualDensity: VisualDensity.compact,
              iconSize: 20,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProductFormScreen(productId: product.id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

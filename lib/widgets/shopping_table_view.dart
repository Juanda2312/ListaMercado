import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/list_grouping.dart';
import '../providers/products_provider.dart';
import '../providers/shopping_list_provider.dart';
import '../providers/supermarkets_provider.dart';
import '../screens/product_form_screen.dart';
import '../utils/discount.dart';
import '../utils/price_format.dart';
import 'confirm_dialog.dart';
import 'discount_dialog.dart';
import 'initial_avatar.dart';

/// Ancho de cada tarjeta: fijo en pantallas anchas; en estrechas, 80 % del
/// espacio (entre 240 y 320) para que la siguiente tarjeta asome.
double _columnWidthFor(double available) =>
    available >= 600 ? 280 : (available * 0.8).clamp(240.0, 320.0).toDouble();

class ShoppingTableView extends StatelessWidget {
  const ShoppingTableView({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ShoppingListProvider>().items;
    final products = context.watch<ProductsProvider>().products;
    final supermarkets = context.watch<SupermarketsProvider>().supermarkets;
    final sections = buildSections(buildRows(items, products), supermarkets);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = _columnWidthFor(constraints.maxWidth);
        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in sections)
                  _SectionColumn(section: section, width: width),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionColumn extends StatelessWidget {
  const _SectionColumn({required this.section, required this.width});

  final SupermarketSection section;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final count = section.rows.length;

    return SizedBox(
      width: width,
      child: Card(
        margin: const EdgeInsets.only(right: 8),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: scheme.secondaryContainer,
              padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
              child: Row(
                children: [
                  InitialAvatar(name: section.title),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                        Text(
                          count == 1 ? '1 producto' : '$count productos',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ],
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
            for (var i = 0; i < section.rows.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 12),
              _Cell(row: section.rows[i]),
            ],
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Text('Total', style: theme.textTheme.bodyMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section.totalLabel,
                      key: Key('section-total-${section.title}'),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
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
    final percent = row.discountPercent;

    // El descuento se distingue por color y peso, no por texto extra.
    final lineStyle = theme.textTheme.bodySmall?.copyWith(
      color: checked
          ? muted
          : (row.hasDiscount ? theme.colorScheme.primary : null),
      fontWeight: row.hasDiscount && !checked ? FontWeight.bold : null,
    );

    return InkWell(
      onTap: () =>
          context.read<ShoppingListProvider>().toggleChecked(product.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${row.item.quantity} × ${unit == null ? '—' : formatPrice(unit)}'
                    '${percent == null ? '' : ' (-${formatPercent(percent)})'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: lineStyle,
                  ),
                ),
                IconButton(
                  key: Key('discount-cell-${product.id}'),
                  tooltip: 'Descuento',
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  icon: Icon(
                    Icons.sell_outlined,
                    color: row.hasDiscount ? theme.colorScheme.primary : null,
                  ),
                  onPressed: () => showDiscountDialog(context, row),
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
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'discount_dialog.dart';
import '../logic/list_grouping.dart';
import '../providers/products_provider.dart';
import '../providers/shopping_list_provider.dart';
import '../providers/supermarkets_provider.dart';
import '../screens/product_form_screen.dart';
import '../utils/price_format.dart';
import '../utils/discount.dart';
import 'quantity_stepper.dart';

class ShoppingListView extends StatelessWidget {
  const ShoppingListView({super.key});

  @override
  Widget build(BuildContext context) {
    final list = context.watch<ShoppingListProvider>();
    final products = context.watch<ProductsProvider>().products;
    final supermarkets = context.watch<SupermarketsProvider>();
    final rows = buildRows(list.items, products);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        return Dismissible(
          key: Key('dismiss-${row.product.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            child: Icon(
              Icons.delete,
              color: Theme.of(context).colorScheme.onError,
            ),
          ),
          onDismissed: (_) => _remove(context, row),
          child: _ListRowTile(
            row: row,
            supermarketName:
                supermarkets.byId(row.product.supermarketId)?.name ??
                kOthersTitle,
          ),
        );
      },
    );
  }

  void _remove(BuildContext context, ListRow row) {
    final list = context.read<ShoppingListProvider>();
    final messenger = ScaffoldMessenger.of(context);
    // Se captura antes de quitar, para poder restaurarlo tal cual.
    final item = row.item;

    list.removeProduct(item.productId);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('«${row.product.name}» quitado de la lista'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => list.restoreItem(item),
          ),
        ),
      );
  }
}

class _ListRowTile extends StatelessWidget {
  const _ListRowTile({required this.row, required this.supermarketName});

  final ListRow row;
  final String supermarketName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = row.product;
    final checked = row.item.checked;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);
    final unit = row.unitPrice;
    final total = row.lineTotal;
    final base = row.basePrice;
    final percent = row.discountPercent;

    return Card(
      key: Key('list-row-${product.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            context.read<ShoppingListProvider>().toggleChecked(product.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      product.name,
                      key: Key('row-name-${product.id}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: checked
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: checked ? muted : null,
                      ),
                    ),
                  ),
                  IconButton(
                    key: Key('edit-discount-${product.id}'),
                    tooltip: 'Descuento',
                    icon: Icon(
                      Icons.sell_outlined,
                      color: row.hasDiscount ? theme.colorScheme.primary : null,
                    ),
                    onPressed: () => showDiscountDialog(context, row),
                  ),
                  IconButton(
                    key: Key('edit-product-${product.id}'),
                    tooltip: 'Editar producto',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ProductFormScreen(productId: product.id),
                      ),
                    ),
                  ),
                ],
              ),
              Chip(
                label: Text(
                  supermarketName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                labelStyle: theme.textTheme.bodySmall?.copyWith(
                  color: checked ? muted : null,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  QuantityStepper(
                    value: row.item.quantity,
                    onChanged: (v) => context
                        .read<ShoppingListProvider>()
                        .setQuantity(product.id, v),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text.rich(
                          key: Key('row-unit-${product.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          TextSpan(
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: checked ? muted : null,
                            ),
                            children: [
                              const TextSpan(text: 'c/u '),
                              if (row.hasDiscount && base != null) ...[
                                TextSpan(
                                  text: formatPrice(base),
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const TextSpan(text: ' '),
                              ],
                              TextSpan(
                                text: unit == null ? '—' : formatPrice(unit),
                              ),
                              if (percent != null)
                                TextSpan(
                                  text: ' -${formatPercent(percent)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: checked
                                        ? null
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          total == null ? '—' : formatPrice(total),
                          key: Key('row-total-${product.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: checked ? muted : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

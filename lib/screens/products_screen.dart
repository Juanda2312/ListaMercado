import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/product_search.dart';
import '../models/product.dart';
import '../models/supermarket.dart';
import '../providers/products_provider.dart';
import '../providers/shopping_list_provider.dart';
import '../providers/supermarkets_provider.dart';
import '../utils/price_format.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/discount_fields.dart';
import '../widgets/quantity_stepper.dart';
import 'product_form_screen.dart';

enum _ProductAction { edit, delete }

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';
  String? _filter;

  /// Si el supermercado filtrado se eliminó, vuelve a "Todos".
  String? _effectiveFilter(List<Supermarket> supermarkets) {
    final f = _filter;
    if (f == null || f == kNoSupermarketFilter) return f;
    return supermarkets.any((s) => s.id == f) ? f : null;
  }

  @override
  Widget build(BuildContext context) {
    final allProducts = context.watch<ProductsProvider>().products;
    final supermarketsProvider = context.watch<SupermarketsProvider>();
    final supermarkets = supermarketsProvider.supermarkets;
    final filter = _effectiveFilter(supermarkets);

    final results = searchProducts(
      allProducts,
      query: _query,
      supermarketFilter: filter,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const Key('product-search'),
              decoration: const InputDecoration(
                hintText: 'Buscar producto',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Supermercado',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  key: const Key('product-filter'),
                  value: filter,
                  isExpanded: true,
                  isDense: true,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Todos'),
                    ),
                    for (final s in supermarkets)
                      DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const DropdownMenuItem<String?>(
                      value: kNoSupermarketFilter,
                      child: Text('Sin supermercado'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _filter = v),
                ),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? Center(
                    child: Text(
                      allProducts.isEmpty
                          ? 'Aún no hay productos'
                          : 'Sin resultados',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: results.length,
                    itemBuilder: (context, i) =>
                        _buildTile(context, results[i], supermarketsProvider),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-product'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProductFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Añadir producto'),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    Product product,
    SupermarketsProvider supermarkets,
  ) {
    final parts = <String>[
      ?supermarkets.byId(product.supermarketId)?.name,
      if (product.price != null) formatPrice(product.price!),
    ];

    return ListTile(
      key: Key('product-tile-${product.id}'),
      title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: parts.isEmpty
          ? null
          : Text(
              parts.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('add-to-list-${product.id}'),
            tooltip: 'Añadir a la lista',
            icon: const Icon(Icons.add_shopping_cart),
            onPressed: () => _addToList(context, product),
          ),
          PopupMenuButton<_ProductAction>(
            key: Key('product-menu-${product.id}'),
            onSelected: (action) {
              switch (action) {
                case _ProductAction.edit:
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProductFormScreen(productId: product.id),
                    ),
                  );
                case _ProductAction.delete:
                  _delete(context, product);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _ProductAction.edit, child: Text('Editar')),
              PopupMenuItem(
                value: _ProductAction.delete,
                child: Text('Eliminar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _addToList(BuildContext context, Product product) async {
    final list = context.read<ShoppingListProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final result = await showDialog<({int quantity, double? tempPrice})>(
      context: context,
      builder: (_) =>
          _QuantityDialog(productName: product.name, basePrice: product.price),
    );
    if (result == null) return;
    if (!context.mounted) return;

    final quantity = result.quantity;
    final tempPrice = result.tempPrice;

    // La confirmación vive aquí (UI), no en el provider.
    final current = list.quantityOf(product.id);
    if (current != null) {
      final discountNote = tempPrice == null
          ? ''
          : ' Se aplicará el precio temporal ${formatPrice(tempPrice)}.';
      final confirmed = await confirmDialog(
        context,
        title: 'Producto ya en la lista',
        message:
            '"${product.name}" ya está en la lista con cantidad '
            '$current. ¿Sumar $quantity más para un total de '
            '${current + quantity}?$discountNote',
        confirmLabel: 'Sumar',
      );
      if (!confirmed) return;
    }

    await list.addProduct(product.id, quantity, tempPrice: tempPrice);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('"${product.name}" añadido a la lista')),
      );
  }

  Future<void> _delete(BuildContext context, Product product) async {
    final products = context.read<ProductsProvider>();
    final confirmed = await confirmDialog(
      context,
      title: 'Eliminar producto',
      message:
          '¿Eliminar "${product.name}"? También se quitará de la '
          'lista de mercado.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed) return;
    await products.remove(product.id);
  }
}

class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.productName, required this.basePrice});

  final String productName;
  final double? basePrice;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  int _quantity = 1;
  double? _tempPrice;
  bool _discountValid = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Añadir a la lista'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Center(
            child: QuantityStepper(
              value: _quantity,
              onChanged: (v) => setState(() => _quantity = v),
            ),
          ),
          const SizedBox(height: 16),
          DiscountFields(
            basePrice: widget.basePrice,
            onChanged: (price, valid) => setState(() {
              _tempPrice = price;
              _discountValid = valid;
            }),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _discountValid
              ? () =>
                    Navigator.of(context)
                        .pop((quantity: _quantity, tempPrice: _tempPrice))
              : null,
          child: const Text('Añadir'),
        ),
      ],
    );
  }
}

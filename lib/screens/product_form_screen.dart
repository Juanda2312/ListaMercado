import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/products_provider.dart';
import '../providers/supermarkets_provider.dart';
import '../utils/price_format.dart';

String _priceToText(double price) {
  if (price == price.truncateToDouble()) return price.toInt().toString();
  return price.toString().replaceAll('.', ',');
}

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.productId});

  /// `null` = alta; si no, edición del producto existente.
  final String? productId;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  Product? _existing;
  String? _supermarketId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final id = widget.productId;
    if (id != null) {
      _existing = context.read<ProductsProvider>().byId(id);
    }
    final existing = _existing;
    final price = existing?.price;
    final supermarketId = existing?.supermarketId;
    final supermarkets = context.read<SupermarketsProvider>();

    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _priceCtrl = TextEditingController(
      text: price == null ? '' : _priceToText(price),
    );
    // Si el supermercado ya no existe, el producto se muestra "sin supermercado".
    _supermarketId = supermarkets.byId(supermarketId) == null
        ? null
        : supermarketId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final products = context.read<ProductsProvider>();
    final price = parsePrice(_priceCtrl.text);
    final existing = _existing;

    if (existing == null) {
      await products.add(
        name: _nameCtrl.text,
        supermarketId: _supermarketId,
        price: price,
      );
    } else {
      await products.update(
        Product(
          id: existing.id,
          name: _nameCtrl.text,
          supermarketId: _supermarketId,
          price: price,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final supermarkets = context.watch<SupermarketsProvider>().supermarkets;
    final isEditing = widget.productId != null;

    if (isEditing && _existing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Editar producto')),
        body: const Center(child: Text('Producto no encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar producto' : 'Añadir producto'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              key: const Key('product-name'),
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El nombre es obligatorio'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              key: const Key('product-supermarket'),
              initialValue: _supermarketId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Supermercado',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Sin supermercado'),
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
              ],
              onChanged: (v) => setState(() => _supermarketId = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('product-price'),
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio (opcional)',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
              validator: validatePriceInput,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('product-save'),
              onPressed: _saving ? null : _save,
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

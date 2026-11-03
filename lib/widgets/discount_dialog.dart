import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/list_grouping.dart';
import '../providers/shopping_list_provider.dart';
import 'discount_fields.dart';

/// Abre el diálogo de descuento de una fila de la lista.
/// Guardar -> `setTempPrice(valor)`; Quitar -> `setTempPrice(null)`.
Future<void> showDiscountDialog(BuildContext context, ListRow row) async {
  final list = context.read<ShoppingListProvider>();
  final result = await showDialog<({double? value})>(
    context: context,
    builder: (_) => _DiscountDialog(
      productName: row.product.name,
      basePrice: row.basePrice,
      initial: row.item.tempPrice,
    ),
  );
  if (result == null) return; // cancelado
  await list.setTempPrice(row.product.id, result.value);
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({
    required this.productName,
    required this.basePrice,
    required this.initial,
  });

  final String productName;
  final double? basePrice;
  final double? initial;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late double? _tempPrice = widget.initial;
  bool _valid = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Descuento'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          DiscountFields(
            basePrice: widget.basePrice,
            initialTempPrice: widget.initial,
            onChanged: (price, valid) => setState(() {
              _tempPrice = price;
              _valid = valid;
            }),
          ),
        ],
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
        FilledButton(
          // Guardar solo con un descuento válido y no vacío.
          onPressed: _valid && _tempPrice != null
              ? () => Navigator.of(context).pop((value: _tempPrice))
              : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

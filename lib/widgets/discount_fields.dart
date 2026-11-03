import 'package:flutter/material.dart';

import '../utils/discount.dart';
import '../utils/price_format.dart';

String _plain(double value) => value == value.truncateToDouble()
    ? value.toInt().toString()
    : value.toString().replaceAll('.', ',');

String _plainPercent(double value) => formatPercent(value).replaceAll('%', '');

/// Dos campos complementarios y opcionales: % de descuento y precio final.
/// Al editar uno se calcula y rellena el otro.
///
/// `onChanged(tempPrice, isValid)`:
/// - campos vacíos          -> `(null, true)`
/// - descuento válido       -> `(precioFinal, true)`
/// - algún campo inválido   -> `(null, false)`
class DiscountFields extends StatefulWidget {
  const DiscountFields({
    super.key,
    required this.basePrice,
    required this.onChanged,
    this.initialTempPrice,
  });

  /// Precio base del producto. Si es `null`, solo se puede indicar el precio final.
  final double? basePrice;
  final double? initialTempPrice;
  final void Function(double? tempPrice, bool isValid) onChanged;

  @override
  State<DiscountFields> createState() => _DiscountFieldsState();
}

class _DiscountFieldsState extends State<DiscountFields> {
  late final TextEditingController _percentCtrl;
  late final TextEditingController _priceCtrl;
  String? _percentError;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    final base = widget.basePrice;
    final initial = widget.initialTempPrice;
    final percent = (base == null || initial == null)
        ? null
        : percentFromPrice(base, initial);
    _priceCtrl = TextEditingController(
      text: initial == null ? '' : _plain(initial),
    );
    _percentCtrl = TextEditingController(
      text: percent == null ? '' : _plainPercent(percent),
    );
  }

  @override
  void dispose() {
    _percentCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  // Asignar `controller.text` por código no dispara `onChanged`, así que los
  // dos campos no se llaman entre sí en bucle.
  void _onPercentChanged(String raw) {
    final base = widget.basePrice;
    String? error;
    double? price;
    if (raw.trim().isNotEmpty) {
      final percent = parsePercent(raw);
      price = (percent == null || base == null)
          ? null
          : priceFromPercent(base, percent);
      if (price == null) error = 'Descuento inválido';
    }
    setState(() {
      _percentError = error;
      _priceError = null;
      _priceCtrl.text = price == null ? '' : _plain(price);
    });
    widget.onChanged(price, error == null);
  }

  void _onPriceChanged(String raw) {
    final base = widget.basePrice;
    String? error;
    double? price;
    var percentText = '';
    if (raw.trim().isNotEmpty) {
      price = parsePrice(raw);
      if (price == null) {
        error = 'Precio inválido';
      } else if (base != null) {
        final percent = percentFromPrice(base, price);
        if (percent == null) {
          error = 'Descuento inválido';
          price = null;
        } else {
          percentText = _plainPercent(percent);
        }
      }
    }
    setState(() {
      _priceError = error;
      _percentError = null;
      _percentCtrl.text = percentText;
    });
    widget.onChanged(price, error == null);
  }

  @override
  Widget build(BuildContext context) {
    final hasBase = widget.basePrice != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Descuento (opcional)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('discount-percent'),
          controller: _percentCtrl,
          enabled: hasBase,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Descuento',
            suffixText: '%',
            helperText: hasBase ? null : 'Sin precio: indica el precio final',
            errorText: _percentError,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: _onPercentChanged,
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('discount-price'),
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Precio final',
            prefixText: '\$ ',
            errorText: _priceError,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: _onPriceChanged,
        ),
      ],
    );
  }
}

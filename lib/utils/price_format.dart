final _thousandsFormat = RegExp(r'^\d{1,3}(\.\d{3})+(,\d+)?$');
final _plainNumber = RegExp(r'^\d+([.,]\d+)?$');

double? parsePrice(String raw) {
  final text = raw.replaceAll(RegExp(r'\s'), '');
  if (text.isEmpty) return null;

  final String normalized;
  if (_thousandsFormat.hasMatch(text)) {
    normalized = text.replaceAll('.', '').replaceAll(',', '.');
  } else if (_plainNumber.hasMatch(text)) {
    normalized = text.replaceAll(',', '.');
  } else {
    return null;
  }

  final value = double.tryParse(normalized);
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}

String? validatePriceInput(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return parsePrice(raw) == null ? 'Precio inválido' : null;
}

String formatPrice(double value) {
  final fixed = value.toStringAsFixed(2);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final decimals = parts[1].replaceFirst(RegExp(r'0+$'), '');
  return decimals.isEmpty ? '\$$intPart' : '\$$intPart,$decimals';
}

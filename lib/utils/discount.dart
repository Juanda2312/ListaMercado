import 'price_format.dart';

double _round2(double value) => (value * 100).roundToDouble() / 100;

/// Precio final tras aplicar [percent] % de descuento a [base].
///
/// `null` si [base] <= 0, [percent] no está en (0, 100) o el resultado
/// redondeado a 2 decimales es <= 0 o no queda por debajo de [base].
double? priceFromPercent(double base, double percent) {
  if (!base.isFinite || base <= 0) return null;
  if (!percent.isFinite || percent <= 0 || percent >= 100) return null;
  final result = _round2(base * (100 - percent) / 100);
  if (result <= 0 || result >= base) return null;
  return result;
}

/// Porcentaje de descuento que representa [price] respecto a [base].
///
/// `null` si [base] <= 0, [price] <= 0 o [price] no es menor que [base].
double? percentFromPrice(double base, double price) {
  if (!base.isFinite || base <= 0) return null;
  if (!price.isFinite || price <= 0 || price >= base) return null;
  return _round2((base - price) * 100 / base);
}

/// Mismas reglas de parseo que [parsePrice], pero el valor debe estar en (0, 100).
double? parsePercent(String raw) {
  final value = parsePrice(raw);
  if (value == null || value >= 100) return null;
  return value;
}

String? validatePercentInput(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return parsePercent(raw) == null ? 'Descuento inválido' : null;
}

/// `15` -> `15%`, `12.5` -> `12,5%` (máximo 2 decimales, sin ceros finales).
String formatPercent(double value) {
  var text = value.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return '${text.replaceAll('.', ',')}%';
}

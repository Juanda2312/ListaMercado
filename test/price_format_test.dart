import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/utils/price_format.dart';
import 'package:lista_mercado/utils/text_normalize.dart';

void main() {
  group('normalizeText', () {
    test('lowercases, trims and removes accents', () {
      expect(normalizeText('  ÉXITO '), 'exito');
      expect(normalizeText('Café'), 'cafe');
      expect(normalizeText('Pingüino'), 'pinguino');
    });

    test('keeps ñ', () {
      expect(normalizeText('Piña'), 'piña');
    });
  });

  group('parsePrice', () {
    test('accepts comma or dot as decimal separator', () {
      expect(parsePrice('1,5'), 1.5);
      expect(parsePrice('1.5'), 1.5);
      expect(parsePrice('2500'), 2500);
    });

    test('dot followed by exactly 3 digits is a thousands separator', () {
      expect(parsePrice('12.500'), 12500);
      expect(parsePrice('1.234.567'), 1234567);
      expect(parsePrice('12.500,5'), 12500.5);
    });

    test('empty, invalid or non-positive values return null', () {
      expect(parsePrice(''), isNull);
      expect(parsePrice('   '), isNull);
      expect(parsePrice('abc'), isNull);
      expect(parsePrice('-3'), isNull);
      expect(parsePrice('0'), isNull);
      expect(parsePrice('0,00'), isNull);
      expect(parsePrice('1,2,3'), isNull);
      expect(parsePrice('Infinity'), isNull);
    });
  });

  group('validatePriceInput', () {
    test('null for empty or valid input', () {
      expect(validatePriceInput(null), isNull);
      expect(validatePriceInput(''), isNull);
      expect(validatePriceInput('  '), isNull);
      expect(validatePriceInput('12.500'), isNull);
    });

    test('error message for invalid input', () {
      expect(validatePriceInput('abc'), 'Precio inválido');
      expect(validatePriceInput('0'), 'Precio inválido');
      expect(validatePriceInput('-3'), 'Precio inválido');
    });
  });

  group('formatPrice', () {
    test('thousands with dot, decimals with comma only when present', () {
      expect(formatPrice(12500), '\$12.500');
      expect(formatPrice(999), '\$999');
      expect(formatPrice(1234567.5), '\$1.234.567,5');
      expect(formatPrice(2.25), '\$2,25');
    });

    test('rounds to at most 2 decimals', () {
      expect(formatPrice(2.256), '\$2,26');
      expect(formatPrice(3.0), '\$3');
    });

    test('zero', () {
      expect(formatPrice(0), '\$0');
    });
  });
}

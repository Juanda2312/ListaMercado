import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/utils/discount.dart';

void main() {
  group('priceFromPercent', () {
    test('applies the percentage to the base price', () {
      expect(priceFromPercent(10000, 15), 8500);
      expect(priceFromPercent(4200, 10), 3780);
    });

    test('rounds to 2 decimals', () {
      expect(priceFromPercent(999, 33.33), 666.03);
      expect(priceFromPercent(1000, 12.5), 875);
    });

    test('percent outside (0, 100) returns null', () {
      expect(priceFromPercent(10000, 0), isNull);
      expect(priceFromPercent(10000, -5), isNull);
      expect(priceFromPercent(10000, 100), isNull);
      expect(priceFromPercent(10000, 150), isNull);
    });

    test('invalid base returns null', () {
      expect(priceFromPercent(0, 10), isNull);
      expect(priceFromPercent(-1000, 10), isNull);
      expect(priceFromPercent(double.infinity, 10), isNull);
    });
  });

  group('percentFromPrice', () {
    test('computes the discount against the base price', () {
      expect(percentFromPrice(10000, 8500), 15);
      expect(percentFromPrice(10000, 9000), 10);
      expect(percentFromPrice(8000, 7000), 12.5);
    });

    test('rounds to 2 decimals', () {
      expect(percentFromPrice(3, 2), 33.33);
    });

    test('price equal to or above base returns null', () {
      expect(percentFromPrice(10000, 10000), isNull);
      expect(percentFromPrice(10000, 12000), isNull);
    });

    test('non-positive price or base returns null', () {
      expect(percentFromPrice(10000, 0), isNull);
      expect(percentFromPrice(10000, -1), isNull);
      expect(percentFromPrice(0, 100), isNull);
    });
  });

  group('parsePercent / validatePercentInput', () {
    test('accepts comma or dot decimals inside (0, 100)', () {
      expect(parsePercent('15'), 15);
      expect(parsePercent('12,5'), 12.5);
      expect(parsePercent('12.5'), 12.5);
      expect(parsePercent('99,99'), 99.99);
    });

    test('rejects empty, invalid, zero, negative and >= 100', () {
      for (final bad in ['', 'abc', '0', '-5', '100', '150']) {
        expect(parsePercent(bad), isNull, reason: bad);
      }
    });

    test('validatePercentInput: null when empty or valid, error otherwise', () {
      expect(validatePercentInput(null), isNull);
      expect(validatePercentInput(''), isNull);
      expect(validatePercentInput('  '), isNull);
      expect(validatePercentInput('15'), isNull);
      expect(validatePercentInput('abc'), 'Descuento inválido');
      expect(validatePercentInput('100'), 'Descuento inválido');
      expect(validatePercentInput('0'), 'Descuento inválido');
    });
  });

  group('formatPercent', () {
    test('no trailing zeros, comma decimal, max 2 decimals', () {
      expect(formatPercent(15), '15%');
      expect(formatPercent(12.5), '12,5%');
      expect(formatPercent(33.33), '33,33%');
      expect(formatPercent(33.333), '33,33%');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/widgets/discount_fields.dart';

final _percent = find.byKey(const Key('discount-percent'));
final _price = find.byKey(const Key('discount-price'));

String _text(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

class _Emitted {
  double? price;
  bool valid = true;
  int calls = 0;
}

Future<_Emitted> _pump(
  WidgetTester tester, {
  double? base = 10000,
  double? initial,
}) async {
  final emitted = _Emitted();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DiscountFields(
            basePrice: base,
            initialTempPrice: initial,
            onChanged: (price, valid) {
              emitted
                ..price = price
                ..valid = valid
                ..calls = emitted.calls + 1;
            },
          ),
        ),
      ),
    ),
  );
  return emitted;
}

void main() {
  testWidgets('typing a percent fills the final price', (tester) async {
    final emitted = await _pump(tester);
    await tester.enterText(_percent, '15');
    await tester.pump();

    expect(_text(tester, _price), '8500');
    expect(emitted.price, 8500);
    expect(emitted.valid, isTrue);
  });

  testWidgets('typing a final price fills the percent', (tester) async {
    final emitted = await _pump(tester);
    await tester.enterText(_price, '8500');
    await tester.pump();

    expect(_text(tester, _percent), '15');
    expect(emitted.price, 8500);
    expect(emitted.valid, isTrue);
  });

  testWidgets('decimal percent is shown with a comma', (tester) async {
    await _pump(tester, base: 8000);
    await tester.enterText(_price, '7000');
    await tester.pump();
    expect(_text(tester, _percent), '12,5');
  });

  testWidgets('clearing one field clears the other and emits null', (
    tester,
  ) async {
    final emitted = await _pump(tester);
    await tester.enterText(_percent, '15');
    await tester.pump();
    await tester.enterText(_percent, '');
    await tester.pump();

    expect(_text(tester, _price), '');
    expect(emitted.price, isNull);
    expect(emitted.valid, isTrue);

    await tester.enterText(_price, '8500');
    await tester.pump();
    await tester.enterText(_price, '');
    await tester.pump();
    expect(_text(tester, _percent), '');
    expect(emitted.price, isNull);
    expect(emitted.valid, isTrue);
  });

  testWidgets("invalid percent ('abc', '0', '100') shows the error", (
    tester,
  ) async {
    final emitted = await _pump(tester);
    for (final bad in ['abc', '0', '100']) {
      await tester.enterText(_percent, bad);
      await tester.pump();
      expect(find.text('Descuento inválido'), findsOneWidget, reason: bad);
      expect(_text(tester, _price), '');
      expect(emitted.price, isNull);
      expect(emitted.valid, isFalse);
    }

    await tester.enterText(_percent, '20');
    await tester.pump();
    expect(find.text('Descuento inválido'), findsNothing);
    expect(emitted.valid, isTrue);
    expect(emitted.price, 8000);
  });

  testWidgets('final price equal to or above the base is invalid', (
    tester,
  ) async {
    final emitted = await _pump(tester);
    for (final bad in ['10000', '12000']) {
      await tester.enterText(_price, bad);
      await tester.pump();
      expect(find.text('Descuento inválido'), findsOneWidget, reason: bad);
      expect(_text(tester, _percent), '');
      expect(emitted.price, isNull);
      expect(emitted.valid, isFalse);
    }
  });

  testWidgets("unparseable final price shows 'Precio inválido'", (
    tester,
  ) async {
    final emitted = await _pump(tester);
    await tester.enterText(_price, 'abc');
    await tester.pump();
    expect(find.text('Precio inválido'), findsOneWidget);
    expect(emitted.valid, isFalse);
  });

  testWidgets('without a base price the percent is disabled and the final '
      'price still works', (tester) async {
    final emitted = await _pump(tester, base: null);
    expect(tester.widget<TextField>(_percent).enabled, isFalse);
    expect(find.text('Sin precio: indica el precio final'), findsOneWidget);

    await tester.enterText(_price, '500');
    await tester.pump();
    expect(emitted.price, 500);
    expect(emitted.valid, isTrue);
    expect(_text(tester, _percent), '');
  });

  testWidgets('initialTempPrice preloads both fields without emitting', (
    tester,
  ) async {
    final emitted = await _pump(tester, initial: 8500);
    expect(_text(tester, _price), '8500');
    expect(_text(tester, _percent), '15');
    expect(emitted.calls, 0);
  });
}

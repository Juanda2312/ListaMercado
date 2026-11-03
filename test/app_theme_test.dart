import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lista_mercado/app.dart';
import 'package:lista_mercado/app_providers.dart';
import 'package:lista_mercado/data/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'ListaMercadoApp defines a light and a dark theme and follows the system',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ListaMercadoApp(providers: AppProviders.create(LocalStorage(prefs))),
      );
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.theme!.brightness, Brightness.light);
      expect(app.darkTheme!.brightness, Brightness.dark);
      expect(app.themeMode, ThemeMode.system);
    },
  );
}

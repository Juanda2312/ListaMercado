import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_providers.dart';
import 'providers/products_provider.dart';
import 'providers/shopping_list_provider.dart';
import 'providers/supermarkets_provider.dart';
import 'screens/home_shell.dart';

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D32),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    appBarTheme: const AppBarTheme(scrolledUnderElevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
    ),
  );
}

class ListaMercadoApp extends StatelessWidget {
  const ListaMercadoApp({super.key, required this.providers});

  final AppProviders providers;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SupermarketsProvider>.value(
          value: providers.supermarkets,
        ),
        ChangeNotifierProvider<ProductsProvider>.value(
          value: providers.products,
        ),
        ChangeNotifierProvider<ShoppingListProvider>.value(
          value: providers.shoppingList,
        ),
      ],
      child: MaterialApp(
        title: 'Lista Mercado',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const HomeShell(),
      ),
    );
  }
}

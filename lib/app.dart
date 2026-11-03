import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_providers.dart';
import 'providers/products_provider.dart';
import 'providers/shopping_list_provider.dart';
import 'providers/supermarkets_provider.dart';
import 'screens/home_shell.dart';

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
        theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
        home: const HomeShell(),
      ),
    );
  }
}

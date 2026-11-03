import 'data/local_storage.dart';
import 'providers/products_provider.dart';
import 'providers/shopping_list_provider.dart';
import 'providers/supermarkets_provider.dart';

class AppProviders {
  final SupermarketsProvider supermarkets;
  final ProductsProvider products;
  final ShoppingListProvider shoppingList;

  AppProviders._(this.supermarkets, this.products, this.shoppingList);

  /// Crea los tres providers y cablea las cascadas de eliminación:
  /// supermercado -> productos (quedan sin supermercado) y
  /// producto -> lista de mercado (se quita de la lista).
  factory AppProviders.create(LocalStorage storage) {
    final shoppingList = ShoppingListProvider(storage: storage);
    final products = ProductsProvider(
      storage: storage,
      onRemoved: shoppingList.removeProduct,
    );
    final supermarkets = SupermarketsProvider(
      storage: storage,
      onRemoved: products.clearSupermarket,
    );
    return AppProviders._(supermarkets, products, shoppingList);
  }
}

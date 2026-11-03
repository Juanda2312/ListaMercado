class ShoppingItem {
  final String productId;
  final int quantity;
  final bool checked;

  const ShoppingItem({
    required this.productId,
    this.quantity = 1,
    this.checked = false,
  });

  ShoppingItem copyWith({int? quantity, bool? checked}) => ShoppingItem(
    productId: productId,
    quantity: quantity ?? this.quantity,
    checked: checked ?? this.checked,
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'checked': checked,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final productId = json['productId'];
    final quantity = json['quantity'] ?? 1;
    final checked = json['checked'] ?? false;
    if (productId is! String || quantity is! int || checked is! bool) {
      throw const FormatException('Ítem de lista inválido');
    }
    return ShoppingItem(
      productId: productId,
      quantity: quantity,
      checked: checked,
    );
  }
}

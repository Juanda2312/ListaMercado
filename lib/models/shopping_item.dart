class ShoppingItem {
  final String productId;
  final int quantity;
  final bool checked;

  /// Precio final con descuento de esta entrada de la lista (opcional).
  /// El porcentaje no se guarda: se calcula contra el precio base del producto.
  final double? tempPrice;

  const ShoppingItem({
    required this.productId,
    this.quantity = 1,
    this.checked = false,
    this.tempPrice,
  });

  ShoppingItem copyWith({
    int? quantity,
    bool? checked,
    double? tempPrice,
    bool clearTempPrice = false,
  }) => ShoppingItem(
    productId: productId,
    quantity: quantity ?? this.quantity,
    checked: checked ?? this.checked,
    tempPrice: clearTempPrice ? null : (tempPrice ?? this.tempPrice),
  );

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'quantity': quantity,
    'checked': checked,
    if (tempPrice != null) 'tempPrice': tempPrice,
  };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    final productId = json['productId'];
    final quantity = json['quantity'] ?? 1;
    final checked = json['checked'] ?? false;
    if (productId is! String || quantity is! int || checked is! bool) {
      throw const FormatException('Ítem de lista inválido');
    }
    // Un tempPrice ausente o inválido se ignora: nunca descarta el ítem.
    final rawTemp = json['tempPrice'];
    final tempPrice = rawTemp is num && rawTemp.isFinite && rawTemp > 0
        ? rawTemp.toDouble()
        : null;
    return ShoppingItem(
      productId: productId,
      quantity: quantity,
      checked: checked,
      tempPrice: tempPrice,
    );
  }
}

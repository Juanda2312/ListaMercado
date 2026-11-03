class Product {
  final String id;
  final String name;
  final String? supermarketId;
  final double? price;

  const Product({
    required this.id,
    required this.name,
    this.supermarketId,
    this.price,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'supermarketId': supermarketId,
    'price': price,
  };

  factory Product.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final supermarketId = json['supermarketId'];
    final price = json['price'];
    if (id is! String || name is! String) {
      throw const FormatException('Producto inválido');
    }
    if (supermarketId != null && supermarketId is! String) {
      throw const FormatException('supermarketId inválido');
    }
    if (price != null && price is! num) {
      throw const FormatException('price inválido');
    }
    return Product(
      id: id,
      name: name,
      supermarketId: supermarketId as String?,
      price: (price as num?)?.toDouble(),
    );
  }
}

class Supermarket {
  final String id;
  final String name;

  const Supermarket({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Supermarket.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    if (id is! String || name is! String) {
      throw const FormatException('Supermercado inválido');
    }
    return Supermarket(id: id, name: name);
  }
}

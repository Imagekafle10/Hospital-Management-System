class Medicine {
  final int id;
  final String name;
  final String? genericName;
  final String? category;
  final String unit;
  final int stockQuantity;

  Medicine({
    required this.id,
    required this.name,
    this.genericName,
    this.category,
    this.unit = 'Tablet',
    this.stockQuantity = 0,
  });

  bool get inStock => stockQuantity > 0;

  /// "Paracetamol (Acetaminophen)" style label for pickers.
  String get label => (genericName != null && genericName!.isNotEmpty)
      ? '$name ($genericName)'
      : name;

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        genericName: json['genericName'] as String?,
        category: json['category'] as String?,
        unit: json['unit'] as String? ?? 'Tablet',
        stockQuantity: (json['stockQuantity'] as num?)?.toInt() ?? 0,
      );
}

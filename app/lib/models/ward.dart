class Ward {
  final int id;
  final String name;
  final String wardType;
  final int? floorNumber;
  final String? description;
  final int totalBeds;
  final int availableBeds;

  Ward({
    required this.id,
    required this.name,
    required this.wardType,
    this.floorNumber,
    this.description,
    required this.totalBeds,
    required this.availableBeds,
  });

  factory Ward.fromJson(Map<String, dynamic> json) => Ward(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        wardType: json['wardType'] as String? ?? 'General',
        floorNumber: json['floorNumber'] as int?,
        description: json['description'] as String?,
        totalBeds: json['totalBeds'] as int? ?? 0,
        availableBeds: json['availableBeds'] as int? ?? 0,
      );
}

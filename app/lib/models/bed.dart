class Bed {
  final int id;
  final int wardId;
  final String bedNumber;
  final String status;
  final String? wardName;
  final String? wardType;

  Bed({
    required this.id,
    required this.wardId,
    required this.bedNumber,
    required this.status,
    this.wardName,
    this.wardType,
  });

  factory Bed.fromJson(Map<String, dynamic> json) => Bed(
        id: json['id'] as int,
        wardId: json['wardId'] as int,
        bedNumber: json['bedNumber'] as String? ?? '',
        status: json['status'] as String? ?? 'Available',
        wardName: json['wardName'] as String?,
        wardType: json['wardType'] as String?,
      );
}

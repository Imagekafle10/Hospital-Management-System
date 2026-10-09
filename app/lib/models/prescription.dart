class Prescription {
  final int id;
  final int appointmentId;
  final String medication;
  final String? dosage;
  final String? instructions;
  final DateTime createdAt;

  Prescription({
    required this.id,
    required this.appointmentId,
    required this.medication,
    this.dosage,
    this.instructions,
    required this.createdAt,
  });

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
        id: json['id'] as int,
        appointmentId: json['appointmentId'] as int,
        medication: json['medication'] as String? ?? '',
        dosage: json['dosage'] as String?,
        instructions: json['instructions'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

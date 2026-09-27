class Appointment {
  final int id;
  final int patientId;
  final int doctorId;
  final DateTime appointmentDate;
  final String? reason;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? patientName;
  final String? doctorName;
  final String? doctorSpecialization;

  Appointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.appointmentDate,
    this.reason,
    required this.status,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.patientName,
    this.doctorName,
    this.doctorSpecialization,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'] as int,
        patientId: json['patientId'] as int,
        doctorId: json['doctorId'] as int,
        appointmentDate: DateTime.parse(json['appointmentDate'] as String),
        reason: json['reason'] as String?,
        status: json['status'] as String? ?? 'Pending',
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
        patientName: json['patientName'] as String?,
        doctorName: json['doctorName'] as String?,
        doctorSpecialization: json['doctorSpecialization'] as String?,
      );
}

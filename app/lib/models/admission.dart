class Admission {
  final int id;
  final int patientId;
  final int admittingDoctorId;
  final int bedId;
  final DateTime admissionDate;
  final DateTime? expectedDischargeDate;
  final DateTime? dischargeDate;
  final String reasonForAdmission;
  final String status;
  final String? dischargeSummary;
  final String? patientName;
  final String? doctorName;
  final String? bedNumber;
  final String? wardName;

  Admission({
    required this.id,
    required this.patientId,
    required this.admittingDoctorId,
    required this.bedId,
    required this.admissionDate,
    this.expectedDischargeDate,
    this.dischargeDate,
    required this.reasonForAdmission,
    required this.status,
    this.dischargeSummary,
    this.patientName,
    this.doctorName,
    this.bedNumber,
    this.wardName,
  });

  bool get isActive => status == 'Admitted';

  factory Admission.fromJson(Map<String, dynamic> json) => Admission(
        id: json['id'] as int,
        patientId: json['patientId'] as int,
        admittingDoctorId: json['admittingDoctorId'] as int,
        bedId: json['bedId'] as int,
        admissionDate: json['admissionDate'] != null
            ? DateTime.parse(json['admissionDate'] as String)
            : DateTime.now(),
        expectedDischargeDate: json['expectedDischargeDate'] != null
            ? DateTime.tryParse(json['expectedDischargeDate'] as String)
            : null,
        dischargeDate: json['dischargeDate'] != null
            ? DateTime.tryParse(json['dischargeDate'] as String)
            : null,
        reasonForAdmission: json['reasonForAdmission'] as String? ?? '',
        status: json['status'] as String? ?? 'Admitted',
        dischargeSummary: json['dischargeSummary'] as String?,
        patientName: json['patientName'] as String?,
        doctorName: json['doctorName'] as String?,
        bedNumber: json['bedNumber'] as String?,
        wardName: json['wardName'] as String?,
      );
}

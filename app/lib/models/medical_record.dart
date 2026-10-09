class MedicalRecord {
  final int id;
  final int patientId;
  final int? doctorId;
  final int? appointmentId;
  final String recordType;
  final String title;
  final String? description;
  final String fileName;
  final String contentType;
  final int fileSizeBytes;
  final int uploadedByUserId;
  final DateTime createdAt;

  MedicalRecord({
    required this.id,
    required this.patientId,
    this.doctorId,
    this.appointmentId,
    required this.recordType,
    required this.title,
    this.description,
    required this.fileName,
    required this.contentType,
    required this.fileSizeBytes,
    required this.uploadedByUserId,
    required this.createdAt,
  });

  String get fileSizeLabel {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory MedicalRecord.fromJson(Map<String, dynamic> json) => MedicalRecord(
        id: json['id'] as int,
        patientId: json['patientId'] as int,
        doctorId: json['doctorId'] as int?,
        appointmentId: json['appointmentId'] as int?,
        recordType: json['recordType'] as String? ?? 'Other',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        fileName: json['fileName'] as String? ?? '',
        contentType: json['contentType'] as String? ?? '',
        fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
        uploadedByUserId: json['uploadedByUserId'] as int? ?? 0,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

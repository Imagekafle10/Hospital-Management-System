class Doctor {
  final int id;
  final int userId;
  final String specialization;
  final String licenseNumber;
  final double consultationFee;
  final int yearsOfExperience;
  final String? availableFrom;
  final String? availableTo;
  final String? fullName;
  final String? email;
  final String? phone;

  Doctor({
    required this.id,
    required this.userId,
    required this.specialization,
    required this.licenseNumber,
    required this.consultationFee,
    required this.yearsOfExperience,
    this.availableFrom,
    this.availableTo,
    this.fullName,
    this.email,
    this.phone,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
        id: json['id'] as int,
        userId: json['userId'] as int,
        specialization: json['specialization'] as String? ?? '',
        licenseNumber: json['licenseNumber'] as String? ?? '',
        consultationFee: (json['consultationFee'] as num?)?.toDouble() ?? 0,
        yearsOfExperience: json['yearsOfExperience'] as int? ?? 0,
        availableFrom: json['availableFrom'] as String?,
        availableTo: json['availableTo'] as String?,
        fullName: json['fullName'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
      );
}

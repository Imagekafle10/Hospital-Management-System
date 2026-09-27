class Patient {
  final int id;
  final int userId;
  final DateTime? dateOfBirth;
  final String? gender;
  final String? bloodGroup;
  final String? address;
  final String? emergencyContact;
  final String? fullName;
  final String? email;
  final String? phone;

  Patient({
    required this.id,
    required this.userId,
    this.dateOfBirth,
    this.gender,
    this.bloodGroup,
    this.address,
    this.emergencyContact,
    this.fullName,
    this.email,
    this.phone,
  });

  factory Patient.fromJson(Map<String, dynamic> json) => Patient(
        id: json['id'] as int,
        userId: json['userId'] as int,
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.tryParse(json['dateOfBirth'] as String)
            : null,
        gender: json['gender'] as String?,
        bloodGroup: json['bloodGroup'] as String?,
        address: json['address'] as String?,
        emergencyContact: json['emergencyContact'] as String?,
        fullName: json['fullName'] as String?,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
      );
}

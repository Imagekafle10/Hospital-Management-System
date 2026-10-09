class AuthResponse {
  final String token;
  final int userId;
  final String fullName;
  final String role;
  final DateTime expiresAt;

  AuthResponse({
    required this.token,
    required this.userId,
    required this.fullName,
    required this.role,
    required this.expiresAt,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        userId: json['userId'] as int,
        fullName: json['fullName'] as String,
        role: json['role'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

class AppSession {
  final int userId;
  final String fullName;
  final String role;
  final DateTime expiresAt;

  AppSession({
    required this.userId,
    required this.fullName,
    required this.role,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isAdmin => role == 'Admin';
  bool get isDoctor => role == 'Doctor';
  bool get isPatient => role == 'Patient';
}

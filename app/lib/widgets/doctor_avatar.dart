import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../theme/app_theme.dart';

/// Doctor profile picture; falls back to the first letter of the name.
class DoctorAvatar extends StatelessWidget {
  final Doctor doctor;
  final double radius;
  const DoctorAvatar({super.key, required this.doctor, this.radius = 26});

  @override
  Widget build(BuildContext context) {
    final initial =
        (doctor.fullName?.isNotEmpty == true ? doctor.fullName![0] : '?').toUpperCase();
    final fallback = Text(
      initial,
      style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.7),
    );
    final url = doctor.photoUrl;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: url == null
          ? fallback
          : ClipOval(
              child: Image.network(
                url,
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            ),
    );
  }
}

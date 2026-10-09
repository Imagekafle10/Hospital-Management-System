using System.ComponentModel.DataAnnotations;

namespace HospitalMgmtSystem.DTOs;

// Admin creates any account: Admin, Doctor, Patient or Pharmacist.
public class AdminCreateUserDto
{
    [Required] public string FullName { get; set; } = string.Empty;
    [Required, EmailAddress] public string Email { get; set; } = string.Empty;
    [Required, MinLength(6)] public string Password { get; set; } = string.Empty;
    [Required] public string Role { get; set; } = "Patient";
    public string? Phone { get; set; }

    // Doctor
    public string? Specialization { get; set; }
    public string? LicenseNumber { get; set; }
    public decimal? ConsultationFee { get; set; }
    public int? YearsOfExperience { get; set; }

    // Patient
    public DateTime? DateOfBirth { get; set; }
    public string? Gender { get; set; }
    public string? BloodGroup { get; set; }
    public string? Address { get; set; }
    public string? EmergencyContact { get; set; }
}

public class AdminUpdateUserDto
{
    public string? FullName { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public bool? IsActive { get; set; }
    public string? NewPassword { get; set; }
}

public class AdminUpdateDoctorDto : AdminUpdateUserDto
{
    public string? Specialization { get; set; }
    public string? LicenseNumber { get; set; }
    public decimal? ConsultationFee { get; set; }
    public int? YearsOfExperience { get; set; }
    public TimeSpan? AvailableFrom { get; set; }
    public TimeSpan? AvailableTo { get; set; }
}

public class AdminUpdatePatientDto : AdminUpdateUserDto
{
    public DateTime? DateOfBirth { get; set; }
    public string? Gender { get; set; }
    public string? BloodGroup { get; set; }
    public string? Address { get; set; }
    public string? EmergencyContact { get; set; }
}

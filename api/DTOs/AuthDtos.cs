using System.ComponentModel.DataAnnotations;

namespace HospitalMgmtSystem.DTOs;

public class RegisterDto
{
    [Required] public string FullName { get; set; } = string.Empty;
    [Required, EmailAddress] public string Email { get; set; } = string.Empty;
    [Required, MinLength(6)] public string Password { get; set; } = string.Empty;
    public string? Phone { get; set; }

    // "Doctor" or "Patient" (Admin accounts are created separately, not via public register)
    [Required] public string Role { get; set; } = "Patient";

    // Required when Role == "Doctor"
    public string? Specialization { get; set; }
    public string? LicenseNumber { get; set; }
    public decimal? ConsultationFee { get; set; }

    // Optional, used when Role == "Patient"
    public DateTime? DateOfBirth { get; set; }
    public string? Gender { get; set; }
    public string? BloodGroup { get; set; }
    public string? Address { get; set; }
}

public class LoginDto
{
    [Required, EmailAddress] public string Email { get; set; } = string.Empty;
    [Required] public string Password { get; set; } = string.Empty;
}

public class AuthResponseDto
{
    public string Token { get; set; } = string.Empty;
    public int UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
}

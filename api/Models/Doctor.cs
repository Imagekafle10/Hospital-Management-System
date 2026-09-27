namespace HospitalMgmtSystem.Models;

public class Doctor
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public string Specialization { get; set; } = string.Empty;
    public string LicenseNumber { get; set; } = string.Empty;
    public decimal ConsultationFee { get; set; }
    public int YearsOfExperience { get; set; }
    public TimeSpan? AvailableFrom { get; set; }
    public TimeSpan? AvailableTo { get; set; }
    public DateTime CreatedAt { get; set; }

    // Joined fields (populated from Users table via JOIN, not stored here)
    public string? FullName { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
}

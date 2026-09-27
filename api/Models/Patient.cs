namespace HospitalMgmtSystem.Models;

public class Patient
{
    public int Id { get; set; }
    public int UserId { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public string? Gender { get; set; }
    public string? BloodGroup { get; set; }
    public string? Address { get; set; }
    public string? EmergencyContact { get; set; }
    public DateTime CreatedAt { get; set; }

    // Joined fields (populated from Users table via JOIN, not stored here)
    public string? FullName { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
}

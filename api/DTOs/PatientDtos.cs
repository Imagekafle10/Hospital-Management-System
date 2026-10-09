namespace HospitalMgmtSystem.DTOs;

public class PatientUpdateDto
{
    public DateTime? DateOfBirth { get; set; }
    public string? Gender { get; set; }
    public string? BloodGroup { get; set; }
    public string? Address { get; set; }
    public string? EmergencyContact { get; set; }
}

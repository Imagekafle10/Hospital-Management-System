namespace HospitalMgmtSystem.Models;

public class Prescription
{
    public int Id { get; set; }
    public int AppointmentId { get; set; }
    public string Medication { get; set; } = string.Empty;
    public string? Dosage { get; set; }
    public string? Instructions { get; set; }
    public DateTime CreatedAt { get; set; }
}

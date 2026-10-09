namespace HospitalMgmtSystem.Models;

public class Admission
{
    public int Id { get; set; }
    public int PatientId { get; set; }
    public int AdmittingDoctorId { get; set; }
    public int BedId { get; set; }

    public DateTime AdmissionDate { get; set; }
    public DateTime? ExpectedDischargeDate { get; set; }
    public DateTime? DischargeDate { get; set; }

    public string ReasonForAdmission { get; set; } = string.Empty;

    // "Admitted", "Discharged"
    public string Status { get; set; } = "Admitted";
    public string? DischargeSummary { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }

    // Joined convenience fields
    public string? PatientName { get; set; }
    public string? DoctorName { get; set; }
    public string? BedNumber { get; set; }
    public string? WardName { get; set; }
}

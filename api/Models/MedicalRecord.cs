namespace HospitalMgmtSystem.Models;

public class MedicalRecord
{
    public int Id { get; set; }
    public int PatientId { get; set; }
    public int? DoctorId { get; set; }
    public int? AppointmentId { get; set; }

    // "LabReport", "Prescription", "Diagnosis", "Imaging", "Other"
    public string RecordType { get; set; } = "Other";
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }

    public string FileName { get; set; } = string.Empty;
    public string StoredFileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }

    public int UploadedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
}

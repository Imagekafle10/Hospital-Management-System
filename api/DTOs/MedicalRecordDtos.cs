using System.ComponentModel.DataAnnotations;

namespace HospitalMgmtSystem.DTOs;

public class UploadMedicalRecordDto
{
    // Required only when an Admin/Doctor uploads on behalf of a patient.
    // Ignored (and derived from the token) when the caller is a Patient.
    public int? PatientId { get; set; }

    public int? AppointmentId { get; set; }

    [Required] public string RecordType { get; set; } = "Other";
    [Required] public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }

    [Required] public IFormFile File { get; set; } = null!;
}

public class MedicalRecordResponseDto
{
    public int Id { get; set; }
    public int PatientId { get; set; }
    public int? DoctorId { get; set; }
    public int? AppointmentId { get; set; }
    public string RecordType { get; set; } = string.Empty;
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string FileName { get; set; } = string.Empty;
    public string ContentType { get; set; } = string.Empty;
    public long FileSizeBytes { get; set; }
    public int UploadedByUserId { get; set; }
    public DateTime CreatedAt { get; set; }
}

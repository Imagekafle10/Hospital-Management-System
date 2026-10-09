using System.ComponentModel.DataAnnotations;

namespace HospitalMgmtSystem.DTOs;

public class CreateAppointmentDto
{
    [Required] public int DoctorId { get; set; }
    [Required] public DateTime AppointmentDate { get; set; }
    public string? Reason { get; set; }

    // Previously uploaded medical records (ids) the patient wants the doctor to see
    public List<int>? RecordIds { get; set; }
}

public class UpdateAppointmentStatusDto
{
    // "Pending", "Confirmed", "Completed", "Cancelled"
    [Required] public string Status { get; set; } = string.Empty;
    public string? Notes { get; set; }
}

public class SetFollowUpDto
{
    // false = clear any follow-up
    public bool Required { get; set; }
    public DateTime? Date { get; set; }
    [MaxLength(500)] public string? Notes { get; set; }
}

public class CreatePrescriptionDto
{
    [Required] public string Medication { get; set; } = string.Empty;
    public string? Dosage { get; set; }
    public string? Instructions { get; set; }
}

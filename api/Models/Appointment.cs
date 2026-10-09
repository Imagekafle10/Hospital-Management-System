namespace HospitalMgmtSystem.Models;

public class Appointment
{
    public int Id { get; set; }
    public int PatientId { get; set; }
    public int DoctorId { get; set; }
    public DateTime AppointmentDate { get; set; }
    public string? Reason { get; set; }

    // "Pending", "Confirmed", "Completed", "Cancelled"
    public string Status { get; set; } = "Pending";
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }

    // Follow-up (set by the doctor after the checkup is Completed)
    public bool FollowUpRequired { get; set; }
    public DateTime? FollowUpDate { get; set; }
    public string? FollowUpNotes { get; set; }

    // Joined fields for convenient display
    public string? PatientName { get; set; }
    public string? DoctorName { get; set; }
    public string? DoctorSpecialization { get; set; }
}

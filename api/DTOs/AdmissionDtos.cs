using System.ComponentModel.DataAnnotations;

namespace HospitalMgmtSystem.DTOs;

public class CreateAdmissionDto
{
    [Required] public int PatientId { get; set; }
    [Required] public int BedId { get; set; }
    [Required] public string ReasonForAdmission { get; set; } = string.Empty;
    public DateTime? ExpectedDischargeDate { get; set; }

    // Required only when an Admin creates the admission. Ignored (derived from the token) when a Doctor creates it.
    public int? AdmittingDoctorId { get; set; }
}

public class DischargeAdmissionDto
{
    public string? DischargeSummary { get; set; }
}

public class TransferBedDto
{
    [Required] public int NewBedId { get; set; }
}

using System.ComponentModel.DataAnnotations;

namespace HospitalMgmtSystem.DTOs;

public class CreateBedDto
{
    [Required] public string BedNumber { get; set; } = string.Empty;
}

public class UpdateBedStatusDto
{
    // "Available", "Maintenance" (use admission endpoints to occupy/free a bed)
    [Required] public string Status { get; set; } = string.Empty;
}

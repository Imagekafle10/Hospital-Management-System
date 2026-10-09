using System.ComponentModel.DataAnnotations;

namespace HospitalMgmtSystem.DTOs;

public class CreateWardDto
{
    [Required] public string Name { get; set; } = string.Empty;

    // "General", "ICU", "Private", "Maternity", "Emergency"
    [Required] public string WardType { get; set; } = "General";
    public int? FloorNumber { get; set; }
    public string? Description { get; set; }
}

public class UpdateWardDto
{
    public string? Name { get; set; }
    public string? WardType { get; set; }
    public int? FloorNumber { get; set; }
    public string? Description { get; set; }
}

namespace HospitalMgmtSystem.Models;

public class Ward
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;

    // "General", "ICU", "Private", "Maternity", "Emergency"
    public string WardType { get; set; } = "General";
    public int? FloorNumber { get; set; }
    public string? Description { get; set; }
    public DateTime CreatedAt { get; set; }

    // Aggregate convenience fields (populated by the repository, not stored)
    public int TotalBeds { get; set; }
    public int AvailableBeds { get; set; }
}

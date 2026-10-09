namespace HospitalMgmtSystem.Models;

public class Bed
{
    public int Id { get; set; }
    public int WardId { get; set; }
    public string BedNumber { get; set; } = string.Empty;

    // "Available", "Occupied", "Maintenance"
    public string Status { get; set; } = "Available";
    public DateTime CreatedAt { get; set; }

    // Joined convenience fields
    public string? WardName { get; set; }
    public string? WardType { get; set; }
}

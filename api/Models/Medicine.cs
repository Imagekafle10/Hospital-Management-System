namespace HospitalMgmtSystem.Models;

public class Medicine
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? GenericName { get; set; }
    public string? Category { get; set; }
    public string? Manufacturer { get; set; }
    public string? BatchNumber { get; set; }
    // "Tablet", "Capsule", "Syrup", "Injection", "Ointment", ...
    public string Unit { get; set; } = "Tablet";
    public decimal UnitPrice { get; set; }
    public int StockQuantity { get; set; }
    public int ReorderLevel { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; }

    // Computed (not stored)
    public bool IsLowStock => StockQuantity <= ReorderLevel;
    public bool IsExpired => ExpiryDate.HasValue && ExpiryDate.Value.Date < DateTime.UtcNow.Date;
}

public class PharmacyDispense
{
    public int Id { get; set; }
    public int? PrescriptionId { get; set; }
    public int PatientId { get; set; }
    public string? PatientName { get; set; }
    public int MedicineId { get; set; }
    public string? MedicineName { get; set; }
    public int Quantity { get; set; }
    public decimal UnitPrice { get; set; }
    public decimal TotalPrice { get; set; }
    public int DispensedByUserId { get; set; }
    public string? Notes { get; set; }
    public DateTime CreatedAt { get; set; }
}

using System.ComponentModel.DataAnnotations;

namespace HospitalMgmtSystem.DTOs;

public class CreateMedicineDto
{
    [Required] public string Name { get; set; } = string.Empty;
    public string? GenericName { get; set; }
    public string? Category { get; set; }
    public string? Manufacturer { get; set; }
    public string? BatchNumber { get; set; }
    public string Unit { get; set; } = "Tablet";
    [Range(0, 1000000)] public decimal UnitPrice { get; set; }
    [Range(0, int.MaxValue)] public int StockQuantity { get; set; }
    [Range(0, int.MaxValue)] public int ReorderLevel { get; set; } = 10;
    public DateTime? ExpiryDate { get; set; }
}

public class UpdateMedicineDto
{
    public string? Name { get; set; }
    public string? GenericName { get; set; }
    public string? Category { get; set; }
    public string? Manufacturer { get; set; }
    public string? BatchNumber { get; set; }
    public string? Unit { get; set; }
    public decimal? UnitPrice { get; set; }
    public int? ReorderLevel { get; set; }
    public DateTime? ExpiryDate { get; set; }
    public bool? IsActive { get; set; }
}

public class RestockDto
{
    // Positive = add stock, negative = remove (damaged/expired)
    [Required] public int Quantity { get; set; }
    public string? BatchNumber { get; set; }
    public DateTime? ExpiryDate { get; set; }
}

public class DispenseDto
{
    [Required] public int PatientId { get; set; }
    [Required] public int MedicineId { get; set; }
    [Required, Range(1, 100000)] public int Quantity { get; set; }
    public int? PrescriptionId { get; set; }
    public string? Notes { get; set; }
}

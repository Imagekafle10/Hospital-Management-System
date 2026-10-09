namespace HospitalMgmtSystem.Models;

public class Payment
{
    public int Id { get; set; }
    public int AppointmentId { get; set; }
    public int PatientId { get; set; }
    public decimal Amount { get; set; }

    // "Esewa", "Khalti", "COD"
    public string Method { get; set; } = string.Empty;

    // "Pending", "Success", "Failed", "Cancelled"
    public string Status { get; set; } = "Pending";

    // Our own reference sent to the gateway (esewa transaction_uuid / khalti purchase_order_id)
    public string TransactionUuid { get; set; } = string.Empty;

    // Reference returned by the gateway once paid (esewa ref_id / khalti transaction_id), null for COD until settled
    public string? GatewayReference { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime? PaidAt { get; set; }

    // Joined convenience fields
    public string? PatientName { get; set; }
    public string? DoctorName { get; set; }
}

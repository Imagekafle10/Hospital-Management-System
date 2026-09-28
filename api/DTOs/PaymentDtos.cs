using System.ComponentModel.DataAnnotations;

namespace HospitalMgmtSystem.DTOs;

public class InitiatePaymentDto
{
    [Required] public int AppointmentId { get; set; }

    // "Esewa", "Khalti", "COD" (case-insensitive)
    [Required] public string Method { get; set; } = string.Empty;
}

public class EsewaInitiateResponseDto
{
    public int PaymentId { get; set; }
    public string GatewayUrl { get; set; } = string.Empty;
    public Dictionary<string, string> FormFields { get; set; } = new();
}

public class KhaltiInitiateResponseDto
{
    public int PaymentId { get; set; }
    public string PaymentUrl { get; set; } = string.Empty;
    public string Pidx { get; set; } = string.Empty;
}

public class CodConfirmDto
{
    public int PaymentId { get; set; }
    public string Message { get; set; } = "Cash on delivery selected. Please pay at the hospital counter.";
}

public class KhaltiVerifyDto
{
    [Required] public string Pidx { get; set; } = string.Empty;
}

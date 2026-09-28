using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace HospitalMgmtSystem.Services;

public class EsewaVerifyResult
{
    public bool Success { get; set; }
    public string? TransactionUuid { get; set; }
    public string? RefId { get; set; }
    public string? Status { get; set; }
    public string? Message { get; set; }
}

public interface IEsewaService
{
    Dictionary<string, string> BuildFormFields(decimal amount, string transactionUuid);
    string GatewayUrl { get; }
    EsewaVerifyResult VerifyCallback(string base64Data);
}

/// <summary>
/// eSewa ePay v2 integration (form POST + signature verification).
/// Docs: https://developer.esewa.com.np/pages/Epay#introduction
/// </summary>
public class EsewaService : IEsewaService
{
    private readonly string _merchantCode;
    private readonly string _secretKey;
    private readonly string _successUrl;
    private readonly string _failureUrl;
    private readonly string _gatewayUrl;

    public EsewaService(IConfiguration configuration)
    {
        _merchantCode = configuration["Payments:Esewa:MerchantCode"] ?? "EPAYTEST";
        _secretKey = configuration["Payments:Esewa:SecretKey"] ?? "8gBm/:&EnhH.1/q(";
        _successUrl = configuration["Payments:Esewa:SuccessUrl"] ?? "https://localhost:5001/api/payments/esewa/verify";
        _failureUrl = configuration["Payments:Esewa:FailureUrl"] ?? "https://localhost:5001/api/payments/failed";
        _gatewayUrl = configuration["Payments:Esewa:BaseUrl"] ?? "https://rc-epay.esewa.com.np/api/epay/main/v2/form";
    }

    public string GatewayUrl => _gatewayUrl;

    public Dictionary<string, string> BuildFormFields(decimal amount, string transactionUuid)
    {
        var totalAmount = amount.ToString("0.00");
        var signedFieldNames = "total_amount,transaction_uuid,product_code";
        var message = $"total_amount={totalAmount},transaction_uuid={transactionUuid},product_code={_merchantCode}";
        var signature = Sign(message);

        return new Dictionary<string, string>
        {
            ["amount"] = totalAmount,
            ["tax_amount"] = "0",
            ["total_amount"] = totalAmount,
            ["transaction_uuid"] = transactionUuid,
            ["product_code"] = _merchantCode,
            ["product_service_charge"] = "0",
            ["product_delivery_charge"] = "0",
            ["success_url"] = _successUrl,
            ["failure_url"] = _failureUrl,
            ["signed_field_names"] = signedFieldNames,
            ["signature"] = signature
        };
    }

    // eSewa redirects to success_url with a base64-encoded JSON payload in the "data" query param.
    public EsewaVerifyResult VerifyCallback(string base64Data)
    {
        try
        {
            var json = Encoding.UTF8.GetString(Convert.FromBase64String(base64Data));
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            var status = root.GetProperty("status").GetString();
            var transactionUuid = root.GetProperty("transaction_uuid").GetString();
            var totalAmount = root.GetProperty("total_amount").GetString();
            var productCode = root.GetProperty("product_code").GetString();
            var signature = root.GetProperty("signature").GetString();
            var refId = root.TryGetProperty("transaction_code", out var refEl) ? refEl.GetString() : null;

            var message = $"total_amount={totalAmount},transaction_uuid={transactionUuid},product_code={productCode}";
            var expectedSignature = Sign(message);

            if (signature != expectedSignature)
            {
                return new EsewaVerifyResult { Success = false, Message = "Signature mismatch.", TransactionUuid = transactionUuid };
            }

            return new EsewaVerifyResult
            {
                Success = status == "COMPLETE",
                TransactionUuid = transactionUuid,
                RefId = refId,
                Status = status,
                Message = status == "COMPLETE" ? "Payment verified." : $"Payment status: {status}"
            };
        }
        catch (Exception ex)
        {
            return new EsewaVerifyResult { Success = false, Message = $"Could not parse eSewa response: {ex.Message}" };
        }
    }

    private string Sign(string message)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(_secretKey));
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(message));
        return Convert.ToBase64String(hash);
    }
}

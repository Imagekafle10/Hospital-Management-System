using System.Net.Http.Headers;
using System.Net.Http.Json;

namespace HospitalMgmtSystem.Services;

public class KhaltiInitiateResult
{
    public bool Success { get; set; }
    public string? Pidx { get; set; }
    public string? PaymentUrl { get; set; }
    public string? Message { get; set; }
}

public class KhaltiVerifyResult
{
    public bool Success { get; set; }
    public string? Status { get; set; }
    public string? TransactionId { get; set; }
    public decimal AmountPaidNpr { get; set; }
    public string? Message { get; set; }
}

public interface IKhaltiService
{
    Task<KhaltiInitiateResult> InitiateAsync(decimal amountNpr, string purchaseOrderId, string purchaseOrderName, string customerName, string customerEmail);
    Task<KhaltiVerifyResult> VerifyAsync(string pidx);
}

/// <summary>
/// Khalti ePayment (Web Checkout) integration.
/// Docs: https://docs.khalti.com/khalti-epayment/
/// </summary>
public class KhaltiService : IKhaltiService
{
    private readonly HttpClient _http;
    private readonly string _secretKey;
    private readonly string _returnUrl;
    private readonly string _websiteUrl;
    private readonly string _baseUrl;

    public KhaltiService(HttpClient http, IConfiguration configuration)
    {
        _http = http;
        _secretKey = configuration["Payments:Khalti:SecretKey"] ?? "test_secret_key_00000000000000000000000000000000";
        _returnUrl = configuration["Payments:Khalti:ReturnUrl"] ?? "https://localhost:5001/api/payments/khalti/return";
        _websiteUrl = configuration["Payments:Khalti:WebsiteUrl"] ?? "https://localhost:5001";
        _baseUrl = configuration["Payments:Khalti:BaseUrl"] ?? "https://dev.khalti.com/api/v2/epayment/";

        _http.BaseAddress = new Uri(_baseUrl);
        _http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Key", _secretKey);
    }

    public async Task<KhaltiInitiateResult> InitiateAsync(decimal amountNpr, string purchaseOrderId, string purchaseOrderName, string customerName, string customerEmail)
    {
        try
        {
            var payload = new
            {
                return_url = _returnUrl,
                website_url = _websiteUrl,
                amount = (int)(amountNpr * 100), // Khalti expects paisa
                purchase_order_id = purchaseOrderId,
                purchase_order_name = purchaseOrderName,
                customer_info = new { name = customerName, email = customerEmail }
            };

            var response = await _http.PostAsJsonAsync("initiate/", payload);
            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                return new KhaltiInitiateResult { Success = false, Message = $"Khalti initiate failed: {errorBody}" };
            }

            var result = await response.Content.ReadFromJsonAsync<KhaltiInitiateApiResponse>();
            return new KhaltiInitiateResult
            {
                Success = true,
                Pidx = result?.pidx,
                PaymentUrl = result?.payment_url
            };
        }
        catch (Exception ex)
        {
            return new KhaltiInitiateResult { Success = false, Message = $"Khalti initiate error: {ex.Message}" };
        }
    }

    public async Task<KhaltiVerifyResult> VerifyAsync(string pidx)
    {
        try
        {
            var response = await _http.PostAsJsonAsync("lookup/", new { pidx });
            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                return new KhaltiVerifyResult { Success = false, Message = $"Khalti lookup failed: {errorBody}" };
            }

            var result = await response.Content.ReadFromJsonAsync<KhaltiLookupApiResponse>();
            var isComplete = result?.status == "Completed";

            return new KhaltiVerifyResult
            {
                Success = isComplete,
                Status = result?.status,
                TransactionId = result?.transaction_id,
                AmountPaidNpr = (result?.total_amount ?? 0) / 100m,
                Message = isComplete ? "Payment verified." : $"Payment status: {result?.status}"
            };
        }
        catch (Exception ex)
        {
            return new KhaltiVerifyResult { Success = false, Message = $"Khalti verify error: {ex.Message}" };
        }
    }

    private class KhaltiInitiateApiResponse
    {
        public string? pidx { get; set; }
        public string? payment_url { get; set; }
    }

    private class KhaltiLookupApiResponse
    {
        public string? pidx { get; set; }
        public string? status { get; set; }
        public long? total_amount { get; set; }
        public string? transaction_id { get; set; }
    }
}

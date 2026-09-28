using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IPaymentRepository
{
    Task<int> CreateAsync(int appointmentId, int patientId, decimal amount, string method, string transactionUuid);
    Task<Payment?> GetByIdAsync(int id);
    Task<Payment?> GetByTransactionUuidAsync(string transactionUuid);
    Task<Payment?> GetByGatewayReferenceAsync(string gatewayReference);
    Task<List<Payment>> GetByAppointmentIdAsync(int appointmentId);
    Task<List<Payment>> GetByPatientIdAsync(int patientId);
    Task<List<Payment>> GetAllAsync();
    Task<bool> UpdateStatusAsync(int id, string status, string? gatewayReference);
    Task<bool> HasSuccessfulPaymentAsync(int appointmentId);
}

public class PaymentRepository : IPaymentRepository
{
    private readonly ISqlConnectionFactory _factory;

    public PaymentRepository(ISqlConnectionFactory factory)
    {
        _factory = factory;
    }

    private const string BaseSelect = @"
        SELECT pay.Id, pay.AppointmentId, pay.PatientId, pay.Amount, pay.Method, pay.Status,
               pay.TransactionUuid, pay.GatewayReference, pay.CreatedAt, pay.PaidAt,
               up.FullName AS PatientName, ud.FullName AS DoctorName
        FROM dbo.Payments pay
        INNER JOIN dbo.Patients p ON p.Id = pay.PatientId
        INNER JOIN dbo.Users up ON up.Id = p.UserId
        INNER JOIN dbo.Appointments a ON a.Id = pay.AppointmentId
        INNER JOIN dbo.Doctors d ON d.Id = a.DoctorId
        INNER JOIN dbo.Users ud ON ud.Id = d.UserId";

    public async Task<int> CreateAsync(int appointmentId, int patientId, decimal amount, string method, string transactionUuid)
    {
        const string sql = @"INSERT INTO dbo.Payments (AppointmentId, PatientId, Amount, Method, Status, TransactionUuid, CreatedAt)
                              OUTPUT INSERTED.Id
                              VALUES (@AppointmentId, @PatientId, @Amount, @Method, 'Pending', @TransactionUuid, SYSUTCDATETIME())";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@AppointmentId", appointmentId);
        cmd.Parameters.AddWithValue("@PatientId", patientId);
        cmd.Parameters.AddWithValue("@Amount", amount);
        cmd.Parameters.AddWithValue("@Method", method);
        cmd.Parameters.AddWithValue("@TransactionUuid", transactionUuid);

        await conn.OpenAsync();
        var id = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(id);
    }

    public async Task<Payment?> GetByIdAsync(int id)
    {
        var sql = $"{BaseSelect} WHERE pay.Id = @Id";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<Payment?> GetByTransactionUuidAsync(string transactionUuid)
    {
        var sql = $"{BaseSelect} WHERE pay.TransactionUuid = @Uuid";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Uuid", transactionUuid);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<Payment?> GetByGatewayReferenceAsync(string gatewayReference)
    {
        var sql = $"{BaseSelect} WHERE pay.GatewayReference = @Ref";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Ref", gatewayReference);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<List<Payment>> GetByAppointmentIdAsync(int appointmentId)
    {
        var sql = $"{BaseSelect} WHERE pay.AppointmentId = @AppointmentId ORDER BY pay.CreatedAt DESC";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@AppointmentId", appointmentId);

        var results = new List<Payment>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));
        return results;
    }

    public async Task<List<Payment>> GetByPatientIdAsync(int patientId)
    {
        var sql = $"{BaseSelect} WHERE pay.PatientId = @PatientId ORDER BY pay.CreatedAt DESC";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@PatientId", patientId);

        var results = new List<Payment>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));
        return results;
    }

    public async Task<List<Payment>> GetAllAsync()
    {
        var sql = $"{BaseSelect} ORDER BY pay.CreatedAt DESC";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);

        var results = new List<Payment>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));
        return results;
    }

    public async Task<bool> UpdateStatusAsync(int id, string status, string? gatewayReference)
    {
        const string sql = @"UPDATE dbo.Payments SET
                                Status = @Status,
                                GatewayReference = COALESCE(@GatewayReference, GatewayReference),
                                PaidAt = CASE WHEN @Status = 'Success' THEN SYSUTCDATETIME() ELSE PaidAt END
                              WHERE Id = @Id";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@Status", status);
        cmd.Parameters.AddWithValue("@GatewayReference", (object?)gatewayReference ?? DBNull.Value);

        await conn.OpenAsync();
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    public async Task<bool> HasSuccessfulPaymentAsync(int appointmentId)
    {
        const string sql = "SELECT COUNT(1) FROM dbo.Payments WHERE AppointmentId = @AppointmentId AND Status = 'Success'";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@AppointmentId", appointmentId);

        await conn.OpenAsync();
        var count = (int)(await cmd.ExecuteScalarAsync() ?? 0);
        return count > 0;
    }

    private static Payment Map(SqlDataReader reader) => new Payment
    {
        Id = reader.GetInt32(reader.GetOrdinal("Id")),
        AppointmentId = reader.GetInt32(reader.GetOrdinal("AppointmentId")),
        PatientId = reader.GetInt32(reader.GetOrdinal("PatientId")),
        Amount = reader.GetDecimal(reader.GetOrdinal("Amount")),
        Method = reader.GetString(reader.GetOrdinal("Method")),
        Status = reader.GetString(reader.GetOrdinal("Status")),
        TransactionUuid = reader.GetString(reader.GetOrdinal("TransactionUuid")),
        GatewayReference = reader.IsDBNull(reader.GetOrdinal("GatewayReference")) ? null : reader.GetString(reader.GetOrdinal("GatewayReference")),
        CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
        PaidAt = reader.IsDBNull(reader.GetOrdinal("PaidAt")) ? null : reader.GetDateTime(reader.GetOrdinal("PaidAt")),
        PatientName = reader.IsDBNull(reader.GetOrdinal("PatientName")) ? null : reader.GetString(reader.GetOrdinal("PatientName")),
        DoctorName = reader.IsDBNull(reader.GetOrdinal("DoctorName")) ? null : reader.GetString(reader.GetOrdinal("DoctorName"))
    };
}

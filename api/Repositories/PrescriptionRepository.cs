using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IPrescriptionRepository
{
    Task<int> CreateAsync(int appointmentId, string medication, string? dosage, string? instructions);
    Task<List<Prescription>> GetByAppointmentIdAsync(int appointmentId);
}

public class PrescriptionRepository : IPrescriptionRepository
{
    private readonly ISqlConnectionFactory _factory;

    public PrescriptionRepository(ISqlConnectionFactory factory)
    {
        _factory = factory;
    }

    public async Task<int> CreateAsync(int appointmentId, string medication, string? dosage, string? instructions)
    {
        const string sql = @"INSERT INTO dbo.Prescriptions (AppointmentId, Medication, Dosage, Instructions, CreatedAt)
                              OUTPUT INSERTED.Id
                              VALUES (@AppointmentId, @Medication, @Dosage, @Instructions, SYSUTCDATETIME())";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@AppointmentId", appointmentId);
        cmd.Parameters.AddWithValue("@Medication", medication);
        cmd.Parameters.AddWithValue("@Dosage", (object?)dosage ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Instructions", (object?)instructions ?? DBNull.Value);

        await conn.OpenAsync();
        var id = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(id);
    }

    public async Task<List<Prescription>> GetByAppointmentIdAsync(int appointmentId)
    {
        const string sql = @"SELECT Id, AppointmentId, Medication, Dosage, Instructions, CreatedAt
                              FROM dbo.Prescriptions WHERE AppointmentId = @AppointmentId ORDER BY CreatedAt DESC";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@AppointmentId", appointmentId);

        var results = new List<Prescription>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new Prescription
            {
                Id = reader.GetInt32(reader.GetOrdinal("Id")),
                AppointmentId = reader.GetInt32(reader.GetOrdinal("AppointmentId")),
                Medication = reader.GetString(reader.GetOrdinal("Medication")),
                Dosage = reader.IsDBNull(reader.GetOrdinal("Dosage")) ? null : reader.GetString(reader.GetOrdinal("Dosage")),
                Instructions = reader.IsDBNull(reader.GetOrdinal("Instructions")) ? null : reader.GetString(reader.GetOrdinal("Instructions")),
                CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
            });
        }
        return results;
    }
}

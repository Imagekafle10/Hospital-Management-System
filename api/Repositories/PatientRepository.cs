using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IPatientRepository
{
    Task<int> CreateAsync(int userId, DateTime? dob, string? gender, string? bloodGroup, string? address);
    Task<Patient?> GetByIdAsync(int id);
    Task<Patient?> GetByUserIdAsync(int userId);
    Task<List<Patient>> GetAllAsync();
    Task<bool> UpdateAsync(int patientId, DateTime? dob, string? gender, string? bloodGroup, string? address, string? emergencyContact);
}

public class PatientRepository : IPatientRepository
{
    private readonly ISqlConnectionFactory _factory;

    public PatientRepository(ISqlConnectionFactory factory)
    {
        _factory = factory;
    }

    private const string BaseSelect = @"
        SELECT p.Id, p.UserId, p.DateOfBirth, p.Gender, p.BloodGroup, p.Address, p.EmergencyContact, p.CreatedAt,
               u.FullName, u.Email, u.Phone
        FROM dbo.Patients p
        INNER JOIN dbo.Users u ON u.Id = p.UserId";

    public async Task<int> CreateAsync(int userId, DateTime? dob, string? gender, string? bloodGroup, string? address)
    {
        const string sql = @"INSERT INTO dbo.Patients (UserId, DateOfBirth, Gender, BloodGroup, Address, CreatedAt)
                              OUTPUT INSERTED.Id
                              VALUES (@UserId, @Dob, @Gender, @BloodGroup, @Address, SYSUTCDATETIME())";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@UserId", userId);
        cmd.Parameters.AddWithValue("@Dob", (object?)dob ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Gender", (object?)gender ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@BloodGroup", (object?)bloodGroup ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Address", (object?)address ?? DBNull.Value);

        await conn.OpenAsync();
        var id = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(id);
    }

    public async Task<Patient?> GetByIdAsync(int id)
    {
        var sql = $"{BaseSelect} WHERE p.Id = @Id";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<Patient?> GetByUserIdAsync(int userId)
    {
        var sql = $"{BaseSelect} WHERE p.UserId = @UserId";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@UserId", userId);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<List<Patient>> GetAllAsync()
    {
        var sql = $"{BaseSelect} ORDER BY u.FullName";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);

        var results = new List<Patient>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));

        return results;
    }

    public async Task<bool> UpdateAsync(int patientId, DateTime? dob, string? gender, string? bloodGroup, string? address, string? emergencyContact)
    {
        const string sql = @"UPDATE dbo.Patients SET
                                DateOfBirth = COALESCE(@Dob, DateOfBirth),
                                Gender = COALESCE(@Gender, Gender),
                                BloodGroup = COALESCE(@BloodGroup, BloodGroup),
                                Address = COALESCE(@Address, Address),
                                EmergencyContact = COALESCE(@Emergency, EmergencyContact)
                              WHERE Id = @Id";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", patientId);
        cmd.Parameters.AddWithValue("@Dob", (object?)dob ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Gender", (object?)gender ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@BloodGroup", (object?)bloodGroup ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Address", (object?)address ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Emergency", (object?)emergencyContact ?? DBNull.Value);

        await conn.OpenAsync();
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    private static Patient Map(SqlDataReader reader) => new Patient
    {
        Id = reader.GetInt32(reader.GetOrdinal("Id")),
        UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
        DateOfBirth = reader.IsDBNull(reader.GetOrdinal("DateOfBirth")) ? null : reader.GetDateTime(reader.GetOrdinal("DateOfBirth")),
        Gender = reader.IsDBNull(reader.GetOrdinal("Gender")) ? null : reader.GetString(reader.GetOrdinal("Gender")),
        BloodGroup = reader.IsDBNull(reader.GetOrdinal("BloodGroup")) ? null : reader.GetString(reader.GetOrdinal("BloodGroup")),
        Address = reader.IsDBNull(reader.GetOrdinal("Address")) ? null : reader.GetString(reader.GetOrdinal("Address")),
        EmergencyContact = reader.IsDBNull(reader.GetOrdinal("EmergencyContact")) ? null : reader.GetString(reader.GetOrdinal("EmergencyContact")),
        CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
        FullName = reader.GetString(reader.GetOrdinal("FullName")),
        Email = reader.GetString(reader.GetOrdinal("Email")),
        Phone = reader.IsDBNull(reader.GetOrdinal("Phone")) ? null : reader.GetString(reader.GetOrdinal("Phone"))
    };
}

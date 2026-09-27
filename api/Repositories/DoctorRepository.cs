using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IDoctorRepository
{
    Task<int> CreateAsync(int userId, string specialization, string licenseNumber, decimal consultationFee);
    Task<Doctor?> GetByIdAsync(int id);
    Task<Doctor?> GetByUserIdAsync(int userId);
    Task<List<Doctor>> GetAllAsync(string? specialization);
    Task<bool> UpdateAsync(int doctorId, string? specialization, decimal? fee, int? experience, TimeSpan? from, TimeSpan? to);
}

public class DoctorRepository : IDoctorRepository
{
    private readonly ISqlConnectionFactory _factory;

    public DoctorRepository(ISqlConnectionFactory factory)
    {
        _factory = factory;
    }

    private const string BaseSelect = @"
        SELECT d.Id, d.UserId, d.Specialization, d.LicenseNumber, d.ConsultationFee,
               d.YearsOfExperience, d.AvailableFrom, d.AvailableTo, d.CreatedAt,
               u.FullName, u.Email, u.Phone
        FROM dbo.Doctors d
        INNER JOIN dbo.Users u ON u.Id = d.UserId";

    public async Task<int> CreateAsync(int userId, string specialization, string licenseNumber, decimal consultationFee)
    {
        const string sql = @"INSERT INTO dbo.Doctors (UserId, Specialization, LicenseNumber, ConsultationFee, CreatedAt)
                              OUTPUT INSERTED.Id
                              VALUES (@UserId, @Specialization, @LicenseNumber, @Fee, SYSUTCDATETIME())";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@UserId", userId);
        cmd.Parameters.AddWithValue("@Specialization", specialization);
        cmd.Parameters.AddWithValue("@LicenseNumber", licenseNumber);
        cmd.Parameters.AddWithValue("@Fee", consultationFee);

        await conn.OpenAsync();
        var id = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(id);
    }

    public async Task<Doctor?> GetByIdAsync(int id)
    {
        var sql = $"{BaseSelect} WHERE d.Id = @Id";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<Doctor?> GetByUserIdAsync(int userId)
    {
        var sql = $"{BaseSelect} WHERE d.UserId = @UserId";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@UserId", userId);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<List<Doctor>> GetAllAsync(string? specialization)
    {
        var sql = BaseSelect;
        if (!string.IsNullOrWhiteSpace(specialization))
            sql += " WHERE d.Specialization LIKE @Spec";
        sql += " ORDER BY u.FullName";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        if (!string.IsNullOrWhiteSpace(specialization))
            cmd.Parameters.AddWithValue("@Spec", $"%{specialization}%");

        var results = new List<Doctor>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));

        return results;
    }

    public async Task<bool> UpdateAsync(int doctorId, string? specialization, decimal? fee, int? experience, TimeSpan? from, TimeSpan? to)
    {
        const string sql = @"UPDATE dbo.Doctors SET
                                Specialization = COALESCE(@Specialization, Specialization),
                                ConsultationFee = COALESCE(@Fee, ConsultationFee),
                                YearsOfExperience = COALESCE(@Experience, YearsOfExperience),
                                AvailableFrom = COALESCE(@From, AvailableFrom),
                                AvailableTo = COALESCE(@To, AvailableTo)
                              WHERE Id = @Id";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", doctorId);
        cmd.Parameters.AddWithValue("@Specialization", (object?)specialization ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Fee", (object?)fee ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Experience", (object?)experience ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@From", (object?)from ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@To", (object?)to ?? DBNull.Value);

        await conn.OpenAsync();
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    private static Doctor Map(SqlDataReader reader) => new Doctor
    {
        Id = reader.GetInt32(reader.GetOrdinal("Id")),
        UserId = reader.GetInt32(reader.GetOrdinal("UserId")),
        Specialization = reader.GetString(reader.GetOrdinal("Specialization")),
        LicenseNumber = reader.GetString(reader.GetOrdinal("LicenseNumber")),
        ConsultationFee = reader.GetDecimal(reader.GetOrdinal("ConsultationFee")),
        YearsOfExperience = reader.GetInt32(reader.GetOrdinal("YearsOfExperience")),
        AvailableFrom = reader.IsDBNull(reader.GetOrdinal("AvailableFrom")) ? null : reader.GetTimeSpan(reader.GetOrdinal("AvailableFrom")),
        AvailableTo = reader.IsDBNull(reader.GetOrdinal("AvailableTo")) ? null : reader.GetTimeSpan(reader.GetOrdinal("AvailableTo")),
        CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
        FullName = reader.GetString(reader.GetOrdinal("FullName")),
        Email = reader.GetString(reader.GetOrdinal("Email")),
        Phone = reader.IsDBNull(reader.GetOrdinal("Phone")) ? null : reader.GetString(reader.GetOrdinal("Phone"))
    };
}

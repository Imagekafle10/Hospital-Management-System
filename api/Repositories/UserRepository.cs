using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IUserRepository
{
    Task<User?> GetByEmailAsync(string email);
    Task<User?> GetByIdAsync(int id);
    Task<int> CreateAsync(User user);
    Task<List<User>> GetAllAsync(string? role);
    Task<bool> UpdateAsync(int id, string? fullName, string? email, string? phone, bool? isActive, string? passwordHash);
    Task<bool> DeleteAsync(int id);
    Task<Dictionary<string, decimal>> GetStatsAsync();
}

public class UserRepository : IUserRepository
{
    private readonly ISqlConnectionFactory _factory;

    public UserRepository(ISqlConnectionFactory factory)
    {
        _factory = factory;
    }

    public async Task<User?> GetByEmailAsync(string email)
    {
        const string sql = @"SELECT Id, FullName, Email, PasswordHash, Role, Phone, IsActive, CreatedAt
                              FROM dbo.Users WHERE Email = @Email";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Email", email);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return Map(reader);
        }
        return null;
    }

    public async Task<User?> GetByIdAsync(int id)
    {
        const string sql = @"SELECT Id, FullName, Email, PasswordHash, Role, Phone, IsActive, CreatedAt
                              FROM dbo.Users WHERE Id = @Id";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        if (await reader.ReadAsync())
        {
            return Map(reader);
        }
        return null;
    }

    public async Task<int> CreateAsync(User user)
    {
        const string sql = @"INSERT INTO dbo.Users (FullName, Email, PasswordHash, Role, Phone, IsActive, CreatedAt)
                              OUTPUT INSERTED.Id
                              VALUES (@FullName, @Email, @PasswordHash, @Role, @Phone, 1, SYSUTCDATETIME())";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@FullName", user.FullName);
        cmd.Parameters.AddWithValue("@Email", user.Email);
        cmd.Parameters.AddWithValue("@PasswordHash", user.PasswordHash);
        cmd.Parameters.AddWithValue("@Role", user.Role);
        cmd.Parameters.AddWithValue("@Phone", (object?)user.Phone ?? DBNull.Value);

        await conn.OpenAsync();
        var newId = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(newId);
    }

    public async Task<List<User>> GetAllAsync(string? role)
    {
        var sql = @"SELECT Id, FullName, Email, PasswordHash, Role, Phone, IsActive, CreatedAt FROM dbo.Users"
                  + (string.IsNullOrWhiteSpace(role) ? "" : " WHERE Role = @Role") + " ORDER BY CreatedAt DESC";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        if (!string.IsNullOrWhiteSpace(role)) cmd.Parameters.AddWithValue("@Role", role);
        var list = new List<User>();
        await conn.OpenAsync();
        using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(Map(r));
        return list;
    }

    public async Task<bool> UpdateAsync(int id, string? fullName, string? email, string? phone, bool? isActive, string? passwordHash)
    {
        const string sql = @"UPDATE dbo.Users SET
                                FullName = COALESCE(@FullName, FullName),
                                Email = COALESCE(@Email, Email),
                                Phone = COALESCE(@Phone, Phone),
                                IsActive = COALESCE(@IsActive, IsActive),
                                PasswordHash = COALESCE(@PasswordHash, PasswordHash)
                             WHERE Id = @Id";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@FullName", (object?)fullName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Email", (object?)email ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Phone", (object?)phone ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@IsActive", (object?)isActive ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@PasswordHash", (object?)passwordHash ?? DBNull.Value);
        await conn.OpenAsync();
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand("DELETE FROM dbo.Users WHERE Id = @Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        await conn.OpenAsync();
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<Dictionary<string, decimal>> GetStatsAsync()
    {
        const string sql = @"SELECT
            (SELECT COUNT(*) FROM dbo.Patients) AS patients,
            (SELECT COUNT(*) FROM dbo.Doctors) AS doctors,
            (SELECT COUNT(*) FROM dbo.Users WHERE Role = 'Pharmacist') AS pharmacists,
            (SELECT COUNT(*) FROM dbo.Appointments) AS appointments,
            (SELECT COUNT(*) FROM dbo.Appointments WHERE Status = 'Pending') AS pendingAppointments,
            (SELECT COUNT(*) FROM dbo.Admissions WHERE Status = 'Admitted') AS activeAdmissions,
            (SELECT COUNT(*) FROM dbo.Beds) AS totalBeds,
            (SELECT COUNT(*) FROM dbo.Beds WHERE Status = 'Available') AS availableBeds,
            (SELECT COUNT(*) FROM dbo.Medicines WHERE IsActive = 1 AND StockQuantity <= ReorderLevel) AS lowStockMedicines,
            (SELECT COALESCE(SUM(Amount),0) FROM dbo.Payments WHERE Status = 'Success') AS revenue,
            (SELECT COALESCE(SUM(TotalPrice),0) FROM dbo.PharmacyDispenses) AS pharmacySales";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        await conn.OpenAsync();
        using var r = await cmd.ExecuteReaderAsync();
        var d = new Dictionary<string, decimal>();
        if (await r.ReadAsync())
            for (var i = 0; i < r.FieldCount; i++) d[r.GetName(i)] = Convert.ToDecimal(r.GetValue(i));
        return d;
    }

    private static User Map(SqlDataReader reader) => new User
    {
        Id = reader.GetInt32(reader.GetOrdinal("Id")),
        FullName = reader.GetString(reader.GetOrdinal("FullName")),
        Email = reader.GetString(reader.GetOrdinal("Email")),
        PasswordHash = reader.GetString(reader.GetOrdinal("PasswordHash")),
        Role = reader.GetString(reader.GetOrdinal("Role")),
        Phone = reader.IsDBNull(reader.GetOrdinal("Phone")) ? null : reader.GetString(reader.GetOrdinal("Phone")),
        IsActive = reader.GetBoolean(reader.GetOrdinal("IsActive")),
        CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
    };
}

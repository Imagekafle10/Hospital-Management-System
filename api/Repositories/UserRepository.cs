using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IUserRepository
{
    Task<User?> GetByEmailAsync(string email);
    Task<User?> GetByIdAsync(int id);
    Task<int> CreateAsync(User user);
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

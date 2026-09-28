using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IBedRepository
{
    Task<int> CreateAsync(int wardId, string bedNumber);
    Task<Bed?> GetByIdAsync(int id);
    Task<List<Bed>> GetByWardIdAsync(int wardId);
    Task<List<Bed>> GetAllAsync(string? status);
    Task<bool> BedNumberExistsInWardAsync(int wardId, string bedNumber);
    Task<bool> UpdateStatusAsync(int id, string status);
    Task<bool> DeleteAsync(int id);
}

public class BedRepository : IBedRepository
{
    private readonly ISqlConnectionFactory _factory;

    public BedRepository(ISqlConnectionFactory factory)
    {
        _factory = factory;
    }

    private const string BaseSelect = @"
        SELECT b.Id, b.WardId, b.BedNumber, b.Status, b.CreatedAt, w.Name AS WardName, w.WardType
        FROM dbo.Beds b
        INNER JOIN dbo.Wards w ON w.Id = b.WardId";

    public async Task<int> CreateAsync(int wardId, string bedNumber)
    {
        const string sql = @"INSERT INTO dbo.Beds (WardId, BedNumber, Status, CreatedAt)
                              OUTPUT INSERTED.Id
                              VALUES (@WardId, @BedNumber, 'Available', SYSUTCDATETIME())";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@WardId", wardId);
        cmd.Parameters.AddWithValue("@BedNumber", bedNumber);

        await conn.OpenAsync();
        var id = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(id);
    }

    public async Task<Bed?> GetByIdAsync(int id)
    {
        var sql = $"{BaseSelect} WHERE b.Id = @Id";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<List<Bed>> GetByWardIdAsync(int wardId)
    {
        var sql = $"{BaseSelect} WHERE b.WardId = @WardId ORDER BY b.BedNumber";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@WardId", wardId);

        var results = new List<Bed>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));

        return results;
    }

    public async Task<List<Bed>> GetAllAsync(string? status)
    {
        var sql = BaseSelect;
        if (!string.IsNullOrWhiteSpace(status))
            sql += " WHERE b.Status = @Status";
        sql += " ORDER BY w.Name, b.BedNumber";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        if (!string.IsNullOrWhiteSpace(status))
            cmd.Parameters.AddWithValue("@Status", status);

        var results = new List<Bed>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));

        return results;
    }

    public async Task<bool> BedNumberExistsInWardAsync(int wardId, string bedNumber)
    {
        const string sql = "SELECT COUNT(*) FROM dbo.Beds WHERE WardId = @WardId AND BedNumber = @BedNumber";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@WardId", wardId);
        cmd.Parameters.AddWithValue("@BedNumber", bedNumber);

        await conn.OpenAsync();
        var count = (int)await cmd.ExecuteScalarAsync();
        return count > 0;
    }

    public async Task<bool> UpdateStatusAsync(int id, string status)
    {
        const string sql = "UPDATE dbo.Beds SET Status = @Status WHERE Id = @Id";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@Status", status);

        await conn.OpenAsync();
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        const string sql = "DELETE FROM dbo.Beds WHERE Id = @Id";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    private static Bed Map(SqlDataReader reader) => new()
    {
        Id = reader.GetInt32(reader.GetOrdinal("Id")),
        WardId = reader.GetInt32(reader.GetOrdinal("WardId")),
        BedNumber = reader.GetString(reader.GetOrdinal("BedNumber")),
        Status = reader.GetString(reader.GetOrdinal("Status")),
        CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
        WardName = reader.GetString(reader.GetOrdinal("WardName")),
        WardType = reader.GetString(reader.GetOrdinal("WardType"))
    };
}

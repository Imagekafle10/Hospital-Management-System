using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IWardRepository
{
    Task<int> CreateAsync(string name, string wardType, int? floorNumber, string? description);
    Task<Ward?> GetByIdAsync(int id);
    Task<List<Ward>> GetAllAsync();
    Task<bool> UpdateAsync(int id, string? name, string? wardType, int? floorNumber, string? description);
    Task<bool> DeleteAsync(int id);
    Task<bool> HasBedsAsync(int wardId);
}

public class WardRepository : IWardRepository
{
    private readonly ISqlConnectionFactory _factory;

    public WardRepository(ISqlConnectionFactory factory)
    {
        _factory = factory;
    }

    // Aggregates bed counts alongside each ward.
    private const string BaseSelect = @"
        SELECT w.Id, w.Name, w.WardType, w.FloorNumber, w.Description, w.CreatedAt,
               COUNT(b.Id) AS TotalBeds,
               SUM(CASE WHEN b.Status = 'Available' THEN 1 ELSE 0 END) AS AvailableBeds
        FROM dbo.Wards w
        LEFT JOIN dbo.Beds b ON b.WardId = w.Id";

    private const string GroupBy = " GROUP BY w.Id, w.Name, w.WardType, w.FloorNumber, w.Description, w.CreatedAt";

    public async Task<int> CreateAsync(string name, string wardType, int? floorNumber, string? description)
    {
        const string sql = @"INSERT INTO dbo.Wards (Name, WardType, FloorNumber, Description, CreatedAt)
                              OUTPUT INSERTED.Id
                              VALUES (@Name, @WardType, @FloorNumber, @Description, SYSUTCDATETIME())";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Name", name);
        cmd.Parameters.AddWithValue("@WardType", wardType);
        cmd.Parameters.AddWithValue("@FloorNumber", (object?)floorNumber ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Description", (object?)description ?? DBNull.Value);

        await conn.OpenAsync();
        var id = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(id);
    }

    public async Task<Ward?> GetByIdAsync(int id)
    {
        var sql = $"{BaseSelect} WHERE w.Id = @Id{GroupBy}";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<List<Ward>> GetAllAsync()
    {
        var sql = $"{BaseSelect}{GroupBy} ORDER BY w.Name";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);

        var results = new List<Ward>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));

        return results;
    }

    public async Task<bool> UpdateAsync(int id, string? name, string? wardType, int? floorNumber, string? description)
    {
        const string sql = @"UPDATE dbo.Wards SET
                                Name = COALESCE(@Name, Name),
                                WardType = COALESCE(@WardType, WardType),
                                FloorNumber = COALESCE(@FloorNumber, FloorNumber),
                                Description = COALESCE(@Description, Description)
                              WHERE Id = @Id";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@Name", (object?)name ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@WardType", (object?)wardType ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FloorNumber", (object?)floorNumber ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Description", (object?)description ?? DBNull.Value);

        await conn.OpenAsync();
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        const string sql = "DELETE FROM dbo.Wards WHERE Id = @Id";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    public async Task<bool> HasBedsAsync(int wardId)
    {
        const string sql = "SELECT COUNT(*) FROM dbo.Beds WHERE WardId = @WardId";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@WardId", wardId);

        await conn.OpenAsync();
        var count = (int)await cmd.ExecuteScalarAsync();
        return count > 0;
    }

    private static Ward Map(SqlDataReader reader) => new()
    {
        Id = reader.GetInt32(reader.GetOrdinal("Id")),
        Name = reader.GetString(reader.GetOrdinal("Name")),
        WardType = reader.GetString(reader.GetOrdinal("WardType")),
        FloorNumber = reader.IsDBNull(reader.GetOrdinal("FloorNumber")) ? null : reader.GetInt32(reader.GetOrdinal("FloorNumber")),
        Description = reader.IsDBNull(reader.GetOrdinal("Description")) ? null : reader.GetString(reader.GetOrdinal("Description")),
        CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
        TotalBeds = reader.GetInt32(reader.GetOrdinal("TotalBeds")),
        AvailableBeds = reader.IsDBNull(reader.GetOrdinal("AvailableBeds")) ? 0 : reader.GetInt32(reader.GetOrdinal("AvailableBeds"))
    };
}

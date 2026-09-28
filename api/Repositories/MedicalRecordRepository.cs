using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IMedicalRecordRepository
{
    Task<int> CreateAsync(MedicalRecord record);
    Task<MedicalRecord?> GetByIdAsync(int id);
    Task<List<MedicalRecord>> GetByPatientIdAsync(int patientId);
    Task<bool> DeleteAsync(int id);
}

public class MedicalRecordRepository : IMedicalRecordRepository
{
    private readonly ISqlConnectionFactory _factory;

    public MedicalRecordRepository(ISqlConnectionFactory factory)
    {
        _factory = factory;
    }

    public async Task<int> CreateAsync(MedicalRecord record)
    {
        const string sql = @"INSERT INTO dbo.MedicalRecords
                                (PatientId, DoctorId, AppointmentId, RecordType, Title, Description,
                                 FileName, StoredFileName, ContentType, FileSizeBytes, UploadedByUserId, CreatedAt)
                              OUTPUT INSERTED.Id
                              VALUES
                                (@PatientId, @DoctorId, @AppointmentId, @RecordType, @Title, @Description,
                                 @FileName, @StoredFileName, @ContentType, @FileSizeBytes, @UploadedByUserId, SYSUTCDATETIME())";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@PatientId", record.PatientId);
        cmd.Parameters.AddWithValue("@DoctorId", (object?)record.DoctorId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@AppointmentId", (object?)record.AppointmentId ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@RecordType", record.RecordType);
        cmd.Parameters.AddWithValue("@Title", record.Title);
        cmd.Parameters.AddWithValue("@Description", (object?)record.Description ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@FileName", record.FileName);
        cmd.Parameters.AddWithValue("@StoredFileName", record.StoredFileName);
        cmd.Parameters.AddWithValue("@ContentType", record.ContentType);
        cmd.Parameters.AddWithValue("@FileSizeBytes", record.FileSizeBytes);
        cmd.Parameters.AddWithValue("@UploadedByUserId", record.UploadedByUserId);

        await conn.OpenAsync();
        var id = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(id);
    }

    public async Task<MedicalRecord?> GetByIdAsync(int id)
    {
        const string sql = @"SELECT Id, PatientId, DoctorId, AppointmentId, RecordType, Title, Description,
                                     FileName, StoredFileName, ContentType, FileSizeBytes, UploadedByUserId, CreatedAt
                              FROM dbo.MedicalRecords WHERE Id = @Id";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<List<MedicalRecord>> GetByPatientIdAsync(int patientId)
    {
        const string sql = @"SELECT Id, PatientId, DoctorId, AppointmentId, RecordType, Title, Description,
                                     FileName, StoredFileName, ContentType, FileSizeBytes, UploadedByUserId, CreatedAt
                              FROM dbo.MedicalRecords WHERE PatientId = @PatientId ORDER BY CreatedAt DESC";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@PatientId", patientId);

        var results = new List<MedicalRecord>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(Map(reader));
        }
        return results;
    }

    public async Task<bool> DeleteAsync(int id)
    {
        const string sql = "DELETE FROM dbo.MedicalRecords WHERE Id = @Id";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    private static MedicalRecord Map(SqlDataReader reader) => new()
    {
        Id = reader.GetInt32(reader.GetOrdinal("Id")),
        PatientId = reader.GetInt32(reader.GetOrdinal("PatientId")),
        DoctorId = reader.IsDBNull(reader.GetOrdinal("DoctorId")) ? null : reader.GetInt32(reader.GetOrdinal("DoctorId")),
        AppointmentId = reader.IsDBNull(reader.GetOrdinal("AppointmentId")) ? null : reader.GetInt32(reader.GetOrdinal("AppointmentId")),
        RecordType = reader.GetString(reader.GetOrdinal("RecordType")),
        Title = reader.GetString(reader.GetOrdinal("Title")),
        Description = reader.IsDBNull(reader.GetOrdinal("Description")) ? null : reader.GetString(reader.GetOrdinal("Description")),
        FileName = reader.GetString(reader.GetOrdinal("FileName")),
        StoredFileName = reader.GetString(reader.GetOrdinal("StoredFileName")),
        ContentType = reader.GetString(reader.GetOrdinal("ContentType")),
        FileSizeBytes = reader.GetInt64(reader.GetOrdinal("FileSizeBytes")),
        UploadedByUserId = reader.GetInt32(reader.GetOrdinal("UploadedByUserId")),
        CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt"))
    };
}

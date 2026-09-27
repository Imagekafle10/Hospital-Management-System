using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IAppointmentRepository
{
    Task<int> CreateAsync(int patientId, int doctorId, DateTime date, string? reason);
    Task<Appointment?> GetByIdAsync(int id);
    Task<List<Appointment>> GetByPatientIdAsync(int patientId);
    Task<List<Appointment>> GetByDoctorIdAsync(int doctorId);
    Task<List<Appointment>> GetAllAsync();
    Task<bool> UpdateStatusAsync(int appointmentId, string status, string? notes);
    Task<bool> IsDoctorBookedAsync(int doctorId, DateTime date);
}

public class AppointmentRepository : IAppointmentRepository
{
    private readonly ISqlConnectionFactory _factory;

    public AppointmentRepository(ISqlConnectionFactory factory)
    {
        _factory = factory;
    }

    private const string BaseSelect = @"
        SELECT a.Id, a.PatientId, a.DoctorId, a.AppointmentDate, a.Reason, a.Status, a.Notes, a.CreatedAt, a.UpdatedAt,
               pu.FullName AS PatientName, du.FullName AS DoctorName, d.Specialization AS DoctorSpecialization
        FROM dbo.Appointments a
        INNER JOIN dbo.Patients p ON p.Id = a.PatientId
        INNER JOIN dbo.Users pu ON pu.Id = p.UserId
        INNER JOIN dbo.Doctors d ON d.Id = a.DoctorId
        INNER JOIN dbo.Users du ON du.Id = d.UserId";

    public async Task<int> CreateAsync(int patientId, int doctorId, DateTime date, string? reason)
    {
        const string sql = @"INSERT INTO dbo.Appointments (PatientId, DoctorId, AppointmentDate, Reason, Status, CreatedAt)
                              OUTPUT INSERTED.Id
                              VALUES (@PatientId, @DoctorId, @Date, @Reason, 'Pending', SYSUTCDATETIME())";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@PatientId", patientId);
        cmd.Parameters.AddWithValue("@DoctorId", doctorId);
        cmd.Parameters.AddWithValue("@Date", date);
        cmd.Parameters.AddWithValue("@Reason", (object?)reason ?? DBNull.Value);

        await conn.OpenAsync();
        var id = await cmd.ExecuteScalarAsync();
        return Convert.ToInt32(id);
    }

    public async Task<Appointment?> GetByIdAsync(int id)
    {
        var sql = $"{BaseSelect} WHERE a.Id = @Id";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<List<Appointment>> GetByPatientIdAsync(int patientId)
    {
        var sql = $"{BaseSelect} WHERE a.PatientId = @PatientId ORDER BY a.AppointmentDate DESC";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@PatientId", patientId);
        return await ReadListAsync(conn, cmd);
    }

    public async Task<List<Appointment>> GetByDoctorIdAsync(int doctorId)
    {
        var sql = $"{BaseSelect} WHERE a.DoctorId = @DoctorId ORDER BY a.AppointmentDate DESC";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@DoctorId", doctorId);
        return await ReadListAsync(conn, cmd);
    }

    public async Task<List<Appointment>> GetAllAsync()
    {
        var sql = $"{BaseSelect} ORDER BY a.AppointmentDate DESC";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        return await ReadListAsync(conn, cmd);
    }

    public async Task<bool> UpdateStatusAsync(int appointmentId, string status, string? notes)
    {
        const string sql = @"UPDATE dbo.Appointments SET
                                Status = @Status,
                                Notes = COALESCE(@Notes, Notes),
                                UpdatedAt = SYSUTCDATETIME()
                              WHERE Id = @Id";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", appointmentId);
        cmd.Parameters.AddWithValue("@Status", status);
        cmd.Parameters.AddWithValue("@Notes", (object?)notes ?? DBNull.Value);

        await conn.OpenAsync();
        var rows = await cmd.ExecuteNonQueryAsync();
        return rows > 0;
    }

    public async Task<bool> IsDoctorBookedAsync(int doctorId, DateTime date)
    {
        const string sql = @"SELECT COUNT(1) FROM dbo.Appointments
                              WHERE DoctorId = @DoctorId AND AppointmentDate = @Date
                              AND Status NOT IN ('Cancelled')";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@DoctorId", doctorId);
        cmd.Parameters.AddWithValue("@Date", date);

        await conn.OpenAsync();
        var count = (int)await cmd.ExecuteScalarAsync();
        return count > 0;
    }

    private static async Task<List<Appointment>> ReadListAsync(SqlConnection conn, SqlCommand cmd)
    {
        var results = new List<Appointment>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));
        return results;
    }

    private static Appointment Map(SqlDataReader reader) => new Appointment
    {
        Id = reader.GetInt32(reader.GetOrdinal("Id")),
        PatientId = reader.GetInt32(reader.GetOrdinal("PatientId")),
        DoctorId = reader.GetInt32(reader.GetOrdinal("DoctorId")),
        AppointmentDate = reader.GetDateTime(reader.GetOrdinal("AppointmentDate")),
        Reason = reader.IsDBNull(reader.GetOrdinal("Reason")) ? null : reader.GetString(reader.GetOrdinal("Reason")),
        Status = reader.GetString(reader.GetOrdinal("Status")),
        Notes = reader.IsDBNull(reader.GetOrdinal("Notes")) ? null : reader.GetString(reader.GetOrdinal("Notes")),
        CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
        UpdatedAt = reader.IsDBNull(reader.GetOrdinal("UpdatedAt")) ? null : reader.GetDateTime(reader.GetOrdinal("UpdatedAt")),
        PatientName = reader.GetString(reader.GetOrdinal("PatientName")),
        DoctorName = reader.GetString(reader.GetOrdinal("DoctorName")),
        DoctorSpecialization = reader.GetString(reader.GetOrdinal("DoctorSpecialization"))
    };
}

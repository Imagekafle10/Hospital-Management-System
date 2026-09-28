using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IAdmissionRepository
{
    Task<int?> AdmitAsync(int patientId, int admittingDoctorId, int bedId, string reasonForAdmission, DateTime? expectedDischargeDate);
    Task<Admission?> GetByIdAsync(int id);
    Task<List<Admission>> GetActiveAsync();
    Task<List<Admission>> GetByPatientIdAsync(int patientId);
    Task<Admission?> GetActiveByPatientIdAsync(int patientId);
    Task<bool> DischargeAsync(int id, string? dischargeSummary);
    Task<bool> TransferBedAsync(int id, int newBedId);
}

public class AdmissionRepository : IAdmissionRepository
{
    private readonly ISqlConnectionFactory _factory;

    public AdmissionRepository(ISqlConnectionFactory factory)
    {
        _factory = factory;
    }

    private const string BaseSelect = @"
        SELECT ad.Id, ad.PatientId, ad.AdmittingDoctorId, ad.BedId, ad.AdmissionDate, ad.ExpectedDischargeDate,
               ad.DischargeDate, ad.ReasonForAdmission, ad.Status, ad.DischargeSummary, ad.CreatedAt, ad.UpdatedAt,
               up.FullName AS PatientName, ud.FullName AS DoctorName, b.BedNumber, w.Name AS WardName
        FROM dbo.Admissions ad
        INNER JOIN dbo.Patients p ON p.Id = ad.PatientId
        INNER JOIN dbo.Users up ON up.Id = p.UserId
        INNER JOIN dbo.Doctors d ON d.Id = ad.AdmittingDoctorId
        INNER JOIN dbo.Users ud ON ud.Id = d.UserId
        INNER JOIN dbo.Beds b ON b.Id = ad.BedId
        INNER JOIN dbo.Wards w ON w.Id = b.WardId";

    // Returns the new Admission Id, or null if the bed was not available (checked inside the transaction to avoid a race).
    public async Task<int?> AdmitAsync(int patientId, int admittingDoctorId, int bedId, string reasonForAdmission, DateTime? expectedDischargeDate)
    {
        using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        using var tx = conn.BeginTransaction();

        try
        {
            const string lockBedSql = "SELECT Status FROM dbo.Beds WITH (UPDLOCK, ROWLOCK) WHERE Id = @BedId";
            using (var checkCmd = new SqlCommand(lockBedSql, conn, tx))
            {
                checkCmd.Parameters.AddWithValue("@BedId", bedId);
                var status = (string?)await checkCmd.ExecuteScalarAsync();
                if (status != "Available")
                {
                    tx.Rollback();
                    return null;
                }
            }

            const string insertSql = @"INSERT INTO dbo.Admissions
                                            (PatientId, AdmittingDoctorId, BedId, AdmissionDate, ExpectedDischargeDate,
                                             ReasonForAdmission, Status, CreatedAt)
                                        OUTPUT INSERTED.Id
                                        VALUES
                                            (@PatientId, @DoctorId, @BedId, SYSUTCDATETIME(), @ExpectedDischargeDate,
                                             @Reason, 'Admitted', SYSUTCDATETIME())";
            int admissionId;
            using (var insertCmd = new SqlCommand(insertSql, conn, tx))
            {
                insertCmd.Parameters.AddWithValue("@PatientId", patientId);
                insertCmd.Parameters.AddWithValue("@DoctorId", admittingDoctorId);
                insertCmd.Parameters.AddWithValue("@BedId", bedId);
                insertCmd.Parameters.AddWithValue("@ExpectedDischargeDate", (object?)expectedDischargeDate ?? DBNull.Value);
                insertCmd.Parameters.AddWithValue("@Reason", reasonForAdmission);
                admissionId = Convert.ToInt32(await insertCmd.ExecuteScalarAsync());
            }

            const string occupyBedSql = "UPDATE dbo.Beds SET Status = 'Occupied' WHERE Id = @BedId";
            using (var occupyCmd = new SqlCommand(occupyBedSql, conn, tx))
            {
                occupyCmd.Parameters.AddWithValue("@BedId", bedId);
                await occupyCmd.ExecuteNonQueryAsync();
            }

            tx.Commit();
            return admissionId;
        }
        catch
        {
            tx.Rollback();
            throw;
        }
    }

    public async Task<Admission?> GetByIdAsync(int id)
    {
        var sql = $"{BaseSelect} WHERE ad.Id = @Id";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<List<Admission>> GetActiveAsync()
    {
        var sql = $"{BaseSelect} WHERE ad.Status = 'Admitted' ORDER BY ad.AdmissionDate DESC";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);

        var results = new List<Admission>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));

        return results;
    }

    public async Task<List<Admission>> GetByPatientIdAsync(int patientId)
    {
        var sql = $"{BaseSelect} WHERE ad.PatientId = @PatientId ORDER BY ad.AdmissionDate DESC";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@PatientId", patientId);

        var results = new List<Admission>();
        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        while (await reader.ReadAsync())
            results.Add(Map(reader));

        return results;
    }

    public async Task<Admission?> GetActiveByPatientIdAsync(int patientId)
    {
        var sql = $"{BaseSelect} WHERE ad.PatientId = @PatientId AND ad.Status = 'Admitted'";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@PatientId", patientId);

        await conn.OpenAsync();
        using var reader = await cmd.ExecuteReaderAsync();
        return await reader.ReadAsync() ? Map(reader) : null;
    }

    public async Task<bool> DischargeAsync(int id, string? dischargeSummary)
    {
        using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        using var tx = conn.BeginTransaction();

        try
        {
            const string getBedSql = "SELECT BedId, Status FROM dbo.Admissions WHERE Id = @Id";
            int bedId;
            using (var getCmd = new SqlCommand(getBedSql, conn, tx))
            {
                getCmd.Parameters.AddWithValue("@Id", id);
                using var reader = await getCmd.ExecuteReaderAsync();
                if (!await reader.ReadAsync())
                {
                    tx.Rollback();
                    return false;
                }
                var currentStatus = reader.GetString(reader.GetOrdinal("Status"));
                bedId = reader.GetInt32(reader.GetOrdinal("BedId"));
                if (currentStatus != "Admitted")
                {
                    tx.Rollback();
                    return false;
                }
            }

            const string dischargeSql = @"UPDATE dbo.Admissions SET
                                                Status = 'Discharged',
                                                DischargeDate = SYSUTCDATETIME(),
                                                DischargeSummary = @Summary,
                                                UpdatedAt = SYSUTCDATETIME()
                                           WHERE Id = @Id";
            using (var dischargeCmd = new SqlCommand(dischargeSql, conn, tx))
            {
                dischargeCmd.Parameters.AddWithValue("@Id", id);
                dischargeCmd.Parameters.AddWithValue("@Summary", (object?)dischargeSummary ?? DBNull.Value);
                await dischargeCmd.ExecuteNonQueryAsync();
            }

            const string freeBedSql = "UPDATE dbo.Beds SET Status = 'Available' WHERE Id = @BedId";
            using (var freeCmd = new SqlCommand(freeBedSql, conn, tx))
            {
                freeCmd.Parameters.AddWithValue("@BedId", bedId);
                await freeCmd.ExecuteNonQueryAsync();
            }

            tx.Commit();
            return true;
        }
        catch
        {
            tx.Rollback();
            throw;
        }
    }

    public async Task<bool> TransferBedAsync(int id, int newBedId)
    {
        using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        using var tx = conn.BeginTransaction();

        try
        {
            const string getAdmissionSql = "SELECT BedId, Status FROM dbo.Admissions WHERE Id = @Id";
            int oldBedId;
            using (var getCmd = new SqlCommand(getAdmissionSql, conn, tx))
            {
                getCmd.Parameters.AddWithValue("@Id", id);
                using var reader = await getCmd.ExecuteReaderAsync();
                if (!await reader.ReadAsync())
                {
                    tx.Rollback();
                    return false;
                }
                var currentStatus = reader.GetString(reader.GetOrdinal("Status"));
                oldBedId = reader.GetInt32(reader.GetOrdinal("BedId"));
                if (currentStatus != "Admitted")
                {
                    tx.Rollback();
                    return false;
                }
            }

            const string lockNewBedSql = "SELECT Status FROM dbo.Beds WITH (UPDLOCK, ROWLOCK) WHERE Id = @BedId";
            using (var checkCmd = new SqlCommand(lockNewBedSql, conn, tx))
            {
                checkCmd.Parameters.AddWithValue("@BedId", newBedId);
                var status = (string?)await checkCmd.ExecuteScalarAsync();
                if (status != "Available")
                {
                    tx.Rollback();
                    return false;
                }
            }

            const string updateAdmissionSql = "UPDATE dbo.Admissions SET BedId = @NewBedId, UpdatedAt = SYSUTCDATETIME() WHERE Id = @Id";
            using (var updateCmd = new SqlCommand(updateAdmissionSql, conn, tx))
            {
                updateCmd.Parameters.AddWithValue("@Id", id);
                updateCmd.Parameters.AddWithValue("@NewBedId", newBedId);
                await updateCmd.ExecuteNonQueryAsync();
            }

            const string occupyNewBedSql = "UPDATE dbo.Beds SET Status = 'Occupied' WHERE Id = @BedId";
            using (var occupyCmd = new SqlCommand(occupyNewBedSql, conn, tx))
            {
                occupyCmd.Parameters.AddWithValue("@BedId", newBedId);
                await occupyCmd.ExecuteNonQueryAsync();
            }

            const string freeOldBedSql = "UPDATE dbo.Beds SET Status = 'Available' WHERE Id = @BedId";
            using (var freeCmd = new SqlCommand(freeOldBedSql, conn, tx))
            {
                freeCmd.Parameters.AddWithValue("@BedId", oldBedId);
                await freeCmd.ExecuteNonQueryAsync();
            }

            tx.Commit();
            return true;
        }
        catch
        {
            tx.Rollback();
            throw;
        }
    }

    private static Admission Map(SqlDataReader reader) => new()
    {
        Id = reader.GetInt32(reader.GetOrdinal("Id")),
        PatientId = reader.GetInt32(reader.GetOrdinal("PatientId")),
        AdmittingDoctorId = reader.GetInt32(reader.GetOrdinal("AdmittingDoctorId")),
        BedId = reader.GetInt32(reader.GetOrdinal("BedId")),
        AdmissionDate = reader.GetDateTime(reader.GetOrdinal("AdmissionDate")),
        ExpectedDischargeDate = reader.IsDBNull(reader.GetOrdinal("ExpectedDischargeDate")) ? null : reader.GetDateTime(reader.GetOrdinal("ExpectedDischargeDate")),
        DischargeDate = reader.IsDBNull(reader.GetOrdinal("DischargeDate")) ? null : reader.GetDateTime(reader.GetOrdinal("DischargeDate")),
        ReasonForAdmission = reader.GetString(reader.GetOrdinal("ReasonForAdmission")),
        Status = reader.GetString(reader.GetOrdinal("Status")),
        DischargeSummary = reader.IsDBNull(reader.GetOrdinal("DischargeSummary")) ? null : reader.GetString(reader.GetOrdinal("DischargeSummary")),
        CreatedAt = reader.GetDateTime(reader.GetOrdinal("CreatedAt")),
        UpdatedAt = reader.IsDBNull(reader.GetOrdinal("UpdatedAt")) ? null : reader.GetDateTime(reader.GetOrdinal("UpdatedAt")),
        PatientName = reader.GetString(reader.GetOrdinal("PatientName")),
        DoctorName = reader.GetString(reader.GetOrdinal("DoctorName")),
        BedNumber = reader.GetString(reader.GetOrdinal("BedNumber")),
        WardName = reader.GetString(reader.GetOrdinal("WardName"))
    };
}

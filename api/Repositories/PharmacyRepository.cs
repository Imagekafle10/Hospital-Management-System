using HospitalMgmtSystem.Data;
using HospitalMgmtSystem.Models;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Repositories;

public interface IPharmacyRepository
{
    Task<int> CreateMedicineAsync(Medicine m);
    Task<Medicine?> GetMedicineAsync(int id);
    Task<List<Medicine>> GetMedicinesAsync(string? search, string? category, bool lowStockOnly, bool expiredOrExpiringSoon, bool includeInactive);
    Task<bool> UpdateMedicineAsync(int id, string? name, string? generic, string? category, string? manufacturer,
        string? batch, string? unit, decimal? price, int? reorder, DateTime? expiry, bool? isActive);
    Task<bool> DeleteMedicineAsync(int id);
    Task<bool> HasDispensesAsync(int medicineId);
    Task<bool> AdjustStockAsync(int id, int delta, string? batch, DateTime? expiry);

    // Returns (dispenseId, error). Atomic: stock check + decrement + insert in one transaction.
    Task<(int? Id, string? Error)> DispenseAsync(int patientId, int medicineId, int quantity, int? prescriptionId, int userId, string? notes);
    Task<List<PharmacyDispense>> GetDispensesAsync(int? patientId, int? medicineId);
    Task<List<object>> GetPatientPrescriptionsAsync(int patientId);
}

public class PharmacyRepository : IPharmacyRepository
{
    private readonly ISqlConnectionFactory _factory;
    public PharmacyRepository(ISqlConnectionFactory factory) => _factory = factory;

    private const string MedSelect = @"SELECT Id, Name, GenericName, Category, Manufacturer, BatchNumber, Unit, UnitPrice,
                                              StockQuantity, ReorderLevel, ExpiryDate, IsActive, CreatedAt
                                       FROM dbo.Medicines";

    public async Task<int> CreateMedicineAsync(Medicine m)
    {
        const string sql = @"INSERT INTO dbo.Medicines
            (Name, GenericName, Category, Manufacturer, BatchNumber, Unit, UnitPrice, StockQuantity, ReorderLevel, ExpiryDate, IsActive, CreatedAt)
            OUTPUT INSERTED.Id
            VALUES (@Name, @GenericName, @Category, @Manufacturer, @BatchNumber, @Unit, @UnitPrice, @Stock, @Reorder, @Expiry, 1, SYSUTCDATETIME())";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Name", m.Name);
        cmd.Parameters.AddWithValue("@GenericName", (object?)m.GenericName ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Category", (object?)m.Category ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Manufacturer", (object?)m.Manufacturer ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@BatchNumber", (object?)m.BatchNumber ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Unit", m.Unit);
        cmd.Parameters.AddWithValue("@UnitPrice", m.UnitPrice);
        cmd.Parameters.AddWithValue("@Stock", m.StockQuantity);
        cmd.Parameters.AddWithValue("@Reorder", m.ReorderLevel);
        cmd.Parameters.AddWithValue("@Expiry", (object?)m.ExpiryDate ?? DBNull.Value);
        await conn.OpenAsync();
        return Convert.ToInt32(await cmd.ExecuteScalarAsync());
    }

    public async Task<Medicine?> GetMedicineAsync(int id)
    {
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand($"{MedSelect} WHERE Id = @Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        await conn.OpenAsync();
        using var r = await cmd.ExecuteReaderAsync();
        return await r.ReadAsync() ? MapMed(r) : null;
    }

    public async Task<List<Medicine>> GetMedicinesAsync(string? search, string? category, bool lowStockOnly, bool expiredOrExpiringSoon, bool includeInactive)
    {
        var where = new List<string>();
        if (!includeInactive) where.Add("IsActive = 1");
        if (!string.IsNullOrWhiteSpace(search)) where.Add("(Name LIKE @Search OR GenericName LIKE @Search)");
        if (!string.IsNullOrWhiteSpace(category)) where.Add("Category = @Category");
        if (lowStockOnly) where.Add("StockQuantity <= ReorderLevel");
        if (expiredOrExpiringSoon) where.Add("ExpiryDate IS NOT NULL AND ExpiryDate <= DATEADD(DAY, 90, CAST(SYSUTCDATETIME() AS DATE))");

        var sql = MedSelect + (where.Count > 0 ? " WHERE " + string.Join(" AND ", where) : "") + " ORDER BY Name";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        if (!string.IsNullOrWhiteSpace(search)) cmd.Parameters.AddWithValue("@Search", $"%{search}%");
        if (!string.IsNullOrWhiteSpace(category)) cmd.Parameters.AddWithValue("@Category", category);

        var list = new List<Medicine>();
        await conn.OpenAsync();
        using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync()) list.Add(MapMed(r));
        return list;
    }

    public async Task<bool> UpdateMedicineAsync(int id, string? name, string? generic, string? category, string? manufacturer,
        string? batch, string? unit, decimal? price, int? reorder, DateTime? expiry, bool? isActive)
    {
        const string sql = @"UPDATE dbo.Medicines SET
                                Name = COALESCE(@Name, Name),
                                GenericName = COALESCE(@Generic, GenericName),
                                Category = COALESCE(@Category, Category),
                                Manufacturer = COALESCE(@Manufacturer, Manufacturer),
                                BatchNumber = COALESCE(@Batch, BatchNumber),
                                Unit = COALESCE(@Unit, Unit),
                                UnitPrice = COALESCE(@Price, UnitPrice),
                                ReorderLevel = COALESCE(@Reorder, ReorderLevel),
                                ExpiryDate = COALESCE(@Expiry, ExpiryDate),
                                IsActive = COALESCE(@IsActive, IsActive)
                             WHERE Id = @Id";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@Name", (object?)name ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Generic", (object?)generic ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Category", (object?)category ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Manufacturer", (object?)manufacturer ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Batch", (object?)batch ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Unit", (object?)unit ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Price", (object?)price ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Reorder", (object?)reorder ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Expiry", (object?)expiry ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@IsActive", (object?)isActive ?? DBNull.Value);
        await conn.OpenAsync();
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> DeleteMedicineAsync(int id)
    {
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand("DELETE FROM dbo.Medicines WHERE Id = @Id", conn);
        cmd.Parameters.AddWithValue("@Id", id);
        await conn.OpenAsync();
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<bool> HasDispensesAsync(int medicineId)
    {
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand("SELECT COUNT(*) FROM dbo.PharmacyDispenses WHERE MedicineId = @Id", conn);
        cmd.Parameters.AddWithValue("@Id", medicineId);
        await conn.OpenAsync();
        return (int)(await cmd.ExecuteScalarAsync())! > 0;
    }

    public async Task<bool> AdjustStockAsync(int id, int delta, string? batch, DateTime? expiry)
    {
        // Never allow stock to go below zero.
        const string sql = @"UPDATE dbo.Medicines SET
                                StockQuantity = StockQuantity + @Delta,
                                BatchNumber = COALESCE(@Batch, BatchNumber),
                                ExpiryDate = COALESCE(@Expiry, ExpiryDate)
                             WHERE Id = @Id AND StockQuantity + @Delta >= 0";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@Id", id);
        cmd.Parameters.AddWithValue("@Delta", delta);
        cmd.Parameters.AddWithValue("@Batch", (object?)batch ?? DBNull.Value);
        cmd.Parameters.AddWithValue("@Expiry", (object?)expiry ?? DBNull.Value);
        await conn.OpenAsync();
        return await cmd.ExecuteNonQueryAsync() > 0;
    }

    public async Task<(int? Id, string? Error)> DispenseAsync(int patientId, int medicineId, int quantity, int? prescriptionId, int userId, string? notes)
    {
        using var conn = _factory.CreateConnection();
        await conn.OpenAsync();
        using var tx = conn.BeginTransaction();
        try
        {
            // Lock the row so concurrent dispenses can't oversell stock.
            decimal price; int stock; bool active; DateTime? expiry;
            using (var cmd = new SqlCommand(
                "SELECT UnitPrice, StockQuantity, IsActive, ExpiryDate FROM dbo.Medicines WITH (UPDLOCK, ROWLOCK) WHERE Id = @Id", conn, tx))
            {
                cmd.Parameters.AddWithValue("@Id", medicineId);
                using var r = await cmd.ExecuteReaderAsync();
                if (!await r.ReadAsync()) { return (null, "Medicine not found."); }
                price = r.GetDecimal(0);
                stock = r.GetInt32(1);
                active = r.GetBoolean(2);
                expiry = r.IsDBNull(3) ? null : r.GetDateTime(3);
            }

            if (!active) { tx.Rollback(); return (null, "This medicine is inactive."); }
            if (expiry.HasValue && expiry.Value.Date < DateTime.UtcNow.Date) { tx.Rollback(); return (null, "This medicine is expired and cannot be dispensed."); }
            if (stock < quantity) { tx.Rollback(); return (null, $"Insufficient stock. Available: {stock}."); }

            using (var cmd = new SqlCommand("UPDATE dbo.Medicines SET StockQuantity = StockQuantity - @Q WHERE Id = @Id", conn, tx))
            {
                cmd.Parameters.AddWithValue("@Q", quantity);
                cmd.Parameters.AddWithValue("@Id", medicineId);
                await cmd.ExecuteNonQueryAsync();
            }

            int newId;
            using (var cmd = new SqlCommand(@"INSERT INTO dbo.PharmacyDispenses
                    (PrescriptionId, PatientId, MedicineId, Quantity, UnitPrice, TotalPrice, DispensedByUserId, Notes, CreatedAt)
                    OUTPUT INSERTED.Id
                    VALUES (@PrescriptionId, @PatientId, @MedicineId, @Q, @Price, @Total, @UserId, @Notes, SYSUTCDATETIME())", conn, tx))
            {
                cmd.Parameters.AddWithValue("@PrescriptionId", (object?)prescriptionId ?? DBNull.Value);
                cmd.Parameters.AddWithValue("@PatientId", patientId);
                cmd.Parameters.AddWithValue("@MedicineId", medicineId);
                cmd.Parameters.AddWithValue("@Q", quantity);
                cmd.Parameters.AddWithValue("@Price", price);
                cmd.Parameters.AddWithValue("@Total", price * quantity);
                cmd.Parameters.AddWithValue("@UserId", userId);
                cmd.Parameters.AddWithValue("@Notes", (object?)notes ?? DBNull.Value);
                newId = Convert.ToInt32(await cmd.ExecuteScalarAsync());
            }

            tx.Commit();
            return (newId, null);
        }
        catch
        {
            try { tx.Rollback(); } catch { /* already rolled back */ }
            throw;
        }
    }

    public async Task<List<PharmacyDispense>> GetDispensesAsync(int? patientId, int? medicineId)
    {
        var where = new List<string>();
        if (patientId.HasValue) where.Add("d.PatientId = @PatientId");
        if (medicineId.HasValue) where.Add("d.MedicineId = @MedicineId");

        var sql = @"SELECT d.Id, d.PrescriptionId, d.PatientId, u.FullName AS PatientName, d.MedicineId, m.Name AS MedicineName,
                           d.Quantity, d.UnitPrice, d.TotalPrice, d.DispensedByUserId, d.Notes, d.CreatedAt
                    FROM dbo.PharmacyDispenses d
                    JOIN dbo.Medicines m ON m.Id = d.MedicineId
                    JOIN dbo.Patients p ON p.Id = d.PatientId
                    JOIN dbo.Users u ON u.Id = p.UserId"
                  + (where.Count > 0 ? " WHERE " + string.Join(" AND ", where) : "")
                  + " ORDER BY d.CreatedAt DESC";

        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        if (patientId.HasValue) cmd.Parameters.AddWithValue("@PatientId", patientId.Value);
        if (medicineId.HasValue) cmd.Parameters.AddWithValue("@MedicineId", medicineId.Value);

        var list = new List<PharmacyDispense>();
        await conn.OpenAsync();
        using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
        {
            list.Add(new PharmacyDispense
            {
                Id = r.GetInt32(r.GetOrdinal("Id")),
                PrescriptionId = r.IsDBNull(r.GetOrdinal("PrescriptionId")) ? null : r.GetInt32(r.GetOrdinal("PrescriptionId")),
                PatientId = r.GetInt32(r.GetOrdinal("PatientId")),
                PatientName = r.GetString(r.GetOrdinal("PatientName")),
                MedicineId = r.GetInt32(r.GetOrdinal("MedicineId")),
                MedicineName = r.GetString(r.GetOrdinal("MedicineName")),
                Quantity = r.GetInt32(r.GetOrdinal("Quantity")),
                UnitPrice = r.GetDecimal(r.GetOrdinal("UnitPrice")),
                TotalPrice = r.GetDecimal(r.GetOrdinal("TotalPrice")),
                DispensedByUserId = r.GetInt32(r.GetOrdinal("DispensedByUserId")),
                Notes = r.IsDBNull(r.GetOrdinal("Notes")) ? null : r.GetString(r.GetOrdinal("Notes")),
                CreatedAt = r.GetDateTime(r.GetOrdinal("CreatedAt"))
            });
        }
        return list;
    }

    public async Task<List<object>> GetPatientPrescriptionsAsync(int patientId)
    {
        const string sql = @"SELECT pr.Id, pr.AppointmentId, pr.Medication, pr.Dosage, pr.Instructions, pr.CreatedAt, du.FullName AS DoctorName
                             FROM dbo.Prescriptions pr
                             JOIN dbo.Appointments a ON a.Id = pr.AppointmentId
                             JOIN dbo.Doctors d ON d.Id = a.DoctorId
                             JOIN dbo.Users du ON du.Id = d.UserId
                             WHERE a.PatientId = @PatientId ORDER BY pr.CreatedAt DESC";
        using var conn = _factory.CreateConnection();
        using var cmd = new SqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("@PatientId", patientId);
        var list = new List<object>();
        await conn.OpenAsync();
        using var r = await cmd.ExecuteReaderAsync();
        while (await r.ReadAsync())
            list.Add(new
            {
                id = r.GetInt32(0), appointmentId = r.GetInt32(1), medication = r.GetString(2),
                dosage = r.IsDBNull(3) ? null : r.GetString(3), instructions = r.IsDBNull(4) ? null : r.GetString(4),
                createdAt = r.GetDateTime(5), doctorName = r.GetString(6)
            });
        return list;
    }

    private static string? S(SqlDataReader r, string c) => r.IsDBNull(r.GetOrdinal(c)) ? null : r.GetString(r.GetOrdinal(c));

    private static Medicine MapMed(SqlDataReader r) => new()
    {
        Id = r.GetInt32(r.GetOrdinal("Id")),
        Name = r.GetString(r.GetOrdinal("Name")),
        GenericName = S(r, "GenericName"),
        Category = S(r, "Category"),
        Manufacturer = S(r, "Manufacturer"),
        BatchNumber = S(r, "BatchNumber"),
        Unit = r.GetString(r.GetOrdinal("Unit")),
        UnitPrice = r.GetDecimal(r.GetOrdinal("UnitPrice")),
        StockQuantity = r.GetInt32(r.GetOrdinal("StockQuantity")),
        ReorderLevel = r.GetInt32(r.GetOrdinal("ReorderLevel")),
        ExpiryDate = r.IsDBNull(r.GetOrdinal("ExpiryDate")) ? null : r.GetDateTime(r.GetOrdinal("ExpiryDate")),
        IsActive = r.GetBoolean(r.GetOrdinal("IsActive")),
        CreatedAt = r.GetDateTime(r.GetOrdinal("CreatedAt"))
    };
}

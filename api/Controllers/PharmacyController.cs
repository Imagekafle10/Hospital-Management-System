using System.Security.Claims;
using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Models;
using HospitalMgmtSystem.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PharmacyController : ControllerBase
{
    private readonly IPharmacyRepository _repo;
    private readonly IPatientRepository _patientRepo;

    public PharmacyController(IPharmacyRepository repo, IPatientRepository patientRepo)
    {
        _repo = repo;
        _patientRepo = patientRepo;
    }

    private int CurrentUserId => int.Parse(User.FindFirstValue("userId")!);

    // ---------------- Medicines (catalog + stock) ----------------

    [HttpPost("medicines")]
    [Authorize(Roles = "Admin,Pharmacist")]
    public async Task<IActionResult> CreateMedicine(CreateMedicineDto dto)
    {
        var id = await _repo.CreateMedicineAsync(new Medicine
        {
            Name = dto.Name, GenericName = dto.GenericName, Category = dto.Category,
            Manufacturer = dto.Manufacturer, BatchNumber = dto.BatchNumber, Unit = dto.Unit,
            UnitPrice = dto.UnitPrice, StockQuantity = dto.StockQuantity,
            ReorderLevel = dto.ReorderLevel, ExpiryDate = dto.ExpiryDate
        });
        var created = await _repo.GetMedicineAsync(id);
        return CreatedAtAction(nameof(GetMedicine), new { id }, created);
    }

    // Admin/Doctor can browse stock (doctors use it when prescribing).
    [HttpGet("medicines")]
    [Authorize(Roles = "Admin,Doctor,Pharmacist")]
    public async Task<IActionResult> GetMedicines(
        [FromQuery] string? search, [FromQuery] string? category,
        [FromQuery] bool lowStock = false, [FromQuery] bool expiring = false,
        [FromQuery] bool includeInactive = false)
    {
        var inactive = includeInactive && (User.IsInRole("Admin") || User.IsInRole("Pharmacist"));
        return Ok(await _repo.GetMedicinesAsync(search, category, lowStock, expiring, inactive));
    }

    [HttpGet("medicines/{id:int}")]
    [Authorize(Roles = "Admin,Doctor,Pharmacist")]
    public async Task<IActionResult> GetMedicine(int id)
    {
        var m = await _repo.GetMedicineAsync(id);
        return m == null ? NotFound() : Ok(m);
    }

    [HttpPut("medicines/{id:int}")]
    [Authorize(Roles = "Admin,Pharmacist")]
    public async Task<IActionResult> UpdateMedicine(int id, UpdateMedicineDto dto)
    {
        if (await _repo.GetMedicineAsync(id) == null) return NotFound();
        var ok = await _repo.UpdateMedicineAsync(id, dto.Name, dto.GenericName, dto.Category, dto.Manufacturer,
            dto.BatchNumber, dto.Unit, dto.UnitPrice, dto.ReorderLevel, dto.ExpiryDate, dto.IsActive);
        return ok ? NoContent() : StatusCode(500, "Update failed.");
    }

    // Add stock (positive) or write off stock (negative).
    [HttpPost("medicines/{id:int}/restock")]
    [Authorize(Roles = "Admin,Pharmacist")]
    public async Task<IActionResult> Restock(int id, RestockDto dto)
    {
        if (dto.Quantity == 0) return BadRequest("Quantity cannot be 0.");
        if (await _repo.GetMedicineAsync(id) == null) return NotFound();

        var ok = await _repo.AdjustStockAsync(id, dto.Quantity, dto.BatchNumber, dto.ExpiryDate);
        if (!ok) return BadRequest("Stock cannot go below zero.");
        return Ok(await _repo.GetMedicineAsync(id));
    }

    [HttpDelete("medicines/{id:int}")]
    [Authorize(Roles = "Admin,Pharmacist")]
    public async Task<IActionResult> DeleteMedicine(int id)
    {
        if (await _repo.GetMedicineAsync(id) == null) return NotFound();
        if (await _repo.HasDispensesAsync(id))
            return Conflict("This medicine has dispensing history. Mark it inactive instead of deleting.");
        return await _repo.DeleteMedicineAsync(id) ? NoContent() : StatusCode(500, "Delete failed.");
    }

    // ---------------- Dispensing ----------------

    [HttpPost("dispense")]
    [Authorize(Roles = "Admin,Pharmacist")]
    public async Task<IActionResult> Dispense(DispenseDto dto)
    {
        if (await _patientRepo.GetByIdAsync(dto.PatientId) == null)
            return NotFound("Patient not found.");

        var (id, error) = await _repo.DispenseAsync(dto.PatientId, dto.MedicineId, dto.Quantity,
            dto.PrescriptionId, CurrentUserId, dto.Notes);
        if (error != null) return BadRequest(error);

        return Ok(new { dispenseId = id });
    }

    [HttpGet("dispenses")]
    [Authorize(Roles = "Admin,Pharmacist")]
    public async Task<IActionResult> GetDispenses([FromQuery] int? patientId, [FromQuery] int? medicineId)
        => Ok(await _repo.GetDispensesAsync(patientId, medicineId));

    // Prescriptions written for a patient (so the pharmacist can see what to dispense).
    [HttpGet("prescriptions/patient/{patientId:int}")]
    [Authorize(Roles = "Admin,Pharmacist")]
    public async Task<IActionResult> PatientPrescriptions(int patientId)
        => Ok(await _repo.GetPatientPrescriptionsAsync(patientId));

    // A patient's own pharmacy history.
    [HttpGet("dispenses/mine")]
    [Authorize(Roles = "Patient")]
    public async Task<IActionResult> MyDispenses()
    {
        var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
        if (patient == null) return NotFound("Patient profile not found.");
        return Ok(await _repo.GetDispensesAsync(patient.Id, null));
    }
}

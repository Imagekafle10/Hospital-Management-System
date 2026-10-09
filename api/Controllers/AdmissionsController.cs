using System.Security.Claims;
using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AdmissionsController : ControllerBase
{
    private readonly IAdmissionRepository _admissionRepo;
    private readonly IBedRepository _bedRepo;
    private readonly IPatientRepository _patientRepo;
    private readonly IDoctorRepository _doctorRepo;

    public AdmissionsController(
        IAdmissionRepository admissionRepo,
        IBedRepository bedRepo,
        IPatientRepository patientRepo,
        IDoctorRepository doctorRepo)
    {
        _admissionRepo = admissionRepo;
        _bedRepo = bedRepo;
        _patientRepo = patientRepo;
        _doctorRepo = doctorRepo;
    }

    private int CurrentUserId => int.Parse(User.FindFirstValue("userId")!);
    private string CurrentRole => User.FindFirstValue(ClaimTypes.Role) ?? string.Empty;

    // Admits a patient into a specific bed. Doctor is recorded as the admitting doctor (or chosen by Admin).
    [HttpPost]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> Admit(CreateAdmissionDto dto)
    {
        var patient = await _patientRepo.GetByIdAsync(dto.PatientId);
        if (patient == null) return BadRequest("Patient not found.");

        var existingActive = await _admissionRepo.GetActiveByPatientIdAsync(dto.PatientId);
        if (existingActive != null)
            return Conflict($"This patient is already admitted (bed {existingActive.BedNumber}, {existingActive.WardName}).");

        var bed = await _bedRepo.GetByIdAsync(dto.BedId);
        if (bed == null) return BadRequest("Bed not found.");
        if (bed.Status != "Available") return Conflict($"Bed {bed.BedNumber} is not available (status: {bed.Status}).");

        int admittingDoctorId;
        if (CurrentRole == "Doctor")
        {
            var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
            if (doctor == null) return NotFound("Doctor profile not found.");
            admittingDoctorId = doctor.Id;
        }
        else // Admin
        {
            if (dto.AdmittingDoctorId == null) return BadRequest("AdmittingDoctorId is required when an admin creates the admission.");
            var doctor = await _doctorRepo.GetByIdAsync(dto.AdmittingDoctorId.Value);
            if (doctor == null) return BadRequest("Admitting doctor not found.");
            admittingDoctorId = doctor.Id;
        }

        var admissionId = await _admissionRepo.AdmitAsync(dto.PatientId, admittingDoctorId, dto.BedId, dto.ReasonForAdmission, dto.ExpectedDischargeDate);
        if (admissionId == null)
            return Conflict("This bed was just taken by another admission. Please pick a different bed.");

        var created = await _admissionRepo.GetByIdAsync(admissionId.Value);
        return CreatedAtAction(nameof(GetById), new { id = admissionId }, created);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var admission = await _admissionRepo.GetByIdAsync(id);
        if (admission == null) return NotFound();

        if (CurrentRole == "Patient")
        {
            var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
            if (patient == null || patient.Id != admission.PatientId) return Forbid();
        }

        return Ok(admission);
    }

    // Currently admitted patients hospital-wide (for ward/bed management).
    [HttpGet("active")]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> GetActive()
    {
        return Ok(await _admissionRepo.GetActiveAsync());
    }

    [HttpGet("mine")]
    [Authorize(Roles = "Patient")]
    public async Task<IActionResult> GetMine()
    {
        var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
        if (patient == null) return NotFound("Patient profile not found.");

        return Ok(await _admissionRepo.GetByPatientIdAsync(patient.Id));
    }

    [HttpGet("patient/{patientId:int}")]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> GetByPatient(int patientId)
    {
        var patient = await _patientRepo.GetByIdAsync(patientId);
        if (patient == null) return NotFound("Patient not found.");

        return Ok(await _admissionRepo.GetByPatientIdAsync(patientId));
    }

    [HttpPut("{id:int}/discharge")]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> Discharge(int id, DischargeAdmissionDto dto)
    {
        var admission = await _admissionRepo.GetByIdAsync(id);
        if (admission == null) return NotFound();

        if (admission.Status != "Admitted")
            return Conflict("This patient has already been discharged.");

        if (CurrentRole == "Doctor")
        {
            var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
            if (doctor == null || doctor.Id != admission.AdmittingDoctorId)
                return StatusCode(StatusCodes.Status403Forbidden, new { message = "Only the admitting doctor or an admin can discharge this patient." });
        }

        var success = await _admissionRepo.DischargeAsync(id, dto.DischargeSummary);
        return success ? NoContent() : Conflict("Discharge failed — the admission may have already been updated.");
    }

    [HttpPut("{id:int}/transfer-bed")]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> TransferBed(int id, TransferBedDto dto)
    {
        var admission = await _admissionRepo.GetByIdAsync(id);
        if (admission == null) return NotFound();

        if (admission.Status != "Admitted")
            return Conflict("Cannot transfer a bed for a patient who is not currently admitted.");

        var newBed = await _bedRepo.GetByIdAsync(dto.NewBedId);
        if (newBed == null) return BadRequest("Target bed not found.");
        if (newBed.Status != "Available") return Conflict($"Bed {newBed.BedNumber} is not available.");

        var success = await _admissionRepo.TransferBedAsync(id, dto.NewBedId);
        return success
            ? NoContent()
            : Conflict("Transfer failed — the target bed may have just been taken, or the admission changed.");
    }
}

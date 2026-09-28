using System.Security.Claims;
using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Models;
using HospitalMgmtSystem.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.StaticFiles;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MedicalRecordsController : ControllerBase
{
    private static readonly string[] ValidRecordTypes = { "LabReport", "Prescription", "Diagnosis", "Imaging", "Other" };
    private static readonly string[] AllowedExtensions = { ".pdf", ".jpg", ".jpeg", ".png", ".doc", ".docx" };

    private readonly IMedicalRecordRepository _recordRepo;
    private readonly IPatientRepository _patientRepo;
    private readonly IDoctorRepository _doctorRepo;
    private readonly IAppointmentRepository _appointmentRepo;
    private readonly IConfiguration _config;
    private readonly IWebHostEnvironment _env;

    public MedicalRecordsController(
        IMedicalRecordRepository recordRepo,
        IPatientRepository patientRepo,
        IDoctorRepository doctorRepo,
        IAppointmentRepository appointmentRepo,
        IConfiguration config,
        IWebHostEnvironment env)
    {
        _recordRepo = recordRepo;
        _patientRepo = patientRepo;
        _doctorRepo = doctorRepo;
        _appointmentRepo = appointmentRepo;
        _config = config;
        _env = env;
    }

    private int CurrentUserId => int.Parse(User.FindFirstValue("userId")!);
    private string CurrentRole => User.FindFirstValue(ClaimTypes.Role) ?? string.Empty;

    private string StorageRoot
    {
        get
        {
            var configured = _config["FileStorage:MedicalRecordsPath"] ?? "App_Data/medical-records";
            var root = Path.IsPathRooted(configured) ? configured : Path.Combine(_env.ContentRootPath, configured);
            Directory.CreateDirectory(root);
            return root;
        }
    }

    private long MaxFileSizeBytes => (_config.GetValue<long?>("FileStorage:MaxFileSizeMb") ?? 20) * 1024 * 1024;

    // Patient uploads their own record, or Doctor/Admin uploads on behalf of a patient.
    [HttpPost]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(50_000_000)]
    public async Task<IActionResult> Upload([FromForm] UploadMedicalRecordDto dto)
    {
        if (!ValidRecordTypes.Contains(dto.RecordType))
            return BadRequest($"RecordType must be one of: {string.Join(", ", ValidRecordTypes)}");

        if (dto.File.Length == 0)
            return BadRequest("File is empty.");

        if (dto.File.Length > MaxFileSizeBytes)
            return BadRequest($"File exceeds the {MaxFileSizeBytes / (1024 * 1024)} MB limit.");

        var extension = Path.GetExtension(dto.File.FileName).ToLowerInvariant();
        if (!AllowedExtensions.Contains(extension))
            return BadRequest($"File type not allowed. Allowed types: {string.Join(", ", AllowedExtensions)}");

        int patientId;
        int? doctorId = null;

        if (CurrentRole == "Patient")
        {
            var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
            if (patient == null) return NotFound("Patient profile not found.");
            patientId = patient.Id;
        }
        else if (CurrentRole == "Doctor")
        {
            var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
            if (doctor == null) return NotFound("Doctor profile not found.");
            doctorId = doctor.Id;

            if (dto.PatientId == null) return BadRequest("PatientId is required when a doctor uploads a record.");
            var targetPatient = await _patientRepo.GetByIdAsync(dto.PatientId.Value);
            if (targetPatient == null) return BadRequest("Patient not found.");
            patientId = targetPatient.Id;
        }
        else // Admin
        {
            if (dto.PatientId == null) return BadRequest("PatientId is required.");
            var targetPatient = await _patientRepo.GetByIdAsync(dto.PatientId.Value);
            if (targetPatient == null) return BadRequest("Patient not found.");
            patientId = targetPatient.Id;
        }

        if (dto.AppointmentId != null)
        {
            var appointment = await _appointmentRepo.GetByIdAsync(dto.AppointmentId.Value);
            if (appointment == null) return BadRequest("Appointment not found.");
            if (appointment.PatientId != patientId) return BadRequest("Appointment does not belong to this patient.");
        }

        var storedFileName = $"{Guid.NewGuid():N}{extension}";
        var fullPath = Path.Combine(StorageRoot, storedFileName);

        await using (var stream = System.IO.File.Create(fullPath))
        {
            await dto.File.CopyToAsync(stream);
        }

        var record = new MedicalRecord
        {
            PatientId = patientId,
            DoctorId = doctorId,
            AppointmentId = dto.AppointmentId,
            RecordType = dto.RecordType,
            Title = dto.Title,
            Description = dto.Description,
            FileName = dto.File.FileName,
            StoredFileName = storedFileName,
            ContentType = dto.File.ContentType,
            FileSizeBytes = dto.File.Length,
            UploadedByUserId = CurrentUserId
        };

        var id = await _recordRepo.CreateAsync(record);
        var created = await _recordRepo.GetByIdAsync(id);
        return CreatedAtAction(nameof(GetById), new { id }, ToDto(created!));
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var record = await _recordRepo.GetByIdAsync(id);
        if (record == null) return NotFound();

        if (!await UserCanAccessRecord(record))
            return Forbid();

        return Ok(ToDto(record));
    }

    [HttpGet("{id:int}/download")]
    public async Task<IActionResult> Download(int id)
    {
        var record = await _recordRepo.GetByIdAsync(id);
        if (record == null) return NotFound();

        if (!await UserCanAccessRecord(record))
            return Forbid();

        var fullPath = Path.Combine(StorageRoot, record.StoredFileName);
        if (!System.IO.File.Exists(fullPath))
            return NotFound("Stored file is missing.");

        var contentType = record.ContentType;
        if (string.IsNullOrWhiteSpace(contentType) &&
            new FileExtensionContentTypeProvider().TryGetContentType(fullPath, out var detected))
        {
            contentType = detected;
        }

        var bytes = await System.IO.File.ReadAllBytesAsync(fullPath);
        return File(bytes, string.IsNullOrWhiteSpace(contentType) ? "application/octet-stream" : contentType, record.FileName);
    }

    // Patient: own records. Doctor: records for a given patient (must have treated them). Admin: any patient.
    [HttpGet("patient/{patientId:int}")]
    public async Task<IActionResult> GetByPatient(int patientId)
    {
        if (CurrentRole == "Patient")
        {
            var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
            if (patient == null || patient.Id != patientId) return Forbid();
        }
        else if (CurrentRole == "Doctor")
        {
            var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
            if (doctor == null) return Forbid();

            var appointments = await _appointmentRepo.GetByDoctorIdAsync(doctor.Id);
            var hasTreatedPatient = appointments.Any(a => a.PatientId == patientId);
            if (!hasTreatedPatient) return StatusCode(StatusCodes.Status403Forbidden, new { message = "You may only view records for patients you have appointments with." });
        }
        // Admin: no restriction

        var records = await _recordRepo.GetByPatientIdAsync(patientId);
        return Ok(records.Select(ToDto));
    }

    [HttpGet("mine")]
    [Authorize(Roles = "Patient")]
    public async Task<IActionResult> GetMine()
    {
        var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
        if (patient == null) return NotFound("Patient profile not found.");

        var records = await _recordRepo.GetByPatientIdAsync(patient.Id);
        return Ok(records.Select(ToDto));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> Delete(int id)
    {
        var record = await _recordRepo.GetByIdAsync(id);
        if (record == null) return NotFound();

        // Only the uploader or an Admin can delete.
        if (CurrentRole != "Admin" && record.UploadedByUserId != CurrentUserId)
            return Forbid();

        var deleted = await _recordRepo.DeleteAsync(id);
        if (!deleted) return StatusCode(500, "Delete failed.");

        var fullPath = Path.Combine(StorageRoot, record.StoredFileName);
        if (System.IO.File.Exists(fullPath))
        {
            System.IO.File.Delete(fullPath);
        }

        return NoContent();
    }

    private async Task<bool> UserCanAccessRecord(MedicalRecord record)
    {
        if (CurrentRole == "Admin") return true;

        if (CurrentRole == "Patient")
        {
            var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
            return patient != null && patient.Id == record.PatientId;
        }

        if (CurrentRole == "Doctor")
        {
            var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
            if (doctor == null) return false;
            if (record.DoctorId == doctor.Id) return true;

            var appointments = await _appointmentRepo.GetByDoctorIdAsync(doctor.Id);
            return appointments.Any(a => a.PatientId == record.PatientId);
        }

        return false;
    }

    private static MedicalRecordResponseDto ToDto(MedicalRecord r) => new()
    {
        Id = r.Id,
        PatientId = r.PatientId,
        DoctorId = r.DoctorId,
        AppointmentId = r.AppointmentId,
        RecordType = r.RecordType,
        Title = r.Title,
        Description = r.Description,
        FileName = r.FileName,
        ContentType = r.ContentType,
        FileSizeBytes = r.FileSizeBytes,
        UploadedByUserId = r.UploadedByUserId,
        CreatedAt = r.CreatedAt
    };
}
using System.Security.Claims;
using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class AppointmentsController : ControllerBase
{
    private readonly IAppointmentRepository _appointmentRepo;
    private readonly IPatientRepository _patientRepo;
    private readonly IDoctorRepository _doctorRepo;
    private readonly IPrescriptionRepository _prescriptionRepo;

    private static readonly string[] ValidStatuses = { "Pending", "Confirmed", "Completed", "Cancelled" };

    public AppointmentsController(
        IAppointmentRepository appointmentRepo,
        IPatientRepository patientRepo,
        IDoctorRepository doctorRepo,
        IPrescriptionRepository prescriptionRepo)
    {
        _appointmentRepo = appointmentRepo;
        _patientRepo = patientRepo;
        _doctorRepo = doctorRepo;
        _prescriptionRepo = prescriptionRepo;
    }

    private int CurrentUserId => int.Parse(User.FindFirstValue("userId")!);

    // Patient books an appointment with a doctor
    [HttpPost]
    [Authorize(Roles = "Patient")]
    public async Task<IActionResult> Create(CreateAppointmentDto dto)
    {
        var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
        if (patient == null) return NotFound("Patient profile not found.");

        var doctor = await _doctorRepo.GetByIdAsync(dto.DoctorId);
        if (doctor == null) return BadRequest("Doctor not found.");

        if (dto.AppointmentDate <= DateTime.UtcNow)
            return BadRequest("Appointment date must be in the future.");

        var alreadyBooked = await _appointmentRepo.IsDoctorBookedAsync(dto.DoctorId, dto.AppointmentDate);
        if (alreadyBooked)
            return Conflict("This doctor already has an appointment at that exact time.");

        var id = await _appointmentRepo.CreateAsync(patient.Id, dto.DoctorId, dto.AppointmentDate, dto.Reason);
        var created = await _appointmentRepo.GetByIdAsync(id);
        return CreatedAtAction(nameof(GetById), new { id }, created);
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var appointment = await _appointmentRepo.GetByIdAsync(id);
        if (appointment == null) return NotFound();

        if (!await UserCanAccessAppointment(appointment))
            return Forbid();

        return Ok(appointment);
    }

    // Patient: my appointments. Doctor: my appointments. Admin: all appointments.
    [HttpGet("mine")]
    public async Task<IActionResult> GetMine()
    {
        var role = User.FindFirstValue(ClaimTypes.Role);

        if (role == "Patient")
        {
            var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
            if (patient == null) return NotFound("Patient profile not found.");
            return Ok(await _appointmentRepo.GetByPatientIdAsync(patient.Id));
        }

        if (role == "Doctor")
        {
            var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
            if (doctor == null) return NotFound("Doctor profile not found.");
            return Ok(await _appointmentRepo.GetByDoctorIdAsync(doctor.Id));
        }

        return Ok(await _appointmentRepo.GetAllAsync());
    }

    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _appointmentRepo.GetAllAsync());
    }

    // Doctor confirms/completes/cancels; patient can cancel their own
    [HttpPut("{id:int}/status")]
    public async Task<IActionResult> UpdateStatus(int id, UpdateAppointmentStatusDto dto)
    {
        if (!ValidStatuses.Contains(dto.Status))
            return BadRequest($"Status must be one of: {string.Join(", ", ValidStatuses)}");

        var appointment = await _appointmentRepo.GetByIdAsync(id);
        if (appointment == null) return NotFound();

        var role = User.FindFirstValue(ClaimTypes.Role);

        if (role == "Patient")
        {
            var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
            if (patient == null || patient.Id != appointment.PatientId) return Forbid();
            if (dto.Status != "Cancelled") return Forbid("Patients may only cancel their own appointments.");
        }
        else if (role == "Doctor")
        {
            var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
            if (doctor == null || doctor.Id != appointment.DoctorId) return Forbid();
        }
        // Admin: no restriction

        var success = await _appointmentRepo.UpdateStatusAsync(id, dto.Status, dto.Notes);
        return success ? NoContent() : StatusCode(500, "Update failed.");
    }

    // Doctor adds a prescription to a completed/confirmed appointment
    [HttpPost("{id:int}/prescriptions")]
    [Authorize(Roles = "Doctor")]
    public async Task<IActionResult> AddPrescription(int id, CreatePrescriptionDto dto)
    {
        var appointment = await _appointmentRepo.GetByIdAsync(id);
        if (appointment == null) return NotFound();

        var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
        if (doctor == null || doctor.Id != appointment.DoctorId) return Forbid();

        var prescriptionId = await _prescriptionRepo.CreateAsync(id, dto.Medication, dto.Dosage, dto.Instructions);
        return Ok(new { Id = prescriptionId });
    }

    [HttpGet("{id:int}/prescriptions")]
    public async Task<IActionResult> GetPrescriptions(int id)
    {
        var appointment = await _appointmentRepo.GetByIdAsync(id);
        if (appointment == null) return NotFound();

        if (!await UserCanAccessAppointment(appointment))
            return Forbid();

        return Ok(await _prescriptionRepo.GetByAppointmentIdAsync(id));
    }

    private async Task<bool> UserCanAccessAppointment(Models.Appointment appointment)
    {
        var role = User.FindFirstValue(ClaimTypes.Role);
        if (role == "Admin") return true;

        if (role == "Patient")
        {
            var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
            return patient != null && patient.Id == appointment.PatientId;
        }

        if (role == "Doctor")
        {
            var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
            return doctor != null && doctor.Id == appointment.DoctorId;
        }

        return false;
    }
}

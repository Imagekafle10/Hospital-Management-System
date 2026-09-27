using System.Security.Claims;
using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PatientsController : ControllerBase
{
    private readonly IPatientRepository _patientRepo;

    public PatientsController(IPatientRepository patientRepo)
    {
        _patientRepo = patientRepo;
    }

    // Admin only: list every patient
    [HttpGet]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> GetAll()
    {
        var patients = await _patientRepo.GetAllAsync();
        return Ok(patients);
    }

    [HttpGet("{id:int}")]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> GetById(int id)
    {
        var patient = await _patientRepo.GetByIdAsync(id);
        return patient == null ? NotFound() : Ok(patient);
    }

    // A patient viewing/updating their own profile
    [HttpGet("me")]
    [Authorize(Roles = "Patient")]
    public async Task<IActionResult> GetMyProfile()
    {
        var userId = int.Parse(User.FindFirstValue("userId")!);
        var patient = await _patientRepo.GetByUserIdAsync(userId);
        return patient == null ? NotFound() : Ok(patient);
    }

    [HttpPut("me")]
    [Authorize(Roles = "Patient")]
    public async Task<IActionResult> UpdateMyProfile(PatientUpdateDto dto)
    {
        var userId = int.Parse(User.FindFirstValue("userId")!);
        var patient = await _patientRepo.GetByUserIdAsync(userId);
        if (patient == null) return NotFound();

        var success = await _patientRepo.UpdateAsync(
            patient.Id, dto.DateOfBirth, dto.Gender, dto.BloodGroup, dto.Address, dto.EmergencyContact);

        return success ? NoContent() : StatusCode(500, "Update failed.");
    }
}

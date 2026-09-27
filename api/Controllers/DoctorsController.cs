using System.Security.Claims;
using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DoctorsController : ControllerBase
{
    private readonly IDoctorRepository _doctorRepo;

    public DoctorsController(IDoctorRepository doctorRepo)
    {
        _doctorRepo = doctorRepo;
    }

    // Public/any authenticated user can browse doctors (patients need this to book appointments)
    [HttpGet]
    [Authorize]
    public async Task<IActionResult> GetAll([FromQuery] string? specialization)
    {
        var doctors = await _doctorRepo.GetAllAsync(specialization);
        return Ok(doctors);
    }

    [HttpGet("{id:int}")]
    [Authorize]
    public async Task<IActionResult> GetById(int id)
    {
        var doctor = await _doctorRepo.GetByIdAsync(id);
        return doctor == null ? NotFound() : Ok(doctor);
    }

    // A doctor viewing/updating their own profile
    [HttpGet("me")]
    [Authorize(Roles = "Doctor")]
    public async Task<IActionResult> GetMyProfile()
    {
        var userId = int.Parse(User.FindFirstValue("userId")!);
        var doctor = await _doctorRepo.GetByUserIdAsync(userId);
        return doctor == null ? NotFound() : Ok(doctor);
    }

    [HttpPut("me")]
    [Authorize(Roles = "Doctor")]
    public async Task<IActionResult> UpdateMyProfile(DoctorUpdateDto dto)
    {
        var userId = int.Parse(User.FindFirstValue("userId")!);
        var doctor = await _doctorRepo.GetByUserIdAsync(userId);
        if (doctor == null) return NotFound();

        var success = await _doctorRepo.UpdateAsync(
            doctor.Id, dto.Specialization, dto.ConsultationFee, dto.YearsOfExperience, dto.AvailableFrom, dto.AvailableTo);

        return success ? NoContent() : StatusCode(500, "Update failed.");
    }
}

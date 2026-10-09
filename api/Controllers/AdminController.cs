using System.Security.Claims;
using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Models;
using HospitalMgmtSystem.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class AdminController : ControllerBase
{
    private static readonly string[] Roles = { "Admin", "Doctor", "Patient", "Pharmacist" };

    private readonly IUserRepository _users;
    private readonly IDoctorRepository _doctors;
    private readonly IPatientRepository _patients;

    public AdminController(IUserRepository users, IDoctorRepository doctors, IPatientRepository patients)
    {
        _users = users; _doctors = doctors; _patients = patients;
    }

    private int CurrentUserId => int.Parse(User.FindFirstValue("userId")!);

    private static object UserView(User u) => new { u.Id, u.FullName, u.Email, u.Role, u.Phone, u.IsActive, u.CreatedAt };

    [HttpGet("stats")]
    public async Task<IActionResult> Stats() => Ok(await _users.GetStatsAsync());

    [HttpGet("users")]
    public async Task<IActionResult> Users([FromQuery] string? role)
        => Ok((await _users.GetAllAsync(role)).Select(UserView));

    [HttpPost("users")]
    public async Task<IActionResult> CreateUser(AdminCreateUserDto dto)
    {
        if (!Roles.Contains(dto.Role)) return BadRequest($"Role must be one of: {string.Join(", ", Roles)}");
        if (await _users.GetByEmailAsync(dto.Email) != null) return Conflict("An account with this email already exists.");
        if (dto.Role == "Doctor" && (string.IsNullOrWhiteSpace(dto.Specialization) || string.IsNullOrWhiteSpace(dto.LicenseNumber)))
            return BadRequest("Specialization and LicenseNumber are required for a Doctor.");

        var user = new User
        {
            FullName = dto.FullName, Email = dto.Email, Role = dto.Role, Phone = dto.Phone,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password)
        };
        var userId = await _users.CreateAsync(user);

        if (dto.Role == "Doctor")
        {
            var did = await _doctors.CreateAsync(userId, dto.Specialization!, dto.LicenseNumber!, dto.ConsultationFee ?? 0);
            if (dto.YearsOfExperience.HasValue)
                await _doctors.UpdateAsync(did, null, null, dto.YearsOfExperience, null, null);
        }
        else if (dto.Role == "Patient")
        {
            var pid = await _patients.CreateAsync(userId, dto.DateOfBirth, dto.Gender, dto.BloodGroup, dto.Address);
            if (!string.IsNullOrWhiteSpace(dto.EmergencyContact))
                await _patients.UpdateAsync(pid, null, null, null, null, dto.EmergencyContact);
        }

        return Ok(UserView((await _users.GetByIdAsync(userId))!));
    }

    [HttpPut("users/{id:int}")]
    public async Task<IActionResult> UpdateUser(int id, AdminUpdateUserDto dto)
    {
        var err = await ApplyUserUpdate(id, dto);
        return err ?? NoContent();
    }

    [HttpPut("doctors/{id:int}")]
    public async Task<IActionResult> UpdateDoctor(int id, AdminUpdateDoctorDto dto)
    {
        var doctor = await _doctors.GetByIdAsync(id);
        if (doctor == null) return NotFound();
        var err = await ApplyUserUpdate(doctor.UserId, dto);
        if (err != null) return err;

        await _doctors.UpdateAsync(id, dto.Specialization, dto.ConsultationFee, dto.YearsOfExperience, dto.AvailableFrom, dto.AvailableTo);
        if (!string.IsNullOrWhiteSpace(dto.LicenseNumber)) await _doctors.SetLicenseAsync(id, dto.LicenseNumber);
        return NoContent();
    }

    [HttpPut("patients/{id:int}")]
    public async Task<IActionResult> UpdatePatient(int id, AdminUpdatePatientDto dto)
    {
        var patient = await _patients.GetByIdAsync(id);
        if (patient == null) return NotFound();
        var err = await ApplyUserUpdate(patient.UserId, dto);
        if (err != null) return err;

        await _patients.UpdateAsync(id, dto.DateOfBirth, dto.Gender, dto.BloodGroup, dto.Address, dto.EmergencyContact);
        return NoContent();
    }

    // Deleting a user cascades to their Doctor/Patient profile. If they have appointments,
    // admissions, payments, etc. the database refuses and we tell the admin to deactivate instead.
    [HttpDelete("users/{id:int}")]
    public async Task<IActionResult> DeleteUser(int id)
    {
        if (id == CurrentUserId) return BadRequest("You cannot delete your own account.");
        if (await _users.GetByIdAsync(id) == null) return NotFound();
        try
        {
            return await _users.DeleteAsync(id) ? NoContent() : StatusCode(500, "Delete failed.");
        }
        catch (SqlException ex) when (ex.Number == 547)
        {
            return Conflict("This user has linked records (appointments, admissions, payments...). Deactivate the account instead.");
        }
    }

    private async Task<IActionResult?> ApplyUserUpdate(int userId, AdminUpdateUserDto dto)
    {
        var user = await _users.GetByIdAsync(userId);
        if (user == null) return NotFound();

        if (userId == CurrentUserId && dto.IsActive == false)
            return BadRequest("You cannot deactivate your own account.");

        if (!string.IsNullOrWhiteSpace(dto.Email) && !dto.Email.Equals(user.Email, StringComparison.OrdinalIgnoreCase)
            && await _users.GetByEmailAsync(dto.Email) != null)
            return Conflict("Another account already uses this email.");

        var hash = string.IsNullOrWhiteSpace(dto.NewPassword) ? null : BCrypt.Net.BCrypt.HashPassword(dto.NewPassword);
        await _users.UpdateAsync(userId, dto.FullName, dto.Email, dto.Phone, dto.IsActive, hash);
        return null;
    }
}

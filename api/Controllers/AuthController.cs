using BCrypt.Net;
using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Models;
using HospitalMgmtSystem.Repositories;
using HospitalMgmtSystem.Services;
using Microsoft.AspNetCore.Mvc;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IUserRepository _userRepo;
    private readonly IDoctorRepository _doctorRepo;
    private readonly IPatientRepository _patientRepo;
    private readonly ITokenService _tokenService;

    public AuthController(
        IUserRepository userRepo,
        IDoctorRepository doctorRepo,
        IPatientRepository patientRepo,
        ITokenService tokenService)
    {
        _userRepo = userRepo;
        _doctorRepo = doctorRepo;
        _patientRepo = patientRepo;
        _tokenService = tokenService;
    }

    [HttpPost("register")]
    public async Task<ActionResult<AuthResponseDto>> Register(RegisterDto dto)
    {
        if (dto.Role != "Doctor" && dto.Role != "Patient")
            return BadRequest("Role must be 'Doctor' or 'Patient'. Admin accounts are provisioned separately.");

        var existing = await _userRepo.GetByEmailAsync(dto.Email);
        if (existing != null)
            return Conflict("An account with this email already exists.");

        if (dto.Role == "Doctor" && (string.IsNullOrWhiteSpace(dto.Specialization) || string.IsNullOrWhiteSpace(dto.LicenseNumber)))
            return BadRequest("Specialization and LicenseNumber are required to register as a Doctor.");

        var user = new User
        {
            FullName = dto.FullName,
            Email = dto.Email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password),
            Role = dto.Role,
            Phone = dto.Phone
        };

        var userId = await _userRepo.CreateAsync(user);
        user.Id = userId;

        if (dto.Role == "Doctor")
        {
            await _doctorRepo.CreateAsync(userId, dto.Specialization!, dto.LicenseNumber!, dto.ConsultationFee ?? 0);
        }
        else
        {
            await _patientRepo.CreateAsync(userId, dto.DateOfBirth, dto.Gender, dto.BloodGroup, dto.Address);
        }

        var (token, expiresAt) = _tokenService.GenerateToken(user);
        return Ok(new AuthResponseDto
        {
            Token = token,
            UserId = user.Id,
            FullName = user.FullName,
            Role = user.Role,
            ExpiresAt = expiresAt
        });
    }

    [HttpPost("login")]
    public async Task<ActionResult<AuthResponseDto>> Login(LoginDto dto)
    {
        var user = await _userRepo.GetByEmailAsync(dto.Email);
        if (user == null || !user.IsActive || !BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
            return Unauthorized("Invalid email or password.");

        var (token, expiresAt) = _tokenService.GenerateToken(user);
        return Ok(new AuthResponseDto
        {
            Token = token,
            UserId = user.Id,
            FullName = user.FullName,
            Role = user.Role,
            ExpiresAt = expiresAt
        });
    }
}

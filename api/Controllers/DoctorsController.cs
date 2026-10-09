using System.Security.Claims;
using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.StaticFiles;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DoctorsController : ControllerBase
{
    private static readonly string[] PhotoExtensions = { ".jpg", ".jpeg", ".png", ".webp" };
    private const long MaxPhotoBytes = 5 * 1024 * 1024;

    private readonly IDoctorRepository _doctorRepo;
    private readonly IConfiguration _config;
    private readonly IWebHostEnvironment _env;

    public DoctorsController(IDoctorRepository doctorRepo, IConfiguration config, IWebHostEnvironment env)
    {
        _doctorRepo = doctorRepo;
        _config = config;
        _env = env;
    }

    private string PhotoRoot
    {
        get
        {
            var configured = _config["FileStorage:DoctorPhotosPath"] ?? "App_Data/doctor-photos";
            var root = Path.IsPathRooted(configured) ? configured : Path.Combine(_env.ContentRootPath, configured);
            Directory.CreateDirectory(root);
            return root;
        }
    }

    // Doctor uploads / replaces their own profile photo (called right after registration, and from Profile).
    [HttpPost("me/photo")]
    [Authorize(Roles = "Doctor")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(10_000_000)]
    public async Task<IActionResult> UploadMyPhoto([FromForm] DoctorPhotoUploadDto dto)
    {
        var photo = dto.Photo;
        if (photo == null || photo.Length == 0) return BadRequest("Photo is empty.");
        if (photo.Length > MaxPhotoBytes) return BadRequest("Photo must be 5 MB or smaller.");

        var ext = Path.GetExtension(photo.FileName).ToLowerInvariant();
        if (!PhotoExtensions.Contains(ext))
            return BadRequest($"Photo type not allowed. Allowed: {string.Join(", ", PhotoExtensions)}");

        var userId = int.Parse(User.FindFirstValue("userId")!);
        var doctor = await _doctorRepo.GetByUserIdAsync(userId);
        if (doctor == null) return NotFound("Doctor profile not found.");

        var stored = $"{Guid.NewGuid():N}{ext}";
        await using (var stream = System.IO.File.Create(Path.Combine(PhotoRoot, stored)))
        {
            await photo.CopyToAsync(stream);
        }

        if (!await _doctorRepo.SetPhotoAsync(doctor.Id, stored))
            return StatusCode(500, "Could not save photo.");

        // remove the previous photo file
        if (!string.IsNullOrEmpty(doctor.PhotoFileName))
        {
            var old = Path.Combine(PhotoRoot, doctor.PhotoFileName);
            if (System.IO.File.Exists(old)) System.IO.File.Delete(old);
        }

        return Ok(new { photoFileName = stored });
    }

    // Public on purpose: doctor photos are shown in lists, and Image.network can't send auth headers easily.
    [HttpGet("{id:int}/photo")]
    [AllowAnonymous]
    public async Task<IActionResult> GetPhoto(int id)
    {
        var doctor = await _doctorRepo.GetByIdAsync(id);
        if (doctor == null || string.IsNullOrEmpty(doctor.PhotoFileName)) return NotFound();

        var full = Path.Combine(PhotoRoot, Path.GetFileName(doctor.PhotoFileName));
        if (!System.IO.File.Exists(full)) return NotFound();

        new FileExtensionContentTypeProvider().TryGetContentType(full, out var ct);
        return PhysicalFile(full, ct ?? "image/jpeg");
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

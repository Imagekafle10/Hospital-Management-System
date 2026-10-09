using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class WardsController : ControllerBase
{
    private static readonly string[] ValidWardTypes = { "General", "ICU", "Private", "Maternity", "Emergency" };

    private readonly IWardRepository _wardRepo;

    public WardsController(IWardRepository wardRepo)
    {
        _wardRepo = wardRepo;
    }

    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(CreateWardDto dto)
    {
        if (!ValidWardTypes.Contains(dto.WardType))
            return BadRequest($"WardType must be one of: {string.Join(", ", ValidWardTypes)}");

        var id = await _wardRepo.CreateAsync(dto.Name, dto.WardType, dto.FloorNumber, dto.Description);
        var created = await _wardRepo.GetByIdAsync(id);
        return CreatedAtAction(nameof(GetById), new { id }, created);
    }

    // Any logged-in user with clinical/admin access can browse wards and their bed availability.
    [HttpGet]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _wardRepo.GetAllAsync());
    }

    [HttpGet("{id:int}")]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> GetById(int id)
    {
        var ward = await _wardRepo.GetByIdAsync(id);
        return ward == null ? NotFound() : Ok(ward);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(int id, UpdateWardDto dto)
    {
        if (dto.WardType != null && !ValidWardTypes.Contains(dto.WardType))
            return BadRequest($"WardType must be one of: {string.Join(", ", ValidWardTypes)}");

        var ward = await _wardRepo.GetByIdAsync(id);
        if (ward == null) return NotFound();

        var success = await _wardRepo.UpdateAsync(id, dto.Name, dto.WardType, dto.FloorNumber, dto.Description);
        return success ? NoContent() : StatusCode(500, "Update failed.");
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var ward = await _wardRepo.GetByIdAsync(id);
        if (ward == null) return NotFound();

        if (await _wardRepo.HasBedsAsync(id))
            return Conflict("Remove all beds from this ward before deleting it.");

        var success = await _wardRepo.DeleteAsync(id);
        return success ? NoContent() : StatusCode(500, "Delete failed.");
    }
}

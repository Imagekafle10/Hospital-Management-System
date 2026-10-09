using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api")]
[Authorize]
public class BedsController : ControllerBase
{
    private static readonly string[] ManuallySettableStatuses = { "Available", "Maintenance" };

    private readonly IBedRepository _bedRepo;
    private readonly IWardRepository _wardRepo;

    public BedsController(IBedRepository bedRepo, IWardRepository wardRepo)
    {
        _bedRepo = bedRepo;
        _wardRepo = wardRepo;
    }

    [HttpPost("wards/{wardId:int}/beds")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create(int wardId, CreateBedDto dto)
    {
        var ward = await _wardRepo.GetByIdAsync(wardId);
        if (ward == null) return NotFound("Ward not found.");

        if (await _bedRepo.BedNumberExistsInWardAsync(wardId, dto.BedNumber))
            return Conflict("A bed with this number already exists in this ward.");

        var id = await _bedRepo.CreateAsync(wardId, dto.BedNumber);
        var created = await _bedRepo.GetByIdAsync(id);
        return CreatedAtAction(nameof(GetById), new { id }, created);
    }

    [HttpGet("wards/{wardId:int}/beds")]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> GetByWard(int wardId)
    {
        var ward = await _wardRepo.GetByIdAsync(wardId);
        if (ward == null) return NotFound("Ward not found.");

        return Ok(await _bedRepo.GetByWardIdAsync(wardId));
    }

    // ?status=Available to find an open bed to admit a patient into.
    [HttpGet("beds")]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> GetAll([FromQuery] string? status)
    {
        return Ok(await _bedRepo.GetAllAsync(status));
    }

    [HttpGet("beds/{id:int}")]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> GetById(int id)
    {
        var bed = await _bedRepo.GetByIdAsync(id);
        return bed == null ? NotFound() : Ok(bed);
    }

    // For manually taking a bed in/out of "Maintenance". Occupying/freeing a bed happens via admit/discharge.
    [HttpPut("beds/{id:int}/status")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateStatus(int id, UpdateBedStatusDto dto)
    {
        if (!ManuallySettableStatuses.Contains(dto.Status))
            return BadRequest($"Status must be one of: {string.Join(", ", ManuallySettableStatuses)}. Use the admissions endpoints to occupy or free a bed.");

        var bed = await _bedRepo.GetByIdAsync(id);
        if (bed == null) return NotFound();

        if (bed.Status == "Occupied")
            return Conflict("This bed is currently occupied by an admitted patient; discharge or transfer them first.");

        var success = await _bedRepo.UpdateStatusAsync(id, dto.Status);
        return success ? NoContent() : StatusCode(500, "Update failed.");
    }

    [HttpDelete("beds/{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Delete(int id)
    {
        var bed = await _bedRepo.GetByIdAsync(id);
        if (bed == null) return NotFound();

        if (bed.Status == "Occupied")
            return Conflict("Cannot delete an occupied bed.");

        var success = await _bedRepo.DeleteAsync(id);
        return success ? NoContent() : StatusCode(500, "Delete failed.");
    }
}

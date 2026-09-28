using System.Security.Claims;
using HospitalMgmtSystem.DTOs;
using HospitalMgmtSystem.Repositories;
using HospitalMgmtSystem.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace HospitalMgmtSystem.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController : ControllerBase
{
    private static readonly string[] ValidMethods = { "Esewa", "Khalti", "COD" };

    private readonly IPaymentRepository _paymentRepo;
    private readonly IAppointmentRepository _appointmentRepo;
    private readonly IPatientRepository _patientRepo;
    private readonly IDoctorRepository _doctorRepo;
    private readonly IEsewaService _esewa;
    private readonly IKhaltiService _khalti;

    public PaymentsController(
        IPaymentRepository paymentRepo,
        IAppointmentRepository appointmentRepo,
        IPatientRepository patientRepo,
        IDoctorRepository doctorRepo,
        IEsewaService esewa,
        IKhaltiService khalti)
    {
        _paymentRepo = paymentRepo;
        _appointmentRepo = appointmentRepo;
        _patientRepo = patientRepo;
        _doctorRepo = doctorRepo;
        _esewa = esewa;
        _khalti = khalti;
    }

    private int CurrentUserId => int.Parse(User.FindFirstValue("userId")!);

    // Patient starts a payment for an appointment's consultation fee.
    // Method = "Esewa" | "Khalti" | "COD"
    [HttpPost("initiate")]
    [Authorize(Roles = "Patient")]
    public async Task<IActionResult> Initiate(InitiatePaymentDto dto)
    {
        var method = ValidMethods.FirstOrDefault(m => string.Equals(m, dto.Method, StringComparison.OrdinalIgnoreCase));
        if (method == null)
            return BadRequest($"Method must be one of: {string.Join(", ", ValidMethods)}");

        var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
        if (patient == null) return NotFound("Patient profile not found.");

        var appointment = await _appointmentRepo.GetByIdAsync(dto.AppointmentId);
        if (appointment == null) return NotFound("Appointment not found.");
        if (appointment.PatientId != patient.Id) return Forbid();

        if (await _paymentRepo.HasSuccessfulPaymentAsync(dto.AppointmentId))
            return Conflict("This appointment has already been paid for.");

        var doctor = await _doctorRepo.GetByIdAsync(appointment.DoctorId);
        if (doctor == null) return NotFound("Doctor not found.");

        var amount = doctor.ConsultationFee;
        if (amount <= 0) return BadRequest("This doctor has no consultation fee configured.");

        var transactionUuid = Guid.NewGuid().ToString("N");
        var paymentId = await _paymentRepo.CreateAsync(dto.AppointmentId, patient.Id, amount, method, transactionUuid);

        switch (method)
        {
            case "Esewa":
            {
                var fields = _esewa.BuildFormFields(amount, transactionUuid);
                return Ok(new EsewaInitiateResponseDto
                {
                    PaymentId = paymentId,
                    GatewayUrl = _esewa.GatewayUrl,
                    FormFields = fields
                });
            }
            case "Khalti":
            {
                var result = await _khalti.InitiateAsync(
                    amount,
                    transactionUuid,
                    $"Consultation - Appointment #{appointment.Id}",
                    patient.FullName ?? "Patient",
                    patient.Email ?? "patient@example.com");

                if (!result.Success)
                {
                    await _paymentRepo.UpdateStatusAsync(paymentId, "Failed", null);
                    return StatusCode(502, result.Message);
                }

                // Store Khalti's pidx right away so the return/verify step can look the payment up by it.
                await _paymentRepo.UpdateStatusAsync(paymentId, "Pending", result.Pidx);

                return Ok(new KhaltiInitiateResponseDto
                {
                    PaymentId = paymentId,
                    PaymentUrl = result.PaymentUrl!,
                    Pidx = result.Pidx!
                });
            }
            default: // COD
            {
                return Ok(new CodConfirmDto { PaymentId = paymentId });
            }
        }
    }

    // eSewa redirects the browser here after checkout with a base64 "data" query param.
    [HttpGet("esewa/verify")]
    [AllowAnonymous]
    public async Task<IActionResult> VerifyEsewa([FromQuery] string data)
    {
        if (string.IsNullOrWhiteSpace(data)) return BadRequest("Missing eSewa response data.");

        var result = _esewa.VerifyCallback(data);
        if (result.TransactionUuid == null) return BadRequest(result.Message);

        var payment = await _paymentRepo.GetByTransactionUuidAsync(result.TransactionUuid);
        if (payment == null) return NotFound("Payment record not found for this transaction.");

        await _paymentRepo.UpdateStatusAsync(payment.Id, result.Success ? "Success" : "Failed", result.RefId);

        return Ok(new { payment.Id, Status = result.Success ? "Success" : "Failed", result.Message });
    }

    // eSewa redirects here if the user cancels or the payment fails.
    [HttpGet("failed")]
    [AllowAnonymous]
    public async Task<IActionResult> EsewaFailed([FromQuery] string? data)
    {
        // eSewa may send a base64 "data" payload; mark the payment Failed if we can identify it.
        if (!string.IsNullOrWhiteSpace(data))
        {
            var result = _esewa.VerifyCallback(data);
            if (result.TransactionUuid != null)
            {
                var payment = await _paymentRepo.GetByTransactionUuidAsync(result.TransactionUuid);
                if (payment != null && payment.Status != "Success")
                    await _paymentRepo.UpdateStatusAsync(payment.Id, "Failed", null);
            }
        }
        return Ok(new { Status = "Failed", Message = "Payment was cancelled or failed." });
    }

    // Frontend calls this after Khalti redirects back with ?pidx=...
    [HttpPost("khalti/verify")]
    public async Task<IActionResult> VerifyKhalti(KhaltiVerifyDto dto)
    {
        var payment = await _paymentRepo.GetByGatewayReferenceAsync(dto.Pidx);
        var result = await _khalti.VerifyAsync(dto.Pidx);

        if (payment != null)
            await _paymentRepo.UpdateStatusAsync(payment.Id, result.Success ? "Success" : "Failed", dto.Pidx);

        return Ok(new { Status = result.Status, result.Success, result.TransactionId, result.Message });
    }

    // Admin/Doctor confirms cash was collected on delivery (at the counter).
    [HttpPut("{id:int}/collect")]
    [Authorize(Roles = "Admin,Doctor")]
    public async Task<IActionResult> CollectCod(int id)
    {
        var payment = await _paymentRepo.GetByIdAsync(id);
        if (payment == null) return NotFound();
        if (payment.Method != "COD") return BadRequest("Only Cash on Delivery payments can be manually collected.");
        if (payment.Status == "Success") return Conflict("Already marked as collected.");

        var success = await _paymentRepo.UpdateStatusAsync(id, "Success", "COD-COLLECTED");
        return success ? NoContent() : StatusCode(500, "Update failed.");
    }

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var payment = await _paymentRepo.GetByIdAsync(id);
        if (payment == null) return NotFound();
        if (!await UserCanAccessPayment(payment)) return Forbid();
        return Ok(payment);
    }

    [HttpGet("appointment/{appointmentId:int}")]
    public async Task<IActionResult> GetByAppointment(int appointmentId)
    {
        var appointment = await _appointmentRepo.GetByIdAsync(appointmentId);
        if (appointment == null) return NotFound();

        var role = User.FindFirstValue(ClaimTypes.Role);
        if (role == "Patient")
        {
            var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
            if (patient == null || patient.Id != appointment.PatientId) return Forbid();
        }
        else if (role == "Doctor")
        {
            var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
            if (doctor == null || doctor.Id != appointment.DoctorId) return Forbid();
        }

        return Ok(await _paymentRepo.GetByAppointmentIdAsync(appointmentId));
    }

    [HttpGet("mine")]
    [Authorize(Roles = "Patient")]
    public async Task<IActionResult> GetMine()
    {
        var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
        if (patient == null) return NotFound("Patient profile not found.");
        return Ok(await _paymentRepo.GetByPatientIdAsync(patient.Id));
    }

    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll()
    {
        return Ok(await _paymentRepo.GetAllAsync());
    }

    private async Task<bool> UserCanAccessPayment(Models.Payment payment)
    {
        var role = User.FindFirstValue(ClaimTypes.Role);
        if (role == "Admin") return true;

        if (role == "Patient")
        {
            var patient = await _patientRepo.GetByUserIdAsync(CurrentUserId);
            return patient != null && patient.Id == payment.PatientId;
        }

        if (role == "Doctor")
        {
            var appointment = await _appointmentRepo.GetByIdAsync(payment.AppointmentId);
            if (appointment == null) return false;
            var doctor = await _doctorRepo.GetByUserIdAsync(CurrentUserId);
            return doctor != null && doctor.Id == appointment.DoctorId;
        }

        return false;
    }
}
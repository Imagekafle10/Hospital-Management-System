namespace HospitalMgmtSystem.DTOs;

public class DoctorPhotoUploadDto
{
    public IFormFile Photo { get; set; } = null!;
}

public class DoctorUpdateDto
{
    public string? Specialization { get; set; }
    public decimal? ConsultationFee { get; set; }
    public int? YearsOfExperience { get; set; }
    public TimeSpan? AvailableFrom { get; set; }
    public TimeSpan? AvailableTo { get; set; }
}

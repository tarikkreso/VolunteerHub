namespace VolunteerHub.API.Contracts;

public class ValidationErrorResponse
{
    public string Message { get; set; } = string.Empty;
    public Dictionary<string, string[]> Errors { get; set; } = new();
}

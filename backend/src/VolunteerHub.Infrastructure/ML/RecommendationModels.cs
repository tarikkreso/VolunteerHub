using Microsoft.ML.Data;

namespace VolunteerHub.Infrastructure.ML;

/// <summary>
/// Input data for the ML.NET recommendation model.
/// Uses TF-IDF on combined text features (user skills + event metadata).
/// </summary>
public class RecommendationInput
{
    /// <summary>
    /// User skills concatenated as text (e.g. "Prva pomoć, IT vještine, Fizički rad")
    /// </summary>
    [LoadColumn(0)]
    public string UserFeatures { get; set; } = string.Empty;

    /// <summary>
    /// Event features concatenated as text (e.g. "Zdravlje humanitarno Čišćenje parka okoliš")
    /// </summary>
    [LoadColumn(1)]
    public string EventFeatures { get; set; } = string.Empty;

    /// <summary>
    /// Label: 1 = user registered for this event (positive), 0 = not registered (negative)
    /// </summary>
    [LoadColumn(2)]
    public bool Label { get; set; }
}

/// <summary>
/// Output prediction from the ML.NET model.
/// </summary>
public class RecommendationPrediction
{
    [ColumnName("PredictedLabel")]
    public bool PredictedLabel { get; set; }

    /// <summary>
    /// Probability of the user being interested in the event (0-1).
    /// </summary>
    [ColumnName("Probability")]
    public float Probability { get; set; }

    [ColumnName("Score")]
    public float Score { get; set; }
}

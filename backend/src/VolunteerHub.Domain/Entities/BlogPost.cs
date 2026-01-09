namespace VolunteerHub.Domain.Entities;

/// <summary>
/// BlogPost entity - educational content
/// </summary>
public class BlogPost : BaseEntity
{
    public string Title { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string? Summary { get; set; }
    public string? ImageUrl { get; set; }
    public string? Tags { get; set; }
    public bool IsPublished { get; set; }
    public DateTime? PublishedAt { get; set; }
    public DateTime? ScheduledPublishAt { get; set; }
    public int ViewCount { get; set; }

    public int? OrganizationId { get; set; }
    public Organization? Organization { get; set; }

    public int? BlogCategoryId { get; set; }
    public BlogCategory? BlogCategory { get; set; }

    public int AuthorId { get; set; }
    public User Author { get; set; } = null!;
}

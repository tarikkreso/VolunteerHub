namespace VolunteerHub.Domain.Entities;

public class Organization : BaseEntity
{
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string? Email { get; set; }
    public string? Phone { get; set; }
    public string? Website { get; set; }
    public string? LogoUrl { get; set; }
    public string? Address { get; set; }
    public int? CityId { get; set; }
    public City? City { get; set; }
    public int? OwnerUserId { get; set; }
    public User? OwnerUser { get; set; }

    public virtual ICollection<Event> Events { get; set; } = new List<Event>();
    public virtual ICollection<Campaign> Campaigns { get; set; } = new List<Campaign>();
    public virtual ICollection<BlogPost> BlogPosts { get; set; } = new List<BlogPost>();
}

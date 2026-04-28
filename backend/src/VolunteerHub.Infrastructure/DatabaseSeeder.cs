using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using VolunteerHub.Domain.Entities;
using VolunteerHub.Domain.Enums;
using VolunteerHub.Infrastructure.Data;

namespace VolunteerHub.Infrastructure;

public static class DatabaseSeeder
{
    public static async Task SeedAsync(IServiceProvider serviceProvider, ApplicationDbContext context)
    {
        var userManager = serviceProvider.GetRequiredService<UserManager<ApplicationUser>>();
        var roleManager = serviceProvider.GetRequiredService<RoleManager<IdentityRole<int>>>();

        await EnsureRolesAsync(roleManager);
        await SeedReferenceDataAsync(context);
        await SeedUsersAsync(context, userManager);
        await SeedOrganizationsAsync(context);
        await SeedEventsAndShiftsAsync(context);
        await SeedCampaignsAndDonationsAsync(context);
        await SeedBlogAsync(context);
        await SeedNotificationsAsync(context);
        await ApplyVisualAssetsAsync(context);
    }

    private static async Task EnsureRolesAsync(RoleManager<IdentityRole<int>> roleManager)
    {
        foreach (var roleName in new[] { "Admin", "Volunteer", "SuperAdmin" })
        {
            if (!await roleManager.RoleExistsAsync(roleName))
            {
                await roleManager.CreateAsync(new IdentityRole<int>(roleName));
            }
        }
    }

    private static async Task SeedReferenceDataAsync(ApplicationDbContext context)
    {
        if (!context.Countries.Any())
        {
            await context.Countries.AddRangeAsync(
                new Country { Name = "Bosna i Hercegovina", Code = "BA" },
                new Country { Name = "Hrvatska", Code = "HR" },
                new Country { Name = "Srbija", Code = "RS" });
            await context.SaveChangesAsync();
        }

        var bosniaId = await context.Countries.Where(c => c.Code == "BA").Select(c => c.Id).FirstAsync();
        var croatiaId = await context.Countries.Where(c => c.Code == "HR").Select(c => c.Id).FirstAsync();
        var existingCities = await context.Cities.Select(c => c.Name).ToListAsync();
        var existingCityNames = existingCities.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var defaultCities = new[]
        {
            new City { Name = "Sarajevo", PostalCode = "71000", CountryId = bosniaId },
            new City { Name = "Mostar", PostalCode = "88000", CountryId = bosniaId },
            new City { Name = "Tuzla", PostalCode = "75000", CountryId = bosniaId },
            new City { Name = "Zenica", PostalCode = "72000", CountryId = bosniaId },
            new City { Name = "Banja Luka", PostalCode = "78000", CountryId = bosniaId },
            new City { Name = "Bihac", PostalCode = "77000", CountryId = bosniaId },
            new City { Name = "Travnik", PostalCode = "72270", CountryId = bosniaId },
            new City { Name = "Doboj", PostalCode = "74000", CountryId = bosniaId },
            new City { Name = "Bijeljina", PostalCode = "76300", CountryId = bosniaId },
            new City { Name = "Trebinje", PostalCode = "89101", CountryId = bosniaId },
            new City { Name = "Bugojno", PostalCode = "70230", CountryId = bosniaId },
            new City { Name = "Gorazde", PostalCode = "73000", CountryId = bosniaId },
            new City { Name = "Zagreb", PostalCode = "10000", CountryId = croatiaId }
        };

        var missingCities = defaultCities
            .Where(c => !existingCityNames.Contains(c.Name))
            .ToList();

        if (missingCities.Count > 0)
        {
            await context.Cities.AddRangeAsync(missingCities);
            await context.SaveChangesAsync();
        }

        if (!context.EventCategories.Any())
        {
            await context.EventCategories.AddRangeAsync(
                new EventCategory { Name = "Okoliš", Description = "Ekološke akcije", IconUrl = "leaf", Color = "#4CAF50" },
                new EventCategory { Name = "Edukacija", Description = "Mentorstvo i radionice", IconUrl = "school", Color = "#2196F3" },
                new EventCategory { Name = "Humanitarno", Description = "Pomoć zajednici", IconUrl = "favorite", Color = "#E91E63" },
                new EventCategory { Name = "Sport", Description = "Sportske aktivnosti", IconUrl = "sports_soccer", Color = "#FF9800" },
                new EventCategory { Name = "Stariji", Description = "Podrška starijim osobama", IconUrl = "elderly", Color = "#00BCD4" });
            await context.SaveChangesAsync();
        }

        if (!context.Skills.Any())
        {
            await context.Skills.AddRangeAsync(
                new Skill { Name = "Fizički rad", Description = "Terenski i fizički zadaci" },
                new Skill { Name = "Podučavanje", Description = "Radionice i mentorstvo" },
                new Skill { Name = "Prva pomoć", Description = "Medicinska podrška" },
                new Skill { Name = "Vožnja", Description = "Vozačka dozvola i prevoz" },
                new Skill { Name = "IT vještine", Description = "Digitalna podrška i alati" },
                new Skill { Name = "Marketing", Description = "Promocija događaja" });
            await context.SaveChangesAsync();
        }

        if (!context.BlogCategories.Any())
        {
            await context.BlogCategories.AddRangeAsync(
                new BlogCategory { Name = "Novosti", Description = "Aktuelnosti i najave", Color = "#2196F3" },
                new BlogCategory { Name = "Savjeti", Description = "Praktični vodiči za volontere", Color = "#4CAF50" },
                new BlogCategory { Name = "Priče", Description = "Iskustva iz zajednice", Color = "#FF9800" });
            await context.SaveChangesAsync();
        }
    }

    private static async Task SeedUsersAsync(ApplicationDbContext context, UserManager<ApplicationUser> userManager)
    {
        if (context.Volunteers.Any())
            return;

        var cityIds = await context.Cities.ToDictionaryAsync(c => c.Name, c => c.Id);

        var profiles = new[]
        {
            new SeedUser("desktop", "desktop@volunteerhub.ba", "Desktop", "Admin", UserRole.Admin, "Admin", cityIds["Sarajevo"], "+38761100100", "Administrator sistema"),
            new SeedUser("mobile", "mobile@volunteerhub.ba", "Mobile", "Volonter", UserRole.Volunteer, "Volunteer", cityIds["Sarajevo"], "+38762200200", "Aktivni mobilni korisnik"),
            new SeedUser("tarik", "tarik@test.ba", "Tarik", "Kreso", UserRole.Volunteer, "Volunteer", cityIds["Sarajevo"], "+38761111111", "Student i volonter"),
            new SeedUser("amra", "amra@test.ba", "Amra", "Hodzic", UserRole.Volunteer, "Volunteer", cityIds["Mostar"], "+38762222222", "Volonterka iz Mostara"),
            new SeedUser("mirza", "mirza@test.ba", "Mirza", "Begic", UserRole.Volunteer, "Volunteer", cityIds["Tuzla"], "+38763333333", "Podrška humanitarnim akcijama"),
            new SeedUser("lejla", "lejla@test.ba", "Lejla", "Ibrahimovic", UserRole.Volunteer, "Volunteer", cityIds["Zenica"], "+38764444444", "Iskusna volonterka")
        };

        foreach (var seedUser in profiles)
        {
            var identityUser = new ApplicationUser
            {
                UserName = seedUser.Username,
                Email = seedUser.Email,
                IsActive = true
            };

            var identityResult = await userManager.CreateAsync(identityUser, "test");
            if (!identityResult.Succeeded)
            {
                throw new InvalidOperationException(string.Join(" ", identityResult.Errors.Select(e => e.Description)));
            }

            await userManager.AddToRoleAsync(identityUser, seedUser.IdentityRole);

            var profile = new User
            {
                IdentityUserId = identityUser.Id,
                FirstName = seedUser.FirstName,
                LastName = seedUser.LastName,
                Email = seedUser.Email,
                Phone = seedUser.Phone,
                ProfileImageUrl = GetUserAvatarUrl(seedUser.Username),
                Role = seedUser.Role,
                CityId = seedUser.CityId,
                Bio = seedUser.Bio,
                IsActive = true
            };

            context.Volunteers.Add(profile);
            await context.SaveChangesAsync();

            identityUser.ProfileUserId = profile.Id;
            await userManager.UpdateAsync(identityUser);

            context.LeaderboardEntries.Add(new LeaderboardEntry
            {
                UserId = profile.Id,
                TotalHours = seedUser.Role == UserRole.Volunteer ? 12 + (profile.Id * 4) : 0,
                TotalEvents = seedUser.Role == UserRole.Volunteer ? Math.Max(1, profile.Id - 1) : 0,
                TotalShifts = seedUser.Role == UserRole.Volunteer ? Math.Max(2, profile.Id) : 0,
                Rank = 0,
                Points = seedUser.Role == UserRole.Volunteer ? (12 + (profile.Id * 4)) * 10 : 0
            });
        }

        await context.SaveChangesAsync();

        var leaderboard = await context.LeaderboardEntries.OrderByDescending(x => x.TotalHours).ToListAsync();
        for (var i = 0; i < leaderboard.Count; i++)
        {
            leaderboard[i].Rank = i + 1;
        }

        var skills = await context.Skills.OrderBy(s => s.Id).ToListAsync();
        var volunteers = await context.Volunteers.Where(u => u.Role == UserRole.Volunteer).OrderBy(u => u.Id).ToListAsync();

        for (var i = 0; i < volunteers.Count; i++)
        {
            context.UserSkills.Add(new UserSkill
            {
                UserId = volunteers[i].Id,
                SkillId = skills[i % skills.Count].Id,
                ProficiencyLevel = 3 + (i % 3),
                YearsExperience = 1 + i,
                IsVerified = i % 2 == 0
            });

            context.UserSkills.Add(new UserSkill
            {
                UserId = volunteers[i].Id,
                SkillId = skills[(i + 2) % skills.Count].Id,
                ProficiencyLevel = 2 + (i % 2),
                YearsExperience = 1,
                IsVerified = true
            });
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedOrganizationsAsync(ApplicationDbContext context)
    {
        if (context.Organizations.Any())
            return;

        var cityIds = await context.Cities.ToDictionaryAsync(c => c.Name, c => c.Id);
        var adminId = await context.Volunteers.Where(u => u.Role == UserRole.Admin).Select(u => u.Id).FirstAsync();

        await context.Organizations.AddRangeAsync(
            new Organization
            {
                Name = "Crveni Križ Sarajevo",
                Description = "Humanitarna organizacija fokusirana na podršku zajednici i hitne akcije.",
                Email = "info@cks.ba",
                Phone = "+38733222111",
                Website = "https://cks.ba",
                LogoUrl = GetOrganizationLogoUrl("Crveni Križ Sarajevo"),
                Address = "Maršala Tita 10",
                CityId = cityIds["Sarajevo"],
                OwnerUserId = adminId
            },
            new Organization
            {
                Name = "Eko Akcija Mostar",
                Description = "Volonterske ekološke akcije i edukacija mladih.",
                Email = "kontakt@ekoakcija.ba",
                Phone = "+38736222111",
                Website = "https://ekoakcija.ba",
                LogoUrl = GetOrganizationLogoUrl("Eko Akcija Mostar"),
                Address = "Trg mladih 1",
                CityId = cityIds["Mostar"],
                OwnerUserId = adminId
            });

        await context.SaveChangesAsync();
    }

    private static async Task SeedEventsAndShiftsAsync(ApplicationDbContext context)
    {
        if (context.Events.Any())
            return;

        var admin = await context.Volunteers.FirstAsync(u => u.Role == UserRole.Admin);
        var categoryIds = await context.EventCategories.ToDictionaryAsync(c => c.Name, c => c.Id);
        var cityIds = await context.Cities.ToDictionaryAsync(c => c.Name, c => c.Id);
        var orgIds = await context.Organizations.ToDictionaryAsync(o => o.Name, o => o.Id);

        var events = new[]
        {
            new Event
            {
                Title = "Čišćenje rijeke Miljacke",
                Description = "Godišnja akcija čišćenja obala rijeke Miljacke uz koordinaciju lokalnih partnera.",
                Requirements = "Fizički rad, timski rad, boravak na otvorenom",
                ImageUrl = GetEventImageUrl("ciscenje-rijeke-miljacke"),
                StartDate = DateTime.UtcNow.AddDays(7),
                EndDate = DateTime.UtcNow.AddDays(7).AddHours(8),
                Location = "Obala Kulina bana, Sarajevo",
                Latitude = 43.8563,
                Longitude = 18.4131,
                MaxVolunteers = 50,
                Status = EventStatus.Published,
                IsFeatured = true,
                CategoryId = categoryIds["Okoliš"],
                CityId = cityIds["Sarajevo"],
                OrganizationId = orgIds["Eko Akcija Mostar"],
                CreatedByUserId = admin.Id
            },
            new Event
            {
                Title = "Besplatne instrukcije za učenike",
                Description = "Mentorska podrška učenicima osnovnih škola kroz volontiranje nastavnika i studenata.",
                Requirements = "Podučavanje, strpljenje, komunikacija",
                ImageUrl = GetEventImageUrl("instrukcije-za-ucenike"),
                StartDate = DateTime.UtcNow.AddDays(4),
                EndDate = DateTime.UtcNow.AddDays(4).AddHours(4),
                Location = "Centar za kulturu, Sarajevo",
                Latitude = 43.8600,
                Longitude = 18.4200,
                MaxVolunteers = 20,
                Status = EventStatus.Published,
                CategoryId = categoryIds["Edukacija"],
                CityId = cityIds["Sarajevo"],
                OrganizationId = orgIds["Crveni Križ Sarajevo"],
                CreatedByUserId = admin.Id
            },
            new Event
            {
                Title = "Posjeta domu za starije",
                Description = "Druženje, podrška i pomoć starijim osobama kroz vikend posjete.",
                Requirements = "Empatija, komunikacija, odgovornost",
                ImageUrl = GetEventImageUrl("posjeta-domu-za-starije"),
                StartDate = DateTime.UtcNow.AddDays(10),
                EndDate = DateTime.UtcNow.AddDays(10).AddHours(5),
                Location = "Dom za starije Novi Život",
                Latitude = 43.8520,
                Longitude = 18.3890,
                MaxVolunteers = 18,
                Status = EventStatus.Published,
                CategoryId = categoryIds["Stariji"],
                CityId = cityIds["Sarajevo"],
                OrganizationId = orgIds["Crveni Križ Sarajevo"],
                CreatedByUserId = admin.Id
            },
            new Event
            {
                Title = "Proljetno čišćenje grada",
                Description = "Završena akcija za potrebe historije i izvještaja.",
                Requirements = "Fizički rad, timski rad",
                ImageUrl = GetEventImageUrl("proljetno-ciscenje-grada"),
                StartDate = DateTime.UtcNow.AddDays(-14),
                EndDate = DateTime.UtcNow.AddDays(-14).AddHours(6),
                Location = "Centar grada, Sarajevo",
                Latitude = 43.8563,
                Longitude = 18.4131,
                MaxVolunteers = 40,
                Status = EventStatus.Completed,
                CategoryId = categoryIds["Okoliš"],
                CityId = cityIds["Sarajevo"],
                OrganizationId = orgIds["Eko Akcija Mostar"],
                CreatedByUserId = admin.Id
            }
        };

        await context.Events.AddRangeAsync(events);
        await context.SaveChangesAsync();

        var shifts = new List<Shift>();
        foreach (var evt in await context.Events.ToListAsync())
        {
            shifts.Add(new Shift
            {
                EventId = evt.Id,
                Name = "Jutarnja smjena",
                Description = $"Prva smjena za {evt.Title}",
                StartTime = evt.StartDate,
                EndTime = evt.StartDate.AddHours(Math.Max(3, (evt.EndDate - evt.StartDate).TotalHours / 2)),
                MaxVolunteers = Math.Max(5, evt.MaxVolunteers / 2)
            });

            shifts.Add(new Shift
            {
                EventId = evt.Id,
                Name = "Popodnevna smjena",
                Description = $"Druga smjena za {evt.Title}",
                StartTime = evt.StartDate.AddHours(Math.Max(3, (evt.EndDate - evt.StartDate).TotalHours / 2)),
                EndTime = evt.EndDate,
                MaxVolunteers = Math.Max(5, evt.MaxVolunteers / 2)
            });
        }

        await context.Shifts.AddRangeAsync(shifts);
        await context.SaveChangesAsync();

        var mobileUserId = await context.Volunteers.Where(u => u.Email == "mobile@volunteerhub.ba").Select(u => u.Id).FirstAsync();
        var volunteerIds = await context.Volunteers.Where(u => u.Role == UserRole.Volunteer).OrderBy(u => u.Id).Select(u => u.Id).ToListAsync();
        var publishedEvents = await context.Events.Where(e => e.Status == EventStatus.Published).OrderBy(e => e.StartDate).ToListAsync();
        var completedEvent = await context.Events.FirstAsync(e => e.Status == EventStatus.Completed);

        foreach (var evt in publishedEvents.Take(3))
        {
            await context.EventRegistrations.AddAsync(new EventRegistration
            {
                EventId = evt.Id,
                UserId = mobileUserId,
                Notes = "Seed registracija za mobilnu aplikaciju"
            });
        }

        var completedShifts = await context.Shifts.Where(s => s.EventId == completedEvent.Id).OrderBy(s => s.StartTime).ToListAsync();
        foreach (var shift in completedShifts)
        {
            foreach (var volunteerId in volunteerIds.Take(3))
            {
                await context.ShiftRegistrations.AddAsync(new ShiftRegistration
                {
                    UserId = volunteerId,
                    ShiftId = shift.Id,
                    Status = ShiftStatus.Completed,
                    CheckInTime = shift.StartTime,
                    CheckOutTime = shift.EndTime,
                    HoursWorked = (shift.EndTime - shift.StartTime).TotalHours,
                    IsApproved = true,
                    AdminNotes = "Automatski odobreno - seed podaci"
                });
            }
        }

        var upcomingShiftId = await context.Shifts
            .Where(s => s.StartTime > DateTime.UtcNow)
            .OrderBy(s => s.StartTime)
            .Select(s => s.Id)
            .FirstAsync();

        await context.ShiftRegistrations.AddAsync(new ShiftRegistration
        {
            UserId = mobileUserId,
            ShiftId = upcomingShiftId,
            Status = ShiftStatus.Registered
        });

        await context.SaveChangesAsync();

        await SeedVolunteerHistoryAsync(context);
    }

    private static async Task SeedCampaignsAndDonationsAsync(ApplicationDbContext context)
    {
        if (context.Campaigns.Any())
            return;

        var adminId = await context.Volunteers.Where(u => u.Role == UserRole.Admin).Select(u => u.Id).FirstAsync();
        var orgId = await context.Organizations.Where(o => o.Name == "Crveni Križ Sarajevo").Select(o => o.Id).FirstAsync();

        await context.Campaigns.AddRangeAsync(
            new Campaign
            {
                Title = "Pomoć za poplavljena područja",
                Description = "Prikupljanje sredstava za porodice pogođene poplavama.",
                ImageUrl = GetCampaignImageUrl("pomoc-za-poplavljena-podrucja"),
                GoalAmount = 10000,
                CurrentAmount = 2500,
                StartDate = DateTime.UtcNow.AddDays(-7),
                EndDate = DateTime.UtcNow.AddDays(30),
                IsActive = true,
                IsFeatured = true,
                OrganizationId = orgId,
                CreatedByUserId = adminId
            },
            new Campaign
            {
                Title = "Školski pribor za djecu",
                Description = "Podrška kupovini školskog pribora za djecu iz socijalno osjetljivih porodica.",
                ImageUrl = GetCampaignImageUrl("skolski-pribor-za-djecu"),
                GoalAmount = 5000,
                CurrentAmount = 1200,
                StartDate = DateTime.UtcNow.AddDays(-3),
                EndDate = DateTime.UtcNow.AddDays(45),
                IsActive = true,
                OrganizationId = orgId,
                CreatedByUserId = adminId
            },
            new Campaign
            {
                Title = "Azil za životinje Sarajevo",
                Description = "Hrana, veterinarski tretmani i podrška azilu.",
                ImageUrl = GetCampaignImageUrl("azil-za-zivotinje-sarajevo"),
                GoalAmount = 3000,
                CurrentAmount = 850,
                StartDate = DateTime.UtcNow.AddDays(-2),
                EndDate = DateTime.UtcNow.AddDays(60),
                IsActive = true,
                OrganizationId = orgId,
                CreatedByUserId = adminId
            });

        await context.SaveChangesAsync();

        var campaignIds = await context.Campaigns.OrderBy(c => c.Id).Select(c => c.Id).ToListAsync();
        var volunteerIds = await context.Volunteers.Where(u => u.Role == UserRole.Volunteer).OrderBy(u => u.Id).Select(u => u.Id).ToListAsync();

        for (var i = 0; i < campaignIds.Count; i++)
        {
            var donorId = volunteerIds[i % volunteerIds.Count];
            var donor = await context.Volunteers.FindAsync(donorId);
            if (donor == null)
                continue;

            await context.Donations.AddAsync(new Donation
            {
                CampaignId = campaignIds[i],
                UserId = donorId,
                Amount = 50 + (i * 25),
                Currency = "BAM",
                Status = DonationStatus.Completed,
                DonorName = $"{donor.FirstName} {donor.LastName}",
                Message = "Sretno sa kampanjom!",
                IsAnonymous = false
            });

            await context.VolunteerHistories.AddAsync(new VolunteerHistory
            {
                UserId = donorId,
                CampaignId = campaignIds[i],
                ActionType = "Donation",
                Description = "Korisnik je izvršio donaciju kampanji.",
                OccurredAt = DateTime.UtcNow.AddDays(-i)
            });
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedBlogAsync(ApplicationDbContext context)
    {
        if (context.BlogPosts.Any())
            return;

        var adminId = await context.Volunteers.Where(u => u.Role == UserRole.Admin).Select(u => u.Id).FirstAsync();
        var orgId = await context.Organizations.Where(o => o.Name == "Crveni Križ Sarajevo").Select(o => o.Id).FirstAsync();
        var categories = await context.BlogCategories.ToDictionaryAsync(c => c.Name, c => c.Id);

        await context.BlogPosts.AddRangeAsync(
            new BlogPost
            {
                Title = "Dobrodošli na VolunteerHub",
                Content = "VolunteerHub povezuje volontere sa organizacijama kroz događaje, smjene, blog i donacije.",
                Summary = "Upoznajte platformu i njene glavne mogućnosti.",
                ImageUrl = GetBlogImageUrl("dobrodosli-na-volunteerhub"),
                Tags = "uvod,volontiranje,zajednica",
                IsPublished = true,
                PublishedAt = DateTime.UtcNow.AddDays(-10),
                BlogCategoryId = categories["Novosti"],
                OrganizationId = orgId,
                AuthorId = adminId,
                ViewCount = 120
            },
            new BlogPost
            {
                Title = "Kako se pripremiti za volontersku akciju",
                Content = "Prije svake akcije provjerite detalje događaja, potrebne vještine i lokaciju, te dođite na vrijeme.",
                Summary = "Praktični savjeti za nove volontere.",
                ImageUrl = GetBlogImageUrl("priprema-za-volontersku-akciju"),
                Tags = "savjeti,volonteri,priprema",
                IsPublished = true,
                PublishedAt = DateTime.UtcNow.AddDays(-4),
                BlogCategoryId = categories["Savjeti"],
                OrganizationId = orgId,
                AuthorId = adminId,
                ViewCount = 64
            },
            new BlogPost
            {
                Title = "Priča volonterke Lejle",
                Content = "Lejlino iskustvo pokazuje kako se volontiranjem grade vještine i dugoročne veze u zajednici.",
                Summary = "Iskustvo iz zajednice i motivacija za nove članove.",
                ImageUrl = GetBlogImageUrl("prica-volonterke-lejle"),
                Tags = "priče,iskustva,zajednica",
                IsPublished = false,
                ScheduledPublishAt = DateTime.UtcNow.AddDays(2),
                BlogCategoryId = categories["Priče"],
                OrganizationId = orgId,
                AuthorId = adminId
            });

        await context.SaveChangesAsync();
    }

    private static async Task SeedNotificationsAsync(ApplicationDbContext context)
    {
        if (context.Notifications.Any())
            return;

        var mobileUserId = await context.Volunteers.Where(u => u.Email == "mobile@volunteerhub.ba").Select(u => u.Id).FirstAsync();

        await context.Notifications.AddRangeAsync(
            new Notification
            {
                UserId = mobileUserId,
                Title = "Dobrodošli",
                Message = "Prijavljeni ste na VolunteerHub. Istražite preporučene događaje i donacije.",
                Type = NotificationType.General,
                IsRead = false
            },
            new Notification
            {
                UserId = mobileUserId,
                Title = "Nova registracija događaja",
                Message = "Vaša prijava na događaj je evidentirana. Odaberite i odgovarajuću smjenu.",
                Type = NotificationType.ShiftRegistration,
                IsRead = false
            });

        await context.SaveChangesAsync();
    }

    private static async Task SeedVolunteerHistoryAsync(ApplicationDbContext context)
    {
        if (context.VolunteerHistories.Any())
            return;

        var registrations = await context.EventRegistrations.Include(r => r.Event).ToListAsync();
        foreach (var registration in registrations)
        {
            await context.VolunteerHistories.AddAsync(new VolunteerHistory
            {
                UserId = registration.UserId,
                EventId = registration.EventId,
                ActionType = "EventRegistration",
                Description = $"Korisnik se prijavio na događaj {registration.Event.Title}.",
                OccurredAt = registration.RegisteredAt
            });
        }

        var shiftRegistrations = await context.ShiftRegistrations.Include(r => r.Shift).ToListAsync();
        foreach (var shiftRegistration in shiftRegistrations.Take(4))
        {
            await context.VolunteerHistories.AddAsync(new VolunteerHistory
            {
                UserId = shiftRegistration.UserId,
                ShiftId = shiftRegistration.ShiftId,
                ActionType = "ShiftProgress",
                Description = "Evidentirana prijava ili završetak smjene.",
                OccurredAt = shiftRegistration.CreatedAt
            });
        }

        await context.SaveChangesAsync();
    }

    private static async Task ApplyVisualAssetsAsync(ApplicationDbContext context)
    {
        await ApplyUserImagesAsync(context);
        await ApplyOrganizationImagesAsync(context);
        await ApplyEventImagesAsync(context);
        await ApplyCampaignImagesAsync(context);
        await ApplyBlogImagesAsync(context);
    }

    private static async Task ApplyUserImagesAsync(ApplicationDbContext context)
    {
        var users = await context.Volunteers.ToListAsync();
        foreach (var user in users)
        {
            if (!string.IsNullOrWhiteSpace(user.ProfileImageUrl))
                continue;

            user.ProfileImageUrl = GetUserAvatarUrl(user.Email ?? $"{user.FirstName}-{user.LastName}-{user.Id}");
        }

        await context.SaveChangesAsync();
    }

    private static async Task ApplyOrganizationImagesAsync(ApplicationDbContext context)
    {
        var organizations = await context.Organizations.ToListAsync();
        foreach (var org in organizations)
        {
            if (!string.IsNullOrWhiteSpace(org.LogoUrl))
                continue;

            org.LogoUrl = GetOrganizationLogoUrl(org.Name);
        }

        await context.SaveChangesAsync();
    }

    private static async Task ApplyEventImagesAsync(ApplicationDbContext context)
    {
        var events = await context.Events.ToListAsync();
        foreach (var evt in events)
        {
            if (!string.IsNullOrWhiteSpace(evt.ImageUrl))
                continue;

            evt.ImageUrl = GetEventImageUrl(evt.Title);
        }

        await context.SaveChangesAsync();
    }

    private static async Task ApplyCampaignImagesAsync(ApplicationDbContext context)
    {
        var campaigns = await context.Campaigns.ToListAsync();
        foreach (var campaign in campaigns)
        {
            if (!string.IsNullOrWhiteSpace(campaign.ImageUrl))
                continue;

            campaign.ImageUrl = GetCampaignImageUrl(campaign.Title);
        }

        await context.SaveChangesAsync();
    }

    private static async Task ApplyBlogImagesAsync(ApplicationDbContext context)
    {
        var posts = await context.BlogPosts.ToListAsync();
        foreach (var post in posts)
        {
            if (!string.IsNullOrWhiteSpace(post.ImageUrl))
                continue;

            post.ImageUrl = GetBlogImageUrl(post.Title);
        }

        await context.SaveChangesAsync();
    }

    private static string GetUserAvatarUrl(string seed)
    {
        return $"https://i.pravatar.cc/300?u={Uri.EscapeDataString(seed)}";
    }

    private static string GetOrganizationLogoUrl(string seed)
    {
        var text = Uri.EscapeDataString(seed.Length > 18 ? seed[..18] : seed);
        return $"https://placehold.co/400x400/1f2937/ffffff?text={text}";
    }

    private static string GetEventImageUrl(string seed)
    {
        return $"https://picsum.photos/seed/{Uri.EscapeDataString(seed)}/1200/800";
    }

    private static string GetCampaignImageUrl(string seed)
    {
        return $"https://picsum.photos/seed/campaign-{Uri.EscapeDataString(seed)}/1200/800";
    }

    private static string GetBlogImageUrl(string seed)
    {
        return $"https://picsum.photos/seed/blog-{Uri.EscapeDataString(seed)}/1200/800";
    }

    private sealed record SeedUser(
        string Username,
        string Email,
        string FirstName,
        string LastName,
        UserRole Role,
        string IdentityRole,
        int CityId,
        string Phone,
        string Bio);
}

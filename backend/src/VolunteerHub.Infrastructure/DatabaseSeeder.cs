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
        await SeedRecommendationsAsync(context);
        await SeedVolunteerHistoryAsync(context);
        await RebuildLeaderboardAsync(context);
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
        var countries = new[]
        {
            new Country { Name = "Bosna i Hercegovina", Code = "BA" },
            new Country { Name = "Hrvatska", Code = "HR" },
            new Country { Name = "Srbija", Code = "RS" },
            new Country { Name = "Crna Gora", Code = "ME" }
        };

        foreach (var country in countries)
        {
            if (!await context.Countries.AnyAsync(c => c.Code == country.Code))
            {
                context.Countries.Add(country);
            }
        }

        await context.SaveChangesAsync();

        var countryIds = await context.Countries.ToDictionaryAsync(c => c.Code, c => c.Id);
        var cities = new[]
        {
            new City { Name = "Sarajevo", PostalCode = "71000", CountryId = countryIds["BA"] },
            new City { Name = "Mostar", PostalCode = "88000", CountryId = countryIds["BA"] },
            new City { Name = "Tuzla", PostalCode = "75000", CountryId = countryIds["BA"] },
            new City { Name = "Zenica", PostalCode = "72000", CountryId = countryIds["BA"] },
            new City { Name = "Banja Luka", PostalCode = "78000", CountryId = countryIds["BA"] },
            new City { Name = "Bihac", PostalCode = "77000", CountryId = countryIds["BA"] },
            new City { Name = "Travnik", PostalCode = "72270", CountryId = countryIds["BA"] },
            new City { Name = "Doboj", PostalCode = "74000", CountryId = countryIds["BA"] },
            new City { Name = "Bijeljina", PostalCode = "76300", CountryId = countryIds["BA"] },
            new City { Name = "Trebinje", PostalCode = "89101", CountryId = countryIds["BA"] },
            new City { Name = "Bugojno", PostalCode = "70230", CountryId = countryIds["BA"] },
            new City { Name = "Gorazde", PostalCode = "73000", CountryId = countryIds["BA"] },
            new City { Name = "Brcko", PostalCode = "76100", CountryId = countryIds["BA"] },
            new City { Name = "Konjic", PostalCode = "88400", CountryId = countryIds["BA"] },
            new City { Name = "Zagreb", PostalCode = "10000", CountryId = countryIds["HR"] },
            new City { Name = "Split", PostalCode = "21000", CountryId = countryIds["HR"] },
            new City { Name = "Novi Sad", PostalCode = "21000", CountryId = countryIds["RS"] }
        };

        foreach (var city in cities)
        {
            if (!await context.Cities.AnyAsync(c => c.Name == city.Name))
            {
                context.Cities.Add(city);
            }
        }

        var eventCategories = new[]
        {
            new EventCategory { Name = "Okolis", Description = "Ekologija i akcije uredjenja prostora", IconUrl = "leaf", Color = "#4CAF50" },
            new EventCategory { Name = "Edukacija", Description = "Mentorstvo, radionice i obuke", IconUrl = "school", Color = "#2196F3" },
            new EventCategory { Name = "Humanitarno", Description = "Podrska zajednici i kriznim akcijama", IconUrl = "favorite", Color = "#E91E63" },
            new EventCategory { Name = "Sport", Description = "Sportske i rekreativne aktivnosti", IconUrl = "sports_soccer", Color = "#FF9800" },
            new EventCategory { Name = "Seniori", Description = "Podrska starijim osobama", IconUrl = "elderly", Color = "#00BCD4" },
            new EventCategory { Name = "Digitalno", Description = "IT i administrativna podrska", IconUrl = "computer", Color = "#673AB7" }
        };

        foreach (var category in eventCategories)
        {
            if (!await context.EventCategories.AnyAsync(c => c.Name == category.Name))
            {
                context.EventCategories.Add(category);
            }
        }

        var skills = new[]
        {
            new Skill { Name = "Fizicki rad", Description = "Terenski i logisticki zadaci" },
            new Skill { Name = "Poducavanje", Description = "Radionice, mentorstvo i edukacija" },
            new Skill { Name = "Prva pomoc", Description = "Osnovna medicinska podrska" },
            new Skill { Name = "Voznja", Description = "Prevoz opreme ili ljudi" },
            new Skill { Name = "IT vjestine", Description = "Digitalna podrska i alati" },
            new Skill { Name = "Marketing", Description = "Promocija dogadjaja i kampanja" },
            new Skill { Name = "Fotografija", Description = "Dokumentovanje aktivnosti na terenu" },
            new Skill { Name = "Koordinacija tima", Description = "Vodjenje manjih grupa volontera" },
            new Skill { Name = "Rad sa djecom", Description = "Animacija i edukacija djece" },
            new Skill { Name = "Administracija", Description = "Unos podataka i priprema materijala" }
        };

        foreach (var skill in skills)
        {
            if (!await context.Skills.AnyAsync(s => s.Name == skill.Name))
            {
                context.Skills.Add(skill);
            }
        }

        var blogCategories = new[]
        {
            new BlogCategory { Name = "Novosti", Description = "Aktuelnosti i najave", Color = "#2196F3" },
            new BlogCategory { Name = "Savjeti", Description = "Prakticni vodici za volontere", Color = "#4CAF50" },
            new BlogCategory { Name = "Price", Description = "Iskustva iz zajednice", Color = "#FF9800" },
            new BlogCategory { Name = "Intervjui", Description = "Razgovori sa organizatorima i volonterima", Color = "#9C27B0" },
            new BlogCategory { Name = "Donacije", Description = "Transparentnost kampanja i rezultati", Color = "#F44336" }
        };

        foreach (var category in blogCategories)
        {
            if (!await context.BlogCategories.AnyAsync(c => c.Name == category.Name))
            {
                context.BlogCategories.Add(category);
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedUsersAsync(ApplicationDbContext context, UserManager<ApplicationUser> userManager)
    {
        var cityIds = await context.Cities.ToDictionaryAsync(c => c.Name, c => c.Id);
        var users = new[]
        {
            new SeedUser("desktop", "desktop@volunteerhub.ba", "Desktop", "Admin", UserRole.Admin, "Admin", cityIds["Sarajevo"], "+38761100100", "Administrator sistema i glavni test korisnik."),
            new SeedUser("mobile", "mobile@volunteerhub.ba", "Mobile", "Volonter", UserRole.Volunteer, "Volunteer", cityIds["Sarajevo"], "+38762200200", "Aktivni mobilni korisnik sa vise prijava i notifikacija."),
            new SeedUser("superadmin", "superadmin@volunteerhub.ba", "Super", "Admin", UserRole.SuperAdmin, "SuperAdmin", cityIds["Sarajevo"], "+38761100999", "Rezervni administrator za pregled role-based pristupa."),
            new SeedUser("tarik", "tarik@test.ba", "Tarik", "Kreso", UserRole.Volunteer, "Volunteer", cityIds["Sarajevo"], "+38761111111", "Student i volonter sa fokusom na edukaciju i izvjestaje."),
            new SeedUser("amra", "amra@test.ba", "Amra", "Hodzic", UserRole.Volunteer, "Volunteer", cityIds["Mostar"], "+38762222222", "Volonterka iz Mostara, aktivna u humanitarnim kampanjama."),
            new SeedUser("mirza", "mirza@test.ba", "Mirza", "Begic", UserRole.Volunteer, "Volunteer", cityIds["Tuzla"], "+38763333333", "Pomaze na terenskim akcijama i logistici."),
            new SeedUser("lejla", "lejla@test.ba", "Lejla", "Ibrahimovic", UserRole.Volunteer, "Volunteer", cityIds["Zenica"], "+38764444444", "Iskusna volonterka i cesto medju vodecima na leaderboardu."),
            new SeedUser("sara", "sara@test.ba", "Sara", "Kovacevic", UserRole.Volunteer, "Volunteer", cityIds["Banja Luka"], "+38765555555", "Podrska kampanjama i administraciji."),
            new SeedUser("eman", "eman@test.ba", "Eman", "Softic", UserRole.Volunteer, "Volunteer", cityIds["Travnik"], "+38766666666", "Koordinise edukativne radionice za mlade."),
            new SeedUser("adnan", "adnan@test.ba", "Adnan", "Sehic", UserRole.Volunteer, "Volunteer", cityIds["Doboj"], "+38767777777", "Aktivan na sportskim i terenskim akcijama."),
            new SeedUser("selma", "selma@test.ba", "Selma", "Muminovic", UserRole.Volunteer, "Volunteer", cityIds["Bihac"], "+38768888888", "Podrska seniorima i lokalnim zajednicama."),
            new SeedUser("harun", "harun@test.ba", "Harun", "Causevic", UserRole.Volunteer, "Volunteer", cityIds["Bijeljina"], "+38769999999", "Pokriva IT i digitalne zadatke."),
            new SeedUser("ivana", "ivana@test.ba", "Ivana", "Coric", UserRole.Volunteer, "Volunteer", cityIds["Mostar"], "+38761222333", "Volonterka sa interesom za medijsku promociju.")
        };

        foreach (var seedUser in users)
        {
            await EnsureUserAsync(context, userManager, seedUser);
        }

        var skills = await context.Skills.OrderBy(s => s.Id).ToListAsync();
        var volunteers = await context.Volunteers
            .Where(v => v.Role == UserRole.Volunteer)
            .OrderBy(v => v.Id)
            .ToListAsync();

        for (var index = 0; index < volunteers.Count; index++)
        {
            var volunteer = volunteers[index];
            var desiredSkills = new[]
            {
                skills[index % skills.Count],
                skills[(index + 2) % skills.Count],
                skills[(index + 5) % skills.Count]
            };

            foreach (var desiredSkill in desiredSkills)
            {
                if (!await context.UserSkills.AnyAsync(us => us.UserId == volunteer.Id && us.SkillId == desiredSkill.Id))
                {
                    context.UserSkills.Add(new UserSkill
                    {
                        UserId = volunteer.Id,
                        SkillId = desiredSkill.Id,
                        ProficiencyLevel = 3 + ((index + desiredSkill.Id) % 3),
                        YearsExperience = 1 + ((index + desiredSkill.Id) % 4),
                        IsVerified = (index + desiredSkill.Id) % 2 == 0
                    });
                }
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task EnsureUserAsync(
        ApplicationDbContext context,
        UserManager<ApplicationUser> userManager,
        SeedUser seedUser)
    {
        var identityUser = await userManager.FindByNameAsync(seedUser.Username);
        if (identityUser == null)
        {
            identityUser = new ApplicationUser
            {
                UserName = seedUser.Username,
                Email = seedUser.Email,
                IsActive = true,
                EmailConfirmed = true
            };

            var identityResult = await userManager.CreateAsync(identityUser, "test");
            if (!identityResult.Succeeded)
            {
                throw new InvalidOperationException(string.Join(" ", identityResult.Errors.Select(e => e.Description)));
            }
        }

        if (!await userManager.IsInRoleAsync(identityUser, seedUser.IdentityRole))
        {
            await userManager.AddToRoleAsync(identityUser, seedUser.IdentityRole);
        }

        var profile = await context.Volunteers.FirstOrDefaultAsync(v => v.Email == seedUser.Email);
        if (profile == null)
        {
            profile = new User
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
                IsActive = true,
                LastLoginAt = DateTime.UtcNow.AddDays(-2)
            };

            context.Volunteers.Add(profile);
            await context.SaveChangesAsync();
        }
        else
        {
            profile.IdentityUserId ??= identityUser.Id;
            profile.CityId = seedUser.CityId;
            profile.Phone = seedUser.Phone;
            profile.Bio = seedUser.Bio;
            profile.Role = seedUser.Role;
            profile.IsActive = true;
            profile.ProfileImageUrl ??= GetUserAvatarUrl(seedUser.Username);
            await context.SaveChangesAsync();
        }

        if (identityUser.ProfileUserId != profile.Id)
        {
            identityUser.ProfileUserId = profile.Id;
            await userManager.UpdateAsync(identityUser);
        }
    }

    private static async Task SeedOrganizationsAsync(ApplicationDbContext context)
    {
        var cityIds = await context.Cities.ToDictionaryAsync(c => c.Name, c => c.Id);
        var adminId = await context.Volunteers.Where(u => u.Role == UserRole.Admin).Select(u => u.Id).FirstAsync();

        var organizations = new[]
        {
            new Organization
            {
                Name = "Crveni Kriz Sarajevo",
                Description = "Humanitarna organizacija fokusirana na podrsku zajednici, krizne akcije i edukaciju volontera.",
                Email = "info@cks.ba",
                Phone = "+38733222111",
                Website = "https://cks.ba",
                LogoUrl = GetOrganizationLogoUrl("Crveni Kriz Sarajevo"),
                Address = "Marsala Tita 10",
                CityId = cityIds["Sarajevo"],
                OwnerUserId = adminId
            },
            new Organization
            {
                Name = "Eko Akcija Mostar",
                Description = "Volonterske ekoloske akcije i edukacija mladih o zastiti okoline.",
                Email = "kontakt@ekoakcija.ba",
                Phone = "+38736222111",
                Website = "https://ekoakcija.ba",
                LogoUrl = GetOrganizationLogoUrl("Eko Akcija Mostar"),
                Address = "Trg mladih 1",
                CityId = cityIds["Mostar"],
                OwnerUserId = adminId
            },
            new Organization
            {
                Name = "Centar za mlade Tuzla",
                Description = "Programi mentorstva, digitalnih radionica i podrske skolama.",
                Email = "hello@mladituzla.ba",
                Phone = "+38735222000",
                Website = "https://mladituzla.ba",
                LogoUrl = GetOrganizationLogoUrl("Centar za mlade Tuzla"),
                Address = "Slobode 14",
                CityId = cityIds["Tuzla"],
                OwnerUserId = adminId
            },
            new Organization
            {
                Name = "Dom Novi Zivot",
                Description = "Partner za aktivnosti sa seniorima, druzenje i podrsku svakodnevnim potrebama.",
                Email = "kontakt@novizivot.ba",
                Phone = "+38733220055",
                Website = "https://novizivot.ba",
                LogoUrl = GetOrganizationLogoUrl("Dom Novi Zivot"),
                Address = "Naselje Sunca 4",
                CityId = cityIds["Sarajevo"],
                OwnerUserId = adminId
            },
            new Organization
            {
                Name = "Sport za sve Zenica",
                Description = "Lokalna organizacija za sportske dane, inkluzivne aktivnosti i rad sa djecom.",
                Email = "office@sportzasve.ba",
                Phone = "+38732222999",
                Website = "https://sportzasve.ba",
                LogoUrl = GetOrganizationLogoUrl("Sport za sve Zenica"),
                Address = "Bulevar 27",
                CityId = cityIds["Zenica"],
                OwnerUserId = adminId
            }
        };

        foreach (var organization in organizations)
        {
            if (!await context.Organizations.AnyAsync(o => o.Name == organization.Name))
            {
                context.Organizations.Add(organization);
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedEventsAndShiftsAsync(ApplicationDbContext context)
    {
        var adminId = await context.Volunteers.Where(u => u.Role == UserRole.Admin).Select(u => u.Id).FirstAsync();
        var categoryIds = await context.EventCategories.ToDictionaryAsync(c => c.Name, c => c.Id);
        var cityIds = await context.Cities.ToDictionaryAsync(c => c.Name, c => c.Id);
        var orgIds = await context.Organizations.ToDictionaryAsync(o => o.Name, o => o.Id);
        var now = DateTime.UtcNow;

        var events = new[]
        {
            new EventSeed("Ciscenje rijeke Miljacke", "Godisnja akcija ciscenja obala rijeke Miljacke uz koordinaciju lokalnih partnera.", "Fizicki rad, timski rad, boravak na otvorenom", "Obala Kulina bana, Sarajevo", 43.8563, 18.4131, 50, EventStatus.Published, true, "Okolis", "Sarajevo", "Eko Akcija Mostar", now.AddDays(7), now.AddDays(7).AddHours(8)),
            new EventSeed("Besplatne instrukcije za ucenike", "Mentorska podrska ucenicima osnovnih skola kroz volontiranje nastavnika i studenata.", "Poducavanje, strpljenje, komunikacija", "Centar za kulturu, Sarajevo", 43.86, 18.42, 20, EventStatus.Published, true, "Edukacija", "Sarajevo", "Centar za mlade Tuzla", now.AddDays(4), now.AddDays(4).AddHours(4)),
            new EventSeed("Posjeta domu za starije", "Druzenje, podrska i pomoc starijim osobama kroz vikend posjete.", "Empatija, komunikacija, odgovornost", "Dom za starije Novi Zivot", 43.852, 18.389, 18, EventStatus.Published, false, "Seniori", "Sarajevo", "Dom Novi Zivot", now.AddDays(10), now.AddDays(10).AddHours(5)),
            new EventSeed("Sortiranje prehrambenih paketa", "Priprema i pakovanje prehrambenih paketa za porodice u potrebi.", "Administracija, koordinacija tima, fizicki rad", "Magacin humanitarne pomoci, Mostar", 43.3438, 17.8078, 24, EventStatus.Published, false, "Humanitarno", "Mostar", "Crveni Kriz Sarajevo", now.AddDays(5), now.AddDays(5).AddHours(6)),
            new EventSeed("Radionica digitalne pismenosti", "Volonteri pomazu seniorima pri osnovnoj upotrebi telefona i interneta.", "IT vjestine, strpljenje, rad sa ljudima", "Biblioteka Tuzla", 44.5384, 18.6765, 16, EventStatus.Published, false, "Digitalno", "Tuzla", "Centar za mlade Tuzla", now.AddDays(8), now.AddDays(8).AddHours(3)),
            new EventSeed("Sportski dan za djecu", "Organizacija inkluzivnih sportskih aktivnosti za osnovce.", "Rad sa djecom, koordinacija, energija", "Gradski stadion Zenica", 44.2034, 17.9077, 28, EventStatus.Published, true, "Sport", "Zenica", "Sport za sve Zenica", now.AddDays(12), now.AddDays(12).AddHours(7)),
            new EventSeed("Pozivni centar za donacije", "Podrska gradjanima koji zele informacije o aktivnim kampanjama i dogadjajima.", "Administracija, komunikacija, IT vjestine", "Info centar VolunteerHub", 43.858, 18.4137, 10, EventStatus.Published, false, "Digitalno", "Sarajevo", "Crveni Kriz Sarajevo", now.AddHours(-1), now.AddHours(4)),
            new EventSeed("Jesenja sadnja drveca", "Planirana akcija sadnje drveca u gradskim parkovima.", "Fizicki rad, briga o okolisu", "Park prijateljstva, Banja Luka", 44.7722, 17.191, 35, EventStatus.Draft, false, "Okolis", "Banja Luka", "Eko Akcija Mostar", now.AddDays(20), now.AddDays(20).AddHours(6)),
            new EventSeed("Zimska akcija prikupljanja odjece", "Akcija je otkazana zbog logistickih ogranicenja partnera.", "Sortiranje, komunikacija", "Dom kulture, Doboj", 44.7311, 18.0866, 22, EventStatus.Cancelled, false, "Humanitarno", "Doboj", "Crveni Kriz Sarajevo", now.AddDays(2), now.AddDays(2).AddHours(5)),
            new EventSeed("Proljetno ciscenje grada", "Zavrsena akcija koja ostaje dostupna za historiju i izvjestaje.", "Fizicki rad, timski rad", "Centar grada, Sarajevo", 43.8563, 18.4131, 40, EventStatus.Completed, false, "Okolis", "Sarajevo", "Eko Akcija Mostar", now.AddDays(-14), now.AddDays(-14).AddHours(6))
        };

        foreach (var evt in events)
        {
            if (!await context.Events.AnyAsync(e => e.Title == evt.Title))
            {
                context.Events.Add(new Event
                {
                    Title = evt.Title,
                    Description = evt.Description,
                    Requirements = evt.Requirements,
                    ImageUrl = GetEventImageUrl(evt.Title),
                    StartDate = evt.StartDate,
                    EndDate = evt.EndDate,
                    Location = evt.Location,
                    Latitude = evt.Latitude,
                    Longitude = evt.Longitude,
                    MaxVolunteers = evt.MaxVolunteers,
                    Status = evt.Status,
                    IsFeatured = evt.IsFeatured,
                    CategoryId = categoryIds[evt.CategoryName],
                    CityId = cityIds[evt.CityName],
                    OrganizationId = orgIds[evt.OrganizationName],
                    CreatedByUserId = adminId
                });
            }
        }

        await context.SaveChangesAsync();

        var persistedEvents = await context.Events.ToDictionaryAsync(e => e.Title, e => e);
        foreach (var evt in events)
        {
            var persisted = persistedEvents[evt.Title];
            var shiftSeeds = BuildShiftSeedsForEvent(persisted);
            foreach (var shiftSeed in shiftSeeds)
            {
                if (!await context.Shifts.AnyAsync(s => s.EventId == persisted.Id && s.Name == shiftSeed.Name))
                {
                    context.Shifts.Add(new Shift
                    {
                        EventId = persisted.Id,
                        Name = shiftSeed.Name,
                        Description = shiftSeed.Description,
                        StartTime = shiftSeed.StartTime,
                        EndTime = shiftSeed.EndTime,
                        MaxVolunteers = shiftSeed.MaxVolunteers,
                        IsLocked = shiftSeed.IsLocked
                    });
                }
            }
        }

        await context.SaveChangesAsync();

        await SeedEventRegistrationsAsync(context);
        await SeedShiftRegistrationsAsync(context);
        await UpdateShiftOccupancyAsync(context);
    }

    private static List<ShiftSeed> BuildShiftSeedsForEvent(Event evt)
    {
        var seeds = new List<ShiftSeed>();
        var totalHours = Math.Max(2.0, (evt.EndDate - evt.StartDate).TotalHours);
        var halfDuration = TimeSpan.FromHours(Math.Max(2, totalHours / 2));
        var firstEnd = evt.StartDate.Add(halfDuration);
        if (firstEnd > evt.EndDate)
        {
            firstEnd = evt.EndDate.AddHours(-1);
        }

        seeds.Add(new ShiftSeed(
            "Jutarnja smjena",
            $"Prva operativna smjena za dogadjaj {evt.Title}.",
            evt.StartDate,
            firstEnd,
            Math.Max(4, evt.MaxVolunteers / 2),
            evt.Status == EventStatus.Completed));

        seeds.Add(new ShiftSeed(
            "Popodnevna smjena",
            $"Druga operativna smjena za dogadjaj {evt.Title}.",
            firstEnd,
            evt.EndDate,
            Math.Max(4, evt.MaxVolunteers / 2),
            evt.Status == EventStatus.Completed));

        if ((evt.EndDate - evt.StartDate).TotalHours >= 6)
        {
            var eveningStart = evt.StartDate.AddHours(1);
            var eveningEnd = eveningStart.AddHours(2.5);
            if (eveningEnd < evt.EndDate)
            {
                seeds.Add(new ShiftSeed(
                    "Koordinacijska smjena",
                    $"Koordinacija volontera i materijala za {evt.Title}.",
                    eveningStart,
                    eveningEnd,
                    Math.Max(3, evt.MaxVolunteers / 3),
                    evt.Status == EventStatus.Completed));
            }
        }

        return seeds;
    }

    private static async Task SeedEventRegistrationsAsync(ApplicationDbContext context)
    {
        var volunteerIds = await context.Volunteers
            .Where(v => v.Role == UserRole.Volunteer)
            .OrderBy(v => v.Id)
            .Select(v => v.Id)
            .ToListAsync();

        var eventIds = await context.Events.ToDictionaryAsync(e => e.Title, e => e.Id);
        var registrations = new[]
        {
            new EventRegistrationSeed("mobile@volunteerhub.ba", "Ciscenje rijeke Miljacke", "Registered", "Seed registracija za mobilnu aplikaciju."),
            new EventRegistrationSeed("mobile@volunteerhub.ba", "Besplatne instrukcije za ucenike", "Registered", "Zelim raditi sa djecom."),
            new EventRegistrationSeed("mobile@volunteerhub.ba", "Pozivni centar za donacije", "Registered", "Dostupan sam odmah danas."),
            new EventRegistrationSeed("tarik@test.ba", "Radionica digitalne pismenosti", "Registered", "Mogu pokriti uvodni dio radionice."),
            new EventRegistrationSeed("amra@test.ba", "Sortiranje prehrambenih paketa", "Registered", "Dostupna cijelu smjenu."),
            new EventRegistrationSeed("mirza@test.ba", "Ciscenje rijeke Miljacke", "Registered", "Imam iskustvo sa slicnim akcijama."),
            new EventRegistrationSeed("lejla@test.ba", "Sportski dan za djecu", "Registered", "Mogu voditi grupu djece."),
            new EventRegistrationSeed("sara@test.ba", "Pozivni centar za donacije", "Cancelled", "Presla na drugi termin."),
            new EventRegistrationSeed("selma@test.ba", "Posjeta domu za starije", "Registered", "Volim raditi sa seniorima."),
            new EventRegistrationSeed("harun@test.ba", "Radionica digitalne pismenosti", "Registered", "Mogu pomoci oko prijava i uredjaja.")
        };

        var usersByEmail = await context.Volunteers.ToDictionaryAsync(u => u.Email, u => u.Id);
        foreach (var registration in registrations)
        {
            if (!usersByEmail.TryGetValue(registration.Email, out var userId) ||
                !eventIds.TryGetValue(registration.EventTitle, out var eventId))
            {
                continue;
            }

            if (!await context.EventRegistrations.AnyAsync(r => r.UserId == userId && r.EventId == eventId))
            {
                context.EventRegistrations.Add(new EventRegistration
                {
                    UserId = userId,
                    EventId = eventId,
                    Status = registration.Status,
                    Notes = registration.Notes,
                    RegisteredAt = DateTime.UtcNow.AddDays(-Math.Abs(userId % 5))
                });
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedShiftRegistrationsAsync(ApplicationDbContext context)
    {
        var usersByEmail = await context.Volunteers.ToDictionaryAsync(u => u.Email, u => u.Id);
        var adminId = await context.Volunteers.Where(v => v.Role == UserRole.Admin).Select(v => v.Id).FirstAsync();
        var shifts = await context.Shifts.Include(s => s.Event).ToListAsync();

        int ShiftId(string eventTitle, string shiftName)
        {
            return shifts.First(s => s.Event.Title == eventTitle && s.Name == shiftName).Id;
        }

        var registrations = new[]
        {
            new ShiftRegistrationSeed("mobile@volunteerhub.ba", ShiftId("Pozivni centar za donacije", "Jutarnja smjena"), ShiftStatus.Approved, DateTime.UtcNow.AddMinutes(-45), null, null, false, false, "Aktivan check-in za demo."),
            new ShiftRegistrationSeed("mobile@volunteerhub.ba", ShiftId("Besplatne instrukcije za ucenike", "Jutarnja smjena"), ShiftStatus.Registered, null, null, null, false, false, "Ceka potvrdu koordinatora."),
            new ShiftRegistrationSeed("mobile@volunteerhub.ba", ShiftId("Ciscenje rijeke Miljacke", "Jutarnja smjena"), ShiftStatus.Registered, null, null, null, false, false, "Prijava bez kolizije."),
            new ShiftRegistrationSeed("tarik@test.ba", ShiftId("Radionica digitalne pismenosti", "Jutarnja smjena"), ShiftStatus.Approved, null, null, null, false, false, "Odobren kao IT mentor."),
            new ShiftRegistrationSeed("amra@test.ba", ShiftId("Sortiranje prehrambenih paketa", "Jutarnja smjena"), ShiftStatus.Pending, null, null, null, false, false, "Ceka adminsko odobrenje."),
            new ShiftRegistrationSeed("mirza@test.ba", ShiftId("Ciscenje rijeke Miljacke", "Popodnevna smjena"), ShiftStatus.Approved, null, null, null, false, false, "Odobren za terensku smjenu."),
            new ShiftRegistrationSeed("lejla@test.ba", ShiftId("Sportski dan za djecu", "Jutarnja smjena"), ShiftStatus.Approved, null, null, null, false, false, "Voditeljica jedne grupe."),
            new ShiftRegistrationSeed("sara@test.ba", ShiftId("Pozivni centar za donacije", "Popodnevna smjena"), ShiftStatus.Rejected, null, null, null, false, false, "Termin se preklapa sa drugim obavezama."),
            new ShiftRegistrationSeed("selma@test.ba", ShiftId("Posjeta domu za starije", "Jutarnja smjena"), ShiftStatus.Approved, null, null, null, false, false, "Iskustvo sa seniorima."),
            new ShiftRegistrationSeed("harun@test.ba", ShiftId("Radionica digitalne pismenosti", "Popodnevna smjena"), ShiftStatus.Registered, null, null, null, false, false, "Podrska prijavama i uredjajima."),
            new ShiftRegistrationSeed("ivana@test.ba", ShiftId("Sportski dan za djecu", "Popodnevna smjena"), ShiftStatus.Cancelled, null, null, null, false, false, "Korisnica povukla prijavu."),
            new ShiftRegistrationSeed("eman@test.ba", ShiftId("Besplatne instrukcije za ucenike", "Popodnevna smjena"), ShiftStatus.Approved, null, null, null, false, false, "Dodatna podrska ucenicima.")
        };

        foreach (var registration in registrations)
        {
            if (!usersByEmail.TryGetValue(registration.Email, out var userId))
            {
                continue;
            }

            if (await context.ShiftRegistrations.AnyAsync(r => r.UserId == userId && r.ShiftId == registration.ShiftId))
            {
                continue;
            }

            context.ShiftRegistrations.Add(new ShiftRegistration
            {
                UserId = userId,
                ShiftId = registration.ShiftId,
                Status = registration.Status,
                CheckInTime = registration.CheckInTime,
                CheckOutTime = registration.CheckOutTime,
                HoursWorked = registration.HoursWorked,
                IsSuspicious = registration.IsSuspicious,
                IsApproved = registration.IsApproved,
                Notes = registration.Notes,
                AdminNotes = registration.AdminNotes,
                ApprovedByUserId = registration.Status is ShiftStatus.Approved or ShiftStatus.Completed ? adminId : null,
                ApprovedAt = registration.Status is ShiftStatus.Approved or ShiftStatus.Completed ? DateTime.UtcNow.AddHours(-2) : null,
                RejectedByUserId = registration.Status == ShiftStatus.Rejected ? adminId : null,
                RejectedAt = registration.Status == ShiftStatus.Rejected ? DateTime.UtcNow.AddHours(-1) : null
            });
        }

        var completedShifts = shifts.Where(s => s.Event.Status == EventStatus.Completed).OrderBy(s => s.StartTime).ToList();
        var completedVolunteerEmails = new[] { "mobile@volunteerhub.ba", "tarik@test.ba", "amra@test.ba", "lejla@test.ba", "harun@test.ba" };
        foreach (var shift in completedShifts)
        {
            for (var index = 0; index < completedVolunteerEmails.Length; index++)
            {
                var email = completedVolunteerEmails[index];
                var userId = usersByEmail[email];
                if (await context.ShiftRegistrations.AnyAsync(r => r.UserId == userId && r.ShiftId == shift.Id))
                {
                    continue;
                }

                var checkIn = shift.StartTime.AddMinutes(index * 3);
                var checkOut = shift.EndTime.AddMinutes(-(index % 2 == 0 ? 0 : 10));
                var hours = Math.Round((checkOut - checkIn).TotalHours, 2);

                context.ShiftRegistrations.Add(new ShiftRegistration
                {
                    UserId = userId,
                    ShiftId = shift.Id,
                    Status = ShiftStatus.Completed,
                    CheckInTime = checkIn,
                    CheckOutTime = checkOut,
                    HoursWorked = hours,
                    IsApproved = true,
                    IsSuspicious = email == "harun@test.ba" && shift.Name == "Koordinacijska smjena",
                    Notes = "Seed historijski zapis za izvjestaje i leaderboard.",
                    AdminNotes = email == "harun@test.ba" && shift.Name == "Koordinacijska smjena"
                        ? "Sati odobreni uz dodatnu provjeru zbog odstupanja."
                        : "Automatski odobreno za seed podatke.",
                    ApprovedByUserId = adminId,
                    ApprovedAt = shift.EndTime.AddHours(4),
                    FinalApprovedByUserId = adminId,
                    FinalApprovedAt = shift.EndTime.AddHours(6)
                });
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task UpdateShiftOccupancyAsync(ApplicationDbContext context)
    {
        var shifts = await context.Shifts.ToListAsync();
        foreach (var shift in shifts)
        {
            shift.CurrentVolunteers = await context.ShiftRegistrations.CountAsync(r =>
                r.ShiftId == shift.Id &&
                r.Status != ShiftStatus.Rejected &&
                r.Status != ShiftStatus.Cancelled);
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedCampaignsAndDonationsAsync(ApplicationDbContext context)
    {
        var adminId = await context.Volunteers.Where(u => u.Role == UserRole.Admin).Select(u => u.Id).FirstAsync();
        var orgIds = await context.Organizations.ToDictionaryAsync(o => o.Name, o => o.Id);
        var campaigns = new[]
        {
            new Campaign
            {
                Title = "Pomoc za poplavljena podrucja",
                Description = "Prikupljanje sredstava za porodice pogodjene poplavama i sanaciju domova.",
                ImageUrl = GetCampaignImageUrl("Pomoc za poplavljena podrucja"),
                GoalAmount = 15000,
                CurrentAmount = 0,
                StartDate = DateTime.UtcNow.AddDays(-10),
                EndDate = DateTime.UtcNow.AddDays(30),
                IsActive = true,
                IsFeatured = true,
                OrganizationId = orgIds["Crveni Kriz Sarajevo"],
                CreatedByUserId = adminId
            },
            new Campaign
            {
                Title = "Skolski pribor za djecu",
                Description = "Podrska kupovini skolskog pribora za djecu iz socijalno osjetljivih porodica.",
                ImageUrl = GetCampaignImageUrl("Skolski pribor za djecu"),
                GoalAmount = 5000,
                CurrentAmount = 0,
                StartDate = DateTime.UtcNow.AddDays(-5),
                EndDate = DateTime.UtcNow.AddDays(45),
                IsActive = true,
                IsFeatured = true,
                OrganizationId = orgIds["Crveni Kriz Sarajevo"],
                CreatedByUserId = adminId
            },
            new Campaign
            {
                Title = "Azil za zivotinje Sarajevo",
                Description = "Hrana, veterinarski tretmani i podrska azilu kroz male i velike donacije.",
                ImageUrl = GetCampaignImageUrl("Azil za zivotinje Sarajevo"),
                GoalAmount = 3000,
                CurrentAmount = 0,
                StartDate = DateTime.UtcNow.AddDays(-3),
                EndDate = DateTime.UtcNow.AddDays(60),
                IsActive = true,
                OrganizationId = orgIds["Crveni Kriz Sarajevo"],
                CreatedByUserId = adminId
            },
            new Campaign
            {
                Title = "Digitalni kutak za seniore",
                Description = "Kupovina tableta, rutera i edukativnih materijala za radionice sa seniorima.",
                ImageUrl = GetCampaignImageUrl("Digitalni kutak za seniore"),
                GoalAmount = 4200,
                CurrentAmount = 0,
                StartDate = DateTime.UtcNow.AddDays(-2),
                EndDate = DateTime.UtcNow.AddDays(25),
                IsActive = true,
                OrganizationId = orgIds["Dom Novi Zivot"],
                CreatedByUserId = adminId
            },
            new Campaign
            {
                Title = "Sportska oprema za djecu",
                Description = "Nabavka lopti, markera i osnovne opreme za omladinske sportske dane.",
                ImageUrl = GetCampaignImageUrl("Sportska oprema za djecu"),
                GoalAmount = 3600,
                CurrentAmount = 0,
                StartDate = DateTime.UtcNow.AddDays(-1),
                EndDate = DateTime.UtcNow.AddDays(40),
                IsActive = true,
                OrganizationId = orgIds["Sport za sve Zenica"],
                CreatedByUserId = adminId
            },
            new Campaign
            {
                Title = "Zavrsena zimska kampanja",
                Description = "Historijski primjer zavrsene kampanje za pregled statusa i izvjestaja.",
                ImageUrl = GetCampaignImageUrl("Zavrsena zimska kampanja"),
                GoalAmount = 2500,
                CurrentAmount = 0,
                StartDate = DateTime.UtcNow.AddDays(-90),
                EndDate = DateTime.UtcNow.AddDays(-20),
                IsActive = false,
                OrganizationId = orgIds["Crveni Kriz Sarajevo"],
                CreatedByUserId = adminId
            }
        };

        foreach (var campaign in campaigns)
        {
            if (!await context.Campaigns.AnyAsync(c => c.Title == campaign.Title))
            {
                context.Campaigns.Add(campaign);
            }
        }

        await context.SaveChangesAsync();

        var campaignIds = await context.Campaigns.ToDictionaryAsync(c => c.Title, c => c.Id);
        var usersByEmail = await context.Volunteers.ToDictionaryAsync(u => u.Email, u => u.Id);
        var donations = new[]
        {
            new DonationSeed("mobile@volunteerhub.ba", "Pomoc za poplavljena podrucja", 60m, DonationStatus.Completed, false, "Sretno sa kampanjom!", "pi_seed_completed_001"),
            new DonationSeed("tarik@test.ba", "Pomoc za poplavljena podrucja", 100m, DonationStatus.Completed, false, "Zelim pomoci sto prije.", "pi_seed_completed_002"),
            new DonationSeed("amra@test.ba", "Skolski pribor za djecu", 75m, DonationStatus.Completed, false, "Za pocetak nove skolske godine.", "pi_seed_completed_003"),
            new DonationSeed("mirza@test.ba", "Azil za zivotinje Sarajevo", 40m, DonationStatus.Completed, true, "Drzim fige!", "pi_seed_completed_004"),
            new DonationSeed("lejla@test.ba", "Digitalni kutak za seniore", 90m, DonationStatus.Completed, false, "Bit ce ovo korisno seniorima.", "pi_seed_completed_005"),
            new DonationSeed("sara@test.ba", "Sportska oprema za djecu", 55m, DonationStatus.Completed, false, "Za djecu iz komsiluka.", "pi_seed_completed_006"),
            new DonationSeed("harun@test.ba", "Digitalni kutak za seniore", 35m, DonationStatus.Pending, false, "Cekam potvrdu banke.", "pi_seed_pending_001"),
            new DonationSeed("ivana@test.ba", "Azil za zivotinje Sarajevo", 25m, DonationStatus.Failed, false, "Probna transakcija koja je pala.", "pi_seed_failed_001"),
            new DonationSeed("selma@test.ba", "Zavrsena zimska kampanja", 50m, DonationStatus.Refunded, false, "Vracena uplata za historijski zapis.", "pi_seed_refunded_001"),
            new DonationSeed("eman@test.ba", "Skolski pribor za djecu", 120m, DonationStatus.Completed, false, "Dodatna podrska radionici i djeci.", "pi_seed_completed_007")
        };

        foreach (var donation in donations)
        {
            var userId = usersByEmail[donation.Email];
            var campaignId = campaignIds[donation.CampaignTitle];
            if (await context.Donations.AnyAsync(d => d.StripePaymentIntentId == donation.PaymentIntentId))
            {
                continue;
            }

            var user = await context.Volunteers.FindAsync(userId);
            if (user == null)
            {
                continue;
            }

            context.Donations.Add(new Donation
            {
                CampaignId = campaignId,
                UserId = donation.IsAnonymous ? null : userId,
                Amount = donation.Amount,
                Currency = "BAM",
                Status = donation.Status,
                DonorName = donation.IsAnonymous ? "Anonimni donor" : $"{user.FirstName} {user.LastName}",
                Message = donation.Message,
                IsAnonymous = donation.IsAnonymous,
                StripePaymentIntentId = donation.PaymentIntentId,
                StripeChargeId = donation.Status == DonationStatus.Completed ? $"ch_{donation.PaymentIntentId}" : null
            });
        }

        await context.SaveChangesAsync();
        await UpdateCampaignAmountsAsync(context);
    }

    private static async Task UpdateCampaignAmountsAsync(ApplicationDbContext context)
    {
        var campaigns = await context.Campaigns.Include(c => c.Donations).ToListAsync();
        foreach (var campaign in campaigns)
        {
            campaign.CurrentAmount = campaign.Donations
                .Where(d => d.Status == DonationStatus.Completed)
                .Sum(d => d.Amount);
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedBlogAsync(ApplicationDbContext context)
    {
        var adminId = await context.Volunteers.Where(u => u.Role == UserRole.Admin).Select(u => u.Id).FirstAsync();
        var orgIds = await context.Organizations.ToDictionaryAsync(o => o.Name, o => o.Id);
        var categories = await context.BlogCategories.ToDictionaryAsync(c => c.Name, c => c.Id);

        var posts = new[]
        {
            new BlogPostSeed("Dobrodosli na VolunteerHub", "VolunteerHub povezuje volontere sa organizacijama kroz dogadjaje, smjene, blog i donacije.", "Upoznajte platformu i njene glavne mogucnosti.", "uvod,volontiranje,zajednica", true, DateTime.UtcNow.AddDays(-12), null, "Novosti", "Crveni Kriz Sarajevo", 140),
            new BlogPostSeed("Kako se pripremiti za volontersku akciju", "Prije svake akcije provjerite detalje dogadjaja, potrebne vjestine i lokaciju, te dodjite na vrijeme.", "Prakticni savjeti za nove volontere.", "savjeti,volonteri,priprema", true, DateTime.UtcNow.AddDays(-6), null, "Savjeti", "Crveni Kriz Sarajevo", 96),
            new BlogPostSeed("Prica volonterke Lejle", "Lejlino iskustvo pokazuje kako se volontiranjem grade vjestine i dugorocne veze u zajednici.", "Iskustvo iz zajednice i motivacija za nove clanove.", "price,iskustva,zajednica", true, DateTime.UtcNow.AddDays(-3), null, "Price", "Sport za sve Zenica", 88),
            new BlogPostSeed("Kako izgleda transparentna donacijska kampanja", "Kampanja je uspjesna kada korisnici vide jasan cilj, rok, rezultate i trag svake uplate.", "Pregled najboljih praksi za kampanje i donacije.", "donacije,transparentnost,kampanje", true, DateTime.UtcNow.AddDays(-2), null, "Donacije", "Crveni Kriz Sarajevo", 72),
            new BlogPostSeed("Intervju sa koordinatorom radionice", "Koordinator iz Tuzle dijeli kako planira raspored, materijale i feedback volontera.", "Iza scene edukativnih dogadjaja.", "intervju,edukacija,organizacija", false, null, DateTime.UtcNow.AddDays(3), "Intervjui", "Centar za mlade Tuzla", 0),
            new BlogPostSeed("Novi plan jesenje sadnje", "Objava je pripremljena kao draft i ceka finalnu potvrdu termina i partnera.", "Draft objava za jesenju akciju.", "okolis,draft,sadnja", false, null, null, "Novosti", "Eko Akcija Mostar", 0)
        };

        foreach (var post in posts)
        {
            if (!await context.BlogPosts.AnyAsync(p => p.Title == post.Title))
            {
                context.BlogPosts.Add(new BlogPost
                {
                    Title = post.Title,
                    Content = post.Content,
                    Summary = post.Summary,
                    ImageUrl = GetBlogImageUrl(post.Title),
                    Tags = post.Tags,
                    IsPublished = post.IsPublished,
                    PublishedAt = post.PublishedAt,
                    ScheduledPublishAt = post.ScheduledPublishAt,
                    BlogCategoryId = categories[post.CategoryName],
                    OrganizationId = orgIds[post.OrganizationName],
                    AuthorId = adminId,
                    ViewCount = post.ViewCount
                });
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedNotificationsAsync(ApplicationDbContext context)
    {
        var usersByEmail = await context.Volunteers.ToDictionaryAsync(u => u.Email, u => u.Id);
        var eventIds = await context.Events.ToDictionaryAsync(e => e.Title, e => e.Id);
        var campaignIds = await context.Campaigns.ToDictionaryAsync(c => c.Title, c => c.Id);
        var shifts = await context.Shifts.Include(s => s.Event).ToListAsync();

        var notifications = new[]
        {
            new NotificationSeed("mobile@volunteerhub.ba", "Dobrodosli", "Prijavljeni ste na VolunteerHub. Istrazi preporucene dogadjaje, smjene i kampanje.", NotificationType.General, false, null, null, null),
            new NotificationSeed("mobile@volunteerhub.ba", "Prijava na dogadjaj evidentirana", "Tvoja prijava za Besplatne instrukcije za ucenike je uspjesno evidentirana.", NotificationType.EventRegistration, false, "Besplatne instrukcije za ucenike", null, null),
            new NotificationSeed("mobile@volunteerhub.ba", "Smjena odobrena", "Koordinator je odobrio tvoje ucestvovanje u Pozivnom centru za donacije.", NotificationType.ShiftApproved, false, "Pozivni centar za donacije", "Jutarnja smjena", null),
            new NotificationSeed("mobile@volunteerhub.ba", "Podsjetnik za smjenu", "Smjena pocinje uskoro. Dodji 10 minuta ranije radi prijave.", NotificationType.ShiftReminder, false, "Ciscenje rijeke Miljacke", "Jutarnja smjena", null),
            new NotificationSeed("mobile@volunteerhub.ba", "Nova kampanja", "Otvorena je kampanja Digitalni kutak za seniore.", NotificationType.DonationReceived, true, null, null, "Digitalni kutak za seniore"),
            new NotificationSeed("tarik@test.ba", "Nova radionica", "Otvoren je novi termin radionice digitalne pismenosti.", NotificationType.NewEvent, false, "Radionica digitalne pismenosti", null, null),
            new NotificationSeed("amra@test.ba", "Prijava na smjenu ceka pregled", "Administrator ce uskoro pregledati tvoju prijavu za pakete pomoci.", NotificationType.ShiftRegistration, false, "Sortiranje prehrambenih paketa", "Jutarnja smjena", null),
            new NotificationSeed("lejla@test.ba", "Hvala na doprinosu", "Tvoje prethodne smjene su finalno odobrene i usle su u leaderboard.", NotificationType.ShiftCheckOut, true, "Proljetno ciscenje grada", "Popodnevna smjena", null)
        };

        foreach (var notification in notifications)
        {
            var userId = usersByEmail[notification.Email];
            var eventId = notification.EventTitle != null && eventIds.TryGetValue(notification.EventTitle, out var resolvedEventId)
                ? resolvedEventId
                : (int?)null;
            var shiftId = notification.EventTitle != null && notification.ShiftName != null
                ? shifts.FirstOrDefault(s => s.Event.Title == notification.EventTitle && s.Name == notification.ShiftName)?.Id
                : null;
            var campaignId = notification.CampaignTitle != null && campaignIds.TryGetValue(notification.CampaignTitle, out var resolvedCampaignId)
                ? resolvedCampaignId
                : (int?)null;

            if (!await context.Notifications.AnyAsync(n => n.UserId == userId && n.Title == notification.Title && n.Message == notification.Message))
            {
                context.Notifications.Add(new Notification
                {
                    UserId = userId,
                    Title = notification.Title,
                    Message = notification.Message,
                    Type = notification.Type,
                    IsRead = notification.IsRead,
                    ReadAt = notification.IsRead ? DateTime.UtcNow.AddHours(-4) : null,
                    EventId = eventId,
                    ShiftId = shiftId,
                    CampaignId = campaignId
                });
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedRecommendationsAsync(ApplicationDbContext context)
    {
        var volunteers = await context.Volunteers
            .Where(v => v.Role == UserRole.Volunteer)
            .OrderBy(v => v.Id)
            .Take(6)
            .ToListAsync();

        var recommendedEvents = await context.Events
            .Where(e => e.Status == EventStatus.Published && e.StartDate > DateTime.UtcNow)
            .OrderByDescending(e => e.IsFeatured)
            .ThenBy(e => e.StartDate)
            .Take(4)
            .ToListAsync();

        foreach (var volunteer in volunteers)
        {
            if (await context.EventRecommendations.AnyAsync(r => r.UserId == volunteer.Id))
            {
                continue;
            }

            var userSkills = await context.UserSkills
                .Where(us => us.UserId == volunteer.Id)
                .Include(us => us.Skill)
                .Select(us => us.Skill.Name)
                .Take(3)
                .ToListAsync();

            for (var index = 0; index < recommendedEvents.Count; index++)
            {
                var evt = recommendedEvents[index];
                context.EventRecommendations.Add(new EventRecommendation
                {
                    UserId = volunteer.Id,
                    EventId = evt.Id,
                    Score = Math.Round(0.95 - (index * 0.12), 2),
                    ReasonTags = userSkills.Count > 0
                        ? $"Odgovara tvojim vjestinama: {string.Join(", ", userSkills)}"
                        : "Popularan i aktuelan dogadjaj u tvojoj regiji",
                    CalculatedAt = DateTime.UtcNow.AddHours(-1),
                    IsViewed = index == 0
                });
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task SeedVolunteerHistoryAsync(ApplicationDbContext context)
    {
        var eventRegistrations = await context.EventRegistrations.Include(r => r.Event).ToListAsync();
        foreach (var registration in eventRegistrations)
        {
            if (!await context.VolunteerHistories.AnyAsync(h =>
                    h.UserId == registration.UserId &&
                    h.EventId == registration.EventId &&
                    h.ActionType == "EventRegistration"))
            {
                context.VolunteerHistories.Add(new VolunteerHistory
                {
                    UserId = registration.UserId,
                    EventId = registration.EventId,
                    ActionType = "EventRegistration",
                    Description = $"Korisnik se prijavio na dogadjaj {registration.Event.Title}.",
                    OccurredAt = registration.RegisteredAt
                });
            }
        }

        var shiftRegistrations = await context.ShiftRegistrations
            .Include(r => r.Shift)
            .ThenInclude(s => s.Event)
            .ToListAsync();

        foreach (var shiftRegistration in shiftRegistrations)
        {
            if (!await context.VolunteerHistories.AnyAsync(h =>
                    h.UserId == shiftRegistration.UserId &&
                    h.ShiftId == shiftRegistration.ShiftId &&
                    h.ActionType == "ShiftProgress"))
            {
                var statusText = shiftRegistration.Status switch
                {
                    ShiftStatus.Completed => "zavrsio smjenu",
                    ShiftStatus.Rejected => "dobio odbijanje smjene",
                    ShiftStatus.Cancelled => "otkazao smjenu",
                    _ => "azurirao status smjene"
                };

                context.VolunteerHistories.Add(new VolunteerHistory
                {
                    UserId = shiftRegistration.UserId,
                    ShiftId = shiftRegistration.ShiftId,
                    EventId = shiftRegistration.Shift.EventId,
                    ActionType = "ShiftProgress",
                    Description = $"Korisnik je {statusText} za dogadjaj {shiftRegistration.Shift.Event.Title}.",
                    OccurredAt = shiftRegistration.CheckOutTime ?? shiftRegistration.CheckInTime ?? shiftRegistration.CreatedAt
                });
            }
        }

        var donations = await context.Donations.ToListAsync();
        foreach (var donation in donations.Where(d => d.UserId.HasValue))
        {
            if (!await context.VolunteerHistories.AnyAsync(h =>
                    h.UserId == donation.UserId &&
                    h.CampaignId == donation.CampaignId &&
                    h.ActionType == "Donation"))
            {
                context.VolunteerHistories.Add(new VolunteerHistory
                {
                    UserId = donation.UserId!.Value,
                    CampaignId = donation.CampaignId,
                    ActionType = "Donation",
                    Description = $"Korisnik je evidentirao donaciju od {donation.Amount:0.##} {donation.Currency}.",
                    OccurredAt = donation.CreatedAt
                });
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task RebuildLeaderboardAsync(ApplicationDbContext context)
    {
        var volunteers = await context.Volunteers
            .Where(v => v.Role == UserRole.Volunteer)
            .OrderBy(v => v.Id)
            .ToListAsync();

        var registrations = await context.ShiftRegistrations
            .Include(r => r.Shift)
            .ToListAsync();

        var existingEntries = await context.LeaderboardEntries.ToListAsync();
        context.LeaderboardEntries.RemoveRange(existingEntries);

        var leaderboard = volunteers
            .Select(volunteer =>
            {
                var userRegistrations = registrations
                    .Where(r => r.UserId == volunteer.Id && r.IsApproved && r.Status == ShiftStatus.Completed)
                    .ToList();

                var totalHours = Math.Round(userRegistrations.Sum(r => r.HoursWorked ?? 0), 2);
                var totalShifts = userRegistrations.Count;
                var totalEvents = userRegistrations
                    .Select(r => r.Shift.EventId)
                    .Distinct()
                    .Count();

                return new LeaderboardEntry
                {
                    UserId = volunteer.Id,
                    TotalHours = totalHours,
                    TotalEvents = totalEvents,
                    TotalShifts = totalShifts,
                    Points = (int)Math.Round(totalHours * 10) + (totalEvents * 25),
                    Rank = 0
                };
            })
            .OrderByDescending(entry => entry.TotalHours)
            .ThenByDescending(entry => entry.TotalEvents)
            .ThenBy(entry => entry.UserId)
            .ToList();

        for (var index = 0; index < leaderboard.Count; index++)
        {
            leaderboard[index].Rank = index + 1;
        }

        await context.LeaderboardEntries.AddRangeAsync(leaderboard);
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
            if (string.IsNullOrWhiteSpace(user.ProfileImageUrl))
            {
                user.ProfileImageUrl = GetUserAvatarUrl(user.Email ?? $"{user.FirstName}-{user.LastName}-{user.Id}");
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task ApplyOrganizationImagesAsync(ApplicationDbContext context)
    {
        var organizations = await context.Organizations.ToListAsync();
        foreach (var organization in organizations)
        {
            if (string.IsNullOrWhiteSpace(organization.LogoUrl))
            {
                organization.LogoUrl = GetOrganizationLogoUrl(organization.Name);
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task ApplyEventImagesAsync(ApplicationDbContext context)
    {
        var events = await context.Events.ToListAsync();
        foreach (var evt in events)
        {
            if (string.IsNullOrWhiteSpace(evt.ImageUrl))
            {
                evt.ImageUrl = GetEventImageUrl(evt.Title);
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task ApplyCampaignImagesAsync(ApplicationDbContext context)
    {
        var campaigns = await context.Campaigns.ToListAsync();
        foreach (var campaign in campaigns)
        {
            if (string.IsNullOrWhiteSpace(campaign.ImageUrl))
            {
                campaign.ImageUrl = GetCampaignImageUrl(campaign.Title);
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task ApplyBlogImagesAsync(ApplicationDbContext context)
    {
        var posts = await context.BlogPosts.ToListAsync();
        foreach (var post in posts)
        {
            if (string.IsNullOrWhiteSpace(post.ImageUrl))
            {
                post.ImageUrl = GetBlogImageUrl(post.Title);
            }
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

    private sealed record EventSeed(
        string Title,
        string Description,
        string Requirements,
        string Location,
        double Latitude,
        double Longitude,
        int MaxVolunteers,
        EventStatus Status,
        bool IsFeatured,
        string CategoryName,
        string CityName,
        string OrganizationName,
        DateTime StartDate,
        DateTime EndDate);

    private sealed record ShiftSeed(
        string Name,
        string Description,
        DateTime StartTime,
        DateTime EndTime,
        int MaxVolunteers,
        bool IsLocked);

    private sealed record EventRegistrationSeed(
        string Email,
        string EventTitle,
        string Status,
        string Notes);

    private sealed record ShiftRegistrationSeed(
        string Email,
        int ShiftId,
        ShiftStatus Status,
        DateTime? CheckInTime,
        DateTime? CheckOutTime,
        double? HoursWorked,
        bool IsSuspicious,
        bool IsApproved,
        string Notes,
        string? AdminNotes = null);

    private sealed record DonationSeed(
        string Email,
        string CampaignTitle,
        decimal Amount,
        DonationStatus Status,
        bool IsAnonymous,
        string Message,
        string PaymentIntentId);

    private sealed record BlogPostSeed(
        string Title,
        string Content,
        string Summary,
        string Tags,
        bool IsPublished,
        DateTime? PublishedAt,
        DateTime? ScheduledPublishAt,
        string CategoryName,
        string OrganizationName,
        int ViewCount);

    private sealed record NotificationSeed(
        string Email,
        string Title,
        string Message,
        NotificationType Type,
        bool IsRead,
        string? EventTitle,
        string? ShiftName,
        string? CampaignTitle);
}

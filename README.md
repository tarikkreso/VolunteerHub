# VolunteerHub

Platforma za upravljanje volonterima ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â seminarski rad iz predmeta **Razvoj softvera II**.

**Student:** Tarik Kreso  
**Broj indeksa:** IB220193  
**Akademska godina:** 2025/26

---

## O projektu

VolunteerHub je platforma koja olakÃƒâ€¦Ã‚Â¡ava pronalazak, prijavu i praÃƒâ€žÃ¢â‚¬Â¡enje volonterskih aktivnosti. Sistem omoguÃƒâ€žÃ¢â‚¬Â¡ava volonterima brzo pretraÃƒâ€¦Ã‚Â¾ivanje dogaÃƒâ€žÃ¢â‚¬Ëœaja, upravljanje smjenama i donacije, dok organizacijama pruÃƒâ€¦Ã‚Â¾a admin panel za planiranje i izvjeÃƒâ€¦Ã‚Â¡tavanje.

### KljuÃƒâ€žÃ‚Âne funkcionalnosti

- **Upravljanje dogaÃƒâ€žÃ¢â‚¬Ëœajima i smjenama** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â kreiranje, ureÃƒâ€žÃ¢â‚¬Ëœivanje, brisanje
- **Check-in / Check-out** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â praÃƒâ€žÃ¢â‚¬Â¡enje radnih sati volontera u realnom vremenu
- **Odobravanje sati** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â admin pregled i odobravanje / odbijanje prijavljenih sati
- **Donacijske kampanje** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Stripe integracija za online donacije
- **Blog** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â objava i pregled edukativnog sadrÃƒâ€¦Ã‚Â¾aja
- **Rang lista (Leaderboard)** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â rangiranje volontera prema odobrenim satima
- **Notifikacije** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â obavjeÃƒâ€¦Ã‚Â¡tenja putem RabbitMQ ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ Worker ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ MailHog
- **Sistem vjeÃƒâ€¦Ã‚Â¡tina** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â korisnici mogu dodavati vjeÃƒâ€¦Ã‚Â¡tine za bolji matching sa dogaÃƒâ€žÃ¢â‚¬Ëœajima

---

## Arhitektura

Projekat koristi **mikroservisnu arhitekturu** sa 5 Docker servisa:

```
VolunteerHub/
ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ backend/                          # .NET 8 rjeÃƒâ€¦Ã‚Â¡enje (Clean Architecture)
ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡   ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬ÂÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ src/
ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡       ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ VolunteerHub.API/         # REST API servis (port 7000)
ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡       ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ VolunteerHub.Worker/      # RabbitMQ consumer (email, logging)
ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡       ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ VolunteerHub.Application/ # Interfejsi servisa, DTOs, validatori
ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡       ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ VolunteerHub.Infrastructure/ # EF Core, implementacije servisa
ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡       ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ VolunteerHub.Domain/      # Entiteti, enumeracije
ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡       ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬ÂÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ VolunteerHub.Shared/      # ZajedniÃƒâ€žÃ‚Âke klase
ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ desktop/                          # Flutter desktop admin panel (Windows)
ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡   ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬ÂÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ volunteer_hub_desktop/
ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ mobile/                           # Flutter mobilna aplikacija (Android/iOS)
ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬Å¡   ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬ÂÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ volunteer_hub_mobile/
ÃƒÂ¢Ã¢â‚¬ÂÃ…â€œÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ docker-compose.yml                # Orkestracija svih servisa
ÃƒÂ¢Ã¢â‚¬ÂÃ¢â‚¬ÂÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ÃƒÂ¢Ã¢â‚¬ÂÃ¢â€šÂ¬ README.md
```

### Docker servisi

| Servis | Port | Opis |
|--------|------|------|
| **sqlserver** | 1433 | SQL Server 2022 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â baza `220193` |
| **rabbitmq** | 5672 / 15672 | Message broker + Management UI |
| **volunteerhub-api** | 7000 | REST API (.NET 8) |
| **volunteerhub-worker** | ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â | Background servis (email notifikacije) |
| **mailhog** | 1025 / 8025 | SMTP catcher + Web UI za pregled emailova |

---

## Tehnologije

### Backend
- **.NET 8.0** / C#
- **Entity Framework Core 8** (Code First + migracije)
- **SQL Server 2022**
- **RabbitMQ** (inter-service komunikacija)
- **MailKit** (slanje emailova)
- **BCrypt.Net** (hashiranje lozinki)
- **JWT Bearer** autentifikacija
- **Swagger / OpenAPI** dokumentacija

### Desktop (Admin panel)
- **Flutter** (Windows)
- **Provider** (state management)
- **Dio** (HTTP client)
- **fl_chart** (grafovi i dijagrami)
- **data_table_2** (tabele sa sortiranjem)
- **window_manager** (upravljanje prozorom)

### Mobile (Volonterska aplikacija)
- **Flutter** (Android / iOS)
- **Provider** (state management)
- **Dio** (HTTP client)
- **flutter_map + OpenStreetMap** (mapa dogaÃƒâ€žÃ¢â‚¬Ëœaja)
- **table_calendar** (kalendar smjena)
- **flutter_stripe** (Stripe plaÃƒâ€žÃ¢â‚¬Â¡anja)
- **cached_network_image** (uÃƒâ€žÃ‚Âitavanje slika)

---

## Baza podataka

Baza **220193** sadrÃƒâ€¦Ã‚Â¾i 12+ tabela sa referencijalnim integritetom:

| Tabela | Opis |
|--------|------|
| Users | Volonteri i administratori |
| Events | Volonterski dogaÃƒâ€žÃ¢â‚¬Ëœaji |
| Shifts | Smjene unutar dogaÃƒâ€žÃ¢â‚¬Ëœaja |
| ShiftRegistrations | Prijave volontera na smjene (check-in/out, odobreni sati) |
| Campaigns | Donacijske kampanje |
| Donations | PojedinaÃƒâ€žÃ‚Âne donacije |
| BlogPosts | Blog sadrÃƒâ€¦Ã‚Â¾aj |
| Skills | Katalog vjeÃƒâ€¦Ã‚Â¡tina |
| UserSkills | VjeÃƒâ€¦Ã‚Â¡tine korisnika (nivo, iskustvo) |
| Notifications | Notifikacije korisnika |
| EventRecommendations | AI preporuke za korisnike |
| LeaderboardEntries | Rang lista po odobrenim satima |
| Categories | Kategorije dogaÃƒâ€žÃ¢â‚¬Ëœaja |
| Cities | Gradovi |
| Countries | DrÃƒâ€¦Ã‚Â¾ave |

---

## Korisnici za testiranje

### Desktop aplikacija (Admin)
| KorisniÃƒâ€žÃ‚Âko ime | Lozinka | Uloga |
|----------------|---------|-------|
| `desktop` | `test` | Admin |

### Mobilna aplikacija (Volonter)
| KorisniÃƒâ€žÃ‚Âko ime | Lozinka | Uloga |
|----------------|---------|-------|
| `mobile` | `test` | Volunteer |

### Dodatni testni korisnici
| Email | Lozinka | Uloga |
|-------|---------|-------|
| tarik@test.ba | test | Volunteer |
| amra@test.ba | test | Volunteer |
| mirza@test.ba | test | Volunteer |
| lejla@test.ba | test | Volunteer |

---

## Pokretanje projekta

### Preduvjeti
- **Docker** & **Docker Compose**
- **.NET 8 SDK** (za lokalni razvoj)
- **Flutter 3.x** (stable channel)
- **7-Zip (CLI `7z`)** za password + split ZIP arhive za predaju

### 0. Priprema konfiguracije (`.env` i `env.zip`)

```bash
# Prvi setup (kreira .env iz .env.example ako ne postoji)
./scripts/setup.bat
```

Nakon sto podesis vrijednosti u `.env`, za predaju pripremi password-protected `env.zip`:

```bash
powershell -ExecutionPolicy Bypass -File ./scripts/create-env-zip.ps1 -Password "<your-password>"
```


### 1. Docker Compose (preporuÃƒâ€žÃ‚Âeno)

```bash
# Klonirajte repozitorij
git clone https://github.com/your-username/VolunteerHub.git
cd VolunteerHub

# Ako .env ne postoji
./scripts/setup.bat

# Pokrenite sve servise
docker-compose up -d

# Provjerite da li su servisi aktivni
docker-compose ps
```

Nakon pokretanja:
- **API + Swagger:** http://localhost:7000/swagger
- **RabbitMQ Management:** http://localhost:15672 (credentials from `.env`)
- **MailHog Web UI:** http://localhost:8025

### Testiranje RabbitMQ-a, worker servisa i obavijesti

Najbrzi dokaz da sistem radi je ovaj tok:

1. Pokreni `docker-compose up -d`.
2. Prijavi se u aplikaciju ili otvori Swagger.
3. Izazovi jedan od dogadjaja:
   - `POST /api/auth/forgot-password`
   - `POST /api/eventregistrations`
   - `POST /api/shiftregistrations/register/{shiftId}`
   - `PUT /api/shiftregistrations/{id}/approve`
   - `PUT /api/shiftregistrations/{id}/reject`
   - `POST /api/donations`
4. Provjeri rezultat:
   - poruka se pojavi u RabbitMQ queue-u
   - worker je obradi u pozadini
   - email stigne u MailHog
   - za korisnicke tokove se pojavi nova stavka u `/api/notifications`

> Baza se automatski kreira i puni test podacima putem `DatabaseSeeder` pri prvom pokretanju API-ja.

### 2. Lokalno pokretanje (development)

```bash
# Backend API
cd backend
dotnet restore
cd src/VolunteerHub.API
dotnet run

# Worker servis (u zasebnom terminalu)
cd backend/src/VolunteerHub.Worker
dotnet run
```

```bash
# Flutter Desktop (Admin)
cd desktop/volunteer_hub_desktop
flutter pub get
flutter run -d windows --dart-define=API_URL=http://localhost:7000/api

# Flutter Mobile (Volonter)
cd mobile/volunteer_hub_mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:7000/api
```

> Za Android emulator koristite `10.0.2.2` umjesto `localhost`.  
> Za fiziÃƒâ€žÃ‚Âki ureÃƒâ€žÃ¢â‚¬Ëœaj koristite IP adresu raÃƒâ€žÃ‚Âunara u lokalnoj mreÃƒâ€¦Ã‚Â¾i.

---

## Build za predaju

```bash
# Build oba klijenta sa trazenim API_URL vrijednostima
powershell -ExecutionPolicy Bypass -File ./scripts/build-release.ps1
```

Izlazni fajlovi:
- APK: `mobile/volunteer_hub_mobile/build/app/outputs/flutter-apk/app-release.apk`
- Windows: `desktop/volunteer_hub_desktop/build/windows/x64/runner/Release/`

Kreiranje split arhive za GitHub (default 90MB segmenti):

```bash
powershell -ExecutionPolicy Bypass -File ./scripts/package-builds.ps1
```

Skripta generise `fit-build-gg-mm-dd.zip` + `.z01/.z02/...` segmente zasticene lozinkom koju sami odaberete.
Ako koristis 7-Zip CLI, split segmenti su obicno `fit-build-gg-mm-dd.zip.001`, `...zip.002`, itd.

---

## Upute za predaju (RSII)

1. Commitovati kompletan source code (backend + desktop + mobile).
2. Commitovati build artefakte kroz `fit-build-gg-mm-dd.zip` (i sve split dijelove: `.z01/.z02/...` ili `.zip.001/.zip.002/...` zavisno od alata).
3. Commitovati dokumentaciju recommender sistema kao `recommender-dokumentacija.pdf`.
4. Postaviti samo link GitHub repozitorija na DL (sekcija zadaci).
5. Android build testirati sa API adresom `10.0.2.2`, a Windows sa `localhost`.
6. Konfiguraciju drzati u repozitoriju kroz `.env.example` + `env.zip`.

Template dokumenta za recommender je u fajlu `recommender-dokumentacija.md`.

---

## Konfiguracija

Svi konfiguracijski podaci su u config fajlovima ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â **niÃƒâ€¦Ã‚Â¡ta nije hardkodirano**:

### Backend (`appsettings.json`)
| Sekcija | Opis |
|---------|------|
| `ConnectionStrings:DefaultConnection` | SQL Server connection string |
| `Jwt:Key`, `Jwt:Issuer`, `Jwt:Audience` | JWT autentifikacija |
| `RabbitMQ:Host`, `Port`, `Username`, `Password` | Message broker |
| `Smtp:Host`, `Port`, `UseSsl`, `FromEmail` | Email (MailHog) |
| `Stripe:SecretKey`, `PublishableKey` | Stripe plaÃƒâ€žÃ¢â‚¬Â¡anja |

### Flutter (`--dart-define`)
```bash
flutter run --dart-define=API_URL=http://localhost:7000/api
```

---

## API Endpoints

| Endpoint | Metode | Opis |
|----------|--------|------|
| `/api/auth/login` | POST | Prijava (JWT token) |
| `/api/auth/register` | POST | Registracija |
| `/api/auth/forgot-password` | POST | Slanje tokena za reset lozinke |
| `/api/auth/reset-password` | POST | Reset lozinke pomoÃƒâ€žÃ¢â‚¬Â¡u tokena |
| `/api/auth/me` | GET | Trenutni korisnik |
| `/api/events` | GET, POST, PUT, DELETE | Upravljanje dogaÃƒâ€žÃ¢â‚¬Ëœajima |
| `/api/shifts` | GET, POST, PUT, DELETE | Upravljanje smjenama |
| `/api/shiftregistrations` | GET, POST, PUT | Prijave na smjene, check-in/out, approve/reject |
| `/api/campaigns` | GET, POST, PUT, DELETE | Donacijske kampanje |
| `/api/donations` | GET, POST | Donacije |
| `/api/users` | GET, PUT | Korisnici |
| `/api/userskills` | GET, POST, DELETE, PUT | VjeÃƒâ€¦Ã‚Â¡tine korisnika |
| `/api/leaderboard` | GET | Rang lista |
| `/api/blogposts` | GET, POST, PUT, DELETE | Blog |
| `/api/notifications` | GET, PUT | Notifikacije |
| `/api/dashboard/stats` | GET | Dashboard statistika |
| `/api/categories` | GET, POST, PUT, DELETE | Kategorije |
| `/api/cities` | GET, POST, PUT, DELETE | Gradovi |
| `/api/countries` | GET, POST, PUT, DELETE | DrÃƒâ€¦Ã‚Â¾ave |
| `/api/skills` | GET, POST, PUT, DELETE | VjeÃƒâ€¦Ã‚Â¡tine (katalog) |

Kompletna Swagger dokumentacija: http://localhost:7000/swagger

---

## Ekrani

### Desktop (Admin panel)
1. **Login** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â prijava administratora
2. **Dashboard** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â statistika (dogaÃƒâ€žÃ¢â‚¬Ëœaji, volonteri, smjene, sati)
3. **DogaÃƒâ€žÃ¢â‚¬Ëœaji** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â CRUD za dogaÃƒâ€žÃ¢â‚¬Ëœaje sa smjenama
4. **Smjene** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â upravljanje smjenama, odobravanje sati, final approval
5. **Volonteri** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â pregled i pretraga volontera, vjeÃƒâ€¦Ã‚Â¡tine, historija
6. **Kampanje** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â upravljanje donacijskim kampanjama
7. **Blog** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â kreiranje i ureÃƒâ€žÃ¢â‚¬Ëœivanje blog postova
8. **IzvjeÃƒâ€¦Ã‚Â¡taji** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â grafovi (bar chart, pie chart), leaderboard tabela

### Mobile (Volonter)
1. **PoÃƒâ€žÃ‚Âetna** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â pregled statistike, preporuÃƒâ€žÃ‚Âeni dogaÃƒâ€žÃ¢â‚¬Ëœaji, kampanje, blog
2. **DogaÃƒâ€žÃ¢â‚¬Ëœaji** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â pretraga i filtriranje, detalji dogaÃƒâ€žÃ¢â‚¬Ëœaja, prijava na smjene
3. **Smjene** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â aktivni timer, check-in/out, nadolazeÃƒâ€žÃ¢â‚¬Â¡e i zavrÃƒâ€¦Ã‚Â¡ene smjene
4. **Donacije** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â kampanje sa progressom, doniranje (Stripe)
5. **Profil** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â statistika, upravljanje vjeÃƒâ€¦Ã‚Â¡tinama, leaderboard, odjava
6. **Blog** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â pregled blog postova sa cijelim Ãƒâ€žÃ‚Âlankom

---

## Licenca

Seminarski rad ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Fakultet informacijskih tehnologija, Mostar

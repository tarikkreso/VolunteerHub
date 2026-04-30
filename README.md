# VolunteerHub

Platforma za upravljanje volonterima i organizacijama, uradjena kao seminarski rad iz predmeta **Razvoj softvera II**.

**Student:** Tarik Kreso  
**Broj indeksa:** IB220193  
**Akademska godina:** 2025/26

## O projektu

VolunteerHub povezuje volontere sa organizacijama kroz:

- pretragu i pregled dogadjaja
- prijavu na smjene i pracenje sati
- odobravanje i finalizaciju sati u desktop admin panelu
- blog i edukativni sadrzaj
- donacijske kampanje sa Stripe integracijom
- notifikacije preko RabbitMQ i Worker servisa
- preporuke dogadjaja na osnovu korisnickih vjestina i aktivnosti

## Tehnologije

### Backend
- .NET 8 / ASP.NET Core Web API
- Entity Framework Core 8
- SQL Server 2022
- ASP.NET Identity + JWT
- RabbitMQ
- Stripe
- ML.NET

### Desktop
- Flutter Windows
- Provider
- Dio
- fl_chart

### Mobile
- Flutter Android
- Provider
- Dio
- flutter_map
- flutter_stripe

## Arhitektura

Projekat koristi vise servisa kroz `docker-compose.yml`:

- `sqlserver` - baza `220193`
- `rabbitmq` - message broker
- `volunteerhub-api` - glavni REST API
- `volunteerhub-worker` - background worker / consumer
- `mailhog` - pregled email poruka u development i test scenariju

## Seed podaci

Baza se pri prvom pokretanju automatski migrira i puni test podacima kroz `DatabaseSeeder`.

Seed ukljucuje:

- 10+ korisnika sa razlicitim ulogama i gradovima
- vise organizacija
- vise dogadjaja u statusima `Draft`, `Published`, `Cancelled`, `Completed`
- vise smjena i prijava sa statusima `Registered`, `Pending`, `Approved`, `Rejected`, `Completed`, `Cancelled`
- vise kampanja i donacija sa razlicitim statusima
- blog kategorije i vise objava
- notifikacije
- leaderboard podatke
- preporuke dogadjaja
- volunteer history podatke za izvjestaje

To znaci da su dashboard, izvjestaji, mobile ekran historije, leaderboard, donacije i preporuke odmah testabilni na cistoj masini.

## Test korisnici

### Desktop admin
- Username: `desktop`
- Password: `test`

### Mobile volunteer
- Username: `mobile`
- Password: `test`

### Dodatni korisnici
- `superadmin` / `test`
- `tarik` / `test`
- `amra` / `test`
- `mirza` / `test`
- `lejla` / `test`
- `sara` / `test`
- `eman` / `test`
- `adnan` / `test`
- `selma` / `test`
- `harun` / `test`
- `ivana` / `test`

## Pokretanje preko Dockera

### Preduvjeti
- Docker Desktop
- Docker Compose

### 1. Priprema `.env`

Ako `.env` ne postoji:

```powershell
.\scripts\setup.bat
```

Repo sadrzi i `.env.example`.

Ako pravis `env.zip`, koristi vlastitu lozinku:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\create-env-zip.ps1 -Password "<your-password>"
```

### 2. Pokretanje sistema

```powershell
docker compose up --build
```

Nakon pokretanja:

- Swagger: [http://localhost:7000/swagger](http://localhost:7000/swagger)
- RabbitMQ UI: [http://localhost:15672](http://localhost:15672)
- MailHog UI: [http://localhost:8025](http://localhost:8025)

## Lokalno pokretanje bez Dockera

### Backend API

```powershell
cd backend
dotnet restore
cd src\VolunteerHub.API
dotnet run
```

### Worker

```powershell
cd backend\src\VolunteerHub.Worker
dotnet run
```

### Desktop

```powershell
cd desktop\volunteer_hub_desktop
flutter pub get
flutter run -d windows --dart-define=API_URL=http://localhost:7000/api
```

### Mobile

```powershell
cd mobile\volunteer_hub_mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:7000/api
```

Za Android emulator koristi se `10.0.2.2`, a za Windows `localhost`.



## API i funkcionalni pregled

Glavne cjeline:

- `/api/auth`
- `/api/events`
- `/api/shifts`
- `/api/shiftregistrations`
- `/api/eventregistrations`
- `/api/campaigns`
- `/api/donations`
- `/api/blogposts`
- `/api/notifications`
- `/api/leaderboard`
- `/api/dashboard`
- `/api/reports`
- `/api/cities`, `/api/countries`, `/api/skills`, `/api/blogcategories`

Swagger dokumentacija je dostupna na:

- [http://localhost:7000/swagger](http://localhost:7000/swagger)

## Minimalna provjera prije predaje

- `docker compose up --build` prodje bez izmjene koda
- Swagger login radi
- desktop login radi
- mobile login radi
- protected endpoint bez tokena vraca `401`
- admin endpoint sa volunteer korisnikom vraca `403`
- PDF report export radi
- payment ne moze biti evidentiran dva puta za isti payment intent
- notification mark-as-read radi
- recommended events vracaju explanation i reason

## Napomena

`recommender-dokumentacija.pdf` je finalni dokument za predaju recommender dijela.  
`.env` ne treba commitovati; za predaju koristiti `.env.example` i po potrebi `env.zip` ako ga asistenti ili profesor traze po pravilima kursa.

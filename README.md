# VolunteerHub 🚀

VolunteerHub is a comprehensive volunteer and organization management platform. The system consists of a mobile application for volunteers, a desktop administration panel, a primary REST API service, a background worker service for asynchronous message processing, a RabbitMQ message broker, and a SQL Server database.

**Student:** Tarik Kreso  
**Student ID (Index):** IB220193  
**Academic Year:** 2025/26  

---

## 📋 Table of Contents
1. [Technology Stack](#-technology-stack)
2. [System Architecture](#-system-architecture)
3. [Database & Seeding](#-database--seeding)
4. [Testing Credentials (Access)](#-testing-credentials-access)
5. [Configuration (.env)](#-configuration-env)
6. [Running the System](#-running-the-system)
   - [Running via Docker (Recommended)](#1-running-via-docker-recommended)
   - [Running Locally without Docker](#2-running-locally-without-docker)
7. [API & Swagger Documentation](#-api--swagger-documentation)
8. [AI Recommendation System (Recommender)](#-ai-recommendation-system-recommender)
9. [Build and Release Instructions](#-build-and-release-instructions)

---

## 🛠 Technology Stack

### Backend & Worker
* **Framework:** .NET 8 / ASP.NET Core Web API
* **Database Access:** Entity Framework Core 8 (Code First approach)
* **Database:** Microsoft SQL Server 2022
* **Authentication:** ASP.NET Identity + JWT (JSON Web Tokens)
* **Message Broker:** RabbitMQ (inter-service communication)
* **AI/Recommendations:** ML.NET (Logistic Regression + TF-IDF)
* **Payments:** Stripe API integration (in-app Sandbox payments)
* **Mailing:** MailHog (SMTP testing server in development environments)

### Desktop Application
* **Framework:** Flutter (Windows Desktop)
* **State Management:** Provider
* **Networking:** Dio HTTP client
* **Charts:** fl_chart

### Mobile Application
* **Framework:** Flutter (Android)
* **State Management:** Provider
* **Networking:** Dio HTTP client
* **Maps:** flutter_map (OpenStreetMap integration)
* **Payments:** flutter_stripe (Stripe SDK integration)

---

## 🏛 System Architecture

The system implements a **microservices-based architecture** through the following components defined in [docker-compose.yml](file:///c:/Users/Tarik%20K/Documents/VolonteerHub/docker-compose.yml):

1. **Main REST API (`volunteerhub-api`):** Handles all CRUD operations, authentication, Stripe transaction verifications, AI recommendations, and publishes messages to RabbitMQ.
2. **Worker Service (`volunteerhub-worker`):** A separate background service (container) that consumes messages from RabbitMQ to asynchronously send email notifications, log activities, and perform background processing tasks.
3. **RabbitMQ (`rabbitmq`):** Message broker for asynchronous and reliable communication between the API and the Worker service.
4. **SQL Server Database (`sqlserver`):** SQL Server instance hosting the database named `220193`.
5. **MailHog (`mailhog`):** SMTP server mock and Web UI for inspecting outgoing email notifications (accessible on web port `8025`).

---

## 🗄 Database & Seeding

The database is named **`220193`**. The system utilizes Entity Framework Core Code First migrations. Upon initial startup, the database is automatically created, schema migrations are applied, and the database is populated with comprehensive test data via `DatabaseSeeder`.

The database contains **10+ core tables** (excluding lookup/reference tables such as `Cities`, `Countries`, `Categories`, and standard ASP.NET Identity tables) with enforced referential integrity (foreign keys):
1. **Users/Volunteers** (User profiles, roles, and demographic details)
2. **Events** (Volunteer opportunities and activities)
3. **Shifts** (Time slots defined within events)
4. **ShiftVolunteers** (Junction table tracking shift registrations, check-in/out times, and approved working hours)
5. **Skills** (Volunteer skills used for the AI recommendation system)
6. **UserSkills** (Many-to-many relationship mapping volunteers to skills)
7. **Campaigns** (Fundraising campaigns)
8. **Donations** (Donation records mapped to Stripe transaction IDs)
9. **BlogPosts** (Community and informative blog posts)
10. **EventRegistrations** (Junction tracking user registrations to events)
11. **VolunteerHistory** (Audit logs of volunteer activity for PDF report generation)
12. **Notifications** (System and user-level notifications)

---

## 🔑 Testing Credentials (Access)

All testing accounts use the password **`test`**.

| Role / Context | Username | Password | Description |
| :--- | :--- | :--- | :--- |
| **Desktop Admin** | `desktop` | `test` | Main administrator account for the desktop panel |
| **Mobile Volunteer** | `mobile` | `test` | Regular volunteer account for the mobile application |
| **Super Admin** | `superadmin` | `test` | High-privilege administrator account |
| **Volunteers** | `tarik`, `amra`, `mirza`, `lejla`, `sara`, `eman` | `test` | Seeded volunteers with pre-configured skills and history |

---

## ⚙ Configuration (.env)

Configuration is entirely centralized. All application parameters (database connection strings, Stripe API keys, JWT secret keys, RabbitMQ credentials, and SMTP settings) are loaded from environmental variables and are not hardcoded.

An environmental template is provided in the root directory: [.env.example](file:///c:/Users/Tarik%20K/Documents/VolonteerHub/.env.example).  
To run the system, copy `.env.example` to `.env` in the same directory and fill in your Stripe API keys, database credentials, and other secrets.

---

## 🚀 Running the System

### 1. Running via Docker (Recommended)
All backend components (API, Worker, SQL Server, RabbitMQ, MailHog) can be launched using a single command:

```powershell
docker compose up --build
```

Once the containers start up and pass their health checks, the services will be accessible at:
* **Glavni REST API (Swagger):** [http://localhost:7000/swagger](http://localhost:7000/swagger)
* **RabbitMQ Management UI:** [http://localhost:15672](http://localhost:15672)
* **MailHog Web UI:** [http://localhost:8025](http://localhost:8025)

---

### 2. Running Locally without Docker

#### Step A: Run the REST API
```powershell
cd backend
dotnet restore
dotnet run --project src/VolunteerHub.API
```
*The API will be available at [http://localhost:7000](http://localhost:7000)*

#### Step B: Run the Worker Service
```powershell
cd backend
dotnet run --project src/VolunteerHub.Worker
```

#### Step C: Run the Desktop Application (Flutter)
```powershell
cd desktop/volunteer_hub_desktop
flutter pub get
flutter run -d windows --dart-define=API_URL=http://localhost:7000/api
```

#### Step D: Run the Mobile Application (Flutter Android)
```powershell
cd mobile/volunteer_hub_mobile
flutter pub get
flutter run --dart-define=API_URL=http://10.0.2.2:7000/api
```
*Note: `10.0.2.2` is the standard alias to host loopback interface in Android Emulator AVDs. Use `localhost` or `127.0.0.1` for desktop/local testing.*

---

## 📡 API & Swagger Documentation

Swagger UI provides interactive API exploration and testing endpoints. It can be accessed at:
🔗 **[http://localhost:7000/swagger](http://localhost:7000/swagger)**

Key Endpoints:
* `POST /api/auth/login` & `POST /api/auth/register` — User authentication and signup
* `GET /api/events` — Query and search events using filtering criteria
* `GET /api/events/recommended` — Retrieve personalized event recommendations for the current volunteer
* `POST /api/shifts` — Create shift schedules inside events (Admin)
* `POST /api/shiftregistrations` — Sign up for shifts, check-in/out, and approve hours
* `POST /api/donations` — Log donations and verify Stripe payments via Webhook
* `GET /api/reports/volunteer-hours` — Export PDF reports of volunteer hours

---

## 🧠 AI Recommendation System (Recommender)

VolunteerHub features an AI-driven **Content-Based Filtering** recommendation model powered by the **ML.NET** framework.
The recommendation engine matches volunteer skills (`UserSkills`) with descriptions, requirements, and tags of active events using **TF-IDF** vectorization and a **Logistic Regression** classifier.

* **Model Training:** Automatically runs every 24 hours in the background via `RecommendationTrainingService` and saves the updated model file to `recommendation.zip`.
* **Explainable Recommendations:** The mobile app displays recommendations alongside clear reasons (e.g., *"Recommended because it matches your skills: First Aid, Communication"*).
* **Fallback Strategy:** If there are fewer than 10 training samples (required for ML.NET training), the system falls back to keyword-based relevance scoring to ensure recommendations remain active.

For detailed design specifications, view **recommender-dokumentacija.md**
---

## 📦 Build and Release Instructions

### 1. Build Mobile Application (Android APK)
```powershell
cd mobile/volunteer_hub_mobile
flutter clean
flutter build apk --release
```
*The resulting APK file is compiled to: `build/app/outputs/flutter-apk/app-release.apk`*

### 2. Build Desktop Application (Windows Executable)
```powershell
cd desktop/volunteer_hub_desktop
flutter clean
flutter build windows --release
```
*The compiled binary folder is built to: `build/windows/x64/runner/Release/`*

### 3. Packaging and Releases
For production deployment, bundle the executable files (Android APK and Windows Desktop `Release` directory) into a `.zip` archive to be attached to your release tags in the GitHub Releases section.

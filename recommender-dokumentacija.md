# Recommender dokumentacija - VolunteerHub

## 1. Opis implementacije recommender sistema

VolunteerHub koristi content-based recommender implementiran u ASP.NET Core backendu preko ML.NET-a. Sistem poredi profil korisnika sa aktivnim dogadjajima i vraca personalizovane preporuke za mobilnu aplikaciju.

Primarni model:
- Tehnologija: ML.NET
- Pipeline: `FeaturizeText` za korisnicke i event tekstualne atribute, `Concatenate("Features")`, zatim `SdcaLogisticRegression`
- Ulazni korisnicki signali: `UserSkills`
- Ulazni event signali: kategorija, naslov, opis, zahtjevi, lokacija i organizacija
- Pozitivni primjeri: korisnik je registrovan na smjenu dogadjaja
- Negativni primjeri: dogadjaji na koje se korisnik nije registrovao
- Output: score/probability i tekstualno objasnjenje preporuke

Fallback logika:
- Ako model jos nije istreniran ili nema dovoljno podataka, `RecommendationService` koristi keyword-based scoring.
- Fallback i dalje koristi stvarne podatke iz baze: vjestine korisnika, kategorije, naslov/opis dogadjaja, featured flag i isti grad.
- Ako korisnik nema vjestine, vracaju se istaknuti/najnoviji aktivni dogadjaji.

## 2. Putanja glavne logike recommender sistema

Glavni fajlovi:
- `backend/src/VolunteerHub.Infrastructure/ML/RecommendationTrainingService.cs`
- `backend/src/VolunteerHub.Infrastructure/ML/RecommendationModels.cs`
- `backend/src/VolunteerHub.Infrastructure/Services/RecommendationService.cs`
- `backend/src/VolunteerHub.API/Controllers/EventsController.cs`

Trening se registruje kroz dependency injection i pokrece se periodicki svakih 24 sata. Model se snima na putanju:

`AppContext.BaseDirectory/ml_model/recommendation.zip`

Endpoint za mobilnu aplikaciju:

`GET /api/events/recommended?top=5`

Endpoint cita korisnika iz JWT tokena, ne iz query parametra.

![Screenshot koda glavne logike](/images/code.png)


## 3. Putanja UI ekrana gdje se prikazuju preporuke

Mobilna aplikacija prikazuje preporuke u:

- `mobile/volunteer_hub_mobile/lib/screens/home/home_screen.dart`
- `mobile/volunteer_hub_mobile/lib/screens/events/events_tab.dart`
- `mobile/volunteer_hub_mobile/lib/services/api_service.dart`

Kartice prikazuju dogadjaj, score i `reasonTags`, npr. "Odgovara tvojim vjestinama: Prva pomoc, IT vjestine".
![Screenshot preporuka u aplikaciji](/images/app1.png)
![Screenshot preporuka u aplikaciji](/images/app2.png)


## 4. Testni korisnici za evaluaciju

Preporuceni testni login:

- Mobile korisnik: `mobile` / `test`
- Dodatni volonteri: `tarik@test.ba`, `amra@test.ba`, `mirza@test.ba`, `lejla@test.ba` / `test`

Za kvalitetan prikaz preporuka korisnik mora imati povezane vjestine u tabeli `UserSkills`, a baza mora imati objavljene dogadjaje i smjene. Seed podaci se kreiraju kroz `DatabaseSeeder`.

## 5. Kako testirati

1. Pokrenuti `docker compose up --build`.
2. Prijaviti se kao `mobile` / `test`.
3. Pozvati `GET /api/events/recommended?top=5` sa JWT tokenom.
4. Provjeriti da response sadrzi:
   - `event`
   - `score`
   - `reasonTags`
5. U mobilnoj aplikaciji otvoriti pocetnu ili Events ekran i provjeriti da se prikazuju preporucene kartice sa objasnjenjem.

## 6. Ogranicenja

- Ako nema najmanje 10 trening primjera, ML model se ne trenira i koristi se fallback scoring.
- Model je content-based i ne koristi collaborative filtering.

## 7. Zakljucak

Implementacija odgovara prijavljenom zahtjevu: koristi ML.NET, TF-IDF tekstualne atribute, logisticku regresiju, periodican trening i API response sa objasnjenjem preporuke.

# MediCare HMS — Flutter client

A Flutter app for the ASP.NET Core **Hospital Management System API**
(JWT auth, roles: `Admin` / `Doctor` / `Patient`). Covers every endpoint
in your backend's README: auth, doctor browsing/profile, patient
profile, booking, status updates, and prescriptions.

## What's included

This zip contains the **`lib/` source, `pubspec.yaml`, and
`analysis_options.yaml`** for a Flutter app — not a full platform-scaffolded
project (no `android/`, `ios/`, `web/` folders), since those are generated
by the Flutter SDK, which isn't available in the environment that produced
this code. Three steps turn it into a runnable project:

```bash
# 1. Create a fresh Flutter project shell
flutter create hospital_mgmt_app
cd hospital_mgmt_app

# 2. Replace the generated lib/, pubspec.yaml and analysis_options.yaml
#    with the ones from this zip (overwrite the defaults)

# 3. Install packages
flutter pub get
```

Then run it:
```bash
flutter run --dart-define=API_BASE_URL=https://<your-api-host>:<port>
```

## Pointing the app at your API

`lib/core/constants.dart` reads the base URL from a compile-time define,
falling back to `https://10.0.2.2:5001` (the Android-emulator alias for
your host machine's `localhost`, matching `dotnet run`'s default HTTPS
port).

| Running on | Use |
|---|---|
| Android emulator, API on host via `dotnet run` | `https://10.0.2.2:5001` (default, no flag needed) |
| iOS simulator | `flutter run --dart-define=API_BASE_URL=https://localhost:5001` |
| Physical device | `flutter run --dart-define=API_BASE_URL=https://<your-LAN-IP>:5001` |
| Deployed API | `flutter run --dart-define=API_BASE_URL=https://your-domain.com` |

## About the API's self-signed dev certificate

`dotnet run` serves HTTPS with a local ASP.NET Core dev certificate that
mobile OSes don't trust by default, so requests will fail TLS validation
on a real device or simulator until you do one of:

- **Trust the dev cert** on your machine/emulator: `dotnet dev-certs https --trust`,
  then (Android) install/trust it on the emulator's certificate store.
- **Run the API over plain HTTP for local testing** by removing/commenting
  `app.UseHttpsRedirection()` in `Program.cs` and pointing
  `API_BASE_URL` at `http://...` instead — fine for a dev loop, not for
  production.
- **Deploy behind real TLS** (a reverse proxy or hosting platform with a
  proper certificate) — the cleanest option once you're past local dev.

Don't ship a build that disables certificate validation in code; use one
of the options above instead.

## Architecture

- **`core/`** — `ApiClient` (thin `http` wrapper: attaches the JWT, decodes
  JSON, maps error bodies to `ApiException`), `TokenStorage` (JWT +
  session persisted via `flutter_secure_storage`), `constants.dart`
  (all endpoint URLs, role/status enums, specialization list).
- **`models/`** — plain Dart classes mirroring the API's DTOs
  (`Doctor`, `Patient`, `Appointment`, `Prescription`, `AuthResponse`).
- **`providers/`** — `ChangeNotifier`s per resource (`AuthProvider`,
  `DoctorProvider`, `PatientProvider`, `AppointmentProvider`), each
  wrapping the matching controller's endpoints.
- **`screens/`** — `auth/` (login, register with role-aware fields),
  `patient/`, `doctor/`, `admin/` (one dashboard + tabs per role), and
  `shared/appointment_detail_screen.dart` (status updates + prescriptions,
  UI adapts to the logged-in role exactly like the backend's authorization
  rules).
- **`AuthGate`** (`screens/auth_gate.dart`) — restores a persisted session
  on launch and routes to the login screen or the correct role dashboard.

## Role coverage

- **Patient** — browse/filter doctors by specialization, book an
  appointment, view "My appointments", cancel a pending/confirmed one,
  view prescriptions, edit own profile.
- **Doctor** — view own schedule (filterable by status), confirm/complete/
  cancel appointments, add prescriptions, edit own profile (specialization,
  fee, experience, availability window).
- **Admin** — overview stats, every appointment (with status override),
  full doctor and patient directories. (Admin accounts aren't self-registrable
  per your backend's design — provision one directly in the DB as your
  README describes, then log in here with those credentials.)

## Known gaps / next steps

- No token refresh — sessions expire after the backend's configured
  `Jwt:ExpiryMinutes` (180 by default) and the user is bounced to login.
  Wire a refresh-token endpoint into `AuthProvider` if you add one later.
- A 401 mid-session (rather than at login) surfaces as an error banner
  rather than auto-redirecting to login — straightforward to add by having
  `ApiClient` notify `AuthProvider` on a 401.
- No client-side pagination; `GET /api/appointments` and `/api/patients`
  are fetched in full, matching the backend's current (non-paginated)
  responses.

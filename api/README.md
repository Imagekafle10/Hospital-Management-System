# Hospital Management System — Backend API

ASP.NET Core 8 Web API for a hospital system with **Doctors** and **Patients**.
Data access is **raw ADO.NET** (`Microsoft.Data.SqlClient`) with parameterized SQL — no EF Core, no ORM.

## Stack
- ASP.NET Core 8 Web API
- SQL Server (raw `SqlCommand` / `SqlDataReader`, hand-written queries)
- JWT authentication, 3 roles: `Admin`, `Doctor`, `Patient`
- BCrypt password hashing
- Swagger UI for testing

## Setup

### 1. Create the database
Run `SqlScripts/schema.sql` against your SQL Server instance (SSMS, Azure Data Studio, or `sqlcmd`):
```
sqlcmd -S localhost -U sa -P YourStrong@Passw0rd -i SqlScripts/schema.sql
```
This creates the `HospitalMgmtDb` database and all tables (`Users`, `Doctors`, `Patients`, `Appointments`, `Prescriptions`, `MedicalRecords`). If your database already exists from before, just re-run the script — every `CREATE TABLE` is guarded with `IF OBJECT_ID(...) IS NULL`, so it only adds the new `MedicalRecords` table.

### 2. Configure connection & JWT secret
Edit `appsettings.json`:
- `ConnectionStrings:DefaultConnection` — point at your SQL Server
- `Jwt:Key` — replace with a long random secret (32+ characters) before running for real

### 3. Restore & run
```
cd HospitalMgmtSystem
dotnet restore
dotnet run
```
Swagger UI opens at `https://localhost:<port>/swagger` where you can try every endpoint.

## How the pieces fit together
- **Models/** — plain C# classes matching the SQL tables
- **Repositories/** — all raw SQL lives here (one repo per table), each method opens a `SqlConnection`, builds a parameterized `SqlCommand`, and maps `SqlDataReader` rows to models by hand
- **Data/SqlConnectionFactory.cs** — creates `SqlConnection` instances from the connection string
- **Services/TokenService.cs** — issues JWTs on login/register
- **Controllers/** — HTTP endpoints, authorization rules per role
- **DTOs/** — request/response shapes (keeps raw models decoupled from the API surface)

## Key endpoints

| Method | Route | Who | Purpose |
|---|---|---|---|
| POST | `/api/auth/register` | Anyone | Register as Doctor or Patient |
| POST | `/api/auth/login` | Anyone | Log in, get JWT |
| GET | `/api/doctors` | Any logged-in user | Browse doctors (filter by `?specialization=`) |
| GET | `/api/doctors/me` | Doctor | View own profile |
| PUT | `/api/doctors/me` | Doctor | Update own profile (fee, specialization, availability) |
| GET | `/api/patients/me` | Patient | View own profile |
| PUT | `/api/patients/me` | Patient | Update own profile |
| GET | `/api/patients` | Admin, Doctor | List all patients |
| POST | `/api/appointments` | Patient | Book an appointment with a doctor |
| GET | `/api/appointments/mine` | Patient / Doctor | My appointments (role-aware) |
| GET | `/api/appointments` | Admin | All appointments |
| PUT | `/api/appointments/{id}/status` | Doctor / Patient / Admin | Confirm, complete, or cancel |
| POST | `/api/appointments/{id}/prescriptions` | Doctor | Add a prescription |
| GET | `/api/appointments/{id}/prescriptions` | Patient / Doctor / Admin (involved parties only) | View prescriptions |
| POST | `/api/medicalrecords` | Patient (own) / Doctor / Admin | Upload a medical record or lab report (`multipart/form-data`) |
| GET | `/api/medicalrecords/mine` | Patient | List my own records |
| GET | `/api/medicalrecords/patient/{patientId}` | Patient (own) / Doctor (their patients) / Admin | List a patient's records |
| GET | `/api/medicalrecords/{id}` | Involved parties only | Record metadata |
| GET | `/api/medicalrecords/{id}/download` | Involved parties only | Download the underlying file |
| DELETE | `/api/medicalrecords/{id}` | Uploader / Admin | Delete a record and its file |

Every protected route expects: `Authorization: Bearer <token>`

### Uploading a medical record
`POST /api/medicalrecords` expects `multipart/form-data` with fields: `RecordType` (`LabReport`, `Prescription`, `Diagnosis`, `Imaging`, `Other`), `Title`, optional `Description`, optional `AppointmentId`, `PatientId` (required when a Doctor/Admin uploads on behalf of a patient — ignored for Patients, who can only upload their own), and `File` (the actual file — pdf/jpg/jpeg/png/doc/docx, 20 MB default limit, configurable via `FileStorage:MaxFileSizeMb`). Files are stored on disk under `FileStorage:MedicalRecordsPath` (default `App_Data/medical-records`) with a randomized file name; the original file name and content type are kept in the DB for downloads.

### In-patient management (Wards / Beds / Admissions)

| Method | Route | Who | Purpose |
|---|---|---|---|
| POST | `/api/wards` | Admin | Create a ward |
| GET | `/api/wards` | Admin, Doctor | List wards with live bed counts |
| GET | `/api/wards/{id}` | Admin, Doctor | Ward detail |
| PUT | `/api/wards/{id}` | Admin | Update a ward |
| DELETE | `/api/wards/{id}` | Admin | Delete a ward (must have no beds) |
| POST | `/api/wards/{wardId}/beds` | Admin | Add a bed to a ward |
| GET | `/api/wards/{wardId}/beds` | Admin, Doctor | List a ward's beds |
| GET | `/api/beds?status=Available` | Admin, Doctor | List/filter beds across all wards |
| PUT | `/api/beds/{id}/status` | Admin | Manually mark a bed `Available`/`Maintenance` |
| DELETE | `/api/beds/{id}` | Admin | Delete a bed (must not be occupied) |
| POST | `/api/admissions` | Doctor / Admin | Admit a patient into a bed |
| GET | `/api/admissions/{id}` | Involved parties only | Admission detail |
| GET | `/api/admissions/active` | Admin, Doctor | Everyone currently admitted |
| GET | `/api/admissions/mine` | Patient | My own admission history |
| GET | `/api/admissions/patient/{patientId}` | Admin, Doctor | A patient's admission history |
| PUT | `/api/admissions/{id}/discharge` | Admitting Doctor / Admin | Discharge and free the bed |
| PUT | `/api/admissions/{id}/transfer-bed` | Admitting Doctor / Admin | Move the patient to a different bed |

Occupying/freeing a bed is never done directly — it only happens as a side effect of admit/discharge/transfer, each wrapped in a DB transaction so a bed can't be double-booked under concurrent requests. A Doctor is recorded as their own admitting doctor; an Admin must pass `AdmittingDoctorId` explicitly.

> While wiring this in, `Program.cs` was missing the DI registrations for `IPaymentRepository`, `IEsewaService`, and `IKhaltiService` (the Payments controller would have thrown at startup), and `SqlScripts/schema.sql` had no `Payments` table even though the payment code expects one. Both are fixed now — re-run `schema.sql` to pick up the `Payments` table alongside the new `Wards`/`Beds`/`Admissions` ones.

### Pharmacy (medicines, stock, dispensing)

Run `SqlScripts/migration_pharmacy.sql` (or re-run `schema.sql`) to add `Medicines` and `PharmacyDispenses`.

| Method | Route | Who | Purpose |
|---|---|---|---|
| POST | `/api/pharmacy/medicines` | Admin | Add a medicine with opening stock |
| GET | `/api/pharmacy/medicines?search=&category=&lowStock=true&expiring=true` | Admin, Doctor | Browse stock; filter low stock / expired or expiring within 90 days |
| GET | `/api/pharmacy/medicines/{id}` | Admin, Doctor | Medicine detail |
| PUT | `/api/pharmacy/medicines/{id}` | Admin | Update price, reorder level, expiry, active flag, etc. |
| POST | `/api/pharmacy/medicines/{id}/restock` | Admin | Add stock (+qty) or write off (-qty); never below 0 |
| DELETE | `/api/pharmacy/medicines/{id}` | Admin | Delete (only if never dispensed; otherwise mark inactive) |
| POST | `/api/pharmacy/dispense` | Admin | Dispense to a patient (optionally linked to a `PrescriptionId`) |
| GET | `/api/pharmacy/dispenses` | Admin | All dispensing history (`?patientId=&medicineId=`) |
| GET | `/api/pharmacy/dispenses/mine` | Patient | My own dispensed medicines |

Dispensing runs in one DB transaction with a row lock: it checks the medicine is active, not expired and in stock, decrements stock, and records the sale (price snapshot) so concurrent dispenses can't oversell.

## Creating an Admin account
There's no public "register as Admin" endpoint on purpose. Insert one directly after hashing a password with BCrypt, e.g. via a small one-off script or by temporarily allowing `"Admin"` in `RegisterDto.Role` during initial setup, then locking it back down.

## Notes on the raw-SQL approach
- All queries use parameterized `SqlCommand.Parameters` — never string concatenation — to prevent SQL injection.
- Doctor/Patient tables store only role-specific fields; shared identity (name, email, phone) lives in `Users` and is joined in.
- `Appointments.Status` is constrained at the DB level (`CHECK` constraint) and re-validated in the controller.
- If you outgrow hand-written mapping code, consider adding **Dapper** later — it keeps raw SQL but removes the manual `SqlDataReader` mapping boilerplate. Not included here since you asked for a pure raw-SQL/ADO.NET approach.



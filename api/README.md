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
This creates the `HospitalMgmtDb` database and all tables (`Users`, `Doctors`, `Patients`, `Appointments`, `Prescriptions`).

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

Every protected route expects: `Authorization: Bearer <token>`

## Creating an Admin account
There's no public "register as Admin" endpoint on purpose. Insert one directly after hashing a password with BCrypt, e.g. via a small one-off script or by temporarily allowing `"Admin"` in `RegisterDto.Role` during initial setup, then locking it back down.

## Notes on the raw-SQL approach
- All queries use parameterized `SqlCommand.Parameters` — never string concatenation — to prevent SQL injection.
- Doctor/Patient tables store only role-specific fields; shared identity (name, email, phone) lives in `Users` and is joined in.
- `Appointments.Status` is constrained at the DB level (`CHECK` constraint) and re-validated in the controller.
- If you outgrow hand-written mapping code, consider adding **Dapper** later — it keeps raw SQL but removes the manual `SqlDataReader` mapping boilerplate. Not included here since you asked for a pure raw-SQL/ADO.NET approach.



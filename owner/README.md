# Swasthya Hospital Panel (React + TypeScript + Redux Toolkit)

One web app, two panels — the sidebar and routes depend on the logged-in role:

- **Admin** — Dashboard, Patients, Doctors, Staff & Pharmacists (CRUD + activate/deactivate + password reset),
  Appointments (change status), Wards & Beds, Admissions (admit/discharge), Payments (collect COD),
  plus the full Pharmacy screens.
- **Pharmacist** — Dashboard, Medicines & Stock (CRUD, restock/write-off), Dispense (with the patient's prescriptions), Dispense History.

## Run
```
npm install
cp .env.example .env     # VITE_API_URL = your API, e.g. http://192.168.18.201:5000
npm run dev              # http://localhost:5173
```

## Backend steps (once)
1. Run `SqlScripts/migration_pharmacy.sql` and `SqlScripts/migration_admin_pharmacist.sql` in SSMS.
2. Create the first Admin (see main README), then create Pharmacist accounts from **Admin → Staff & Pharmacists**.
3. Start the API: `dotnet run --urls http://0.0.0.0:5000` (CORS is already open).

## Structure
- `src/api/client.ts` fetch wrapper (JWT header, readable errors, auto-logout on 401)
- `src/api/thunk.ts` `makeThunk` = `createAsyncThunk` with string rejections
- `src/features/*Slice.ts` auth, users (patients/doctors/staff/stats), hospital (appointments/wards/beds/admissions/payments), pharmacy
- `src/pages/*` one file per screen, `src/components/*` Layout + shared UI

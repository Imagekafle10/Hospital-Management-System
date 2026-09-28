# MediCare HMS — Flutter app, new functionality

This zip contains your updated `lib/` folder with the previously-unused parts
of your backend API (Admissions, Wards/Beds, Medical Records, Payments) now
wired into the Doctor and Patient roles. Admin was intentionally left
untouched, per your request.

## 1. Add two dependencies

These screens need two packages that weren't in your project before. Add
them to `pubspec.yaml` (versions are a starting point — `flutter pub outdated`
if you want the latest):

```yaml
dependencies:
  file_picker: ^8.0.0
  url_launcher: ^6.2.0
```

Then run `flutter pub get`.

## 2. Drop in the folder

Replace your existing `lib/` folder with the one in this zip (or merge file
by file if you've made local changes since you exported it).

## 3. What's new

### Doctor
- **Admissions tab** — see every currently-admitted patient, discharge them,
  or transfer them to another bed. A `+` button opens **Admit patient**,
  which lets you pick a patient, pick from the currently-available beds
  (across all wards), give a reason, and optionally set an expected
  discharge date.
- **Records tab** — search/pick one of your patients, then view and upload
  medical records (lab reports, prescriptions, diagnoses, imaging, other)
  for them, with delete support.
- **Appointment detail** now shows a Payment section: if a patient paid by
  Cash on Delivery, you can mark it as collected at the counter.

### Patient
- **Records tab** — view your own medical records and upload new ones
  (PDF/JPG/PNG/DOC), with delete support.
- **Payments tab** — history of everything you've paid for appointments.
- **Appointment detail** now lets you pay the consultation fee via eSewa,
  Khalti, or Cash on Delivery. eSewa/Khalti open the gateway checkout page
  in the browser via `url_launcher`; COD just confirms you'll pay at the
  counter.
- **My hospital stays** — a new icon on the Profile screen opens your full
  admission/discharge history, including doctor notes and discharge
  summaries.

## 4. New files

```
lib/core/constants.dart          (extended: admissions/wards/beds/records/payments endpoints)
lib/core/api_client.dart         (extended: delete(), postMultipart())
lib/models/admission.dart
lib/models/ward.dart
lib/models/bed.dart
lib/models/medical_record.dart
lib/models/payment.dart
lib/providers/admission_provider.dart
lib/providers/ward_bed_provider.dart
lib/providers/medical_record_provider.dart
lib/providers/payment_provider.dart
lib/screens/doctor/admissions_screen.dart
lib/screens/doctor/admit_patient_screen.dart
lib/screens/doctor/patients_records_screen.dart
lib/screens/doctor/patient_medical_records_screen.dart
lib/screens/patient/medical_records_screen.dart
lib/screens/patient/payments_screen.dart
lib/screens/patient/my_admissions_screen.dart
lib/screens/shared/medical_record_upload_sheet.dart
lib/widgets/medical_record_tile.dart
```

Plus small edits to `main.dart` (new providers registered),
`doctor_dashboard.dart` and `patient_dashboard.dart` (new nav tabs), and
`screens/shared/appointment_detail_screen.dart` (payment section added).

## 5. Known limitations (kept out to stay fast)

- Medical record **download/preview** isn't wired up in the UI yet — records
  show metadata only (title, type, size, date). The backend endpoint
  (`GET /api/medicalrecords/{id}/download`) is ready whenever you want to
  add it (needs a bearer-token-aware download, e.g. via `http` + a share/
  save package).
- Khalti's `pidx` return-flow (`POST /api/payments/khalti/verify`) isn't
  called automatically after the browser redirects back — for a production
  build you'd want a deep link or a WebView to catch that redirect and call
  it, then refresh the payment status.
- Ward/Bed management screens (create/edit wards & beds) were left out since
  those endpoints are Admin-only and you asked to skip Admin.

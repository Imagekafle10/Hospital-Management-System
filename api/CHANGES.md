# Follow-up + suggest medicine (doctor panel)
1. RUN `SqlScripts/migration_followup.sql` in SSMS (adds Appointments.FollowUpRequired / FollowUpDate / FollowUpNotes).
2. New endpoint: PUT /api/appointments/{id}/followup  { required, date, notes }  (Doctor only, appointment must be Completed). Appointment JSON now includes followUpRequired/followUpDate/followUpNotes.
3. Flutter (appointment detail): after a doctor marks the checkup Completed, a "Follow-up if required" sheet opens; the card stays editable for the doctor and read-only for the patient.
4. "Suggest medicine": search the pharmacy catalog (GET /api/pharmacy/medicines) or type any name, then save as a prescription.

# Admin + Pharmacy panel (React) added
1. RUN `SqlScripts/migration_admin_pharmacist.sql` (adds the Pharmacist role) after `migration_pharmacy.sql`.
2. New backend: Controllers/AdminController.cs (stats, create/update/delete users, edit doctor/patient profiles); Pharmacist can use /api/pharmacy/* and list patients; GET /api/pharmacy/prescriptions/patient/{id}.
3. New web app in `hms-panel/` (see its README): `npm install && npm run dev`.

## Pharmacy module added
1. RUN `SqlScripts/migration_pharmacy.sql` in SSMS (creates Medicines + PharmacyDispenses).
2. New: Models/Medicine.cs, DTOs/PharmacyDtos.cs, Repositories/PharmacyRepository.cs, Controllers/PharmacyController.cs; DI registered in Program.cs.
3. Endpoints under /api/pharmacy/* (see README "Pharmacy").

# What changed

## Backend (DTOs.zip -> HospitalMgmtSystem)
1. RUN `SqlScripts/migration_photo_and_attachments.sql` in SSMS first (adds Doctors.PhotoFileName + AppointmentRecords table).
2. Doctor photo: POST /api/doctors/me/photo (multipart field "Photo"), GET /api/doctors/{id}/photo (public).
3. Booking: POST /api/appointments now accepts "recordIds": [..]; GET /api/appointments/{id}/records lists them.

## Flutter (lib.zip)
- Register as Doctor -> photo is required (uploaded right after the account is created).
- Doctor Profile -> tap "Change photo".
- Doctor photos show in doctor list, booking page, admin list.
- Book appointment -> tick previous reports or "Upload new"; doctor/patient see them under "Attached reports" in the appointment.
- ApiClient now shows "Cannot reach the server at <url>" instead of a raw error.
- constants.dart: set `_pcLanIp` to your PC's IP (ipconfig).

## Connection checklist (if app still can't connect)
1. Start API with:  dotnet run --urls http://0.0.0.0:5000      (launchSettings.json overrides appsettings "Urls", usually to localhost only)
2. Windows Firewall:  netsh advfirewall firewall add rule name="HMS API" dir=in action=allow protocol=TCP localport=5000
3. Android: in android/app/src/main/AndroidManifest.xml add on <application>:  android:usesCleartextTraffic="true"
   and above it:  <uses-permission android:name="android.permission.INTERNET"/>
4. Test from the PHONE browser: http://<PC-IP>:5000/swagger  -> must open.
5. pubspec.yaml must have: http, provider, file_picker, url_launcher, intl, shared_preferences, flutter_secure_storage, webview_flutter.

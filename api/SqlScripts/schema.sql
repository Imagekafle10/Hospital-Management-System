-- =====================================================================
-- Hospital Management System - Database Schema
-- Run this once against your SQL Server instance before starting the API.
-- =====================================================================

IF DB_ID('HospitalMgmtDb') IS NULL
BEGIN
    CREATE DATABASE HospitalMgmtDb;
END
GO

USE HospitalMgmtDb;
GO

-- =====================================================================
-- Users: base login for Admin / Doctor / Patient
-- =====================================================================
IF OBJECT_ID('dbo.Users', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Users (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        FullName      NVARCHAR(150)   NOT NULL,
        Email         NVARCHAR(150)   NOT NULL UNIQUE,
        PasswordHash  NVARCHAR(255)   NOT NULL,
        Role          NVARCHAR(20)    NOT NULL CHECK (Role IN ('Admin','Doctor','Patient','Pharmacist')),
        Phone         NVARCHAR(20)    NULL,
        IsActive      BIT             NOT NULL DEFAULT 1,
        CreatedAt     DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
    );
END
GO

-- =====================================================================
-- Doctors: profile extension for users with Role = 'Doctor'
-- =====================================================================
IF OBJECT_ID('dbo.Doctors', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Doctors (
        Id                INT IDENTITY(1,1) PRIMARY KEY,
        UserId            INT             NOT NULL UNIQUE,
        Specialization    NVARCHAR(100)   NOT NULL,
        LicenseNumber     NVARCHAR(50)    NOT NULL,
        ConsultationFee   DECIMAL(10,2)   NOT NULL DEFAULT 0,
        YearsOfExperience INT             NOT NULL DEFAULT 0,
        AvailableFrom     TIME            NULL,
        AvailableTo       TIME            NULL,
        CreatedAt         DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Doctors_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id) ON DELETE CASCADE
    );
END
GO

-- =====================================================================
-- Patients: profile extension for users with Role = 'Patient'
-- =====================================================================
IF OBJECT_ID('dbo.Patients', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Patients (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        UserId        INT             NOT NULL UNIQUE,
        DateOfBirth   DATE            NULL,
        Gender        NVARCHAR(10)    NULL,
        BloodGroup    NVARCHAR(5)     NULL,
        Address       NVARCHAR(255)   NULL,
        EmergencyContact NVARCHAR(20) NULL,
        CreatedAt     DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Patients_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id) ON DELETE CASCADE
    );
END
GO

-- =====================================================================
-- Appointments: links a Patient to a Doctor
-- =====================================================================
IF OBJECT_ID('dbo.Appointments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Appointments (
        Id              INT IDENTITY(1,1) PRIMARY KEY,
        PatientId       INT             NOT NULL,
        DoctorId        INT             NOT NULL,
        AppointmentDate DATETIME2       NOT NULL,
        Reason          NVARCHAR(255)   NULL,
        Status          NVARCHAR(20)    NOT NULL DEFAULT 'Pending' CHECK (Status IN ('Pending','Confirmed','Completed','Cancelled')),
        Notes           NVARCHAR(1000)  NULL,
        CreatedAt       DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt       DATETIME2       NULL,
        CONSTRAINT FK_Appointments_Patients FOREIGN KEY (PatientId) REFERENCES dbo.Patients(Id),
        CONSTRAINT FK_Appointments_Doctors FOREIGN KEY (DoctorId) REFERENCES dbo.Doctors(Id)
    );
END
GO

-- =====================================================================
-- Prescriptions: written by a Doctor for a completed Appointment
-- =====================================================================
IF OBJECT_ID('dbo.Prescriptions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Prescriptions (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        AppointmentId INT             NOT NULL,
        Medication    NVARCHAR(255)   NOT NULL,
        Dosage        NVARCHAR(100)   NULL,
        Instructions  NVARCHAR(500)   NULL,
        CreatedAt     DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Prescriptions_Appointments FOREIGN KEY (AppointmentId) REFERENCES dbo.Appointments(Id) ON DELETE CASCADE
    );
END
GO

-- =====================================================================
-- MedicalRecords: patient medical records & lab reports (file upload)
-- =====================================================================
IF OBJECT_ID('dbo.MedicalRecords', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.MedicalRecords (
        Id               INT IDENTITY(1,1) PRIMARY KEY,
        PatientId        INT             NOT NULL,
        DoctorId         INT             NULL,
        AppointmentId    INT             NULL,
        RecordType       NVARCHAR(20)    NOT NULL CHECK (RecordType IN ('LabReport','Prescription','Diagnosis','Imaging','Other')),
        Title            NVARCHAR(200)   NOT NULL,
        Description      NVARCHAR(1000)  NULL,
        FileName         NVARCHAR(260)   NOT NULL,
        StoredFileName   NVARCHAR(100)   NOT NULL,
        ContentType      NVARCHAR(150)   NOT NULL,
        FileSizeBytes    BIGINT          NOT NULL,
        UploadedByUserId INT             NOT NULL,
        CreatedAt        DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_MedicalRecords_Patients FOREIGN KEY (PatientId) REFERENCES dbo.Patients(Id) ON DELETE CASCADE,
        CONSTRAINT FK_MedicalRecords_Doctors FOREIGN KEY (DoctorId) REFERENCES dbo.Doctors(Id),
        CONSTRAINT FK_MedicalRecords_Appointments FOREIGN KEY (AppointmentId) REFERENCES dbo.Appointments(Id),
        CONSTRAINT FK_MedicalRecords_Users FOREIGN KEY (UploadedByUserId) REFERENCES dbo.Users(Id)
    );
END
GO

-- =====================================================================
-- Payments: Esewa / Khalti / COD payment for an appointment
-- =====================================================================
IF OBJECT_ID('dbo.Payments', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Payments (
        Id                INT IDENTITY(1,1) PRIMARY KEY,
        AppointmentId     INT             NOT NULL,
        PatientId         INT             NOT NULL,
        Amount            DECIMAL(10,2)   NOT NULL,
        Method            NVARCHAR(20)    NOT NULL CHECK (Method IN ('Esewa','Khalti','COD')),
        Status            NVARCHAR(20)    NOT NULL DEFAULT 'Pending' CHECK (Status IN ('Pending','Success','Failed','Cancelled')),
        TransactionUuid   NVARCHAR(100)   NOT NULL UNIQUE,
        GatewayReference  NVARCHAR(100)   NULL,
        CreatedAt         DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        PaidAt            DATETIME2       NULL,
        CONSTRAINT FK_Payments_Appointments FOREIGN KEY (AppointmentId) REFERENCES dbo.Appointments(Id),
        CONSTRAINT FK_Payments_Patients FOREIGN KEY (PatientId) REFERENCES dbo.Patients(Id)
    );
END
GO

-- =====================================================================
-- Wards / Beds / Admissions: in-patient management
-- =====================================================================
IF OBJECT_ID('dbo.Wards', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Wards (
        Id           INT IDENTITY(1,1) PRIMARY KEY,
        Name         NVARCHAR(100)   NOT NULL UNIQUE,
        WardType     NVARCHAR(20)    NOT NULL CHECK (WardType IN ('General','ICU','Private','Maternity','Emergency')),
        FloorNumber  INT             NULL,
        Description  NVARCHAR(500)   NULL,
        CreatedAt    DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
    );
END
GO

IF OBJECT_ID('dbo.Beds', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Beds (
        Id         INT IDENTITY(1,1) PRIMARY KEY,
        WardId     INT             NOT NULL,
        BedNumber  NVARCHAR(20)    NOT NULL,
        Status     NVARCHAR(20)    NOT NULL DEFAULT 'Available' CHECK (Status IN ('Available','Occupied','Maintenance')),
        CreatedAt  DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Beds_Wards FOREIGN KEY (WardId) REFERENCES dbo.Wards(Id) ON DELETE CASCADE,
        CONSTRAINT UQ_Beds_WardId_BedNumber UNIQUE (WardId, BedNumber)
    );
END
GO

IF OBJECT_ID('dbo.Admissions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Admissions (
        Id                     INT IDENTITY(1,1) PRIMARY KEY,
        PatientId              INT             NOT NULL,
        AdmittingDoctorId      INT             NOT NULL,
        BedId                  INT             NOT NULL,
        AdmissionDate          DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        ExpectedDischargeDate  DATETIME2       NULL,
        DischargeDate          DATETIME2       NULL,
        ReasonForAdmission     NVARCHAR(500)   NOT NULL,
        Status                 NVARCHAR(20)    NOT NULL DEFAULT 'Admitted' CHECK (Status IN ('Admitted','Discharged')),
        DischargeSummary       NVARCHAR(1000)  NULL,
        CreatedAt              DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt              DATETIME2       NULL,
        CONSTRAINT FK_Admissions_Patients FOREIGN KEY (PatientId) REFERENCES dbo.Patients(Id),
        CONSTRAINT FK_Admissions_Doctors FOREIGN KEY (AdmittingDoctorId) REFERENCES dbo.Doctors(Id),
        CONSTRAINT FK_Admissions_Beds FOREIGN KEY (BedId) REFERENCES dbo.Beds(Id)
    );
END
GO

-- Helpful indexes (guarded so this script is safe to re-run)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_DoctorId' AND object_id = OBJECT_ID('dbo.Appointments'))
    CREATE INDEX IX_Appointments_DoctorId ON dbo.Appointments(DoctorId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Appointments_PatientId' AND object_id = OBJECT_ID('dbo.Appointments'))
    CREATE INDEX IX_Appointments_PatientId ON dbo.Appointments(PatientId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Users_Email' AND object_id = OBJECT_ID('dbo.Users'))
    CREATE INDEX IX_Users_Email ON dbo.Users(Email);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_MedicalRecords_PatientId' AND object_id = OBJECT_ID('dbo.MedicalRecords'))
    CREATE INDEX IX_MedicalRecords_PatientId ON dbo.MedicalRecords(PatientId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payments_AppointmentId' AND object_id = OBJECT_ID('dbo.Payments'))
    CREATE INDEX IX_Payments_AppointmentId ON dbo.Payments(AppointmentId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payments_PatientId' AND object_id = OBJECT_ID('dbo.Payments'))
    CREATE INDEX IX_Payments_PatientId ON dbo.Payments(PatientId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Beds_WardId' AND object_id = OBJECT_ID('dbo.Beds'))
    CREATE INDEX IX_Beds_WardId ON dbo.Beds(WardId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_PatientId' AND object_id = OBJECT_ID('dbo.Admissions'))
    CREATE INDEX IX_Admissions_PatientId ON dbo.Admissions(PatientId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_BedId' AND object_id = OBJECT_ID('dbo.Admissions'))
    CREATE INDEX IX_Admissions_BedId ON dbo.Admissions(BedId);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Admissions_Status' AND object_id = OBJECT_ID('dbo.Admissions'))
    CREATE INDEX IX_Admissions_Status ON dbo.Admissions(Status);
GO

PRINT 'Schema created successfully.';
-- =====================================================================
GO

IF OBJECT_ID('dbo.Medicines', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Medicines (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        Name          NVARCHAR(200)  NOT NULL,
        GenericName   NVARCHAR(200)  NULL,
        Category      NVARCHAR(100)  NULL,
        Manufacturer  NVARCHAR(150)  NULL,
        BatchNumber   NVARCHAR(50)   NULL,
        Unit          NVARCHAR(30)   NOT NULL DEFAULT 'Tablet',
        UnitPrice     DECIMAL(10,2)  NOT NULL DEFAULT 0 CHECK (UnitPrice >= 0),
        StockQuantity INT            NOT NULL DEFAULT 0 CHECK (StockQuantity >= 0),
        ReorderLevel  INT            NOT NULL DEFAULT 10,
        ExpiryDate    DATE           NULL,
        IsActive      BIT            NOT NULL DEFAULT 1,
        CreatedAt     DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_Medicines_Name ON dbo.Medicines(Name);
END
GO

IF OBJECT_ID('dbo.PharmacyDispenses', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PharmacyDispenses (
        Id                INT IDENTITY(1,1) PRIMARY KEY,
        PrescriptionId    INT            NULL,
        PatientId         INT            NOT NULL,
        MedicineId        INT            NOT NULL,
        Quantity          INT            NOT NULL CHECK (Quantity > 0),
        UnitPrice         DECIMAL(10,2)  NOT NULL,
        TotalPrice        DECIMAL(12,2)  NOT NULL,
        DispensedByUserId INT            NOT NULL,
        Notes             NVARCHAR(500)  NULL,
        CreatedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Dispenses_Prescriptions FOREIGN KEY (PrescriptionId) REFERENCES dbo.Prescriptions(Id) ON DELETE SET NULL,
        CONSTRAINT FK_Dispenses_Patients FOREIGN KEY (PatientId) REFERENCES dbo.Patients(Id),
        CONSTRAINT FK_Dispenses_Medicines FOREIGN KEY (MedicineId) REFERENCES dbo.Medicines(Id),
        CONSTRAINT FK_Dispenses_Users FOREIGN KEY (DispensedByUserId) REFERENCES dbo.Users(Id)
    );
    CREATE INDEX IX_Dispenses_Patient ON dbo.PharmacyDispenses(PatientId);
END
GO

-- Run this ONCE on HospitalMgmtDb (SSMS) before starting the updated API.

-- 1) Doctor profile photo
IF COL_LENGTH('dbo.Doctors', 'PhotoFileName') IS NULL
    ALTER TABLE dbo.Doctors ADD PhotoFileName NVARCHAR(100) NULL;
GO

-- 2) Reports a patient attaches when booking an appointment
IF OBJECT_ID('dbo.AppointmentRecords', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AppointmentRecords (
        AppointmentId   INT NOT NULL,
        MedicalRecordId INT NOT NULL,
        CreatedAt       DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_AppointmentRecords PRIMARY KEY (AppointmentId, MedicalRecordId),
        CONSTRAINT FK_AppointmentRecords_Appointments FOREIGN KEY (AppointmentId) REFERENCES dbo.Appointments(Id) ON DELETE CASCADE,
        CONSTRAINT FK_AppointmentRecords_MedicalRecords FOREIGN KEY (MedicalRecordId) REFERENCES dbo.MedicalRecords(Id)
    );
END
GO
PRINT 'Migration done.';

-- =====================================================================
-- Pharmacy module: Medicines (stock) + PharmacyDispenses
-- Safe to re-run. Also included at the end of schema.sql.
-- =====================================================================
USE HospitalMgmtDb;
GO

IF OBJECT_ID('dbo.Medicines', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Medicines (
        Id            INT IDENTITY(1,1) PRIMARY KEY,
        Name          NVARCHAR(200)  NOT NULL,
        GenericName   NVARCHAR(200)  NULL,
        Category      NVARCHAR(100)  NULL,
        Manufacturer  NVARCHAR(150)  NULL,
        BatchNumber   NVARCHAR(50)   NULL,
        Unit          NVARCHAR(30)   NOT NULL DEFAULT 'Tablet',
        UnitPrice     DECIMAL(10,2)  NOT NULL DEFAULT 0 CHECK (UnitPrice >= 0),
        StockQuantity INT            NOT NULL DEFAULT 0 CHECK (StockQuantity >= 0),
        ReorderLevel  INT            NOT NULL DEFAULT 10,
        ExpiryDate    DATE           NULL,
        IsActive      BIT            NOT NULL DEFAULT 1,
        CreatedAt     DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
    );
    CREATE INDEX IX_Medicines_Name ON dbo.Medicines(Name);
END
GO

IF OBJECT_ID('dbo.PharmacyDispenses', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PharmacyDispenses (
        Id                INT IDENTITY(1,1) PRIMARY KEY,
        PrescriptionId    INT            NULL,
        PatientId         INT            NOT NULL,
        MedicineId        INT            NOT NULL,
        Quantity          INT            NOT NULL CHECK (Quantity > 0),
        UnitPrice         DECIMAL(10,2)  NOT NULL,
        TotalPrice        DECIMAL(12,2)  NOT NULL,
        DispensedByUserId INT            NOT NULL,
        Notes             NVARCHAR(500)  NULL,
        CreatedAt         DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT FK_Dispenses_Prescriptions FOREIGN KEY (PrescriptionId) REFERENCES dbo.Prescriptions(Id) ON DELETE SET NULL,
        CONSTRAINT FK_Dispenses_Patients FOREIGN KEY (PatientId) REFERENCES dbo.Patients(Id),
        CONSTRAINT FK_Dispenses_Medicines FOREIGN KEY (MedicineId) REFERENCES dbo.Medicines(Id),
        CONSTRAINT FK_Dispenses_Users FOREIGN KEY (DispensedByUserId) REFERENCES dbo.Users(Id)
    );
    CREATE INDEX IX_Dispenses_Patient ON dbo.PharmacyDispenses(PatientId);
END
GO

-- Allow the 'Pharmacist' role in Users.Role (the original CHECK only allowed Admin/Doctor/Patient).
USE HospitalMgmtDb;
GO
DECLARE @name SYSNAME, @sql NVARCHAR(MAX);
SELECT @name = cc.name
FROM sys.check_constraints cc
WHERE cc.parent_object_id = OBJECT_ID('dbo.Users') AND cc.definition LIKE '%Role%';
IF @name IS NOT NULL
BEGIN
    SET @sql = N'ALTER TABLE dbo.Users DROP CONSTRAINT ' + QUOTENAME(@name);
    EXEC sp_executesql @sql;
END
IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_Users_Role' AND parent_object_id = OBJECT_ID('dbo.Users'))
    ALTER TABLE dbo.Users ADD CONSTRAINT CK_Users_Role CHECK (Role IN ('Admin','Doctor','Patient','Pharmacist'));
GO

USE HospitalMgmtDb;
GO
-- Follow-up fields on Appointments (doctor panel: "Follow-up if required")
IF COL_LENGTH('dbo.Appointments', 'FollowUpRequired') IS NULL
    ALTER TABLE dbo.Appointments ADD FollowUpRequired BIT NOT NULL CONSTRAINT DF_Appointments_FollowUpRequired DEFAULT 0;
GO
IF COL_LENGTH('dbo.Appointments', 'FollowUpDate') IS NULL
    ALTER TABLE dbo.Appointments ADD FollowUpDate DATETIME2 NULL;
GO
IF COL_LENGTH('dbo.Appointments', 'FollowUpNotes') IS NULL
    ALTER TABLE dbo.Appointments ADD FollowUpNotes NVARCHAR(500) NULL;
GO

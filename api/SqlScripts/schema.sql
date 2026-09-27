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
        Role          NVARCHAR(20)    NOT NULL CHECK (Role IN ('Admin','Doctor','Patient')),
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

-- Helpful indexes
CREATE INDEX IX_Appointments_DoctorId ON dbo.Appointments(DoctorId);
CREATE INDEX IX_Appointments_PatientId ON dbo.Appointments(PatientId);
CREATE INDEX IX_Users_Email ON dbo.Users(Email);
GO

PRINT 'Schema created successfully.';
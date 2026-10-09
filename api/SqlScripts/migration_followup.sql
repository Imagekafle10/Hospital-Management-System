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

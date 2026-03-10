-- ============================================================
--  MEDICARE+ HOSPITAL & CLINIC MANAGEMENT SYSTEM
--  SQL Server Database Design Project
--  Engine : SQL Server 2019+
-- ============================================================

-- ============================================================
-- SECTION 00 — DATABASE SETUP
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'MediCarePlus')
    DROP DATABASE MediCarePlus;
GO

CREATE DATABASE MediCarePlus;
GO

USE MediCarePlus;
GO

-- ============================================================
-- SECTION 01 — CREATE TABLES (dependency order)
-- ============================================================

-- 1. Departments
CREATE TABLE Departments (
    DepartmentID  INT           IDENTITY(1,1) PRIMARY KEY,
    DeptName      NVARCHAR(100) NOT NULL UNIQUE,
    HeadDoctorID  INT           NULL   -- FK added after Doctors is created
);
GO

-- 2. Doctors
CREATE TABLE Doctors (
    DoctorID       INT            IDENTITY(1,1) PRIMARY KEY,
    FirstName      NVARCHAR(50)   NOT NULL,
    LastName       NVARCHAR(50)   NOT NULL,
    Specialisation NVARCHAR(100)  NOT NULL,
    DepartmentID   INT            NOT NULL REFERENCES Departments(DepartmentID),
    ConsultFee     DECIMAL(10,2)  NOT NULL CHECK (ConsultFee >= 0),
    IsActive       BIT            NOT NULL DEFAULT 1,
    Phone          NVARCHAR(15)   NULL,
    Email          NVARCHAR(100)  NULL
);
GO

-- Add HeadDoctorID FK now that Doctors exists
ALTER TABLE Departments
    ADD CONSTRAINT FK_Dept_HeadDoctor
    FOREIGN KEY (HeadDoctorID) REFERENCES Doctors(DoctorID);
GO

-- 3. DoctorSchedules
CREATE TABLE DoctorSchedules (
    ScheduleID INT          IDENTITY(1,1) PRIMARY KEY,
    DoctorID   INT          NOT NULL REFERENCES Doctors(DoctorID),
    DayOfWeek  NVARCHAR(10) NOT NULL
                   CHECK (DayOfWeek IN ('Monday','Tuesday','Wednesday',
                                        'Thursday','Friday','Saturday','Sunday')),
    TimeSlot   NVARCHAR(20) NOT NULL,
    CONSTRAINT UQ_DoctorSchedule UNIQUE (DoctorID, DayOfWeek, TimeSlot)
);
GO

-- 4. Patients
CREATE TABLE Patients (
    PatientID    INT            IDENTITY(1,1) PRIMARY KEY,
    FirstName    NVARCHAR(50)   NOT NULL,
    LastName     NVARCHAR(50)   NOT NULL,
    DateOfBirth  DATE           NOT NULL,
    Gender       NVARCHAR(10)   CHECK (Gender IN ('Male','Female','Other')),
    Phone        NVARCHAR(15)   NULL,
    Email        NVARCHAR(100)  NULL,
    Address      NVARCHAR(255)  NULL,
    RegisteredOn DATE           NOT NULL DEFAULT CAST(GETDATE() AS DATE)
);
GO

-- 5. InsurancePolicies
CREATE TABLE InsurancePolicies (
    PolicyID        INT            IDENTITY(1,1) PRIMARY KEY,
    PatientID       INT            NOT NULL REFERENCES Patients(PatientID),
    ProviderName    NVARCHAR(100)  NOT NULL,
    PolicyNumber    NVARCHAR(50)   NOT NULL UNIQUE,
    CoveragePercent DECIMAL(5,2)   NOT NULL CHECK (CoveragePercent BETWEEN 0 AND 100),
    YearlyMaximum   DECIMAL(12,2)  NOT NULL CHECK (YearlyMaximum >= 0),
    StartDate       DATE           NOT NULL,
    EndDate         DATE           NOT NULL,
    CONSTRAINT CHK_PolicyDates CHECK (EndDate >= StartDate)
);
GO

-- 6. Appointments
CREATE TABLE Appointments (
    AppointmentID INT            IDENTITY(1,1) PRIMARY KEY,
    PatientID     INT            NOT NULL REFERENCES Patients(PatientID),
    DoctorID      INT            NOT NULL REFERENCES Doctors(DoctorID),
    ApptDate      DATE           NOT NULL,
    TimeSlot      NVARCHAR(20)   NOT NULL,
    Status        NVARCHAR(15)   NOT NULL DEFAULT 'Scheduled'
                      CHECK (Status IN ('Scheduled','Completed','Cancelled')),
    Notes         NVARCHAR(500)  NULL,
    CONSTRAINT UQ_Doctor_DateTime UNIQUE (DoctorID, ApptDate, TimeSlot)
);
GO

-- 7. MedicalRecords  (1:1 with Appointments)
CREATE TABLE MedicalRecords (
    RecordID         INT             IDENTITY(1,1) PRIMARY KEY,
    AppointmentID    INT             NOT NULL UNIQUE REFERENCES Appointments(AppointmentID),
    Diagnosis        NVARCHAR(500)   NOT NULL,
    TreatmentPlan    NVARCHAR(1000)  NULL,
    RequiresFollowUp BIT             NOT NULL DEFAULT 0,
    CreatedAt        DATETIME        NOT NULL DEFAULT GETDATE()
);
GO

-- 8. Medicines  (reference catalogue)
CREATE TABLE Medicines (
    MedicineID INT            IDENTITY(1,1) PRIMARY KEY,
    MedName    NVARCHAR(100)  NOT NULL UNIQUE,
    Category   NVARCHAR(50)   NULL,
    UnitPrice  DECIMAL(10,2)  NOT NULL CHECK (UnitPrice >= 0),
    Unit       NVARCHAR(20)   NOT NULL DEFAULT 'tablet'
);
GO

-- 9. Prescriptions  (junction: Appointment + Medicine)
CREATE TABLE Prescriptions (
    PrescriptionID INT           IDENTITY(1,1) PRIMARY KEY,
    AppointmentID  INT           NOT NULL REFERENCES Appointments(AppointmentID),
    MedicineID     INT           NOT NULL REFERENCES Medicines(MedicineID),
    Dosage         NVARCHAR(50)  NOT NULL,
    DurationDays   INT           NOT NULL CHECK (DurationDays > 0),
    Quantity       INT           NOT NULL CHECK (Quantity > 0),
    CONSTRAINT UQ_Prescription UNIQUE (AppointmentID, MedicineID)
);
GO

-- 10. LabTests  (reference catalogue)
CREATE TABLE LabTests (
    LabTestID   INT            IDENTITY(1,1) PRIMARY KEY,
    TestName    NVARCHAR(100)  NOT NULL UNIQUE,
    Description NVARCHAR(500)  NULL,
    Price       DECIMAL(10,2)  NOT NULL CHECK (Price >= 0)
);
GO

-- 11. LabOrders  (junction: Appointment + LabTest, stores results)
CREATE TABLE LabOrders (
    LabOrderID    INT            IDENTITY(1,1) PRIMARY KEY,
    AppointmentID INT            NOT NULL REFERENCES Appointments(AppointmentID),
    LabTestID     INT            NOT NULL REFERENCES LabTests(LabTestID),
    OrderedOn     DATETIME       NOT NULL DEFAULT GETDATE(),
    ResultValue   NVARCHAR(200)  NULL,
    ResultDate    DATE           NULL,
    IsAbnormal    BIT            NOT NULL DEFAULT 0,
    CONSTRAINT UQ_LabOrder UNIQUE (AppointmentID, LabTestID)
);
GO

-- 12. Billing  (1:1 with Appointments, only for Completed)
CREATE TABLE Billing (
    BillID            INT            IDENTITY(1,1) PRIMARY KEY,
    AppointmentID     INT            NOT NULL UNIQUE REFERENCES Appointments(AppointmentID),
    ConsultCharge     DECIMAL(10,2)  NOT NULL DEFAULT 0,
    MedicineCharge    DECIMAL(10,2)  NOT NULL DEFAULT 0,
    LabCharge         DECIMAL(10,2)  NOT NULL DEFAULT 0,
    InsuranceDiscount DECIMAL(10,2)  NOT NULL DEFAULT 0,
    GSTOnConsult      DECIMAL(10,2)  NOT NULL DEFAULT 0,  -- 0%
    GSTOnMedicine     DECIMAL(10,2)  NOT NULL DEFAULT 0,  -- 5%
    GSTOnLab          DECIMAL(10,2)  NOT NULL DEFAULT 0,  -- 12%
    FinalAmount       DECIMAL(10,2)  NOT NULL DEFAULT 0,
    PaymentStatus     NVARCHAR(15)   NOT NULL DEFAULT 'Unpaid'
                          CHECK (PaymentStatus IN ('Unpaid','Paid','Partially Paid')),
    BilledOn          DATETIME       NOT NULL DEFAULT GETDATE()
);
GO

-- ============================================================
-- SECTION 02 — SAMPLE DATA
-- ============================================================

-- Departments (HeadDoctorID set later after Doctors inserted)
INSERT INTO Departments (DeptName) VALUES
    ('Cardiology'),
    ('Orthopaedics'),
    ('Pathology'),
    ('Neurology'),
    ('General Medicine');
GO

-- Doctors
INSERT INTO Doctors (FirstName, LastName, Specialisation, DepartmentID, ConsultFee, IsActive, Phone, Email)
VALUES
    ('Arjun',  'Mehta',  'Cardiologist',        1, 1200.00, 1, '9876543210', 'arjun@medicare.com'),
    ('Priya',  'Sharma', 'Cardiac Surgeon',      1,  800.00, 1, '9876543211', 'priya@medicare.com'),
    ('Rajan',  'Verma',  'Orthopaedic Surgeon',  2,  900.00, 1, '9876543212', 'rajan@medicare.com'),
    ('Sunita', 'Rao',    'Joint Specialist',     2,  750.00, 1, '9876543213', 'sunita@medicare.com'),
    ('Kavita', 'Nair',   'Pathologist',          3,  600.00, 1, '9876543214', 'kavita@medicare.com'),
    ('Deepak', 'Joshi',  'Neurologist',          4, 1100.00, 1, '9876543215', 'deepak@medicare.com'),
    ('Meena',  'Pillai', 'Neurosurgeon',         4,  950.00, 1, '9876543216', 'meena@medicare.com'),
    ('Rahul',  'Gupta',  'General Physician',    5,  500.00, 1, '9876543217', 'rahul@medicare.com'),
    ('Ananya', 'Singh',  'General Physician',    5,  450.00, 1, '9876543218', 'ananya@medicare.com'),
    ('Vikram', 'Das',    'Cardiologist',         1,  700.00, 0, '9876543219', 'vikram@medicare.com');
GO

-- Set Head Doctors (done after Doctors are inserted)
UPDATE Departments SET HeadDoctorID = 1 WHERE DepartmentID = 1;
UPDATE Departments SET HeadDoctorID = 3 WHERE DepartmentID = 2;
UPDATE Departments SET HeadDoctorID = 5 WHERE DepartmentID = 3;
UPDATE Departments SET HeadDoctorID = 6 WHERE DepartmentID = 4;
UPDATE Departments SET HeadDoctorID = 8 WHERE DepartmentID = 5;
GO

-- DoctorSchedules
INSERT INTO DoctorSchedules (DoctorID, DayOfWeek, TimeSlot) VALUES
    (1,'Monday','09:00-10:00'),(1,'Monday','10:00-11:00'),
    (1,'Wednesday','09:00-10:00'),(1,'Friday','14:00-15:00'),
    (2,'Tuesday','10:00-11:00'),(2,'Thursday','09:00-10:00'),
    (3,'Monday','11:00-12:00'),(3,'Wednesday','11:00-12:00'),
    (4,'Tuesday','09:00-10:00'),(4,'Friday','10:00-11:00'),
    (5,'Monday','09:00-10:00'),(5,'Thursday','14:00-15:00'),
    (6,'Tuesday','10:00-11:00'),(6,'Thursday','10:00-11:00'),
    (7,'Wednesday','14:00-15:00'),(7,'Friday','09:00-10:00'),
    (8,'Monday','09:00-10:00'),(8,'Monday','10:00-11:00'),(8,'Monday','11:00-12:00'),
    (9,'Tuesday','09:00-10:00'),(9,'Thursday','09:00-10:00');
GO

-- Patients
INSERT INTO Patients (FirstName, LastName, DateOfBirth, Gender, Phone, Email, Address)
VALUES
    ('Aditya',  'Kumar',    '1985-03-15', 'Male',   '8800112233', 'aditya@gmail.com',  'Delhi'),
    ('Bhavna',  'Patel',    '1990-07-22', 'Female', '8800112234', 'bhavna@gmail.com',  'Mumbai'),
    ('Chirag',  'Shah',     '1978-11-05', 'Male',   '8800112235', 'chirag@gmail.com',  'Ahmedabad'),
    ('Divya',   'Menon',    '2000-01-18', 'Female', '8800112236', 'divya@gmail.com',   'Chennai'),
    ('Eshan',   'Tiwari',   '1965-09-30', 'Male',   '8800112237', 'eshan@gmail.com',   'Lucknow'),
    ('Farah',   'Sheikh',   '1995-04-12', 'Female', '8800112238', 'farah@gmail.com',   'Hyderabad'),
    ('Gaurav',  'Bose',     '1972-12-25', 'Male',   '8800112239', 'gaurav@gmail.com',  'Kolkata'),
    ('Hina',    'Kapoor',   '1988-06-08', 'Female', '8800112240', 'hina@gmail.com',    'Pune'),
    ('Ishaan',  'Reddy',    '2005-02-28', 'Male',   '8800112241', 'ishaan@gmail.com',  'Bangalore'),
    ('Jyoti',   'Malhotra', '1960-08-14', 'Female', '8800112242', 'jyoti@gmail.com',   'Jaipur');
GO

-- InsurancePolicies (patients 1,2,3,5,7 have insurance)
INSERT INTO InsurancePolicies (PatientID, ProviderName, PolicyNumber, CoveragePercent, YearlyMaximum, StartDate, EndDate)
VALUES
    (1, 'Star Health',   'SH-001', 30.00, 50000.00, '2024-01-01', '2026-12-31'),
    (2, 'HDFC Ergo',     'HE-002', 50.00, 75000.00, '2024-01-01', '2026-12-31'),
    (3, 'Bajaj Allianz', 'BA-003', 20.00, 30000.00, '2024-01-01', '2026-12-31'),
    (5, 'New India',     'NI-005', 40.00, 60000.00, '2024-01-01', '2026-12-31'),
    (7, 'ICICI Lombard', 'IL-007', 35.00, 45000.00, '2024-01-01', '2026-12-31');
GO

-- Medicines
INSERT INTO Medicines (MedName, Category, UnitPrice, Unit) VALUES
    ('Aspirin 75mg',        'Antiplatelet',    5.00, 'tablet'),
    ('Metformin 500mg',     'Antidiabetic',    8.00, 'tablet'),
    ('Amlodipine 5mg',      'Antihypertensive',12.00,'tablet'),
    ('Paracetamol 500mg',   'Analgesic',       3.00, 'tablet'),
    ('Omeprazole 20mg',     'Antacid',        10.00, 'tablet'),
    ('Clopidogrel 75mg',    'Antiplatelet',   25.00, 'tablet'),
    ('Atorvastatin 10mg',   'Statin',         18.00, 'tablet'),
    ('Diclofenac 50mg',     'NSAID',           7.00, 'tablet'),
    ('Amoxicillin 500mg',   'Antibiotic',     15.00, 'capsule'),
    ('Pantoprazole 40mg',   'Antacid',        12.00, 'tablet'),
    ('Vitamin D3 60000IU',  'Supplement',     45.00, 'capsule'),
    ('Gabapentin 300mg',    'Anticonvulsant', 22.00, 'capsule'),
    ('Levothyroxine 50mcg', 'Thyroid',        20.00, 'tablet'),
    ('Cetirizine 10mg',     'Antihistamine',   5.00, 'tablet'),
    ('Ibuprofen 400mg',     'NSAID',           6.00, 'tablet');
GO

-- LabTests
INSERT INTO LabTests (TestName, Description, Price) VALUES
    ('Complete Blood Count', 'Full blood panel',    350.00),
    ('Lipid Profile',        'Cholesterol panel',   500.00),
    ('Blood Glucose Fasting','FBS test',            150.00),
    ('ECG',                  'Electrocardiogram',   300.00),
    ('X-Ray Chest',          'Chest radiograph',    400.00),
    ('MRI Brain',            'MRI of brain',       3500.00),
    ('CT Scan Chest',        'CT chest',           2500.00),
    ('Thyroid Function Test','T3 T4 TSH',           600.00),
    ('Urine Routine',        'Routine urine exam',  120.00),
    ('Liver Function Test',  'LFT panel',           450.00);
GO

-- Appointments (spread Jan-Jun 2024 for meaningful report output)
INSERT INTO Appointments (PatientID, DoctorID, ApptDate, TimeSlot, Status) VALUES
    (1,  1, '2024-01-10', '09:00-10:00', 'Completed'),
    (2,  1, '2024-01-10', '10:00-11:00', 'Completed'),
    (3,  3, '2024-01-15', '11:00-12:00', 'Completed'),
    (4,  8, '2024-01-20', '09:00-10:00', 'Completed'),
    (5,  6, '2024-01-22', '10:00-11:00', 'Completed'),
    (6,  1, '2024-02-05', '09:00-10:00', 'Completed'),
    (7,  3, '2024-02-12', '11:00-12:00', 'Completed'),
    (8,  6, '2024-02-14', '10:00-11:00', 'Completed'),
    (9,  8, '2024-02-20', '10:00-11:00', 'Completed'),
    (10, 2, '2024-02-25', '10:00-11:00', 'Completed'),
    (1,  6, '2024-03-05', '10:00-11:00', 'Completed'),
    (2,  3, '2024-03-10', '11:00-12:00', 'Completed'),
    (3,  1, '2024-03-15', '09:00-10:00', 'Completed'),
    (5,  8, '2024-03-18', '09:00-10:00', 'Completed'),
    (7,  4, '2024-03-22', '09:00-10:00', 'Completed'),
    (4,  7, '2024-04-02', '14:00-15:00', 'Completed'),
    (6,  1, '2024-04-10', '10:00-11:00', 'Completed'),
    (8,  3, '2024-04-15', '11:00-12:00', 'Completed'),
    (9,  6, '2024-04-20', '10:00-11:00', 'Completed'),
    (10, 8, '2024-04-25', '11:00-12:00', 'Completed'),
    (1,  1, '2024-05-03', '10:00-11:00', 'Completed'),
    (2,  6, '2024-05-10', '10:00-11:00', 'Completed'),
    (3,  3, '2024-05-15', '11:00-12:00', 'Completed'),
    (5,  1, '2024-05-20', '09:00-10:00', 'Completed'),
    (7,  8, '2024-05-25', '09:00-10:00', 'Completed'),
    (4,  6, '2024-06-03', '10:00-11:00', 'Completed'),
    (6,  3, '2024-06-10', '11:00-12:00', 'Completed'),
    (8,  1, '2024-06-15', '09:00-10:00', 'Completed'),
    (9,  8, '2024-06-20', '11:00-12:00', 'Completed'),
    (10, 4, '2024-06-25', '09:00-10:00', 'Completed'),
    (1,  1, '2025-01-15', '09:00-10:00', 'Scheduled'),
    (2,  3, '2025-01-16', '11:00-12:00', 'Scheduled'),
    (3,  6, '2024-07-05', '10:00-11:00', 'Cancelled'),
    (4,  1, '2024-07-10', '09:00-10:00', 'Cancelled');
GO

-- MedicalRecords (one per Completed appointment)
INSERT INTO MedicalRecords (AppointmentID, Diagnosis, TreatmentPlan, RequiresFollowUp) VALUES
    (1,  'Hypertension Stage 1',    'Amlodipine 5mg, lifestyle changes',  0),
    (2,  'Coronary Artery Disease', 'Aspirin, statin, follow-up ECG',     0),
    (3,  'Knee Osteoarthritis',     'Physiotherapy, Diclofenac',          0),
    (4,  'Viral Fever',             'Rest, Paracetamol, fluids',          0),
    (5,  'Migraine',                'Gabapentin, avoid triggers',         0),
    (6,  'Arrhythmia',              'ECG monitoring, Clopidogrel',        0),
    (7,  'Lumbar Disc Herniation',  'Rest, physiotherapy',                0),
    (8,  'Tension Headache',        'Analgesics, stress management',      0),
    (9,  'URTI',                    'Amoxicillin, rest',                  0),
    (10, 'Atrial Fibrillation',     'Rate control, anticoagulation',      0),
    (11, 'Migraine with Aura',      'Preventive therapy',                 0),
    (12, 'Rotator Cuff Injury',     'Physiotherapy, NSAIDs',              0),
    (13, 'Essential Hypertension',  'Amlodipine, salt restriction',       0),
    (14, 'Diabetes Type 2',         'Metformin, diet control',            0),
    (15, 'Ligament Tear',           'Immobilisation, surgery consult',    0),
    (16, 'Epilepsy',                'Gabapentin, EEG scheduled',          0),
    (17, 'Hypertension Stage 2',    'Combination antihypertensives',      0),
    (18, 'Spondylitis',             'NSAIDs, physiotherapy',              0),
    (19, 'Chronic Migraine',        'Preventive medication',              0),
    (20, 'Hypertensive Crisis',     'IV antihypertensives',               0),
    (21, 'Stable Angina',           'Nitrates, beta-blockers',            0),
    (22, 'Tension Headache',        'Analgesics',                         0),
    (23, 'Ankle Fracture',          'Immobilisation, calcium supplements',0),
    (24, 'Hypertension follow-up',  'Continue medications',               0),
    (25, 'Diabetes follow-up',      'Continue Metformin, HbA1c recheck', 0),
    (26, 'Vertigo',                 'Vestibular exercises, Betahistine',  0),
    (27, 'Meniscus Tear',           'Surgical referral',                  0),
    (28, 'Hypertension Controlled', 'Continue medications',               0),
    (29, 'GERD',                    'Omeprazole, diet modifications',      0),
    (30, 'Knee Ligament Sprain',    'RICE therapy, NSAIDs',               0);
GO

-- Prescriptions
INSERT INTO Prescriptions (AppointmentID, MedicineID, Dosage, DurationDays, Quantity) VALUES
    (1,  3,  '5mg once daily',      30,  30),
    (1,  7,  '10mg once daily',     30,  30),
    (2,  1,  '75mg once daily',     60,  60),
    (2,  6,  '75mg once daily',     60,  60),
    (3,  8,  '50mg twice daily',    14,  28),
    (4,  4,  '500mg thrice daily',   5,  15),
    (5,  12, '300mg twice daily',   30,  60),
    (6,  6,  '75mg once daily',     90,  90),
    (7,  8,  '50mg twice daily',    14,  28),
    (7,  15, '400mg twice daily',   10,  20),
    (8,  4,  '500mg as needed',      7,  14),
    (9,  9,  '500mg thrice daily',   7,  21),
    (10, 1,  '75mg once daily',     90,  90),
    (11, 12, '300mg twice daily',   30,  60),
    (12, 8,  '50mg twice daily',    14,  28),
    (13, 3,  '5mg once daily',      30,  30),
    (14, 2,  '500mg twice daily',   90, 180),
    (14, 11, '60000IU weekly',      12,  12),
    (16, 12, '300mg twice daily',   60, 120),
    (17, 3,  '10mg once daily',     30,  30),
    (18, 8,  '50mg twice daily',    14,  28),
    (19, 12, '300mg once daily',    30,  30),
    (20, 3,  '10mg once daily',     30,  30),
    (21, 1,  '75mg once daily',     90,  90),
    (22, 4,  '500mg as needed',      5,  10),
    (24, 3,  '5mg once daily',      30,  30),
    (25, 2,  '500mg twice daily',   90, 180),
    (26, 5,  '20mg once daily',     14,  14),
    (28, 3,  '5mg once daily',      30,  30),
    (29, 5,  '20mg twice daily',    30,  60),
    (30, 8,  '50mg twice daily',    10,  20);
GO

-- LabOrders
INSERT INTO LabOrders (AppointmentID, LabTestID, ResultValue, ResultDate, IsAbnormal) VALUES
    (1,  4, 'Normal Sinus Rhythm',   '2024-01-11', 0),
    (1,  2, 'LDL 180 mg/dL HIGH',   '2024-01-11', 1),
    (2,  4, 'AF detected',           '2024-01-11', 1),
    (3,  5, 'Joint space narrowing', '2024-01-16', 1),
    (4,  1, 'WBC 11000 high',        '2024-01-21', 1),
    (5,  6, 'No abnormality',        '2024-01-23', 0),
    (6,  4, 'Irregular rhythm',      '2024-02-06', 1),
    (7,  5, 'L4-L5 disc herniation', '2024-02-13', 1),
    (9,  1, 'WBC 9000 Normal',       '2024-02-21', 0),
    (10, 4, 'AF noted',              '2024-02-26', 1),
    (11, 6, 'No lesion',             '2024-03-06', 0),
    (13, 2, 'LDL 160 mg/dL HIGH',   '2024-03-16', 1),
    (14, 3, 'FBS 145 mg/dL HIGH',   '2024-03-19', 1),
    (16, 6, 'Temporal lobe activity','2024-04-03', 1),
    (17, 4, 'Tachycardia noted',     '2024-04-11', 1),
    (19, 6, 'No abnormality',        '2024-04-21', 0),
    (21, 4, 'ST depression noted',   '2024-05-04', 1),
    (23, 5, 'Fracture confirmed',    '2024-05-16', 1),
    (26, 6, 'Normal',                '2024-06-04', 0),
    (28, 4, 'Normal Sinus',          '2024-06-16', 0);
GO

-- ============================================================
-- SECTION 03 — BILLING DATA (all 30 completed appointments)
-- GST: 0% consult | 5% medicine | 12% lab
-- Insurance discount on med+lab only, applied before GST
-- ============================================================
INSERT INTO Billing (
    AppointmentID, ConsultCharge, MedicineCharge, LabCharge,
    InsuranceDiscount, GSTOnConsult, GSTOnMedicine, GSTOnLab,
    FinalAmount, PaymentStatus
)
SELECT
    a.AppointmentID,
    d.ConsultFee                                                AS ConsultCharge,
    ISNULL(med.MedCost, 0)                                      AS MedicineCharge,
    ISNULL(lab.LabCost, 0)                                      AS LabCharge,
    ROUND(ISNULL(ip.CoveragePercent,0)/100.0
          * (ISNULL(med.MedCost,0) + ISNULL(lab.LabCost,0)), 2) AS InsuranceDiscount,
    0                                                           AS GSTOnConsult,
    ROUND(0.05 * (ISNULL(med.MedCost,0)
        - CASE WHEN (ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0)) > 0
               THEN ROUND(ISNULL(ip.CoveragePercent,0)/100.0
                    * (ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0)),2)
                    * ISNULL(med.MedCost,0)
                    / (ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0))
               ELSE 0 END), 2)                                  AS GSTOnMedicine,
    ROUND(0.12 * (ISNULL(lab.LabCost,0)
        - CASE WHEN (ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0)) > 0
               THEN ROUND(ISNULL(ip.CoveragePercent,0)/100.0
                    * (ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0)),2)
                    * ISNULL(lab.LabCost,0)
                    / (ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0))
               ELSE 0 END), 2)                                  AS GSTOnLab,
    d.ConsultFee
    + (ISNULL(med.MedCost,0) + ISNULL(lab.LabCost,0))
    - ROUND(ISNULL(ip.CoveragePercent,0)/100.0
            * (ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0)), 2)
    + ROUND(0.05*(ISNULL(med.MedCost,0)
        - CASE WHEN (ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0))>0
               THEN ROUND(ISNULL(ip.CoveragePercent,0)/100.0
                    *(ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0)),2)
                    *ISNULL(med.MedCost,0)/(ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0))
               ELSE 0 END),2)
    + ROUND(0.12*(ISNULL(lab.LabCost,0)
        - CASE WHEN (ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0))>0
               THEN ROUND(ISNULL(ip.CoveragePercent,0)/100.0
                    *(ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0)),2)
                    *ISNULL(lab.LabCost,0)/(ISNULL(med.MedCost,0)+ISNULL(lab.LabCost,0))
               ELSE 0 END),2)                                   AS FinalAmount,
    CASE a.AppointmentID % 3
        WHEN 0 THEN 'Paid'
        WHEN 1 THEN 'Unpaid'
        ELSE        'Partially Paid'
    END                                                         AS PaymentStatus
FROM Appointments a
JOIN Doctors d ON d.DoctorID = a.DoctorID
LEFT JOIN (
    SELECT p.AppointmentID, SUM(m.UnitPrice * p.Quantity) AS MedCost
    FROM Prescriptions p JOIN Medicines m ON m.MedicineID = p.MedicineID
    GROUP BY p.AppointmentID
) med ON med.AppointmentID = a.AppointmentID
LEFT JOIN (
    SELECT lo.AppointmentID, SUM(lt.Price) AS LabCost
    FROM LabOrders lo JOIN LabTests lt ON lt.LabTestID = lo.LabTestID
    GROUP BY lo.AppointmentID
) lab ON lab.AppointmentID = a.AppointmentID
LEFT JOIN InsurancePolicies ip
    ON  ip.PatientID  = a.PatientID
    AND ip.StartDate <= a.ApptDate
    AND ip.EndDate   >= a.ApptDate
WHERE a.Status = 'Completed';
GO

-- ============================================================
-- SECTION 04 — VIEWS
-- ============================================================

-- Receptionist: safe patient view (no DOB, address, email)
CREATE OR ALTER VIEW vw_PatientBasic AS
SELECT PatientID, FirstName, LastName, Gender, Phone, RegisteredOn
FROM   Patients;
GO

-- Billing role: name + insurance only (no DOB / phone / address)
CREATE OR ALTER VIEW vw_PatientForBilling AS
SELECT
    p.PatientID,
    p.FirstName + ' ' + p.LastName AS PatientName,
    ip.ProviderName,
    ip.PolicyNumber,
    ip.CoveragePercent,
    ip.YearlyMaximum
FROM Patients p
LEFT JOIN InsurancePolicies ip ON ip.PatientID = p.PatientID;
GO

-- Lab tech: lab orders without patient personal info
CREATE OR ALTER VIEW vw_LabOrdersForTech AS
SELECT
    lo.LabOrderID, lo.AppointmentID, lo.LabTestID,
    lt.TestName, lt.Price,
    lo.OrderedOn, lo.ResultValue, lo.ResultDate, lo.IsAbnormal
FROM LabOrders lo
JOIN LabTests  lt ON lt.LabTestID = lo.LabTestID;
GO

-- ============================================================
-- SECTION 05 — USER-DEFINED FUNCTIONS (Section C)
-- ============================================================

-- ------------------------------------------------------------
-- C1: fn_GetPatientAge
-- Returns age in completed years. Returns NULL if not found.
-- ------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_GetPatientAge (@PatientID INT)
RETURNS INT
AS
BEGIN
    DECLARE @DOB DATE;
    SELECT @DOB = DateOfBirth FROM Patients WHERE PatientID = @PatientID;
    IF @DOB IS NULL RETURN NULL;
    RETURN DATEDIFF(YEAR, @DOB, GETDATE())
         - CASE
               WHEN MONTH(@DOB) > MONTH(GETDATE()) THEN 1
               WHEN MONTH(@DOB) = MONTH(GETDATE())
                AND DAY(@DOB)   > DAY(GETDATE())   THEN 1
               ELSE 0
           END;
END;
GO

-- C1 Demonstration query
SELECT
    PatientID,
    FirstName + ' ' + LastName      AS PatientName,
    DateOfBirth,
    dbo.fn_GetPatientAge(PatientID) AS AgeInYears
FROM   Patients
ORDER  BY PatientID;
GO

-- ------------------------------------------------------------
-- C2: fn_CalculateNetBill
-- Returns final payable after insurance discount + GST.
-- GST: 0% consult | 5% medicine | 12% lab
-- ------------------------------------------------------------
CREATE OR ALTER FUNCTION dbo.fn_CalculateNetBill (
    @ConsultCharge DECIMAL(10,2),
    @MedCharge     DECIMAL(10,2),
    @LabCharge     DECIMAL(10,2),
    @InsurancePct  DECIMAL(5,2)
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @Disc   DECIMAL(10,2);
    DECLARE @NetMed DECIMAL(10,2);
    DECLARE @NetLab DECIMAL(10,2);

    SET @Disc   = ROUND(@InsurancePct / 100.0 * (@MedCharge + @LabCharge), 2);
    SET @NetMed = @MedCharge - CASE WHEN (@MedCharge+@LabCharge)>0
                                    THEN ROUND(@Disc*@MedCharge/(@MedCharge+@LabCharge),2)
                                    ELSE 0 END;
    SET @NetLab = @LabCharge - CASE WHEN (@MedCharge+@LabCharge)>0
                                    THEN ROUND(@Disc*@LabCharge/(@MedCharge+@LabCharge),2)
                                    ELSE 0 END;
    RETURN ROUND(
        @ConsultCharge
        + @NetMed + ROUND(0.05 * @NetMed, 2)
        + @NetLab + ROUND(0.12 * @NetLab, 2)
    , 2);
END;
GO

-- C2 Demonstration query — verify matches stored FinalAmount
SELECT
    b.BillID,
    b.AppointmentID,
    b.FinalAmount                         AS StoredAmount,
    dbo.fn_CalculateNetBill(
        b.ConsultCharge, b.MedicineCharge,
        b.LabCharge, ISNULL(ip.CoveragePercent, 0)
    )                                     AS FunctionAmount,
    CASE WHEN ABS(b.FinalAmount - dbo.fn_CalculateNetBill(
        b.ConsultCharge, b.MedicineCharge,
        b.LabCharge, ISNULL(ip.CoveragePercent,0))) < 1
         THEN 'Match' ELSE 'Mismatch'
    END                                   AS Verification
FROM Billing b
JOIN Appointments a ON a.AppointmentID = b.AppointmentID
LEFT JOIN InsurancePolicies ip
    ON ip.PatientID = a.PatientID
   AND ip.StartDate <= a.ApptDate AND ip.EndDate >= a.ApptDate
ORDER BY b.BillID;
GO

-- ============================================================
-- SECTION 06 — STORED PROCEDURES (Section A)
-- ============================================================

-- ------------------------------------------------------------
-- A1: usp_MonthlyDepartmentReport
-- All departments shown even if zero appointments that month.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_MonthlyDepartmentReport
    @Month INT,
    @Year  INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @Month < 1 OR @Month > 12
            ;THROW 50001, 'Invalid month. Must be 1-12.', 1;
        IF @Year < 2000 OR @Year > 2100
            ;THROW 50002, 'Invalid year. Must be 2000-2100.', 1;

        SELECT
            dept.DepartmentID,
            dept.DeptName                       AS DepartmentName,
            COUNT(a.AppointmentID)              AS TotalAppointments,
            COUNT(DISTINCT a.PatientID)         AS UniquePatients,
            ISNULL(SUM(d.ConsultFee), 0)        AS TotalConsultRevenue
        FROM Departments dept
        LEFT JOIN Doctors      d ON d.DepartmentID  = dept.DepartmentID
        LEFT JOIN Appointments a ON a.DoctorID      = d.DoctorID
                                AND MONTH(a.ApptDate) = @Month
                                AND YEAR(a.ApptDate)  = @Year
                                AND a.Status = 'Completed'
        GROUP BY dept.DepartmentID, dept.DeptName
        ORDER BY dept.DeptName;
    END TRY
    BEGIN CATCH
        ;THROW;
    END CATCH;
END;
GO
EXEC dbo.usp_MonthlyDepartmentReport @Month = 1, @Year = 2024;
GO

-- ------------------------------------------------------------
-- A2: usp_PatientBillingStatement
-- Full billing history + GRAND TOTAL row. Error if ID missing.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_PatientBillingStatement
    @PatientID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM Patients WHERE PatientID = @PatientID)
            ;THROW 50010, 'Patient ID does not exist.', 1;

        SELECT
            CASE WHEN GROUPING(a.ApptDate) = 1
                 THEN 'GRAND TOTAL'
                 ELSE CONVERT(NVARCHAR(20), a.ApptDate, 106)
            END                              AS AppointmentDate,
            CASE WHEN GROUPING(a.ApptDate) = 1
                 THEN '' ELSE d.FirstName + ' ' + d.LastName
            END                              AS DoctorName,
            SUM(b.ConsultCharge)             AS ConsultationCharge,
            SUM(b.MedicineCharge)            AS TotalMedicineCost,
            SUM(b.LabCharge)                 AS TotalLabCost,
            SUM(b.InsuranceDiscount)         AS InsuranceDiscountApplied,
            SUM(b.GSTOnConsult+b.GSTOnMedicine+b.GSTOnLab) AS TotalGST,
            SUM(b.FinalAmount)               AS FinalAmountPayable
        FROM Appointments a
        JOIN Billing  b ON b.AppointmentID = a.AppointmentID
        JOIN Doctors  d ON d.DoctorID      = a.DoctorID
        WHERE a.PatientID = @PatientID AND a.Status = 'Completed'
        GROUP BY GROUPING SETS (
            (a.ApptDate, d.FirstName, d.LastName), ()
        )
        ORDER BY GROUPING(a.ApptDate), a.ApptDate;
    END TRY
    BEGIN CATCH
        ;THROW;
    END CATCH;
END;
GO
EXEC dbo.usp_PatientBillingStatement @PatientID = 1;
GO

-- ------------------------------------------------------------
-- A3: usp_DoctorPerformanceReport
-- Active doctors with >= @MinAppointments. Order by revenue.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_DoctorPerformanceReport
    @MinAppointments INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF @MinAppointments < 0
            ;THROW 50020, 'Minimum appointment count cannot be negative.', 1;

        WITH Stats AS (
            SELECT
                d.DoctorID,
                d.FirstName + ' ' + d.LastName  AS DoctorName,
                dept.DeptName                   AS Department,
                COUNT(a.AppointmentID)          AS TotalAppts,
                SUM(CASE WHEN a.Status='Completed' THEN 1 ELSE 0 END) AS CompletedAppts,
                ISNULL(SUM(b.FinalAmount), 0)   AS TotalRevenue,
                COUNT(DISTINCT mr.Diagnosis)    AS UniqueDiagnoses
            FROM Doctors d
            JOIN Departments dept ON dept.DepartmentID = d.DepartmentID
            LEFT JOIN Appointments   a  ON a.DoctorID       = d.DoctorID
            LEFT JOIN Billing        b  ON b.AppointmentID  = a.AppointmentID
            LEFT JOIN MedicalRecords mr ON mr.AppointmentID = a.AppointmentID
            WHERE d.IsActive = 1
            GROUP BY d.DoctorID, d.FirstName, d.LastName, dept.DeptName
        )
        SELECT
            DoctorName, Department,
            TotalAppts    AS TotalAppointments,
            CompletedAppts,
            CASE WHEN TotalAppts = 0 THEN 0.00
                 ELSE ROUND(CAST(CompletedAppts AS DECIMAL(10,2))/TotalAppts*100, 2)
            END           AS CompletionRatePct,
            TotalRevenue,
            UniqueDiagnoses
        FROM Stats
        WHERE TotalAppts >= @MinAppointments
        ORDER BY TotalRevenue DESC;
    END TRY
    BEGIN CATCH
        ;THROW;
    END CATCH;
END;
GO
EXEC dbo.usp_DoctorPerformanceReport @MinAppointments = 2;
GO

-- ------------------------------------------------------------
-- A4: usp_MedicinesNeverPrescribed
-- Two approaches inside one procedure.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_MedicinesNeverPrescribed
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        -- Approach 1: NOT IN subquery
        SELECT MedicineID, MedName, Category, UnitPrice
        FROM   Medicines
        WHERE  MedicineID NOT IN (SELECT DISTINCT MedicineID FROM Prescriptions);

        -- Approach 2: EXCEPT set operation
        SELECT MedicineID, MedName, Category, UnitPrice FROM Medicines
        EXCEPT
        SELECT m.MedicineID, m.MedName, m.Category, m.UnitPrice
        FROM   Medicines m JOIN Prescriptions p ON p.MedicineID = m.MedicineID;
    END TRY
    BEGIN CATCH
        ;THROW;
    END CATCH;
END;
GO
EXEC dbo.usp_MedicinesNeverPrescribed;
GO

-- ------------------------------------------------------------
-- A5: usp_MonthlyRevenueVsTarget
-- Target = Rs. 5,00,000. Detail + summary result sets.
-- ------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.usp_MonthlyRevenueVsTarget
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Target DECIMAL(12,2) = 500000.00;
    BEGIN TRY
        -- Monthly detail rows
        WITH Monthly AS (
            SELECT
                YEAR(BilledOn)   AS BillYear,
                MONTH(BilledOn)  AS BillMonth,
                SUM(FinalAmount) AS TotalRevenue
            FROM Billing
            GROUP BY YEAR(BilledOn), MONTH(BilledOn)
        )
        SELECT
            FORMAT(DATEFROMPARTS(BillYear,BillMonth,1),'MMM yyyy') AS MonthYear,
            TotalRevenue,
            CASE WHEN TotalRevenue >= @Target THEN 'Yes' ELSE 'No' END AS TargetMet,
            TotalRevenue - @Target                                      AS SurplusOrDeficit
        FROM Monthly
        ORDER BY BillYear, BillMonth;

        -- Summary row
        SELECT
            SUM(CASE WHEN TotalRevenue >= @Target THEN 1 ELSE 0 END) AS MonthsMet,
            SUM(CASE WHEN TotalRevenue <  @Target THEN 1 ELSE 0 END) AS MonthsNotMet
        FROM (
            SELECT YEAR(BilledOn) Y, MONTH(BilledOn) M, SUM(FinalAmount) TotalRevenue
            FROM Billing GROUP BY YEAR(BilledOn), MONTH(BilledOn)
        ) sub;
    END TRY
    BEGIN CATCH
        ;THROW;
    END CATCH;
END;
GO
EXEC dbo.usp_MonthlyRevenueVsTarget;
GO

-- ============================================================
-- SECTION 07 — TRIGGERS (Section B)
-- ============================================================

-- ------------------------------------------------------------
-- B1: trg_PreventDoctorDoubleBooking
-- Rolls back INSERT if doctor already booked at same date+slot.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_PreventDoctorDoubleBooking
ON Appointments
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1
        FROM inserted i
        JOIN Appointments a
            ON  a.DoctorID      = i.DoctorID
            AND a.ApptDate      = i.ApptDate
            AND a.TimeSlot      = i.TimeSlot
            AND a.Status        IN ('Scheduled','Completed')
            AND a.AppointmentID <> i.AppointmentID
    )
    BEGIN
        ROLLBACK TRANSACTION;
        ;THROW 50100,
            'Double-booking error: Doctor already has an appointment at this date and time.',
            1;
    END;
END;
GO

-- ------------------------------------------------------------
-- B2: trg_AutoGenerateBillOnCompletion
-- When Status changes to Completed, auto-inserts a full bill.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_AutoGenerateBillOnCompletion
ON Appointments
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (
        SELECT 1 FROM inserted i
        JOIN deleted d ON d.AppointmentID = i.AppointmentID
        WHERE i.Status = 'Completed' AND d.Status <> 'Completed'
    ) RETURN;

    BEGIN TRY
        DECLARE @ApptID   INT, @PatID INT, @DocID INT, @ApptDate DATE;

        DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
            SELECT i.AppointmentID, i.PatientID, i.DoctorID, i.ApptDate
            FROM inserted i JOIN deleted d ON d.AppointmentID = i.AppointmentID
            WHERE i.Status = 'Completed' AND d.Status <> 'Completed';

        OPEN cur;
        FETCH NEXT FROM cur INTO @ApptID, @PatID, @DocID, @ApptDate;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF EXISTS (SELECT 1 FROM Billing WHERE AppointmentID = @ApptID)
            BEGIN
                CLOSE cur; DEALLOCATE cur;
                ;THROW 50200, 'Bill already exists for this appointment.', 1;
            END;

            DECLARE @Fee    DECIMAL(10,2),
                    @Med    DECIMAL(10,2),
                    @Lab    DECIMAL(10,2),
                    @Ins    DECIMAL(5,2),
                    @Disc   DECIMAL(10,2),
                    @NetMed DECIMAL(10,2),
                    @NetLab DECIMAL(10,2),
                    @GSTMed DECIMAL(10,2),
                    @GSTLab DECIMAL(10,2),
                    @Final  DECIMAL(12,2),
                    @Unpaid DECIMAL(12,2);

            SELECT @Fee = ConsultFee FROM Doctors WHERE DoctorID = @DocID;

            SELECT @Med = ISNULL(SUM(m.UnitPrice * p.Quantity), 0)
            FROM Prescriptions p JOIN Medicines m ON m.MedicineID = p.MedicineID
            WHERE p.AppointmentID = @ApptID;

            SELECT @Lab = ISNULL(SUM(lt.Price), 0)
            FROM LabOrders lo JOIN LabTests lt ON lt.LabTestID = lo.LabTestID
            WHERE lo.AppointmentID = @ApptID;

            SELECT @Ins = ISNULL(CoveragePercent, 0)
            FROM InsurancePolicies
            WHERE PatientID = @PatID AND StartDate <= @ApptDate AND EndDate >= @ApptDate;

            SET @Ins    = ISNULL(@Ins, 0);
            SET @Disc   = ROUND(@Ins/100.0 * (@Med+@Lab), 2);
            SET @NetMed = @Med - CASE WHEN (@Med+@Lab)>0
                                      THEN ROUND(@Disc*@Med/(@Med+@Lab),2) ELSE 0 END;
            SET @NetLab = @Lab - CASE WHEN (@Med+@Lab)>0
                                      THEN ROUND(@Disc*@Lab/(@Med+@Lab),2) ELSE 0 END;
            SET @GSTMed = ROUND(0.05*@NetMed, 2);
            SET @GSTLab = ROUND(0.12*@NetLab, 2);
            SET @Final  = @Fee + @NetMed + @GSTMed + @NetLab + @GSTLab;

            SELECT @Unpaid = ISNULL(SUM(b2.FinalAmount), 0)
            FROM Billing b2 JOIN Appointments a2 ON a2.AppointmentID = b2.AppointmentID
            WHERE a2.PatientID = @PatID AND b2.PaymentStatus <> 'Paid';

            IF (@Unpaid + @Final) > 200000.00
            BEGIN
                CLOSE cur; DEALLOCATE cur;
                ;THROW 50201, 'Patient unpaid bill limit of Rs. 2,00,000 would be exceeded.', 1;
            END;

            INSERT INTO Billing (
                AppointmentID, ConsultCharge, MedicineCharge, LabCharge,
                InsuranceDiscount, GSTOnConsult, GSTOnMedicine, GSTOnLab,
                FinalAmount, PaymentStatus
            ) VALUES (
                @ApptID, @Fee, @Med, @Lab,
                @Disc, 0, @GSTMed, @GSTLab, @Final, 'Unpaid'
            );

            FETCH NEXT FROM cur INTO @ApptID, @PatID, @DocID, @ApptDate;
        END;
        CLOSE cur; DEALLOCATE cur;
    END TRY
    BEGIN CATCH
        IF CURSOR_STATUS('local','cur') >= 0
        BEGIN CLOSE cur; DEALLOCATE cur; END;
        ;THROW;
    END CATCH;
END;
GO

-- ------------------------------------------------------------
-- B3: trg_FlagFollowUpOnAbnormalLab
-- Sets RequiresFollowUp on MedicalRecord when IsAbnormal=1.
-- Prints warning (no rollback) if no medical record exists.
-- ------------------------------------------------------------
CREATE OR ALTER TRIGGER dbo.trg_FlagFollowUpOnAbnormalLab
ON LabOrders
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted WHERE IsAbnormal = 1) RETURN;

    UPDATE mr
    SET    mr.RequiresFollowUp = 1
    FROM   MedicalRecords mr
    JOIN   inserted i ON i.AppointmentID = mr.AppointmentID
    WHERE  i.IsAbnormal = 1;

    IF EXISTS (
        SELECT 1 FROM inserted i
        LEFT JOIN MedicalRecords mr ON mr.AppointmentID = i.AppointmentID
        WHERE i.IsAbnormal = 1 AND mr.RecordID IS NULL
    )
    PRINT 'WARNING: Abnormal result saved but no medical record found. Follow-up flag not set.';
END;
GO

-- ============================================================
-- SECTION 08 — ADVANCED STANDALONE QUERIES (Section D)
-- ============================================================

-- D1: Top 3 revenue-generating doctors per department
-- Uses DENSE_RANK() window function
WITH DoctorRevenue AS (
    SELECT
        dept.DeptName                          AS DepartmentName,
        d.FirstName + ' ' + d.LastName         AS DoctorName,
        SUM(b.FinalAmount)                     AS TotalRevenue,
        DENSE_RANK() OVER (
            PARTITION BY dept.DepartmentID
            ORDER BY SUM(b.FinalAmount) DESC
        )                                      AS RevenueRank
    FROM Doctors d
    JOIN Departments  dept ON dept.DepartmentID = d.DepartmentID
    JOIN Appointments a    ON a.DoctorID        = d.DoctorID AND a.Status = 'Completed'
    JOIN Billing      b    ON b.AppointmentID   = a.AppointmentID
    GROUP BY dept.DepartmentID, dept.DeptName,
             d.DoctorID, d.FirstName, d.LastName
)
SELECT DepartmentName, DoctorName, TotalRevenue, RevenueRank
FROM   DoctorRevenue
WHERE  RevenueRank <= 3
ORDER  BY DepartmentName, RevenueRank;
GO

-- D2: Running monthly cumulative revenue
-- Uses SUM() OVER window function
SELECT
    FORMAT(DATEFROMPARTS(BillYear, BillMonth, 1), 'MMM yyyy') AS MonthYear,
    MonthlyRevenue,
    SUM(MonthlyRevenue) OVER (
        ORDER BY BillYear, BillMonth
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                          AS CumulativeRevenue
FROM (
    SELECT
        YEAR(BilledOn)   AS BillYear,
        MONTH(BilledOn)  AS BillMonth,
        SUM(FinalAmount) AS MonthlyRevenue
    FROM Billing
    GROUP BY YEAR(BilledOn), MONTH(BilledOn)
) sub
ORDER BY BillYear, BillMonth;
GO

-- ============================================================
-- SECTION 09 — SECURITY: ROLES & PERMISSIONS
-- ============================================================

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='db_receptionist' AND type='R')
    CREATE ROLE db_receptionist;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='db_doctor'       AND type='R')
    CREATE ROLE db_doctor;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='db_lab_tech'     AND type='R')
    CREATE ROLE db_lab_tech;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='db_billing'      AND type='R')
    CREATE ROLE db_billing;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='db_admin'        AND type='R')
    CREATE ROLE db_admin;
GO

-- db_receptionist
GRANT SELECT, INSERT ON dbo.vw_PatientBasic TO db_receptionist;
GRANT SELECT, INSERT ON dbo.Patients        TO db_receptionist;
GRANT SELECT, INSERT ON dbo.Appointments    TO db_receptionist;
DENY  SELECT         ON dbo.Billing         TO db_receptionist;
DENY  SELECT         ON dbo.MedicalRecords  TO db_receptionist;
DENY  SELECT         ON dbo.Prescriptions   TO db_receptionist;
DENY  SELECT         ON dbo.LabOrders       TO db_receptionist;
GO

-- db_doctor
GRANT SELECT              ON dbo.vw_PatientBasic  TO db_doctor;
GRANT SELECT              ON dbo.Patients         TO db_doctor;
GRANT SELECT              ON dbo.Appointments     TO db_doctor;
GRANT SELECT, INSERT, UPDATE ON dbo.MedicalRecords TO db_doctor;
GRANT SELECT, INSERT, UPDATE ON dbo.Prescriptions  TO db_doctor;
GRANT SELECT, INSERT, UPDATE ON dbo.LabOrders      TO db_doctor;
GRANT SELECT              ON dbo.Medicines        TO db_doctor;
GRANT SELECT              ON dbo.LabTests         TO db_doctor;
DENY  SELECT              ON dbo.Billing          TO db_doctor;
GO

-- db_lab_tech
GRANT SELECT ON dbo.LabTests            TO db_lab_tech;
GRANT SELECT ON dbo.vw_LabOrdersForTech TO db_lab_tech;
GRANT UPDATE ON dbo.LabOrders           TO db_lab_tech;
DENY  SELECT ON dbo.Patients            TO db_lab_tech;
DENY  SELECT ON dbo.Billing             TO db_lab_tech;
DENY  SELECT ON dbo.MedicalRecords      TO db_lab_tech;
DENY  SELECT ON dbo.Prescriptions       TO db_lab_tech;
GO

-- db_billing
GRANT SELECT, INSERT, UPDATE ON dbo.Billing              TO db_billing;
GRANT SELECT                 ON dbo.vw_PatientForBilling  TO db_billing;
DENY  SELECT ON dbo.Patients       TO db_billing;
DENY  SELECT ON dbo.MedicalRecords TO db_billing;
DENY  SELECT ON dbo.Prescriptions  TO db_billing;
GO

-- db_admin
GRANT CONTROL ON DATABASE::MediCarePlus TO db_admin;
GO

-- ============================================================
-- SECTION 10 — ADDITIONAL BUSINESS RULE TRIGGERS
-- ============================================================

-- Bill only allowed for Completed appointments
CREATE OR ALTER TRIGGER dbo.trg_BillOnlyForCompleted
ON Billing
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
        SELECT 1 FROM inserted i
        JOIN Appointments a ON a.AppointmentID = i.AppointmentID
        WHERE a.Status <> 'Completed'
    )
    BEGIN
        ROLLBACK TRANSACTION;
        ;THROW 50400, 'A bill can only be created for a Completed appointment.', 1;
    END;
END;
GO

-- Patient unpaid total must not exceed Rs. 2,00,000
CREATE OR ALTER TRIGGER dbo.trg_EnforceUnpaidBillLimit
ON Billing
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        IF EXISTS (
            SELECT 1
            FROM (
                SELECT a.PatientID, SUM(b2.FinalAmount) AS TotalUnpaid
                FROM inserted i
                JOIN Appointments a  ON a.AppointmentID = i.AppointmentID
                JOIN Billing      b2 ON b2.AppointmentID IN (
                    SELECT b3.AppointmentID FROM Billing b3
                    JOIN Appointments a3 ON a3.AppointmentID = b3.AppointmentID
                    WHERE a3.PatientID = a.PatientID AND b3.PaymentStatus <> 'Paid'
                )
                GROUP BY a.PatientID
            ) u
            WHERE u.TotalUnpaid > 200000.00
        )
        BEGIN
            ROLLBACK TRANSACTION;
            ;THROW 50300, 'Patient unpaid bill limit of Rs. 2,00,000 exceeded.', 1;
        END;
    END TRY
    BEGIN CATCH
        ;THROW;
    END CATCH;
END;
GO

-- ============================================================
-- END OF SCRIPT
-- ============================================================
-- Tables     : 12  Departments, Doctors, DoctorSchedules,
--                  Patients, InsurancePolicies, Appointments,
--                  MedicalRecords, Medicines, Prescriptions,
--                  LabTests, LabOrders, Billing
-- Views      : 3   vw_PatientBasic, vw_PatientForBilling,
--                  vw_LabOrdersForTech
-- Functions  : 2   fn_GetPatientAge, fn_CalculateNetBill
-- Procedures : 5   A1-A5
-- Triggers   : 5   B1-B3, trg_BillOnlyForCompleted,
--                  trg_EnforceUnpaidBillLimit
-- Roles      : 5   db_receptionist, db_doctor, db_lab_tech,
--                  db_billing, db_admin
-- Queries    : 2   D1 (DENSE_RANK), D2 (running total)
-- ============================================================

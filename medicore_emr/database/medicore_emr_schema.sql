-- ============================================================
-- MediCore EMR — Complete Relational Database Schema (MySQL 8.0+)
-- Architecture: Normalized to Third Normal Form (3NF)
-- System: Electronic Medical Records & Clinical Management
-- ============================================================

CREATE DATABASE IF NOT EXISTS medicore_emr
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE medicore_emr;

-- ============================================================
-- 1. ROLES
-- ============================================================
CREATE TABLE IF NOT EXISTS roles (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(50)  NOT NULL UNIQUE,
  description VARCHAR(255) NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- 2. USERS (Doctors, Administrators, Nurses, Staff)
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  full_name     VARCHAR(150) NOT NULL,
  email         VARCHAR(150) NOT NULL UNIQUE,
  provider_id   VARCHAR(50)  NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role_id       INT          NOT NULL,
  is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
  last_login    TIMESTAMP    NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_users_role FOREIGN KEY (role_id) REFERENCES roles(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  INDEX idx_users_email (email),
  INDEX idx_users_provider_id (provider_id),
  INDEX idx_users_role_id (role_id)
) ENGINE=InnoDB;

-- ============================================================
-- 3. DEPARTMENTS / SPECIALTIES
-- ============================================================
CREATE TABLE IF NOT EXISTS departments (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  name        VARCHAR(100) NOT NULL UNIQUE,
  description VARCHAR(255) NULL,
  created_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- 4. SERVICES (Catalogue)
-- ============================================================
CREATE TABLE IF NOT EXISTS services (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(150) NOT NULL,
  department_id INT          NOT NULL,
  base_cost     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  duration_min  INT          NOT NULL DEFAULT 30,
  is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_services_department FOREIGN KEY (department_id) REFERENCES departments(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  INDEX idx_services_department (department_id)
) ENGINE=InnoDB;

-- ============================================================
-- 5. PATIENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS patients (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  patient_code    VARCHAR(30)  NOT NULL UNIQUE,
  full_name       VARCHAR(200) NOT NULL,
  identity_number VARCHAR(50)  NULL UNIQUE,
  birth_date      DATE         NULL,
  gender          ENUM('Masculino','Femenino','Otro') NULL,
  phone           VARCHAR(30)  NULL,
  email           VARCHAR(150) NULL,
  address         TEXT         NULL,
  blood_type      VARCHAR(10)  NULL,
  photo_url       VARCHAR(500) NULL,
  is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_patients_code (patient_code),
  INDEX idx_patients_name (full_name),
  INDEX idx_patients_identity (identity_number),
  INDEX idx_patients_active (is_active)
) ENGINE=InnoDB;

-- ============================================================
-- 6. EMERGENCY CONTACTS
-- ============================================================
CREATE TABLE IF NOT EXISTS emergency_contacts (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  patient_id    INT          NOT NULL,
  contact_name  VARCHAR(200) NOT NULL,
  relationship  VARCHAR(50)  NOT NULL,
  phone         VARCHAR(30)  NOT NULL,
  created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_emergency_patient FOREIGN KEY (patient_id) REFERENCES patients(id)
    ON UPDATE CASCADE ON DELETE CASCADE,

  INDEX idx_emergency_patient (patient_id)
) ENGINE=InnoDB;

-- ============================================================
-- 7. ALLERGY ALERTS
-- ============================================================
CREATE TABLE IF NOT EXISTS allergy_alerts (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  patient_id      INT          NOT NULL,
  allergen        VARCHAR(200) NOT NULL,
  reaction        VARCHAR(300) NOT NULL,
  severity        ENUM('Leve','Moderada','Severa') NOT NULL DEFAULT 'Leve',
  documented_date DATE         NULL,
  is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_allergy_patient FOREIGN KEY (patient_id) REFERENCES patients(id)
    ON UPDATE CASCADE ON DELETE CASCADE,

  INDEX idx_allergy_patient (patient_id),
  INDEX idx_allergy_severity (severity)
) ENGINE=InnoDB;

-- ============================================================
-- 8. APPOINTMENTS
-- ============================================================
CREATE TABLE IF NOT EXISTS appointments (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  patient_id       INT          NOT NULL,
  doctor_id        INT          NOT NULL,
  service_id       INT          NOT NULL,
  appointment_date DATE         NOT NULL,
  appointment_time TIME         NOT NULL,
  status           ENUM('Waiting','Confirmed','In Progress','Completed','Cancelled') NOT NULL DEFAULT 'Waiting',
  notes            TEXT         NULL,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_appointments_patient FOREIGN KEY (patient_id) REFERENCES patients(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_appointments_doctor FOREIGN KEY (doctor_id) REFERENCES users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_appointments_service FOREIGN KEY (service_id) REFERENCES services(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  INDEX idx_appointments_date (appointment_date),
  INDEX idx_appointments_patient (patient_id),
  INDEX idx_appointments_doctor (doctor_id),
  INDEX idx_appointments_status (status)
) ENGINE=InnoDB;

-- ============================================================
-- 9. CLINICAL RECORDS (Timeline)
-- ============================================================
CREATE TABLE IF NOT EXISTS clinical_records (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  patient_id   INT          NOT NULL,
  doctor_id    INT          NOT NULL,
  record_type  VARCHAR(80)  NOT NULL,
  title        VARCHAR(300) NOT NULL,
  description  TEXT         NULL,
  record_date  DATETIME     NOT NULL,
  tags         JSON         NULL,
  created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_clinical_patient FOREIGN KEY (patient_id) REFERENCES patients(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_clinical_doctor FOREIGN KEY (doctor_id) REFERENCES users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  INDEX idx_clinical_patient (patient_id),
  INDEX idx_clinical_doctor (doctor_id),
  INDEX idx_clinical_date (record_date),
  INDEX idx_clinical_type (record_type)
) ENGINE=InnoDB;

-- ============================================================
-- 10. SOAP CONSULTATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS soap_consultations (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  patient_id       INT          NOT NULL,
  doctor_id        INT          NOT NULL,
  consultation_date DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  subjective       TEXT         NULL,
  objective        TEXT         NULL,
  icd10_code       VARCHAR(50)  NULL,
  assessment       TEXT         NULL,
  plan             TEXT         NULL,
  status           ENUM('Draft','Finalized') NOT NULL DEFAULT 'Draft',
  signed_at        DATETIME     NULL,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_soap_patient FOREIGN KEY (patient_id) REFERENCES patients(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_soap_doctor FOREIGN KEY (doctor_id) REFERENCES users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  INDEX idx_soap_patient (patient_id),
  INDEX idx_soap_doctor (doctor_id),
  INDEX idx_soap_date (consultation_date),
  INDEX idx_soap_status (status)
) ENGINE=InnoDB;

-- ============================================================
-- 11. VITAL SIGNS (1:1 with Consultation or Standalone)
-- ============================================================
CREATE TABLE IF NOT EXISTS vital_signs (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  consultation_id  INT          NULL,
  patient_id       INT          NOT NULL,
  bp_systolic      INT          NOT NULL DEFAULT 120,
  bp_diastolic     INT          NOT NULL DEFAULT 80,
  pulse            INT          NOT NULL DEFAULT 72,
  temperature      DECIMAL(4,1) NOT NULL DEFAULT 36.5,
  weight_kg        DECIMAL(5,2) NOT NULL DEFAULT 70.00,
  height_cm        DECIMAL(5,2) NOT NULL DEFAULT 175.00,
  bmi              DECIMAL(4,1) GENERATED ALWAYS AS (ROUND(weight_kg / ((height_cm/100)*(height_cm/100)), 1)) STORED,
  measured_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_vitals_consultation FOREIGN KEY (consultation_id) REFERENCES soap_consultations(id)
    ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT fk_vitals_patient FOREIGN KEY (patient_id) REFERENCES patients(id)
    ON UPDATE CASCADE ON DELETE CASCADE,

  INDEX idx_vitals_patient (patient_id),
  INDEX idx_vitals_consultation (consultation_id)
) ENGINE=InnoDB;

-- ============================================================
-- 12. PRESCRIPTIONS (Recetas Médicas)
-- ============================================================
CREATE TABLE IF NOT EXISTS prescriptions (
  id                    INT AUTO_INCREMENT PRIMARY KEY,
  patient_id            INT          NOT NULL,
  doctor_id             INT          NOT NULL,
  clinic_name           VARCHAR(150) NOT NULL DEFAULT 'Clínica Sanitas Central',
  clinic_address        VARCHAR(255) NOT NULL DEFAULT 'Av. Principal 123, Ciudad • Tel: 555-0192',
  prescription_date     DATE         NOT NULL,
  created_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at            TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_rx_patient FOREIGN KEY (patient_id) REFERENCES patients(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_rx_doctor FOREIGN KEY (doctor_id) REFERENCES users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  INDEX idx_rx_patient (patient_id),
  INDEX idx_rx_doctor (doctor_id),
  INDEX idx_rx_date (prescription_date)
) ENGINE=InnoDB;

-- ============================================================
-- 13. PRESCRIPTION ITEMS (Medicamentos Recetados)
-- ============================================================
CREATE TABLE IF NOT EXISTS prescription_items (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  prescription_id  INT          NOT NULL,
  drug_name        VARCHAR(200) NOT NULL,
  dose             VARCHAR(100) NOT NULL,
  frequency        VARCHAR(100) NOT NULL,
  duration         VARCHAR(100) NOT NULL,
  instructions     TEXT         NULL,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_rx_items_prescription FOREIGN KEY (prescription_id) REFERENCES prescriptions(id)
    ON UPDATE CASCADE ON DELETE CASCADE,

  INDEX idx_rx_items_prescription (prescription_id)
) ENGINE=InnoDB;

-- ============================================================
-- 14. DIAGNOSTIC FILES (Imaging, Lab Results, Docs)
-- ============================================================
CREATE TABLE IF NOT EXISTS diagnostic_files (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  patient_id       INT          NOT NULL,
  uploaded_by_id   INT          NULL,
  file_name        VARCHAR(255) NOT NULL,
  category         ENUM('Lab Results','Imaging','Referrals','Dermatology','Other') NOT NULL DEFAULT 'Other',
  file_url         VARCHAR(500) NOT NULL,
  file_size        VARCHAR(50)  NOT NULL DEFAULT '2.4 MB',
  total_pages      INT          NOT NULL DEFAULT 1,
  mime_type        VARCHAR(100) NOT NULL DEFAULT 'application/pdf',
  upload_date      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_diag_patient FOREIGN KEY (patient_id) REFERENCES patients(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_diag_uploader FOREIGN KEY (uploaded_by_id) REFERENCES users(id)
    ON UPDATE CASCADE ON DELETE SET NULL,

  INDEX idx_diag_patient (patient_id),
  INDEX idx_diag_category (category),
  INDEX idx_diag_date (upload_date)
) ENGINE=InnoDB;

-- ============================================================
-- 15. ODONTOGRAM FINDINGS & PROCEDURES
-- ============================================================
CREATE TABLE IF NOT EXISTS odontogram_findings (
  id               INT AUTO_INCREMENT PRIMARY KEY,
  patient_id       INT          NOT NULL,
  provider_id      INT          NOT NULL,
  tooth_number     INT          NOT NULL, -- FDI Numbering (11-48)
  condition_type   ENUM('Healthy','Caries','Treated','Missing') NOT NULL DEFAULT 'Healthy',
  surfaces         JSON         NULL, -- ["M", "O", "D", "B", "L"]
  procedure_name   VARCHAR(200) NOT NULL,
  status           ENUM('Pending','Completed','Cancelled') NOT NULL DEFAULT 'Pending',
  notes            TEXT         NULL,
  finding_date     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at       TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_odonto_patient FOREIGN KEY (patient_id) REFERENCES patients(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_odonto_provider FOREIGN KEY (provider_id) REFERENCES users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  INDEX idx_odonto_patient (patient_id),
  INDEX idx_odonto_tooth (tooth_number),
  INDEX idx_odonto_condition (condition_type),
  INDEX idx_odonto_status (status)
) ENGINE=InnoDB;

-- ============================================================
-- 16. PEDIATRIC GROWTH RECORDS (WHO / OMS Standard)
-- ============================================================
CREATE TABLE IF NOT EXISTS pediatric_growth_records (
  id                     INT AUTO_INCREMENT PRIMARY KEY,
  patient_id             INT          NOT NULL,
  provider_id            INT          NOT NULL,
  measurement_date       DATE         NOT NULL,
  age_label              VARCHAR(50)  NOT NULL, -- 'Nacimiento', '6m', '1a', '2a 4m'
  age_months             DECIMAL(4,1) NOT NULL,
  weight_kg              DECIMAL(5,2) NOT NULL,
  weight_percentile      INT          NOT NULL,
  height_cm              DECIMAL(5,2) NOT NULL,
  height_percentile      INT          NOT NULL,
  head_circumference_cm  DECIMAL(4,1) NOT NULL,
  notes                  TEXT         NULL,
  created_at             TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at             TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_growth_patient FOREIGN KEY (patient_id) REFERENCES patients(id)
    ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_growth_provider FOREIGN KEY (provider_id) REFERENCES users(id)
    ON UPDATE CASCADE ON DELETE RESTRICT,

  INDEX idx_growth_patient (patient_id),
  INDEX idx_growth_date (measurement_date),
  INDEX idx_growth_age (age_months)
) ENGINE=InnoDB;


-- ============================================================
-- SEED DATA
-- ============================================================

-- Roles
INSERT INTO roles (name, description) VALUES
  ('Admin',     'System Administrator'),
  ('Doctor',    'Medical Doctor / Provider'),
  ('Nurse',     'Nursing Staff'),
  ('Reception', 'Front Desk / Reception')
ON DUPLICATE KEY UPDATE name=name;

-- Users
INSERT INTO users (full_name, email, provider_id, password_hash, role_id) VALUES
  ('Dr. Smith',          'dr.smith@medicore.com',    'DRS-001', '$2b$12$placeholder_hash_smith',    2),
  ('Dr. Carlos Mendoza', 'dr.mendoza@medicore.com',  'DRM-002', '$2b$12$placeholder_hash_mendoza',  2),
  ('Dr. Rodriguez',      'dr.rodriguez@medicore.com','DRR-003', '$2b$12$placeholder_hash_rodriguez',2),
  ('Dr. Martinez',       'dr.martinez@medicore.com', 'DRM-004', '$2b$12$placeholder_hash_martinez', 2),
  ('Nurse Adams',        'nurse.adams@medicore.com', 'NUR-001', '$2b$12$placeholder_hash_adams',    3),
  ('Admin Principal',    'admin@medicore.com',       'ADM-001', '$2b$12$placeholder_hash_admin',    1)
ON DUPLICATE KEY UPDATE full_name=full_name;

-- Departments
INSERT INTO departments (name, description) VALUES
  ('Medicina General',  'Consulta general y medicina interna'),
  ('Odontología',       'Servicios odontológicos integrales'),
  ('Pediatría',         'Atención y seguimiento pediátrico OMS'),
  ('Radiología',        'Estudios de imagen y diagnóstico')
ON DUPLICATE KEY UPDATE name=name;

-- Services
INSERT INTO services (name, department_id, base_cost, duration_min) VALUES
  ('General Checkup',     1, 500.00,  30),
  ('Odontology Consult',  2, 800.00,  45),
  ('Pediatrics - Vaccine',3, 350.00,  20),
  ('Radiografía Lumbar',  4, 1200.00, 15),
  ('Medicina Interna',    1, 700.00,  40)
ON DUPLICATE KEY UPDATE name=name;

-- Patients
INSERT INTO patients (id, patient_code, full_name, identity_number, birth_date, gender, phone, email, address, blood_type) VALUES
  (1, 'PT-8492',     'Ana Martínez Silva',     'INE-8492-A', '1978-03-15', 'Femenino',  '+52 55 1234 5678', 'ana.martinez@email.com',  'Av. Insurgentes 100, CDMX',                   'A+'),
  (2, 'PT-3104',     'Carlos Ruiz Torres',     'INE-3104-B', '1991-07-22', 'Masculino', '+52 55 9876 5432', 'carlos.ruiz@email.com',   'Col. Roma Norte, CDMX',                       'B+'),
  (3, 'PT-9921',     'Laura Gómez Pérez',      'INE-9921-C', '1955-11-08', 'Femenino',  '+52 33 4455 6677', 'laura.gomez@email.com',   'Guadalajara, Jalisco',                        'O-'),
  (4, 'PT-1045',     'Miguel Vargas López',    'INE-1045-D', '1994-05-30', 'Masculino', '+52 81 2233 4455', 'miguel.vargas@email.com', 'Monterrey, Nuevo León',                       'AB+'),
  (5, 'PTR-8492-XA', 'Juan Carlos Mendoza',    'INE-JCM-01', '1978-08-14', 'Masculino', '+52 (55) 1234-5678', 'jc.mendoza@email.com',    'Av. Reforma 222, Int 14. Col. Juárez, CDMX.', 'O+'),
  (6, 'PT-8472',     'Ana García López',       'INE-8472-G', '1989-10-12', 'Femenino',  '+52 55 4321 8765', 'ana.garcia@email.com',    'Col. Condesa, CDMX',                          'A+'),
  (7, 'PT-88241',    'Sarah Jenkins',          'MRN-88241',  '1985-12-04', 'Femenino',  '+1 555 987 6543',  'sarah.j@email.com',       'San Diego, CA',                               'A+'),
  (8, 'P-8472',      'Mateo Garcia',           'CURP-MG-01', '2021-06-15', 'Masculino', '+52 55 8899 0011', 'padres.mateo@email.com',  'Polanco, CDMX',                               'O+'),
  (9, 'MRN-84729',   'John Doe',               'MRN-84729',  '1980-12-04', 'Masculino', '+1 555 123 9988',  'john.doe@email.com',      'Los Angeles, CA',                             'O+')
ON DUPLICATE KEY UPDATE full_name=full_name;

-- Emergency Contacts
INSERT INTO emergency_contacts (patient_id, contact_name, relationship, phone) VALUES
  (1, 'Roberto Martínez', 'Esposo',  '+52 55 1111 2222'),
  (2, 'María Torres',     'Madre',   '+52 55 3333 4444'),
  (5, 'Elena Mendoza',    'Esposa',  '+52 55 5678-1234'),
  (6, 'Mario García',     'Hermano', '+52 55 4444 5555'),
  (8, 'Sofía Hernández',  'Madre',   '+52 55 8899 0011');

-- Allergy Alerts
INSERT INTO allergy_alerts (patient_id, allergen, reaction, severity, documented_date) VALUES
  (3, 'Aspirina',    'Urticaria',                     'Moderada', '2020-03-15'),
  (5, 'Penicilina',  'Reacción Anafiláctica Severa',  'Severa',   '2021-05-12'),
  (6, 'Penicilina',  'Erupción cutánea y prurito',    'Moderada', '2022-04-10');

-- Appointments (Today)
INSERT INTO appointments (patient_id, doctor_id, service_id, appointment_date, appointment_time, status) VALUES
  (1, 1, 1, CURDATE(), '09:00:00', 'Waiting'),
  (2, 1, 2, CURDATE(), '09:30:00', 'Confirmed'),
  (4, 1, 3, CURDATE(), '10:15:00', 'Confirmed');

-- Clinical Records (Timeline)
INSERT INTO clinical_records (patient_id, doctor_id, record_type, title, description, record_date, tags) VALUES
  (5, 3, 'CONSULTA GENERAL', 'Control Anual y Revisión de Laboratorios',
   'Paciente acude para revisión de rutina. Refiere dolor leve en zona lumbar tras esfuerzo físico. Laboratorios dentro de parámetros normales excepto colesterol ligeramente elevado.',
   '2023-10-24 10:30:00', '["Dr. Rodriguez", "Medicina Interna"]'),
  (5, 4, 'ESTUDIO DE IMAGEN', 'Radiografía Lumbar AP/Lateral',
   'Solicitado por Dr. Martínez por lumbalgia persistente. Resultados pendientes de interpretación formal.',
   '2023-09-15 08:15:00', NULL);

-- Prescriptions & Items
INSERT INTO prescriptions (id, patient_id, doctor_id, clinic_name, clinic_address, prescription_date) VALUES
  (1, 6, 2, 'Clínica Sanitas Central', 'Av. Principal 123, Ciudad • Tel: 555-0192', '2023-10-24')
ON DUPLICATE KEY UPDATE clinic_name=clinic_name;

INSERT INTO prescription_items (prescription_id, drug_name, dose, frequency, duration, instructions) VALUES
  (1, 'Ibuprofeno 600mg', '1 comprimido', 'Cada 8h', '5 días', 'Tomar 1 comprimido cada 8h durante 5 días.'),
  (1, 'Omeprazol 20mg',   '1 cápsula',    'Cada 24h (mañanas)', '14 días', 'Tomar 1 cápsula cada 24h (mañanas) durante 14 días. Tomar en ayunas.');

-- Diagnostic Files
INSERT INTO diagnostic_files (patient_id, uploaded_by_id, file_name, category, file_url, file_size, total_pages, mime_type, upload_date) VALUES
  (9, 4, 'Chest_XRay_AP.dcm',       'Imaging',     'https://example.com/files/chest.dcm',     '18.4 MB', 1, 'image/jpeg',      '2023-10-12 11:20:00'),
  (9, 5, 'Blood_Panel_Q3.pdf',      'Lab Results', 'https://example.com/files/blood_panel.pdf','2.4 MB',  3, 'application/pdf','2023-10-10 14:32:00'),
  (9, 1, 'Referral_Cardio.pdf',     'Referrals',   'https://example.com/files/referral.pdf',   '850 KB',  1, 'application/pdf','2023-09-28 09:15:00'),
  (9, 1, 'Dermatology_Biopsy.pdf',  'Dermatology', 'https://example.com/files/biopsy.pdf',     '4.1 MB',  2, 'application/pdf','2023-09-15 16:40:00');

-- Odontogram Findings
INSERT INTO odontogram_findings (patient_id, provider_id, tooth_number, condition_type, surfaces, procedure_name, status, finding_date) VALUES
  (7, 1, 16, 'Caries',  '["M", "O", "D"]', 'Composite Restoration (MOD)', 'Pending',   '2023-10-15 10:00:00'),
  (7, 1, 14, 'Treated', '["O"]',            'Root Canal Therapy',          'Completed', '2023-09-02 11:30:00'),
  (7, 1, 26, 'Treated', '["O", "B"]',       'Crown Prep & Delivery',       'Completed', '2022-11-20 09:15:00');

-- Pediatric Growth Records (WHO)
INSERT INTO pediatric_growth_records (patient_id, provider_id, measurement_date, age_label, age_months, weight_kg, weight_percentile, height_cm, height_percentile, head_circumference_cm) VALUES
  (8, 1, '2023-10-12', '2a 4m',      28.0, 14.2, 65, 92.0, 70, 49.0),
  (8, 1, '2023-06-15', '2a',         24.0, 12.5, 55, 87.0, 60, 48.0),
  (8, 1, '2022-12-10', '1a 6m',      18.0, 11.1, 50, 82.0, 50, 47.0),
  (8, 1, '2022-06-14', '1a',         12.0,  9.8, 45, 75.0, 40, 46.0),
  (8, 1, '2021-12-15', '6m',          6.0,  7.9, 50, 67.0, 45, 43.0),
  (8, 1, '2021-06-15', 'Nacimiento',  0.0,  3.4, 50, 50.0, 50, 35.0);

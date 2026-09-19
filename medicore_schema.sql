-- ============================================================================
-- SCRIPT DE BASE DE DATOS RELACIONAL: MEDICORE EMR (SISTEMA DE SALUD CLÍNICO)
-- Motor: MySQL 8.0+ / MySQL Workbench
-- Normalización: 3FN (Tercera Forma Normal)
-- Charset: utf8mb4 / Collation: utf8mb4_unicode_ci
-- ============================================================================

CREATE DATABASE IF NOT EXISTS `medicore_emr_db`
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE `medicore_emr_db`;

-- Desactivar temporalmente revisión de claves foráneas para creación limpia
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS `audit_logs`;
DROP TABLE IF EXISTS `user_preferences`;
DROP TABLE IF EXISTS `database_backups`;
DROP TABLE IF EXISTS `financial_transactions`;
DROP TABLE IF EXISTS `pediatric_growth_records`;
DROP TABLE IF EXISTS `odontology_findings`;
DROP TABLE IF EXISTS `odontology_charts`;
DROP TABLE IF EXISTS `diagnostic_files`;
DROP TABLE IF EXISTS `prescription_items`;
DROP TABLE IF EXISTS `prescriptions`;
DROP TABLE IF EXISTS `consultation_diagnoses`;
DROP TABLE IF EXISTS `diagnoses_icd10`;
DROP TABLE IF EXISTS `vital_signs`;
DROP TABLE IF EXISTS `soap_consultations`;
DROP TABLE IF EXISTS `appointments`;
DROP TABLE IF EXISTS `patient_allergies`;
DROP TABLE IF EXISTS `patients`;
DROP TABLE IF EXISTS `clinics`;
DROP TABLE IF EXISTS `users`;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- 1. TABLA: clinics (Información de Establecimientos Médicos / Sucursales)
-- ============================================================================
CREATE TABLE `clinics` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(150) NOT NULL,
  `address` VARCHAR(255) NOT NULL,
  `phone` VARCHAR(30) NOT NULL,
  `email` VARCHAR(120) NOT NULL,
  `tax_id` VARCHAR(50) NULL COMMENT 'RFC / RUC / NIF de la clínica',
  `schedule_weekdays` VARCHAR(100) DEFAULT '08:00 - 18:00',
  `schedule_saturday` VARCHAR(100) DEFAULT '08:00 - 14:00',
  `schedule_sunday` VARCHAR(100) DEFAULT 'Cerrado',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_clinics_name` (`name`),
  INDEX `idx_clinics_is_active` (`is_active`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 2. TABLA: users (Médicos, Especialistas, Enfermeros y Personal Administrativo)
-- ============================================================================
CREATE TABLE `users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `clinic_id` BIGINT UNSIGNED NOT NULL,
  `provider_code` VARCHAR(50) NOT NULL UNIQUE COMMENT 'ID institucional ej. DRS-001',
  `full_name` VARCHAR(150) NOT NULL,
  `email` VARCHAR(120) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `master_key_hash` VARCHAR(255) NULL COMMENT 'Hash de Llave Maestra para cifrado local',
  `phone` VARCHAR(30) NULL,
  `role` ENUM('ADMIN', 'DOCTOR', 'NURSE', 'RECEPTIONIST') NOT NULL DEFAULT 'DOCTOR',
  `specialty` VARCHAR(100) NULL COMMENT 'Ej. Medicina General, Pediatría, Odontología',
  `professional_license` VARCHAR(80) NULL COMMENT 'Cédula o Matrícula Profesional',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `last_login_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_users_clinic` FOREIGN KEY (`clinic_id`)
    REFERENCES `clinics` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX `idx_users_email` (`email`),
  INDEX `idx_users_provider_code` (`provider_code`),
  INDEX `idx_users_role` (`role`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 3. TABLA: patients (Expedientes Demográficos de Pacientes)
-- ============================================================================
CREATE TABLE `patients` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `clinic_id` BIGINT UNSIGNED NOT NULL,
  `patient_code` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Ej. PT-8472 / DNI',
  `national_id` VARCHAR(50) NOT NULL UNIQUE COMMENT 'DNI / CURP / Cédula de Identidad',
  `first_name` VARCHAR(80) NOT NULL,
  `last_name` VARCHAR(80) NOT NULL,
  `birth_date` DATE NOT NULL,
  `gender` ENUM('MASCULINO', 'FEMENINO', 'OTRO') NOT NULL,
  `blood_type` ENUM('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-') NULL,
  `phone` VARCHAR(30) NULL,
  `email` VARCHAR(120) NULL,
  `address` VARCHAR(255) NULL,
  `emergency_contact_name` VARCHAR(120) NULL,
  `emergency_contact_phone` VARCHAR(30) NULL,
  `emergency_contact_relation` VARCHAR(50) NULL,
  `has_critical_alert` TINYINT(1) NOT NULL DEFAULT 0,
  `status` ENUM('ACTIVO', 'INACTIVO') NOT NULL DEFAULT 'ACTIVO',
  `last_visit_date` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_patients_clinic` FOREIGN KEY (`clinic_id`)
    REFERENCES `clinics` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX `idx_patients_national_id` (`national_id`),
  INDEX `idx_patients_patient_code` (`patient_code`),
  INDEX `idx_patients_full_name` (`last_name`, `first_name`),
  INDEX `idx_patients_status` (`status`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 4. TABLA: patient_allergies (Alergias Críticas y Reacciones Documentadas)
-- ============================================================================
CREATE TABLE `patient_allergies` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `patient_id` BIGINT UNSIGNED NOT NULL,
  `allergen` VARCHAR(150) NOT NULL COMMENT 'Ej. Penicilina, Látex, Ibuprofeno',
  `reaction` VARCHAR(200) NOT NULL COMMENT 'Ej. Shock Anafiláctico, Urticaria, Edema',
  `severity` ENUM('LEVE', 'MODERADA', 'CRITICA') NOT NULL DEFAULT 'CRITICA',
  `documented_date` DATE NOT NULL,
  `documented_by_user_id` BIGINT UNSIGNED NULL,
  `notes` TEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_allergies_patient` FOREIGN KEY (`patient_id`)
    REFERENCES `patients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_allergies_user` FOREIGN KEY (`documented_by_user_id`)
    REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_allergies_patient` (`patient_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 5. TABLA: appointments (Agenda y Citas Médicas)
-- ============================================================================
CREATE TABLE `appointments` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `clinic_id` BIGINT UNSIGNED NOT NULL,
  `patient_id` BIGINT UNSIGNED NOT NULL,
  `doctor_id` BIGINT UNSIGNED NOT NULL,
  `appointment_date` DATE NOT NULL,
  `appointment_time` TIME NOT NULL,
  `service_type` VARCHAR(100) NOT NULL COMMENT 'Ej. Consulta General, Control, Odontología, Pediatría',
  `status` ENUM('PROGRAMADA', 'CONFIRMADA', 'EN_ESPERA', 'COMPLETADA', 'CANCELADA') NOT NULL DEFAULT 'PROGRAMADA',
  `notes` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_appointments_clinic` FOREIGN KEY (`clinic_id`)
    REFERENCES `clinics` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_appointments_patient` FOREIGN KEY (`patient_id`)
    REFERENCES `patients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_appointments_doctor` FOREIGN KEY (`doctor_id`)
    REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX `idx_appointments_date_time` (`appointment_date`, `appointment_time`),
  INDEX `idx_appointments_patient` (`patient_id`),
  INDEX `idx_appointments_doctor` (`doctor_id`),
  INDEX `idx_appointments_status` (`status`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 6. TABLA: vital_signs (Registro de Signos Vitales y Triaje)
-- ============================================================================
CREATE TABLE `vital_signs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `patient_id` BIGINT UNSIGNED NOT NULL,
  `recorded_by_user_id` BIGINT UNSIGNED NOT NULL,
  `systolic_bp` INT UNSIGNED NULL COMMENT 'Presión Sistólica (mmHg)',
  `diastolic_bp` INT UNSIGNED NULL COMMENT 'Presión Diastólica (mmHg)',
  `heart_rate_bpm` INT UNSIGNED NULL COMMENT 'Frecuencia Cardíaca (lpm)',
  `temperature_celsius` DECIMAL(4,1) NULL COMMENT 'Temperatura (°C)',
  `weight_kg` DECIMAL(5,2) NULL COMMENT 'Peso en kilogramos',
  `height_cm` DECIMAL(5,2) NULL COMMENT 'Estatura en centímetros',
  `bmi` DECIMAL(4,1) GENERATED ALWAYS AS (
    CASE 
      WHEN `height_cm` > 0 AND `weight_kg` > 0 
      THEN ROUND(`weight_kg` / ((`height_cm` / 100) * (`height_cm` / 100)), 1)
      ELSE NULL 
    END
  ) STORED COMMENT 'Índice de Masa Corporal Calculado',
  `oxygen_saturation_pct` INT UNSIGNED NULL COMMENT 'SpO2 (%)',
  `respiratory_rate` INT UNSIGNED NULL COMMENT 'Frecuencia respiratoria (rpm)',
  `recorded_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_vital_signs_patient` FOREIGN KEY (`patient_id`)
    REFERENCES `patients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_vital_signs_user` FOREIGN KEY (`recorded_by_user_id`)
    REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX `idx_vital_signs_patient` (`patient_id`, `recorded_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 7. TABLA: soap_consultations (Consultas Clínicas bajo Estándar SOAP)
-- ============================================================================
CREATE TABLE `soap_consultations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `appointment_id` BIGINT UNSIGNED NULL,
  `patient_id` BIGINT UNSIGNED NOT NULL,
  `doctor_id` BIGINT UNSIGNED NOT NULL,
  `vital_signs_id` BIGINT UNSIGNED NULL,
  `subjective_notes` TEXT NOT NULL COMMENT 'S: Síntomas, motivo de consulta reportado por el paciente',
  `objective_notes` TEXT NOT NULL COMMENT 'O: Hallazgos del examen físico y datos observados',
  `assessment_notes` TEXT NOT NULL COMMENT 'A: Evaluación médica, impresión diagnóstica',
  `plan_notes` TEXT NOT NULL COMMENT 'P: Plan terapéutico, estudios solicitados, recomendaciones',
  `is_draft` TINYINT(1) NOT NULL DEFAULT 0,
  `is_signed` TINYINT(1) NOT NULL DEFAULT 1,
  `signed_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_soap_appointment` FOREIGN KEY (`appointment_id`)
    REFERENCES `appointments` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_soap_patient` FOREIGN KEY (`patient_id`)
    REFERENCES `patients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_soap_doctor` FOREIGN KEY (`doctor_id`)
    REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_soap_vital_signs` FOREIGN KEY (`vital_signs_id`)
    REFERENCES `vital_signs` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_soap_patient` (`patient_id`),
  INDEX `idx_soap_doctor` (`doctor_id`),
  INDEX `idx_soap_created_at` (`created_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 8. TABLA: diagnoses_icd10 (Catálogo Internacional de Enfermedades CIE-10)
-- ============================================================================
CREATE TABLE `diagnoses_icd10` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code` VARCHAR(20) NOT NULL UNIQUE COMMENT 'Ej. M54.5, J00, I10',
  `description` VARCHAR(255) NOT NULL,
  `category` VARCHAR(100) NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  INDEX `idx_icd10_code` (`code`),
  INDEX `idx_icd10_description` (`description`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 9. TABLA: consultation_diagnoses (Diagnósticos Asociados a la Consulta)
-- ============================================================================
CREATE TABLE `consultation_diagnoses` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `consultation_id` BIGINT UNSIGNED NOT NULL,
  `icd10_id` BIGINT UNSIGNED NOT NULL,
  `diagnosis_type` ENUM('PRINCIPAL', 'SECUNDARIO', 'DIFERENCIAL') NOT NULL DEFAULT 'PRINCIPAL',
  `clinical_notes` VARCHAR(255) NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_cons_diag_consultation` FOREIGN KEY (`consultation_id`)
    REFERENCES `soap_consultations` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_cons_diag_icd10` FOREIGN KEY (`icd10_id`)
    REFERENCES `diagnoses_icd10` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX `idx_cons_diag_consultation` (`consultation_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 10. TABLA: prescriptions (Recetas Médicas Farmacológicas)
-- ============================================================================
CREATE TABLE `prescriptions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `consultation_id` BIGINT UNSIGNED NULL,
  `patient_id` BIGINT UNSIGNED NOT NULL,
  `doctor_id` BIGINT UNSIGNED NOT NULL,
  `clinic_id` BIGINT UNSIGNED NOT NULL,
  `prescription_code` VARCHAR(50) NOT NULL UNIQUE,
  `issue_date` DATE NOT NULL,
  `expiration_date` DATE NULL,
  `status` ENUM('ACTIVA', 'DISPENSADA', 'CANCELADA') NOT NULL DEFAULT 'ACTIVA',
  `general_notes` TEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_prescriptions_consultation` FOREIGN KEY (`consultation_id`)
    REFERENCES `soap_consultations` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_prescriptions_patient` FOREIGN KEY (`patient_id`)
    REFERENCES `patients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_prescriptions_doctor` FOREIGN KEY (`doctor_id`)
    REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_prescriptions_clinic` FOREIGN KEY (`clinic_id`)
    REFERENCES `clinics` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX `idx_prescriptions_patient` (`patient_id`),
  INDEX `idx_prescriptions_code` (`prescription_code`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 11. TABLA: prescription_items (Detalle de Medicamentos en la Receta)
-- ============================================================================
CREATE TABLE `prescription_items` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `prescription_id` BIGINT UNSIGNED NOT NULL,
  `drug_name` VARCHAR(150) NOT NULL COMMENT 'Ej. Amoxicilina 500mg',
  `dose` VARCHAR(80) NOT NULL COMMENT 'Ej. 1 comprimido (500mg)',
  `frequency` VARCHAR(80) NOT NULL COMMENT 'Ej. Cada 8 horas',
  `duration` VARCHAR(80) NOT NULL COMMENT 'Ej. 7 días',
  `instructions` VARCHAR(255) NULL COMMENT 'Ej. Tomar después de los alimentos',
  `quantity` INT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_prescription_items_rx` FOREIGN KEY (`prescription_id`)
    REFERENCES `prescriptions` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX `idx_prescription_items_rx` (`prescription_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 12. TABLA: diagnostic_files (Archivos y Estudios Diagnósticos Adjuntos)
-- ============================================================================
CREATE TABLE `diagnostic_files` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `patient_id` BIGINT UNSIGNED NOT NULL,
  `uploaded_by_user_id` BIGINT UNSIGNED NOT NULL,
  `consultation_id` BIGINT UNSIGNED NULL,
  `file_name` VARCHAR(255) NOT NULL,
  `category` ENUM('LAB_RESULTS', 'IMAGING', 'REFERRALS', 'DERMATOLOGY', 'OTHER') NOT NULL DEFAULT 'LAB_RESULTS',
  `file_url` VARCHAR(500) NOT NULL,
  `file_size_kb` INT UNSIGNED NOT NULL,
  `mime_type` VARCHAR(80) NOT NULL DEFAULT 'application/pdf',
  `total_pages` INT UNSIGNED NOT NULL DEFAULT 1,
  `upload_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `notes` VARCHAR(255) NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_diag_files_patient` FOREIGN KEY (`patient_id`)
    REFERENCES `patients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_diag_files_user` FOREIGN KEY (`uploaded_by_user_id`)
    REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_diag_files_consultation` FOREIGN KEY (`consultation_id`)
    REFERENCES `soap_consultations` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_diag_files_patient` (`patient_id`, `category`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 13. TABLA: odontology_charts (Historial / Cartilla Odontológica)
-- ============================================================================
CREATE TABLE `odontology_charts` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `patient_id` BIGINT UNSIGNED NOT NULL,
  `dentist_id` BIGINT UNSIGNED NOT NULL,
  `chart_date` DATE NOT NULL,
  `notes` TEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_odontology_patient` FOREIGN KEY (`patient_id`)
    REFERENCES `patients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_odontology_dentist` FOREIGN KEY (`dentist_id`)
    REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX `idx_odontology_patient` (`patient_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 14. TABLA: odontology_findings (Hallazgos y Procedimientos por Pieza Dental)
-- ============================================================================
CREATE TABLE `odontology_findings` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `chart_id` BIGINT UNSIGNED NOT NULL,
  `tooth_number` INT UNSIGNED NOT NULL COMMENT 'Numeración FDI: 11-48, 51-85',
  `surfaces` VARCHAR(50) NULL COMMENT 'M=Mesial, D=Distal, O=Oclusal, V=Vestibular, L=Lingual',
  `condition_type` ENUM('CARIES', 'EMPASTE', 'CORONA', 'ENDODONCIA', 'AUSENTE', 'IMPLANTE', 'PROTESIS', 'SANO') NOT NULL,
  `planned_procedure` VARCHAR(150) NULL,
  `status` ENUM('PENDIENTE', 'EN_TRATAMIENTO', 'COMPLETADO') NOT NULL DEFAULT 'PENDIENTE',
  `finding_date` DATE NOT NULL,
  `notes` VARCHAR(255) NULL,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_odonto_findings_chart` FOREIGN KEY (`chart_id`)
    REFERENCES `odontology_charts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX `idx_odonto_findings_tooth` (`chart_id`, `tooth_number`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 15. TABLA: pediatric_growth_records (Curvas y Percentiles de Crecimiento OMS)
-- ============================================================================
CREATE TABLE `pediatric_growth_records` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `patient_id` BIGINT UNSIGNED NOT NULL,
  `recorded_by_user_id` BIGINT UNSIGNED NOT NULL,
  `record_date` DATE NOT NULL,
  `age_months` INT UNSIGNED NOT NULL COMMENT 'Edad en meses al momento del control',
  `weight_kg` DECIMAL(5,2) NOT NULL,
  `height_cm` DECIMAL(5,2) NOT NULL,
  `head_circumference_cm` DECIMAL(4,1) NULL,
  `weight_for_age_percentile` DECIMAL(4,1) NULL COMMENT 'Percentil OMS Peso/Edad',
  `height_for_age_percentile` DECIMAL(4,1) NULL COMMENT 'Percentil OMS Estatura/Edad',
  `notes` VARCHAR(255) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_pediatric_growth_patient` FOREIGN KEY (`patient_id`)
    REFERENCES `patients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_pediatric_growth_user` FOREIGN KEY (`recorded_by_user_id`)
    REFERENCES `users` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX `idx_pediatric_patient_age` (`patient_id`, `age_months`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 16. TABLA: financial_transactions (Módulo de Facturación, Cobros e Ingresos)
-- ============================================================================
CREATE TABLE `financial_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `clinic_id` BIGINT UNSIGNED NOT NULL,
  `patient_id` BIGINT UNSIGNED NOT NULL,
  `appointment_id` BIGINT UNSIGNED NULL,
  `invoice_number` VARCHAR(50) NOT NULL UNIQUE,
  `concept` VARCHAR(150) NOT NULL COMMENT 'Ej. Consulta General, Radiografía, Limpieza Dental',
  `amount` DECIMAL(10,2) NOT NULL,
  `payment_method` ENUM('EFECTIVO', 'TARJETA_CREDITO', 'TARJETA_DEBITO', 'TRANSFERENCIA', 'SEGURO') NOT NULL DEFAULT 'EFECTIVO',
  `status` ENUM('PAGADO', 'PENDIENTE', 'CANCELADO', 'REEMBOLSADO') NOT NULL DEFAULT 'PAGADO',
  `transaction_date` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_finances_clinic` FOREIGN KEY (`clinic_id`)
    REFERENCES `clinics` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_finances_patient` FOREIGN KEY (`patient_id`)
    REFERENCES `patients` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_finances_appointment` FOREIGN KEY (`appointment_id`)
    REFERENCES `appointments` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_finances_date` (`transaction_date`),
  INDEX `idx_finances_status` (`status`),
  INDEX `idx_finances_patient` (`patient_id`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 17. TABLA: database_backups (Registro y Auditoría de Respaldos)
-- ============================================================================
CREATE TABLE `database_backups` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `clinic_id` BIGINT UNSIGNED NOT NULL,
  `backup_type` ENUM('AUTOMATICO', 'MANUAL') NOT NULL DEFAULT 'AUTOMATICO',
  `file_path` VARCHAR(500) NOT NULL,
  `file_size_mb` DECIMAL(6,2) NOT NULL,
  `tables_count` INT UNSIGNED NOT NULL DEFAULT 19,
  `duration_seconds` INT UNSIGNED NOT NULL,
  `status` ENUM('COMPLETADO', 'FALLIDO', 'EN_PROCESO') NOT NULL DEFAULT 'COMPLETADO',
  `error_log` TEXT NULL,
  `executed_by_user_id` BIGINT UNSIGNED NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_backups_clinic` FOREIGN KEY (`clinic_id`)
    REFERENCES `clinics` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_backups_user` FOREIGN KEY (`executed_by_user_id`)
    REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_backups_created_at` (`created_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 18. TABLA: user_preferences (Preferencias del Sistema por Usuario)
-- ============================================================================
CREATE TABLE `user_preferences` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NOT NULL UNIQUE,
  `notifications_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `email_reminders_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `sound_enabled` TINYINT(1) NOT NULL DEFAULT 1,
  `language` VARCHAR(10) NOT NULL DEFAULT 'es',
  `default_consultation_duration_min` INT UNSIGNED NOT NULL DEFAULT 30,
  `theme_mode` ENUM('LIGHT', 'DARK', 'SYSTEM') NOT NULL DEFAULT 'LIGHT',
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_user_prefs_user` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 19. TABLA: audit_logs (Bitácora de Auditoría para Cumplimiento HIPAA)
-- ============================================================================
CREATE TABLE `audit_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id` BIGINT UNSIGNED NULL,
  `action` VARCHAR(80) NOT NULL COMMENT 'LOGIN, VIEW_RECORD, CREATE_CONSULTATION, EXPORT_PDF, etc.',
  `entity_name` VARCHAR(80) NOT NULL COMMENT 'patients, soap_consultations, prescriptions',
  `entity_id` BIGINT UNSIGNED NULL,
  `ip_address` VARCHAR(45) NULL,
  `user_agent` VARCHAR(255) NULL,
  `details` JSON NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_audit_user` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_audit_user_action` (`user_id`, `action`),
  INDEX `idx_audit_created_at` (`created_at`)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- VISTAS ÚTILES PARA REPORTES Y DASHBOARD
-- ============================================================================

-- Vista: Resumen Diario de Citas y Estado de Pacientes
CREATE OR REPLACE VIEW `vw_daily_appointments_summary` AS
SELECT 
  a.id AS appointment_id,
  a.appointment_date,
  a.appointment_time,
  a.status AS appointment_status,
  a.service_type,
  p.id AS patient_id,
  p.patient_code,
  CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
  p.phone AS patient_phone,
  p.has_critical_alert,
  u.id AS doctor_id,
  u.full_name AS doctor_name
FROM `appointments` a
JOIN `patients` p ON a.patient_id = p.id
JOIN `users` u ON a.doctor_id = u.id;

-- Vista: Resumen Financiero Mensual
CREATE OR REPLACE VIEW `vw_monthly_financial_summary` AS
SELECT 
  DATE_FORMAT(transaction_date, '%Y-%m') AS transaction_month,
  COUNT(id) AS total_transactions,
  SUM(CASE WHEN status = 'PAGADO' THEN amount ELSE 0 END) AS total_income,
  SUM(CASE WHEN status = 'PENDIENTE' THEN amount ELSE 0 END) AS total_pending,
  SUM(CASE WHEN status = 'CANCELADO' THEN amount ELSE 0 END) AS total_cancelled
FROM `financial_transactions`
GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
ORDER BY transaction_month DESC;

-- ============================================================================
-- DATOS SEMILLA (SEEDS) PARA PRUEBAS INMEDIATAS EN MYSQL WORKBENCH
-- ============================================================================

INSERT INTO `clinics` (`id`, `name`, `address`, `phone`, `email`, `tax_id`) VALUES
(1, 'MediCore Clínica Central', 'Av. Reforma 123, Col. Centro, CDMX', '+52 55 9876 5432', 'contacto@medicore.com', 'MED230819ABC');

INSERT INTO `users` (`id`, `clinic_id`, `provider_code`, `full_name`, `email`, `password_hash`, `role`, `specialty`, `professional_license`) VALUES
(1, 1, 'DRS-001', 'Dr. Alexander Smith', 'dr.smith@medicore.com', '$2y$10$e0MYzXyjpJS7Pd0RVvHwHeFw9UoNfA4vA8HwE8YqR5V4P2T8U7Gq6', 'ADMIN', 'Medicina General', 'CED-12345678'),
(2, 1, 'DRS-002', 'Dra. María López', 'dra.lopez@medicore.com', '$2y$10$e0MYzXyjpJS7Pd0RVvHwHeFw9UoNfA4vA8HwE8YqR5V4P2T8U7Gq6', 'DOCTOR', 'Pediatría', 'CED-87654321'),
(3, 1, 'ENF-001', 'Lic. Ana Martínez', 'a.martinez@medicore.com', '$2y$10$e0MYzXyjpJS7Pd0RVvHwHeFw9UoNfA4vA8HwE8YqR5V4P2T8U7Gq6', 'NURSE', 'Enfermería General', 'CED-33445566');

INSERT INTO `patients` (`id`, `clinic_id`, `patient_code`, `national_id`, `first_name`, `last_name`, `birth_date`, `gender`, `blood_type`, `phone`, `email`, `has_critical_alert`) VALUES
(1, 1, 'PT-8472', 'DNI-0987654321', 'Ana', 'García López', '1989-05-14', 'FEMENINO', 'O+', '+52 55 1122 3344', 'ana.garcia@email.com', 1),
(2, 1, 'PT-8473', 'DNI-1234567890', 'Carlos', 'López Martínez', '1978-11-23', 'MASCULINO', 'A+', '+52 55 2233 4455', 'carlos.lopez@email.com', 0),
(3, 1, 'PT-8474', 'DNI-5678901234', 'María', 'Rodríguez Silva', '1995-02-18', 'FEMENINO', 'B+', '+52 55 3344 5566', 'maria.rodriguez@email.com', 0),
(4, 1, 'PT-8475', 'DNI-9012345678', 'Mateo', 'García', '2021-08-10', 'MASCULINO', 'O+', '+52 55 4455 6677', 'contacto.mateo@email.com', 0);

INSERT INTO `patient_allergies` (`patient_id`, `allergen`, `reaction`, `severity`, `documented_date`, `documented_by_user_id`) VALUES
(1, 'Penicilina', 'Shock Anafiláctico y Urticaria', 'CRITICA', '2023-04-12', 1);

INSERT INTO `diagnoses_icd10` (`code`, `description`, `category`) VALUES
('M54.5', 'Lumbago no especificado', 'Musculoesquelético'),
('J00', 'Rinofaringitis aguda (resfriado común)', 'Respiratorio'),
('I10', 'Hipertensión esencial (primaria)', 'Cardiovascular'),
('E11', 'Diabetes mellitus tipo 2', 'Endocrino'),
('K02.1', 'Caries de la dentina', 'Odontología');

INSERT INTO `financial_transactions` (`clinic_id`, `patient_id`, `invoice_number`, `concept`, `amount`, `payment_method`, `status`, `transaction_date`) VALUES
(1, 1, 'INV-2026-001', 'Consulta General', 850.00, 'TARJETA_CREDITO', 'PAGADO', '2026-08-18 09:30:00'),
(1, 2, 'INV-2026-002', 'Control', 500.00, 'EFECTIVO', 'PAGADO', '2026-08-18 10:15:00'),
(1, 3, 'INV-2026-003', 'Limpieza Dental', 1200.00, 'TRANSFERENCIA', 'PAGADO', '2026-08-17 11:00:00');

-- Fin del script SQL

-- ============================================================================
-- BASE DE DATOS RELACIONAL: MEDICORE EMR (EXPEDIENTE MÉDICO ELECTRÓNICO)
-- Versión: 2.0 (Estructura en Español con Módulos de Epicrisis, Tratamiento y Medicamentos)
-- Motor: MySQL 8.0+ / MariaDB 10.5+ / MySQL Workbench
-- Normalización: 3FN (Tercera Forma Normal)
-- Charset: utf8mb4 | Collation: utf8mb4_unicode_ci
-- ============================================================================

CREATE DATABASE IF NOT EXISTS `medicore_emr_db`
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE `medicore_emr_db`;

-- ----------------------------------------------------------------------------
-- LIMPIEZA INICIAL CONTROLADA
-- ----------------------------------------------------------------------------
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS `bitacora_auditoria`;
DROP TABLE IF EXISTS `preferencias_usuario`;
DROP TABLE IF EXISTS `respaldos_base_datos`;
DROP TABLE IF EXISTS `transacciones_financieras`;
DROP TABLE IF EXISTS `registros_crecimiento_pediatrico`;
DROP TABLE IF EXISTS `odontologia_hallazgos`;
DROP TABLE IF EXISTS `odontologia_cartillas`;
DROP TABLE IF EXISTS `archivos_diagnostico`;
DROP TABLE IF EXISTS `epicrisis`;
DROP TABLE IF EXISTS `detalle_receta`;
DROP TABLE IF EXISTS `recetas_medicas`;
DROP TABLE IF EXISTS `tratamiento_medicamentos`;
DROP TABLE IF EXISTS `tratamientos`;
DROP TABLE IF EXISTS `medicamentos`;
DROP TABLE IF EXISTS `diagnosticos_consulta`;
DROP TABLE IF EXISTS `catalogo_cie10`;
DROP TABLE IF EXISTS `signos_vitales`;
DROP TABLE IF EXISTS `consultas_soap`;
DROP TABLE IF EXISTS `citas_medicas`;
DROP TABLE IF EXISTS `alergias_paciente`;
DROP TABLE IF EXISTS `contactos_emergencia`;
DROP TABLE IF EXISTS `pacientes`;
DROP TABLE IF EXISTS `servicios`;
DROP TABLE IF EXISTS `departamentos`;
DROP TABLE IF EXISTS `usuarios`;
DROP TABLE IF EXISTS `clinicas`;
DROP TABLE IF EXISTS `roles`;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- 1. TABLA: roles (Roles del Sistema y Permisos Base)
-- ============================================================================
CREATE TABLE `roles` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nombre` VARCHAR(50) NOT NULL UNIQUE COMMENT 'ADMIN, MEDICO, ENFERMERO, RECEPCIONISTA, FARMACIA',
  `descripcion` VARCHAR(255) NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Catálogo de roles para control de acceso';

-- ============================================================================
-- 2. TABLA: clinicas (Sucursales y Sedes Médicas)
-- ============================================================================
CREATE TABLE `clinicas` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nombre` VARCHAR(150) NOT NULL,
  `direccion` VARCHAR(255) NOT NULL,
  `telefono` VARCHAR(30) NOT NULL,
  `correo` VARCHAR(120) NOT NULL,
  `identificacion_fiscal` VARCHAR(50) NULL COMMENT 'RFC / RUC / NIF de la entidad de salud',
  `horario_semana` VARCHAR(100) DEFAULT '08:00 - 18:00',
  `horario_sabado` VARCHAR(100) DEFAULT '08:00 - 14:00',
  `horario_domingo` VARCHAR(100) DEFAULT 'Cerrado',
  `esta_activa` TINYINT(1) NOT NULL DEFAULT 1,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_clinicas_nombre` (`nombre`),
  INDEX `idx_clinicas_activa` (`esta_activa`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Sedes hospitalarias y consultorios clínicos';

-- ============================================================================
-- 3. TABLA: usuarios (Médicos, Especialistas, Enfermeros y Personal)
-- ============================================================================
CREATE TABLE `usuarios` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `clinica_id` INT UNSIGNED NOT NULL,
  `rol_id` INT UNSIGNED NOT NULL,
  `codigo_profesional` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Identificador único ej. MED-001, DRS-001',
  `nombre_completo` VARCHAR(150) NOT NULL,
  `correo` VARCHAR(120) NOT NULL UNIQUE,
  `hash_contrasena` VARCHAR(255) NOT NULL,
  `hash_llave_maestra` VARCHAR(255) NULL COMMENT 'Hash de seguridad para cifrado y desbloqueo local',
  `telefono` VARCHAR(30) NULL,
  `especialidad` VARCHAR(100) NULL COMMENT 'Medicina General, Pediatría, Odontología, Medicina Interna, Cirugía',
  `cedula_profesional` VARCHAR(80) NULL COMMENT 'Licencia médica o número de registro colegiado',
  `esta_activo` TINYINT(1) NOT NULL DEFAULT 1,
  `ultimo_acceso_en` DATETIME NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_usuarios_clinica` FOREIGN KEY (`clinica_id`)
    REFERENCES `clinicas` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_usuarios_rol` FOREIGN KEY (`rol_id`)
    REFERENCES `roles` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_usuarios_correo` (`correo`),
  INDEX `idx_usuarios_codigo` (`codigo_profesional`),
  INDEX `idx_usuarios_especialidad` (`especialidad`),
  INDEX `idx_usuarios_rol` (`rol_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Usuarios con acceso al sistema clínico';

-- ============================================================================
-- 4. TABLA: departamentos (Departamentos Médicos / Especialidades)
-- ============================================================================
CREATE TABLE `departamentos` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nombre` VARCHAR(100) NOT NULL UNIQUE,
  `descripcion` VARCHAR(255) NULL,
  `esta_activo` TINYINT(1) NOT NULL DEFAULT 1,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_dept_nombre` (`nombre`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Departamentos y servicios clínicos institucionales';

-- ============================================================================
-- 5. TABLA: servicios (Catálogo de Prestaciones, Consultas y Procedimientos)
-- ============================================================================
CREATE TABLE `servicios` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `departamento_id` INT UNSIGNED NOT NULL,
  `nombre` VARCHAR(150) NOT NULL,
  `costo_base` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `duracion_minutos` INT UNSIGNED NOT NULL DEFAULT 30,
  `esta_activo` TINYINT(1) NOT NULL DEFAULT 1,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_servicios_departamento` FOREIGN KEY (`departamento_id`)
    REFERENCES `departamentos` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_servicios_departamento` (`departamento_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tarifario y catálogo de servicios médicos';

-- ============================================================================
-- 6. TABLA: pacientes (Expedientes y Datos Demográficos del Paciente)
-- ============================================================================
CREATE TABLE `pacientes` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `clinica_id` INT UNSIGNED NOT NULL,
  `codigo_paciente` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Código único institucional ej. PT-8472',
  `numero_identidad` VARCHAR(50) NOT NULL UNIQUE COMMENT 'DNI / Cédula / Pasaporte / CURP',
  `nombres` VARCHAR(100) NOT NULL,
  `apellidos` VARCHAR(100) NOT NULL,
  `fecha_nacimiento` DATE NOT NULL,
  `genero` ENUM('Masculino', 'Femenino', 'Otro') NOT NULL,
  `tipo_sangre` ENUM('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-') NULL,
  `telefono` VARCHAR(30) NULL,
  `correo` VARCHAR(120) NULL,
  `direccion` TEXT NULL,
  `foto_url` VARCHAR(500) NULL,
  `alerta_critica` TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 si el paciente tiene condición o alergia severa',
  `estado` ENUM('Activo', 'Inactivo') NOT NULL DEFAULT 'Activo',
  `ultima_visita_en` DATETIME NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_pacientes_clinica` FOREIGN KEY (`clinica_id`)
    REFERENCES `clinicas` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_pacientes_codigo` (`codigo_paciente`),
  INDEX `idx_pacientes_identidad` (`numero_identidad`),
  INDEX `idx_pacientes_apellidos` (`apellidos`, `nombres`),
  INDEX `idx_pacientes_estado` (`estado`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Expediente maestro demográfico y clínico del paciente';

-- ============================================================================
-- 7. TABLA: contactos_emergencia (Contactos y Familiares Responsables)
-- ============================================================================
CREATE TABLE `contactos_emergencia` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `paciente_id` INT UNSIGNED NOT NULL,
  `nombre_completo` VARCHAR(150) NOT NULL,
  `parentesco` VARCHAR(50) NOT NULL COMMENT 'Padre, Madre, Cónyuge, Hijo/a, Hermano/a, Tutor, Otro',
  `telefono` VARCHAR(30) NOT NULL,
  `telefono_alternativo` VARCHAR(30) NULL,
  `correo` VARCHAR(120) NULL,
  `es_principal` TINYINT(1) NOT NULL DEFAULT 1,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_contactos_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  INDEX `idx_contactos_paciente` (`paciente_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Contactos de emergencia para cada paciente';

-- ============================================================================
-- 8. TABLA: alergias_paciente (Alertas de Alergias y Reacciones Adversas)
-- ============================================================================
CREATE TABLE `alergias_paciente` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `paciente_id` INT UNSIGNED NOT NULL,
  `alergeno` VARCHAR(150) NOT NULL COMMENT 'Sustancia ej. Penicilina, AINEs, Látex, Mariscos',
  `reaccion` VARCHAR(255) NOT NULL COMMENT 'Urticaria, Angioedema, Anafilaxia, Broncoespasmo',
  `severidad` ENUM('Leve', 'Moderada', 'Grave', 'Critica') NOT NULL DEFAULT 'Grave',
  `fecha_diagnostico` DATE NULL,
  `registrado_por_usuario_id` INT UNSIGNED NULL,
  `esta_activa` TINYINT(1) NOT NULL DEFAULT 1,
  `observaciones` TEXT NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_alergias_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_alergias_usuario` FOREIGN KEY (`registrado_por_usuario_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX `idx_alergias_paciente` (`paciente_id`),
  INDEX `idx_alergias_severidad` (`severidad`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Registro de alergias farmacológicas y ambientales';

-- ============================================================================
-- 9. TABLA: citas_medicas (Agenda y Estado de Consultas)
-- ============================================================================
CREATE TABLE `citas_medicas` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `clinica_id` INT UNSIGNED NOT NULL,
  `paciente_id` INT UNSIGNED NOT NULL,
  `medico_id` INT UNSIGNED NOT NULL,
  `servicio_id` INT UNSIGNED NOT NULL,
  `fecha_cita` DATE NOT NULL,
  `hora_cita` TIME NOT NULL,
  `estado` ENUM('Pendiente', 'Confirmada', 'En Espera', 'En Consulta', 'Completada', 'Cancelada', 'No Asistio') NOT NULL DEFAULT 'Pendiente',
  `motivo_cita` VARCHAR(255) NULL,
  `observaciones` TEXT NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_citas_clinica` FOREIGN KEY (`clinica_id`)
    REFERENCES `clinicas` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_citas_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_citas_medico` FOREIGN KEY (`medico_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_citas_servicio` FOREIGN KEY (`servicio_id`)
    REFERENCES `servicios` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_citas_fecha_hora` (`fecha_cita`, `hora_cita`),
  INDEX `idx_citas_paciente` (`paciente_id`),
  INDEX `idx_citas_medico` (`medico_id`),
  INDEX `idx_citas_estado` (`estado`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Agendamiento de citas médicas y control de flujo';

-- ============================================================================
-- 10. TABLA: signos_vitales (Triaje y Parámetros Fisiológicos)
-- ============================================================================
CREATE TABLE `signos_vitales` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `paciente_id` INT UNSIGNED NOT NULL,
  `registrado_por_usuario_id` INT UNSIGNED NOT NULL,
  `presion_sistolica` INT UNSIGNED NULL COMMENT 'Presión arterial sistólica en mmHg (ej. 120)',
  `presion_diastolica` INT UNSIGNED NULL COMMENT 'Presión arterial diastólica en mmHg (ej. 80)',
  `frecuencia_cardiaca` INT UNSIGNED NULL COMMENT 'Pulsaciones por minuto (lpm)',
  `frecuencia_respiratoria` INT UNSIGNED NULL COMMENT 'Respiraciones por minuto (rpm)',
  `temperatura_celsius` DECIMAL(4,1) NULL COMMENT 'Temperatura corporal en °C',
  `peso_kg` DECIMAL(5,2) NULL COMMENT 'Peso del paciente en kg',
  `altura_cm` DECIMAL(5,2) NULL COMMENT 'Estatura en centímetros',
  `imc` DECIMAL(4,1) GENERATED ALWAYS AS (
    CASE 
      WHEN `altura_cm` > 0 AND `peso_kg` > 0 
      THEN ROUND(`peso_kg` / ((`altura_cm` / 100) * (`altura_cm` / 100)), 1)
      ELSE NULL 
    END
  ) STORED COMMENT 'Índice de Masa Corporal (IMC) calculado automáticamente',
  `saturacion_oxigeno_pct` INT UNSIGNED NULL COMMENT 'Saturación SpO2 en porcentaje (ej. 98)',
  `glucosa_capilar_mgdl` INT UNSIGNED NULL COMMENT 'Glucemia capilar opcional',
  `tomado_en` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `observaciones` VARCHAR(255) NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_signos_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_signos_usuario` FOREIGN KEY (`registrado_por_usuario_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_signos_paciente_fecha` (`paciente_id`, `tomado_en`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Medición de signos vitales para triaje y control médico';

-- ============================================================================
-- 11. TABLA: consultas_soap (Consultas Clínicas Estructuradas SOAP)
-- ============================================================================
CREATE TABLE `consultas_soap` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `cita_id` INT UNSIGNED NULL,
  `paciente_id` INT UNSIGNED NOT NULL,
  `medico_id` INT UNSIGNED NOT NULL,
  `signos_vitales_id` INT UNSIGNED NULL,
  `fecha_consulta` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `subjetivo` TEXT NOT NULL COMMENT 'S: Motivo de consulta referido, sintomatología, padecimiento actual',
  `objetivo` TEXT NOT NULL COMMENT 'O: Hallazgos del examen físico y datos medibles',
  `evaluacion` TEXT NOT NULL COMMENT 'A: Juicio clínico médico, análisis diagnóstico',
  `plan` TEXT NOT NULL COMMENT 'P: Plan terapéutico, estudios complementarios, dieta, reposo',
  `es_borrador` TINYINT(1) NOT NULL DEFAULT 0,
  `esta_firmada` TINYINT(1) NOT NULL DEFAULT 1,
  `firmada_en` DATETIME NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_consultas_cita` FOREIGN KEY (`cita_id`)
    REFERENCES `citas_medicas` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT `fk_consultas_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_consultas_medico` FOREIGN KEY (`medico_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_consultas_signos` FOREIGN KEY (`signos_vitales_id`)
    REFERENCES `signos_vitales` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX `idx_consultas_paciente` (`paciente_id`),
  INDEX `idx_consultas_medico` (`medico_id`),
  INDEX `idx_consultas_fecha` (`fecha_consulta`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Notas y expedientes de consulta médica bajo formato SOAP';

-- ============================================================================
-- 12. TABLA: catalogo_cie10 (Clasificación Internacional de Enfermedades CIE-10)
-- ============================================================================
CREATE TABLE `catalogo_cie10` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codigo` VARCHAR(20) NOT NULL UNIQUE COMMENT 'Código estándar CIE-10 ej. M54.5, J00, I10, E11.9',
  `descripcion` VARCHAR(255) NOT NULL,
  `capitulo` VARCHAR(150) NULL,
  `esta_activo` TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`id`),
  INDEX `idx_cie10_codigo` (`codigo`),
  INDEX `idx_cie10_descripcion` (`descripcion`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Nomenclatura diagnóstica oficial CIE-10';

-- ============================================================================
-- 13. TABLA: diagnosticos_consulta (Diagnósticos Vinculados a la Consulta)
-- ============================================================================
CREATE TABLE `diagnosticos_consulta` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `consulta_id` INT UNSIGNED NOT NULL,
  `cie10_id` INT UNSIGNED NOT NULL,
  `tipo_diagnostico` ENUM('Principal', 'Secundario', 'Diferencial', 'Presuntivo', 'Definitivo') NOT NULL DEFAULT 'Principal',
  `notas_clinicas` VARCHAR(255) NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_diagcons_consulta` FOREIGN KEY (`consulta_id`)
    REFERENCES `consultas_soap` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_diagcons_cie10` FOREIGN KEY (`cie10_id`)
    REFERENCES `catalogo_cie10` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_diagcons_consulta` (`consulta_id`),
  INDEX `idx_diagcons_cie10` (`cie10_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Mapeo de diagnósticos registrados por consulta';

-- ============================================================================
-- 14. TABLA NUEVA: medicamentos (Catálogo e Inventario Farmacológico)
-- ============================================================================
CREATE TABLE `medicamentos` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codigo_nacional` VARCHAR(50) NULL UNIQUE COMMENT 'Código de barra / registro sanitario o NDC',
  `nombre_comercial` VARCHAR(150) NOT NULL COMMENT 'Nombre de marca comercial ej. Amoxil, Tylenol',
  `nombre_generico` VARCHAR(150) NOT NULL COMMENT 'Principio activo ej. Amoxicilina, Paracetamol',
  `forma_farmaceutica` ENUM('Tableta', 'Cápsula', 'Jarabe', 'Suspensión', 'Solución Inyectable', 'Crema', 'Ungüento', 'Gotas Oftálmicas', 'Gotas Óticas', 'Aerosol / Inhalador', 'Supositorio', 'Parche', 'Otro') NOT NULL DEFAULT 'Tableta',
  `concentracion` VARCHAR(80) NOT NULL COMMENT 'Ej. 500 mg, 10 mg/ml, 850 mg',
  `via_administracion` ENUM('Oral', 'Intravenosa', 'Intramuscular', 'Subcutánea', 'Tópica', 'Oftálmica', 'Ótica', 'Nasal', 'Inhalatoria', 'Rectal', 'Sublingual') NOT NULL DEFAULT 'Oral',
  `presentacion` VARCHAR(150) NOT NULL COMMENT 'Ej. Caja con 30 tabletas, Frasco 120 ml, Ampolla 2 ml',
  `laboratorio_fabricante` VARCHAR(120) NULL,
  `codigo_atc` VARCHAR(20) NULL COMMENT 'Clasificación anatómica, terapéutica y química OMS',
  `requiere_receta` TINYINT(1) NOT NULL DEFAULT 1,
  `indicaciones` TEXT NULL,
  `contraindicaciones` TEXT NULL,
  `efectos_adversos` TEXT NULL,
  `stock_actual` INT NOT NULL DEFAULT 0,
  `stock_minimo` INT NOT NULL DEFAULT 5,
  `precio_unitario` DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  `esta_activo` TINYINT(1) NOT NULL DEFAULT 1,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_medicamentos_generico` (`nombre_generico`),
  INDEX `idx_medicamentos_comercial` (`nombre_comercial`),
  INDEX `idx_medicamentos_atc` (`codigo_atc`),
  INDEX `idx_medicamentos_activo` (`esta_activo`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Catálogo maestro de medicamentos y productos farmacéuticos';

-- ============================================================================
-- 15. TABLA NUEVA: tratamientos (Planes Terapéuticos y Manejo Clínico)
-- ============================================================================
CREATE TABLE `tratamientos` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `paciente_id` INT UNSIGNED NOT NULL,
  `medico_id` INT UNSIGNED NOT NULL,
  `consulta_id` INT UNSIGNED NULL,
  `diagnostico_id` INT UNSIGNED NULL,
  `titulo_tratamiento` VARCHAR(200) NOT NULL COMMENT 'Ej. Esquema antibiótico para Neumonía, Plan Antihipertensivo',
  `tipo_tratamiento` ENUM('Farmacológico', 'Quirúrgico', 'Fisioterapéutico', 'Odontológico', 'Preventivo', 'Nutricional', 'Psicoterapéutico', 'Combinado') NOT NULL DEFAULT 'Farmacológico',
  `descripcion` TEXT NOT NULL COMMENT 'Descripción y protocolo detallado del tratamiento',
  `objetivo_terapeutico` TEXT NULL COMMENT 'Metas esperadas (ej. Normalizar presión arterial < 130/80)',
  `fecha_inicio` DATE NOT NULL,
  `fecha_fin_estimada` DATE NULL,
  `fecha_finalizacion_real` DATE NULL,
  `estado` ENUM('Planificado', 'En Curso', 'Completado', 'Suspendido', 'Cancelado') NOT NULL DEFAULT 'En Curso',
  `motivo_suspension` VARCHAR(255) NULL,
  `indicaciones_generales` TEXT NULL COMMENT 'Recomendaciones de estilo de vida, dieta, reposo',
  `observaciones_seguimiento` TEXT NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_tratamientos_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_tratamientos_medico` FOREIGN KEY (`medico_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_tratamientos_consulta` FOREIGN KEY (`consulta_id`)
    REFERENCES `consultas_soap` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT `fk_tratamientos_diagnostico` FOREIGN KEY (`diagnostico_id`)
    REFERENCES `catalogo_cie10` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX `idx_tratamientos_paciente` (`paciente_id`),
  INDEX `idx_tratamientos_medico` (`medico_id`),
  INDEX `idx_tratamientos_estado` (`estado`),
  INDEX `idx_tratamientos_fechas` (`fecha_inicio`, `fecha_fin_estimada`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Planes terapéuticos integrales para el paciente';

-- ============================================================================
-- 16. TABLA NUEVA: tratamiento_medicamentos (Medicamentos por Tratamiento)
-- ============================================================================
CREATE TABLE `tratamiento_medicamentos` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `tratamiento_id` INT UNSIGNED NOT NULL,
  `medicamento_id` INT UNSIGNED NOT NULL,
  `dosis` VARCHAR(100) NOT NULL COMMENT 'Ej. 1 tableta (500mg), 10 ml',
  `frecuencia` VARCHAR(100) NOT NULL COMMENT 'Ej. Cada 8 horas, 1 vez al día con el desayuno',
  `duracion` VARCHAR(100) NOT NULL COMMENT 'Ej. 7 días, Tratamiento continuo por 3 meses',
  `via_administracion` VARCHAR(50) NOT NULL DEFAULT 'Oral',
  `instrucciones_especificas` TEXT NULL COMMENT 'Ej. Tomar con abundante agua antes de dormir',
  `cantidad_total_prescrita` INT UNSIGNED NOT NULL DEFAULT 1,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_trat_med_tratamiento` FOREIGN KEY (`tratamiento_id`)
    REFERENCES `tratamientos` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_trat_med_medicamento` FOREIGN KEY (`medicamento_id`)
    REFERENCES `medicamentos` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_trat_med_tratamiento` (`tratamiento_id`),
  INDEX `idx_trat_med_medicamento` (`medicamento_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Detalle de medicamentos vinculados a un plan de tratamiento';

-- ============================================================================
-- 17. TABLA: recetas_medicas (Prescripciones Farmacológicas Oficiales)
-- ============================================================================
CREATE TABLE `recetas_medicas` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `consulta_id` INT UNSIGNED NULL,
  `tratamiento_id` INT UNSIGNED NULL,
  `paciente_id` INT UNSIGNED NOT NULL,
  `medico_id` INT UNSIGNED NOT NULL,
  `clinica_id` INT UNSIGNED NOT NULL,
  `codigo_receta` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Folio oficial de receta ej. RX-2026-0089',
  `fecha_emision` DATE NOT NULL,
  `fecha_vencimiento` DATE NULL,
  `estado` ENUM('Activa', 'Dispensada', 'Vencida', 'Cancelada') NOT NULL DEFAULT 'Activa',
  `indicaciones_generales` TEXT NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_recetas_consulta` FOREIGN KEY (`consulta_id`)
    REFERENCES `consultas_soap` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT `fk_recetas_tratamiento` FOREIGN KEY (`tratamiento_id`)
    REFERENCES `tratamientos` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT `fk_recetas_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_recetas_medico` FOREIGN KEY (`medico_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_recetas_clinica` FOREIGN KEY (`clinica_id`)
    REFERENCES `clinicas` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_recetas_codigo` (`codigo_receta`),
  INDEX `idx_recetas_paciente` (`paciente_id`),
  INDEX `idx_recetas_medico` (`medico_id`),
  INDEX `idx_recetas_fecha` (`fecha_emision`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Cabecera de recetas médicas con validez clínica y legal';

-- ============================================================================
-- 18. TABLA: detalle_receta (Renglones de Medicamentos en la Receta)
-- ============================================================================
CREATE TABLE `detalle_receta` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `receta_id` INT UNSIGNED NOT NULL,
  `medicamento_id` INT UNSIGNED NULL COMMENT 'Relación directa con catálogo de medicamentos',
  `nombre_medicamento_texto` VARCHAR(150) NOT NULL COMMENT 'Texto descriptivo para recetas personalizadas',
  `dosis` VARCHAR(100) NOT NULL COMMENT 'Ej. 1 cápsula 500mg',
  `frecuencia` VARCHAR(100) NOT NULL COMMENT 'Ej. Cada 8 horas',
  `duracion` VARCHAR(100) NOT NULL COMMENT 'Ej. 7 días',
  `via_administracion` VARCHAR(50) NOT NULL DEFAULT 'Oral',
  `instrucciones` VARCHAR(255) NULL,
  `cantidad_unidades` INT UNSIGNED NOT NULL DEFAULT 1,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_detallereceta_receta` FOREIGN KEY (`receta_id`)
    REFERENCES `recetas_medicas` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_detallereceta_medicamento` FOREIGN KEY (`medicamento_id`)
    REFERENCES `medicamentos` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX `idx_detreceta_receta` (`receta_id`),
  INDEX `idx_detreceta_medicamento` (`medicamento_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Renglones prescritos por cada receta médica';

-- ============================================================================
-- 19. TABLA NUEVA: epicrisis (Informe Detallado de Cierre Clínico y Egreso)
-- ============================================================================
CREATE TABLE `epicrisis` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `codigo_epicrisis` VARCHAR(50) NOT NULL UNIQUE COMMENT 'Identificador único oficial ej. EPI-2026-0001',
  `paciente_id` INT UNSIGNED NOT NULL,
  `medico_responsable_id` INT UNSIGNED NOT NULL,
  `clinica_id` INT UNSIGNED NOT NULL,
  `consulta_id` INT UNSIGNED NULL COMMENT 'Consulta de inicio o cierre asociada si aplica',
  `tratamiento_id` INT UNSIGNED NULL COMMENT 'Tratamiento intrahospitalario o principal asociado',
  `fecha_ingreso` DATETIME NOT NULL,
  `fecha_egreso` DATETIME NOT NULL,
  `dias_estancia` INT UNSIGNED GENERATED ALWAYS AS (
    GREATEST(TIMESTAMPDIFF(DAY, `fecha_ingreso`, `fecha_egreso`), 1)
  ) STORED COMMENT 'Días de estancia hospitalaria calculados automáticamente',
  `tipo_atencion` ENUM('Hospitalización', 'Urgencias', 'Cirugía Ambulatoria', 'Cuidados Intensivos', 'Consulta Especializada') NOT NULL DEFAULT 'Hospitalización',
  `motivo_ingreso` TEXT NOT NULL COMMENT 'Causa principal y síntomas que motivaron el ingreso',
  `resumen_historia_clinica` TEXT NOT NULL COMMENT 'Resumen del cuadro patológico y evolución de la enfermedad',
  `antecedentes_relevantes` TEXT NULL COMMENT 'Comorbilidades, antecedentes quirúrgicos, alérgicos',
  `diagnostico_ingreso_id` INT UNSIGNED NOT NULL,
  `diagnostico_egreso_id` INT UNSIGNED NOT NULL,
  `diagnosticos_secundarios` TEXT NULL COMMENT 'Otros diagnósticos y comorbilidades confirmadas',
  `resumen_evolucion` TEXT NOT NULL COMMENT 'Evolución clínica detallada del paciente durante su estancia',
  `procedimientos_quirurgicos_realizados` TEXT NULL COMMENT 'Cirugías, biopsias, cateterismos u otros procedimientos',
  `estudios_diagnosticos_relevantes` TEXT NULL COMMENT 'Hallazgos de laboratorios, TAC, Rayos X, ecografías más destacadas',
  `tratamiento_recibido` TEXT NOT NULL COMMENT 'Esquema terapéutico, medicación intrahospitalaria y respuesta',
  `complicaciones` TEXT NULL COMMENT 'Eventos adversos o complicaciones intrahospitalarias si ocurrieron',
  `estado_al_egreso` ENUM('Curado', 'Mejorado', 'Estable', 'Secuelas', 'Traslado', 'Alta Voluntaria', 'Defuncion') NOT NULL DEFAULT 'Mejorado',
  `pronostico` ENUM('Excelente', 'Bueno', 'Favorable', 'Reservado', 'Grave') NOT NULL DEFAULT 'Bueno',
  `plan_manejo_ambulatorio` TEXT NOT NULL COMMENT 'Cuidados domiciliarios, dieta recomendada, reposo y actividad',
  `medicacion_al_alta` TEXT NOT NULL COMMENT 'Medicamentos pautados para el hogar con dosis y duración',
  `citas_control_seguimiento` TEXT NULL COMMENT 'Fechas y especialidades requeridas para revisión posterior',
  `signos_alarma_urgencias` TEXT NULL COMMENT 'Instrucciones claras sobre cuándo regresar de inmediato por urgencias',
  `fecha_elaboracion` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `esta_firmada` TINYINT(1) NOT NULL DEFAULT 1,
  `firmada_en` DATETIME NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_epicrisis_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_epicrisis_medico` FOREIGN KEY (`medico_responsable_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_epicrisis_clinica` FOREIGN KEY (`clinica_id`)
    REFERENCES `clinicas` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_epicrisis_consulta` FOREIGN KEY (`consulta_id`)
    REFERENCES `consultas_soap` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT `fk_epicrisis_tratamiento` FOREIGN KEY (`tratamiento_id`)
    REFERENCES `tratamientos` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  CONSTRAINT `fk_epicrisis_diag_ingreso` FOREIGN KEY (`diagnostico_ingreso_id`)
    REFERENCES `catalogo_cie10` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_epicrisis_diag_egreso` FOREIGN KEY (`diagnostico_egreso_id`)
    REFERENCES `catalogo_cie10` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_epicrisis_codigo` (`codigo_epicrisis`),
  INDEX `idx_epicrisis_paciente` (`paciente_id`),
  INDEX `idx_epicrisis_medico` (`medico_responsable_id`),
  INDEX `idx_epicrisis_fechas` (`fecha_ingreso`, `fecha_egreso`),
  INDEX `idx_epicrisis_estado_egreso` (`estado_al_egreso`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Informe y resumen clínico detallado de alta/egreso médico (Epicrisis)';

-- ============================================================================
-- 20. TABLA: archivos_diagnostico (Estudios, Imágenes y Laboratorios)
-- ============================================================================
CREATE TABLE `archivos_diagnostico` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `paciente_id` INT UNSIGNED NOT NULL,
  `subido_por_usuario_id` INT UNSIGNED NOT NULL,
  `consulta_id` INT UNSIGNED NULL,
  `nombre_archivo` VARCHAR(255) NOT NULL,
  `categoria` ENUM('Laboratorio', 'Imagenologia', 'Interconsulta', 'Dermatologia', 'Cardiologia', 'Otro') NOT NULL DEFAULT 'Laboratorio',
  `archivo_url` VARCHAR(500) NOT NULL,
  `tamano_kb` INT UNSIGNED NOT NULL,
  `tipo_mime` VARCHAR(80) NOT NULL DEFAULT 'application/pdf',
  `total_paginas` INT UNSIGNED NOT NULL DEFAULT 1,
  `fecha_subida` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `notas` VARCHAR(255) NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_archivos_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_archivos_usuario` FOREIGN KEY (`subido_por_usuario_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_archivos_consulta` FOREIGN KEY (`consulta_id`)
    REFERENCES `consultas_soap` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX `idx_archivos_paciente` (`paciente_id`, `categoria`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Documentos y estudios clínicos anexados al expediente';

-- ============================================================================
-- 21. TABLA: odontologia_cartillas (Historial Odontológico Base)
-- ============================================================================
CREATE TABLE `odontologia_cartillas` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `paciente_id` INT UNSIGNED NOT NULL,
  `odontologo_id` INT UNSIGNED NOT NULL,
  `fecha_cartilla` DATE NOT NULL,
  `observaciones_generales` TEXT NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_odontocart_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_odontocart_odontologo` FOREIGN KEY (`odontologo_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_odontocart_paciente` (`paciente_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Cartillas odontológicas del paciente';

-- ============================================================================
-- 22. TABLA: odontologia_hallazgos (Odontograma por Pieza Dental FDI)
-- ============================================================================
CREATE TABLE `odontologia_hallazgos` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `cartilla_id` INT UNSIGNED NOT NULL,
  `numero_diente` INT UNSIGNED NOT NULL COMMENT 'Nomenclatura FDI: 11-48 dentición permanente, 51-85 temporal',
  `superficies` VARCHAR(50) NULL COMMENT 'M=Mesial, D=Distal, O=Oclusal, V=Vestibular, L=Lingual, P=Palatino',
  `condicion` ENUM('Sano', 'Caries', 'Empaste', 'Corona', 'Endodoncia', 'Ausente', 'Implante', 'Protesis') NOT NULL DEFAULT 'Sano',
  `procedimiento_planificado` VARCHAR(150) NULL,
  `estado` ENUM('Pendiente', 'En Tratamiento', 'Completado', 'Cancelado') NOT NULL DEFAULT 'Pendiente',
  `fecha_hallazgo` DATE NOT NULL,
  `observaciones` VARCHAR(255) NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_odontohall_cartilla` FOREIGN KEY (`cartilla_id`)
    REFERENCES `odontologia_cartillas` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  INDEX `idx_odontohall_diente` (`cartilla_id`, `numero_diente`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Hallazgos específicos y piezas dentales del odontograma';

-- ============================================================================
-- 23. TABLA: registros_crecimiento_pediatrico (Curvas OMS de Desarrollo)
-- ============================================================================
CREATE TABLE `registros_crecimiento_pediatrico` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `paciente_id` INT UNSIGNED NOT NULL,
  `registrado_por_usuario_id` INT UNSIGNED NOT NULL,
  `fecha_medicion` DATE NOT NULL,
  `etiqueta_edad` VARCHAR(50) NOT NULL COMMENT 'Ej. Nacimiento, 6m, 1a, 2a 4m',
  `edad_meses` DECIMAL(4,1) NOT NULL COMMENT 'Edad exacta en meses para percentiles OMS',
  `peso_kg` DECIMAL(5,2) NOT NULL,
  `percentil_peso_edad` INT UNSIGNED NULL COMMENT 'Percentil peso para la edad (0-100)',
  `talla_cm` DECIMAL(5,2) NOT NULL,
  `percentil_talla_edad` INT UNSIGNED NULL COMMENT 'Percentil talla para la edad (0-100)',
  `perimetro_cefalico_cm` DECIMAL(4,1) NULL,
  `notas` VARCHAR(255) NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_pediatrico_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT `fk_pediatrico_usuario` FOREIGN KEY (`registrado_por_usuario_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  INDEX `idx_pediatrico_paciente_meses` (`paciente_id`, `edad_meses`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Curvas de crecimiento pediátrico bajo estándar OMS';

-- ============================================================================
-- 24. TABLA: transacciones_financieras (Facturación, Cobros e Ingresos)
-- ============================================================================
CREATE TABLE `transacciones_financieras` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `clinica_id` INT UNSIGNED NOT NULL,
  `paciente_id` INT UNSIGNED NOT NULL,
  `cita_id` INT UNSIGNED NULL,
  `numero_factura` VARCHAR(50) NOT NULL UNIQUE,
  `concepto` VARCHAR(150) NOT NULL COMMENT 'Ej. Consulta Médica, Tratamiento Dental, Laboratorio',
  `monto` DECIMAL(10,2) NOT NULL,
  `metodo_pago` ENUM('Efectivo', 'Tarjeta de Credito', 'Tarjeta de Debito', 'Transferencia', 'Seguro Medico') NOT NULL DEFAULT 'Efectivo',
  `estado` ENUM('Pagado', 'Pendiente', 'Cancelado', 'Reembolsado') NOT NULL DEFAULT 'Pagado',
  `fecha_transaccion` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_finanzas_clinica` FOREIGN KEY (`clinica_id`)
    REFERENCES `clinicas` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_finanzas_paciente` FOREIGN KEY (`paciente_id`)
    REFERENCES `pacientes` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_finanzas_cita` FOREIGN KEY (`cita_id`)
    REFERENCES `citas_medicas` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX `idx_finanzas_fecha` (`fecha_transaccion`),
  INDEX `idx_finanzas_estado` (`estado`),
  INDEX `idx_finanzas_paciente` (`paciente_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Módulo administrativo de facturación e ingresos';

-- ============================================================================
-- 25. TABLA: respaldos_base_datos (Control y Auditoría de Copias de Seguridad)
-- ============================================================================
CREATE TABLE `respaldos_base_datos` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `clinica_id` INT UNSIGNED NOT NULL,
  `tipo_respaldo` ENUM('Automatico', 'Manual') NOT NULL DEFAULT 'Automatico',
  `ruta_archivo` VARCHAR(500) NOT NULL,
  `tamano_mb` DECIMAL(6,2) NOT NULL,
  `cantidad_tablas` INT UNSIGNED NOT NULL DEFAULT 27,
  `duracion_segundos` INT UNSIGNED NOT NULL,
  `estado` ENUM('Completado', 'Fallido', 'En Proceso') NOT NULL DEFAULT 'Completado',
  `registro_errores` TEXT NULL,
  `ejecutado_por_usuario_id` INT UNSIGNED NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_respaldos_clinica` FOREIGN KEY (`clinica_id`)
    REFERENCES `clinicas` (`id`) ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT `fk_respaldos_usuario` FOREIGN KEY (`ejecutado_por_usuario_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX `idx_respaldos_fecha` (`creado_en`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Registro de copias de seguridad de la base de datos';

-- ============================================================================
-- 26. TABLA: preferencias_usuario (Configuración Personal por Usuario)
-- ============================================================================
CREATE TABLE `preferencias_usuario` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `usuario_id` INT UNSIGNED NOT NULL UNIQUE,
  `notificaciones_activas` TINYINT(1) NOT NULL DEFAULT 1,
  `recordatorios_correo` TINYINT(1) NOT NULL DEFAULT 1,
  `sonido_activo` TINYINT(1) NOT NULL DEFAULT 1,
  `idioma` VARCHAR(10) NOT NULL DEFAULT 'es',
  `duracion_consulta_defecto_min` INT UNSIGNED NOT NULL DEFAULT 30,
  `modo_tema` ENUM('Claro', 'Oscuro', 'Sistema') NOT NULL DEFAULT 'Claro',
  `actualizado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_preferencias_usuario` FOREIGN KEY (`usuario_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Preferencias individuales de usuario';

-- ============================================================================
-- 27. TABLA: bitacora_auditoria (Auditoría HIPAA y Trazabilidad de Acciones)
-- ============================================================================
CREATE TABLE `bitacora_auditoria` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `usuario_id` INT UNSIGNED NULL,
  `accion` VARCHAR(80) NOT NULL COMMENT 'LOGIN, VER_EXPEDIENTE, CREAR_CONSULTA, EMITIR_RECETA, REGISTRAR_EPICRISIS, EXPORTAR_PDF',
  `nombre_tabla_afectada` VARCHAR(80) NOT NULL COMMENT 'pacientes, consultas_soap, epicrisis, recetas_medicas, etc.',
  `registro_id` INT UNSIGNED NULL,
  `direccion_ip` VARCHAR(45) NULL,
  `agente_usuario` VARCHAR(255) NULL,
  `detalles_json` JSON NULL,
  `creado_en` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_auditoria_usuario` FOREIGN KEY (`usuario_id`)
    REFERENCES `usuarios` (`id`) ON UPDATE CASCADE ON DELETE SET NULL,
  INDEX `idx_auditoria_usuario_accion` (`usuario_id`, `accion`),
  INDEX `idx_auditoria_creado_en` (`creado_en`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Trazabilidad y auditoría de seguridad';

-- ============================================================================
-- VISTAS CLÍNICAS Y ADMINISTRATIVAS EN ESPAÑOL
-- ============================================================================

-- Vista 1: Resumen Diario de Citas Médicas
CREATE OR REPLACE VIEW `vw_resumen_citas_diarias` AS
SELECT 
  c.id AS cita_id,
  c.fecha_cita,
  c.hora_cita,
  c.estado AS estado_cita,
  s.nombre AS nombre_servicio,
  p.id AS paciente_id,
  p.codigo_paciente,
  CONCAT(p.nombres, ' ', p.apellidos) AS nombre_paciente,
  p.telefono AS telefono_paciente,
  p.alerta_critica,
  u.id AS medico_id,
  u.nombre_completo AS nombre_medico,
  u.especialidad
FROM `citas_medicas` c
JOIN `pacientes` p ON c.paciente_id = p.id
JOIN `servicios` s ON c.servicio_id = s.id
JOIN `usuarios` u ON c.medico_id = u.id;

-- Vista 2: Monitoreo de Tratamientos Activos con Paciente y Médico
CREATE OR REPLACE VIEW `vw_monitoreo_tratamientos_activos` AS
SELECT 
  t.id AS tratamiento_id,
  t.titulo_tratamiento,
  t.tipo_tratamiento,
  t.fecha_inicio,
  t.fecha_fin_estimada,
  t.estado AS estado_tratamiento,
  p.codigo_paciente,
  CONCAT(p.nombres, ' ', p.apellidos) AS paciente,
  u.nombre_completo AS medico_tratante,
  cie.codigo AS codigo_cie10,
  cie.descripcion AS diagnostico_cie10,
  COUNT(tm.id) AS total_medicamentos_prescritos
FROM `tratamientos` t
JOIN `pacientes` p ON t.paciente_id = p.id
JOIN `usuarios` u ON t.medico_id = u.id
LEFT JOIN `catalogo_cie10` cie ON t.diagnostico_id = cie.id
LEFT JOIN `tratamiento_medicamentos` tm ON t.id = tm.tratamiento_id
GROUP BY t.id, t.titulo_tratamiento, t.tipo_tratamiento, t.fecha_inicio, t.fecha_fin_estimada, t.estado, p.codigo_paciente, p.nombres, p.apellidos, u.nombre_completo, cie.codigo, cie.descripcion;

-- Vista 3: Resumen Detallado de Epicrisis Hospitalaria
CREATE OR REPLACE VIEW `vw_resumen_epicrisis_clinica` AS
SELECT 
  e.id AS epicrisis_id,
  e.codigo_epicrisis,
  e.fecha_ingreso,
  e.fecha_egreso,
  e.dias_estancia,
  e.tipo_atencion,
  p.codigo_paciente,
  CONCAT(p.nombres, ' ', p.apellidos) AS paciente,
  u.nombre_completo AS medico_alta,
  cie_in.codigo AS cie10_ingreso,
  cie_in.descripcion AS diagnostico_ingreso,
  cie_eg.codigo AS cie10_egreso,
  cie_eg.descripcion AS diagnostico_egreso,
  e.estado_al_egreso,
  e.pronostico
FROM `epicrisis` e
JOIN `pacientes` p ON e.paciente_id = p.id
JOIN `usuarios` u ON e.medico_responsable_id = u.id
JOIN `catalogo_cie10` cie_in ON e.diagnostico_ingreso_id = cie_in.id
JOIN `catalogo_cie10` cie_eg ON e.diagnostico_egreso_id = cie_eg.id;

-- Vista 4: Resumen Financiero Mensual
CREATE OR REPLACE VIEW `vw_resumen_financiero_mensual` AS
SELECT 
  DATE_FORMAT(fecha_transaccion, '%Y-%m') AS mes_transaccion,
  COUNT(id) AS total_transacciones,
  SUM(CASE WHEN estado = 'Pagado' THEN monto ELSE 0 END) AS total_ingresos,
  SUM(CASE WHEN estado = 'Pendiente' THEN monto ELSE 0 END) AS total_por_cobrar,
  SUM(CASE WHEN estado = 'Cancelado' THEN monto ELSE 0 END) AS total_cancelado
FROM `transacciones_financieras`
GROUP BY DATE_FORMAT(fecha_transaccion, '%Y-%m')
ORDER BY mes_transaccion DESC;

-- ============================================================================
-- DATOS SEMILLA (SEEDS) COMPLETOS EN ESPAÑOL
-- ============================================================================

-- 1. Roles
INSERT INTO `roles` (`id`, `nombre`, `descripcion`) VALUES
  (1, 'Administrador', 'Control total del sistema, configuración y usuarios'),
  (2, 'Médico', 'Atención médica, emisión de diagnósticos, tratamientos y recetas'),
  (3, 'Enfermero', 'Triaje, registro de signos vitales y cuidados'),
  (4, 'Recepcionista', 'Gestión de agenda, citas médicas y facturación'),
  (5, 'Farmacéutico', 'Dispensación de recetas e inventario de medicamentos')
ON DUPLICATE KEY UPDATE `nombre`=`nombre`;

-- 2. Clínicas
INSERT INTO `clinicas` (`id`, `nombre`, `direccion`, `telefono`, `correo`, `identificacion_fiscal`) VALUES
  (1, 'MediCore Clínica Central', 'Av. Principal 123, Col. Centro, Managua, Nicaragua', '+505 2255 7788', 'contacto@medicore.com', 'J0310000123456')
ON DUPLICATE KEY UPDATE `nombre`=`nombre`;

-- 3. Usuarios
INSERT INTO `usuarios` (`id`, `clinica_id`, `rol_id`, `codigo_profesional`, `nombre_completo`, `correo`, `hash_contrasena`, `telefono`, `especialidad`, `cedula_profesional`) VALUES
  (1, 1, 1, 'ADM-001', 'Administrador Principal', 'admin@medicore.com', '$2b$12$placeholder_hash_admin', '+505 8888 1111', 'Administración de Salud', 'ADM-998877'),
  (2, 1, 2, 'DRS-001', 'Dr. Alexander Smith', 'dr.smith@medicore.com', '$2b$12$placeholder_hash_smith', '+505 8888 2222', 'Medicina General', 'MINSA-12345'),
  (3, 1, 2, 'DRM-002', 'Dr. Carlos Mendoza', 'dr.mendoza@medicore.com', '$2b$12$placeholder_hash_mendoza', '+505 8888 3333', 'Medicina Interna', 'MINSA-67890'),
  (4, 1, 2, 'DRR-003', 'Dra. Sofía Rodríguez', 'dra.rodriguez@medicore.com', '$2b$12$placeholder_hash_rodriguez', '+505 8888 4444', 'Pediatría', 'MINSA-11223'),
  (5, 1, 2, 'DRD-004', 'Dra. Lucía Martínez', 'dra.martinez@medicore.com', '$2b$12$placeholder_hash_martinez', '+505 8888 5555', 'Odontología Integral', 'MINSA-44556'),
  (6, 1, 3, 'ENF-001', 'Lic. Carmen Adams', 'carmen.adams@medicore.com', '$2b$12$placeholder_hash_adams', '+505 8888 6666', 'Enfermería General', 'MINSA-77889')
ON DUPLICATE KEY UPDATE `nombre_completo`=`nombre_completo`;

-- 4. Departamentos
INSERT INTO `departamentos` (`id`, `nombre`, `descripcion`) VALUES
  (1, 'Medicina General', 'Atención ambulatoria integral y prevención'),
  (2, 'Medicina Interna', 'Manejo de enfermedades complejas y crónicas'),
  (3, 'Pediatría', 'Atención pediátrica, control de niño sano y vacunas'),
  (4, 'Odontología', 'Salud bucal, endodoncia, ortodoncia y prótesis'),
  (5, 'Radiología e Imagen', 'Estudios de rayos X, ultrasonidos y tomografías')
ON DUPLICATE KEY UPDATE `nombre`=`nombre`;

-- 5. Servicios
INSERT INTO `servicios` (`id`, `departamento_id`, `nombre`, `costo_base`, `duracion_minutos`) VALUES
  (1, 1, 'Consulta Médica General', 500.00, 30),
  (2, 2, 'Consulta Medicina Interna', 750.00, 45),
  (3, 3, 'Control Pediátrico y Desarrollo OMS', 600.00, 30),
  (4, 4, 'Consulta Odontológica y Diagnóstico', 450.00, 30),
  (5, 4, 'Limpieza Dental y Profilaxis Profunda', 850.00, 45),
  (6, 5, 'Radiografía Lumbar AP / Lateral', 1200.00, 20)
ON DUPLICATE KEY UPDATE `nombre`=`nombre`;

-- 6. Pacientes
INSERT INTO `pacientes` (`id`, `clinica_id`, `codigo_paciente`, `numero_identidad`, `nombres`, `apellidos`, `fecha_nacimiento`, `genero`, `tipo_sangre`, `telefono`, `correo`, `direccion`, `alerta_critica`) VALUES
  (1, 1, 'PT-8472', '001-140589-0001A', 'Ana', 'García López', '1989-05-14', 'Femenino', 'O+', '+505 8811 2233', 'ana.garcia@email.com', 'Col. Centro, Calle 3 #104, Managua', 1),
  (2, 1, 'PT-8473', '001-231178-0002B', 'Carlos', 'López Martínez', '1978-11-23', 'Masculino', 'A+', '+505 8822 3344', 'carlos.lopez@email.com', 'Residencial Las Colinas #45', 0),
  (3, 1, 'PT-8474', '001-180295-0003C', 'María', 'Rodríguez Silva', '1995-02-18', 'Femenino', 'B+', '+505 8833 4455', 'maria.rodriguez@email.com', 'Bello Horizonte Etapa 2 #12', 0),
  (4, 1, 'PT-8475', '001-100821-0004D', 'Mateo', 'García', '2021-08-10', 'Masculino', 'O+', '+505 8844 5566', 'contacto.mateo@email.com', 'Villa Fontana Sur #89', 0)
ON DUPLICATE KEY UPDATE `nombres`=`nombres`;

-- 7. Contactos de Emergencia
INSERT INTO `contactos_emergencia` (`paciente_id`, `nombre_completo`, `parentesco`, `telefono`, `es_principal`) VALUES
  (1, 'Roberto Martínez García', 'Cónyuge', '+505 8877 6655', 1),
  (2, 'Elena Torres de López', 'Cónyuge', '+505 8866 5544', 1),
  (4, 'Sofía Hernández de García', 'Madre', '+505 8844 5566', 1);

-- 8. Alergias del Paciente
INSERT INTO `alergias_paciente` (`paciente_id`, `alergeno`, `reaccion`, `severidad`, `fecha_diagnostico`, `registrado_por_usuario_id`, `observaciones`) VALUES
  (1, 'Penicilina', 'Shock Anafiláctico y Urticaria Generalizada', 'Critica', '2021-04-12', 2, 'Contraindicación absoluta para betalactámicos'),
  (2, 'Ibuprofeno / AINEs', 'Edema facial y broncoespasmo moderado', 'Grave', '2022-09-18', 3, 'Evitar AINEs; usar Paracetamol');

-- 9. Citas Médicas
INSERT INTO `citas_medicas` (`id`, `clinica_id`, `paciente_id`, `medico_id`, `servicio_id`, `fecha_cita`, `hora_cita`, `estado`, `motivo_cita`) VALUES
  (1, 1, 1, 2, 1, CURDATE(), '09:00:00', 'En Consulta', 'Revisión general y control de síntomas respiratorios'),
  (2, 1, 2, 3, 2, CURDATE(), '09:45:00', 'Confirmada', 'Control de hipertensión arterial y lumbago'),
  (3, 1, 4, 4, 3, CURDATE(), '10:30:00', 'Pendiente', 'Control de crecimiento pediátrico a los 2 años');

-- 10. Signos Vitales
INSERT INTO `signos_vitales` (`id`, `paciente_id`, `registrado_por_usuario_id`, `presion_sistolica`, `presion_diastolica`, `frecuencia_cardiaca`, `frecuencia_respiratoria`, `temperatura_celsius`, `peso_kg`, `altura_cm`, `saturacion_oxigeno_pct`) VALUES
  (1, 1, 6, 118, 76, 74, 18, 36.6, 62.50, 164.00, 98),
  (2, 2, 6, 138, 88, 80, 16, 36.8, 84.00, 175.00, 97),
  (3, 4, 6, NULL, NULL, 95, 24, 36.5, 12.80, 88.50, 99);

-- 11. Consultas SOAP
INSERT INTO `consultas_soap` (`id`, `cita_id`, `paciente_id`, `medico_id`, `signos_vitales_id`, `fecha_consulta`, `subjetivo`, `objetivo`, `evaluacion`, `plan`, `es_borrador`, `esta_firmada`) VALUES
  (1, 1, 1, 2, 1, NOW(),
   'Paciente femenina de 37 años acude por cuadro de 4 días de evolución con odinofagia, rinorrea hialina y febrícula no cuantificada.',
   'Orofaringe congestiva con eritema difuso sin placas purulentas. Membranas timpánicas íntegras. Campos pulmonares limpios y bien ventilados sin ruidos agregados. TA: 118/76 mmHg, FC: 74 lpm, SatO2: 98%.',
   'Faringoamigdalitis aguda de etiología viral probable. Evolución favorable. Alergia crítica documentada a penicilina.',
   '1. Manejo sintomático con hidratación oral abundante.\n2. Paracetamol 500mg cada 8 horas si hay fiebre o dolor.\n3. Reposo por 48 horas.\n4. Signos de alarma explicados al paciente.', 0, 1);

-- 12. Catálogo CIE-10
INSERT INTO `catalogo_cie10` (`id`, `codigo`, `descripcion`, `capitulo`) VALUES
  (1, 'J00', 'Rinofaringitis aguda (resfriado común)', 'Enfermedades del sistema respiratorio'),
  (2, 'J02.9', 'Faringitis aguda, no especificada', 'Enfermedades del sistema respiratorio'),
  (3, 'I10', 'Hipertensión esencial (primaria)', 'Enfermedades del sistema circulatorio'),
  (4, 'M54.5', 'Lumbago no especificado', 'Enfermedades del sistema musculoesquelético'),
  (5, 'E11.9', 'Diabetes mellitus tipo 2 sin mención de complicación', 'Enfermedades endocrinas y metabólicas'),
  (6, 'K02.1', 'Caries de la dentina', 'Enfermedades del sistema digestivo')
ON DUPLICATE KEY UPDATE `descripcion`=`descripcion`;

-- 13. Diagnósticos de Consulta
INSERT INTO `diagnosticos_consulta` (`consulta_id`, `cie10_id`, `tipo_diagnostico`, `notas_clinicas`) VALUES
  (1, 2, 'Principal', 'Faringitis aguda viral autolimitada');

-- 14. Medicamentos (Catálogo Farmacéutico)
INSERT INTO `medicamentos` (`id`, `codigo_nacional`, `nombre_comercial`, `nombre_generico`, `forma_farmaceutica`, `concentracion`, `via_administracion`, `presentacion`, `laboratorio_fabricante`, `codigo_atc`, `requiere_receta`, `stock_actual`, `precio_unitario`) VALUES
  (1, 'MED-PAR-500', 'Paracetamol Genfar', 'Paracetamol (Acetaminofén)', 'Tableta', '500 mg', 'Oral', 'Caja x 20 tabletas', 'Genfar S.A.', 'N02BE01', 0, 250, 45.00),
  (2, 'MED-AMX-500', 'Amoxil', 'Amoxicilina', 'Cápsula', '500 mg', 'Oral', 'Caja x 30 cápsulas', 'GSK', 'J01CA04', 1, 120, 180.00),
  (3, 'MED-LOS-50',  'Cozaar', 'Losartán Potásico', 'Tableta', '50 mg', 'Oral', 'Caja x 30 tabletas', 'Organon', 'C09CA01', 1, 85, 320.00),
  (4, 'MED-IBU-600', 'Actron 600', 'Ibuprofeno', 'Cápsula', '600 mg', 'Oral', 'Caja x 10 cápsulas blandas', 'Bayer', 'M01AE01', 0, 150, 95.00),
  (5, 'MED-AZI-500', 'Zithromax', 'Azitromicina', 'Tableta', '500 mg', 'Oral', 'Caja x 3 tabletas', 'Pfizer', 'J01FA10', 1, 60, 290.00),
  (6, 'MED-OMP-20',  'Prilosec', 'Omeprazol', 'Cápsula', '20 mg', 'Oral', 'Frasco x 14 cápsulas', 'AstraZeneca', 'A02BC01', 0, 190, 110.00)
ON DUPLICATE KEY UPDATE `nombre_generico`=`nombre_generico`;

-- 15. Tratamientos
INSERT INTO `tratamientos` (`id`, `paciente_id`, `medico_id`, `consulta_id`, `diagnostico_id`, `titulo_tratamiento`, `tipo_tratamiento`, `descripcion`, `objetivo_terapeutico`, `fecha_inicio`, `fecha_fin_estimada`, `estado`, `indicaciones_generales`) VALUES
  (1, 1, 2, 1, 2, 'Manejo Sintomático Faringitis Aguda', 'Farmacológico',
   'Tratamiento analgésico y antipirético de soporte para proceso faríngeo de origen vírico.',
   'Control del dolor faríngeo y resolución del cuadro en 5 a 7 días.',
   CURDATE(), DATE_ADD(CURDATE(), INTERVAL 5 DAY), 'En Curso', 'Dieta blanda tibia, abundante hidratación con suero oral y reposo.'),
  (2, 2, 3, NULL, 3, 'Control Integral Hipertensión Arterial Grado 1', 'Combinado',
   'Esquema antihipertensivo con ARA-II complementado con modificaciones higiénico-dietéticas y ejercicio aeróbico.',
   'Lograr metas de presión arterial < 130/80 mmHg y reducción de riesgo cardiovascular.',
   '2026-08-01', '2026-11-01', 'En Curso', 'Reducción de sodio en la dieta (< 2g/día), caminata 30 minutos diarios y registro tensional.');

-- 16. Tratamiento - Medicamentos
INSERT INTO `tratamiento_medicamentos` (`tratamiento_id`, `medicamento_id`, `dosis`, `frecuencia`, `duracion`, `via_administracion`, `instrucciones_especificas`, `cantidad_total_prescrita`) VALUES
  (1, 1, '500 mg (1 tableta)', 'Cada 8 horas', '5 días', 'Oral', 'Tomar después de las comidas con abundante agua', 15),
  (2, 3, '50 mg (1 tableta)', 'Cada 24 horas', '90 días', 'Oral', 'Tomar en ayunas todas las mañanas a la misma hora', 90);

-- 17. Recetas Médicas
INSERT INTO `recetas_medicas` (`id`, `consulta_id`, `tratamiento_id`, `paciente_id`, `medico_id`, `clinica_id`, `codigo_receta`, `fecha_emision`, `fecha_vencimiento`, `estado`, `indicaciones_generales`) VALUES
  (1, 1, 1, 1, 2, 1, 'RX-2026-0001', CURDATE(), DATE_ADD(CURDATE(), INTERVAL 30 DAY), 'Activa', 'Completar el tratamiento según las pautas señaladas. No suspender sin indicación.')
ON DUPLICATE KEY UPDATE `codigo_receta`=`codigo_receta`;

-- 18. Detalle de Receta
INSERT INTO `detalle_receta` (`receta_id`, `medicamento_id`, `nombre_medicamento_texto`, `dosis`, `frecuencia`, `duracion`, `via_administracion`, `instrucciones`, `cantidad_unidades`) VALUES
  (1, 1, 'Paracetamol 500mg', '1 tableta (500mg)', 'Cada 8 horas', '5 días', 'Oral', 'Tomar 1 tableta cada 8h en caso de dolor o fiebre.', 15);

-- 19. Epicrisis (Informe Detallado de Alta / Egreso Hospitalario)
INSERT INTO `epicrisis` (`id`, `codigo_epicrisis`, `paciente_id`, `medico_responsable_id`, `clinica_id`, `consulta_id`, `tratamiento_id`, `fecha_ingreso`, `fecha_egreso`, `tipo_atencion`, `motivo_ingreso`, `resumen_historia_clinica`, `antecedentes_relevantes`, `diagnostico_ingreso_id`, `diagnostico_egreso_id`, `diagnosticos_secundarios`, `resumen_evolucion`, `procedimientos_quirurgicos_realizados`, `estudios_diagnosticos_relevantes`, `tratamiento_recibido`, `complicaciones`, `estado_al_egreso`, `pronostico`, `plan_manejo_ambulatorio`, `medicacion_al_alta`, `citas_control_seguimiento`, `signos_alarma_urgencias`) VALUES
  (1, 'EPI-2026-0001', 2, 3, 1, NULL, 2, '2026-08-10 08:30:00', '2026-08-14 11:00:00', 'Hospitalización',
   'Dolor lumbar agudo e incapacitante irradiado a miembro inferior derecho acompañado de crisis hipertensiva reactiva.',
   'Paciente masculino de 47 años sin adherencia a control antihipertensivo que presenta lumbalgia severa tras levantamiento de carga pesada.',
   'Hipertensión arterial diagnosticada hace 3 años; sobrepeso grado 1; sin antecedentes quirúrgicos previos.',
   4, 4, 'Hipertensión esencial (CIE-10: I10), Obesidad grado I',
   'Durante las 96 horas de internamiento se instauró analgesia parenteral con neuromoduladores y terapia antihipertensiva. El paciente presentó mejoría sustancial de la movilidad lumbar y descenso tensional a cifras controladas (125/82 mmHg). Deambulación asistida tolerada sin parestesias.',
   'Infiltración analgésica guiada por ecografía para alivio facetario lumbar L4-L5.',
   'Resonancia magnética lumbar: protusión discal L4-L5 sin estenosis de canal severa. Perfil lipídico con triglicéridos en 210 mg/dl.',
   'Dexametasona 8mg IV/día por 2 días, Paracetamol 1g IV cada 8h, Losartán 50mg VO c/24h, Fisioterapia motora inicial.',
   'Ninguna complicación intrahospitalaria.',
   'Mejorado', 'Favorable',
   'Reposo relativo sin flexión lumbar forzada por 7 días. Inicio de rehabilitación física ambulatoria. Dieta hiposódica y control de peso.',
   '1. Losartán 50mg: 1 tableta cada mañana.\n2. Paracetamol 500mg: 1 tableta cada 8 horas si hay molestia lumbar.\n3. Complejo B + Gabapentina 300mg: 1 cápsula cada noche por 14 días.',
   'Cita de control por Medicina Interna en 15 días y valoración por Medicina Física y Rehabilitación en 3 semanas.',
   'Regresar de urgencia ante pérdida de fuerza en piernas, incontinencia de esfínteres urinario/fecal o dolor intratable.');

-- 20. Archivos Diagnóstico
INSERT INTO `archivos_diagnostico` (`paciente_id`, `subido_por_usuario_id`, `nombre_archivo`, `categoria`, `archivo_url`, `tamano_kb`, `tipo_mime`, `total_paginas`, `notas`) VALUES
  (2, 3, 'Resonancia_Magnetica_Lumbar_L4L5.pdf', 'Imagenologia', 'https://archivos.medicore.com/estudios/rm_lumbar_pt8473.pdf', 8450, 'application/pdf', 4, 'Estudio complementario de ingreso hospitalario'),
  (1, 2, 'Biometria_Hematica_Completa.pdf', 'Laboratorio', 'https://archivos.medicore.com/estudios/bh_pt8472.pdf', 1200, 'application/pdf', 1, 'Control de rutina ambulatorio');

-- 21. Odontología Cartillas y Hallazgos
INSERT INTO `odontologia_cartillas` (`id`, `paciente_id`, `odontologo_id`, `fecha_cartilla`, `observaciones_generales`) VALUES
  (1, 1, 5, CURDATE(), 'Evaluación odontológica inicial. Requiere restauración en primer molar inferior derecho.');

INSERT INTO `odontologia_hallazgos` (`cartilla_id`, `numero_diente`, `superficies`, `condicion`, `procedimiento_planificado`, `estado`, `fecha_hallazgo`) VALUES
  (1, 46, 'O, D', 'Caries', 'Restauración con resina compuesta fotocurable', 'Pendiente', CURDATE());

-- 22. Pediatría Crecimiento
INSERT INTO `registros_crecimiento_pediatrico` (`paciente_id`, `registrado_por_usuario_id`, `fecha_medicion`, `etiqueta_edad`, `edad_meses`, `peso_kg`, `percentil_peso_edad`, `talla_cm`, `percentil_talla_edad`, `perimetro_cefalico_cm`) VALUES
  (4, 4, CURDATE(), '2a', 24.0, 12.80, 55, 88.50, 60, 48.2);

-- 23. Finanzas
INSERT INTO `transacciones_financieras` (`clinica_id`, `paciente_id`, `cita_id`, `numero_factura`, `concepto`, `monto`, `metodo_pago`, `estado`) VALUES
  (1, 1, 1, 'FAC-2026-0001', 'Consulta Médica General', 500.00, 'Efectivo', 'Pagado'),
  (1, 2, 2, 'FAC-2026-0002', 'Consulta Medicina Interna', 750.00, 'Tarjeta de Credito', 'Pagado');

-- Fin del script maestro en español

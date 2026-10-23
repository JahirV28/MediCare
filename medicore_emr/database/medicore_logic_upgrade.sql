-- ============================================================
-- MediCore EMR — MIGRACIÓN DE LÓGICA REAL Y ENDURECIMIENTO DE BD
-- ------------------------------------------------------------
-- EJECUTAR UNA SOLA VEZ (o las veces que se quiera: es idempotente)
-- en Supabase  ->  SQL Editor  ->  New query  ->  pegar todo  ->  Run
--
-- Qué hace:
--   1. Zona horaria de la clínica (America/Managua) para "hoy".
--   2. Corrige bugs de procedimientos/triggers anteriores
--      (timeline dental, signos vitales, choque de agenda).
--   3. Nuevos procedimientos: panel, notificaciones, cobro de cita,
--      reportes reales, registro de paciente con código secuencial.
--   4. Triggers de integridad (agenda, pagos, alergias, SOAP, pacientes).
--   5. Restricciones CHECK e índices de rendimiento.
-- ============================================================

-- ------------------------------------------------------------
-- 0. UTILIDADES BASE
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_clinic_today()
RETURNS DATE
LANGUAGE sql
STABLE
AS $$
  SELECT (now() AT TIME ZONE 'America/Managua')::date;
$$;

CREATE OR REPLACE FUNCTION public.fn_normalize_appointment_status(p_status TEXT)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE lower(btrim(COALESCE(p_status, '')))
    WHEN 'waiting'      THEN 'Waiting'
    WHEN 'en espera'    THEN 'Waiting'
    WHEN 'pendiente'    THEN 'Waiting'
    WHEN ''             THEN 'Waiting'
    WHEN 'confirmed'    THEN 'Confirmed'
    WHEN 'confirmado'   THEN 'Confirmed'
    WHEN 'confirmada'   THEN 'Confirmed'
    WHEN 'in progress'  THEN 'In Progress'
    WHEN 'en progreso'  THEN 'In Progress'
    WHEN 'completed'    THEN 'Completed'
    WHEN 'completado'   THEN 'Completed'
    WHEN 'completada'   THEN 'Completed'
    WHEN 'atendido'     THEN 'Completed'
    WHEN 'finalizada'   THEN 'Completed'
    WHEN 'cancelled'    THEN 'Cancelled'
    WHEN 'cancelado'    THEN 'Cancelled'
    WHEN 'cancelada'    THEN 'Cancelled'
    ELSE p_status
  END;
$$;

CREATE SEQUENCE IF NOT EXISTS public.seq_patient_code START 1001;
CREATE SEQUENCE IF NOT EXISTS public.seq_invoice_number START 1;

CREATE OR REPLACE FUNCTION public.fn_next_patient_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_code TEXT;
BEGIN
  LOOP
    v_code := 'PT-' || lpad(nextval('public.seq_patient_code')::text, 4, '0')
              || '-' || to_char(public.fn_clinic_today(), 'YY');
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.patients WHERE patient_code = v_code);
  END LOOP;
  RETURN v_code;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_next_invoice_number()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
  v_code TEXT;
BEGIN
  LOOP
    v_code := 'REC-' || to_char(public.fn_clinic_today(), 'YYYY') || '-'
              || lpad(nextval('public.seq_invoice_number')::text, 6, '0');
    EXIT WHEN NOT EXISTS (SELECT 1 FROM public.financial_transactions WHERE invoice_number = v_code);
  END LOOP;
  RETURN v_code;
END;
$$;


-- ------------------------------------------------------------
-- 1. TRIGGER: REGLAS DE AGENDA (reemplaza trg_prevent_appointment_overlap)
--    * Normaliza el estado (Pendiente/Atendido/... -> estándar BD)
--    * Paciente y médico deben estar activos al AGENDAR
--    * No se agenda en fechas pasadas
--    * Una cita completada no se reabre
--    * Sin choques de médico ni de paciente (solo cuando cambia algo relevante,
--      así no se rompen las citas históricas)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_appointment_rules()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_today DATE := public.fn_clinic_today();
  v_flag  BOOLEAN;
  v_check BOOLEAN := FALSE;
BEGIN
  NEW.status := public.fn_normalize_appointment_status(NEW.status);

  IF TG_OP = 'INSERT' THEN
    SELECT is_active INTO v_flag FROM public.patients WHERE id = NEW.patient_id;
    IF v_flag IS NOT TRUE THEN
      RAISE EXCEPTION 'El paciente está inactivo (o no existe) y no puede recibir nuevas citas.';
    END IF;

    SELECT is_active INTO v_flag FROM public.users WHERE id = NEW.doctor_id;
    IF v_flag IS NOT TRUE THEN
      RAISE EXCEPTION 'El médico seleccionado está inactivo (o no existe).';
    END IF;

    IF NEW.appointment_date < v_today AND NEW.status NOT IN ('Cancelled', 'Completed') THEN
      RAISE EXCEPTION 'No se pueden agendar citas en fechas pasadas (%).', NEW.appointment_date;
    END IF;

    v_check := NEW.status <> 'Cancelled';
  ELSE
    IF OLD.status = 'Completed' AND NEW.status <> 'Completed' THEN
      RAISE EXCEPTION 'Una cita completada no puede reabrirse ni cancelarse.';
    END IF;

    IF NEW.appointment_date IS DISTINCT FROM OLD.appointment_date
       AND NEW.appointment_date < v_today
       AND NEW.status NOT IN ('Cancelled', 'Completed') THEN
      RAISE EXCEPTION 'No se puede reprogramar una cita a una fecha pasada (%).', NEW.appointment_date;
    END IF;

    v_check := NEW.status <> 'Cancelled' AND (
      NEW.doctor_id        IS DISTINCT FROM OLD.doctor_id
      OR NEW.appointment_date IS DISTINCT FROM OLD.appointment_date
      OR NEW.appointment_time IS DISTINCT FROM OLD.appointment_time
      OR OLD.status = 'Cancelled'
    );
  END IF;

  IF v_check THEN
    IF EXISTS (
      SELECT 1 FROM public.appointments a
      WHERE a.doctor_id = NEW.doctor_id
        AND a.appointment_date = NEW.appointment_date
        AND a.appointment_time = NEW.appointment_time
        AND a.id <> COALESCE(NEW.id, -1)
        AND a.status <> 'Cancelled'
    ) THEN
      RAISE EXCEPTION 'Colisión de agenda: el médico ya tiene una cita activa el % a las %.',
        NEW.appointment_date, to_char(NEW.appointment_time, 'HH12:MI AM');
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.appointments a
      WHERE a.patient_id = NEW.patient_id
        AND a.appointment_date = NEW.appointment_date
        AND a.appointment_time = NEW.appointment_time
        AND a.id <> COALESCE(NEW.id, -1)
        AND a.status <> 'Cancelled'
    ) THEN
      RAISE EXCEPTION 'El paciente ya tiene otra cita activa el % a las %.',
        NEW.appointment_date, to_char(NEW.appointment_time, 'HH12:MI AM');
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_appointment_overlap ON public.appointments;
DROP TRIGGER IF EXISTS trg_appointment_rules ON public.appointments;
CREATE TRIGGER trg_appointment_rules
  BEFORE INSERT OR UPDATE ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_appointment_rules();

-- Al completar una cita se actualiza la última visita del paciente
CREATE OR REPLACE FUNCTION public.fn_trg_appointment_after_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'Completed'
     AND (TG_OP = 'INSERT' OR OLD.status IS DISTINCT FROM 'Completed') THEN
    UPDATE public.patients SET last_visit = CURRENT_TIMESTAMP WHERE id = NEW.patient_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_appointment_after_change ON public.appointments;
CREATE TRIGGER trg_appointment_after_change
  AFTER INSERT OR UPDATE OF status ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_appointment_after_change();


-- ------------------------------------------------------------
-- 2. TRIGGERS: PACIENTES (código automático + validaciones) y ALERGIAS
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_patients_rules()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.full_name IS DISTINCT FROM OLD.full_name THEN
    NEW.full_name := btrim(regexp_replace(NEW.full_name, '\s+', ' ', 'g'));
    IF char_length(NEW.full_name) < 3 THEN
      RAISE EXCEPTION 'El nombre del paciente debe tener al menos 3 caracteres.';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' AND (NEW.patient_code IS NULL OR btrim(NEW.patient_code) = '') THEN
    NEW.patient_code := public.fn_next_patient_code();
  END IF;

  IF NEW.birth_date IS NOT NULL
     AND (TG_OP = 'INSERT' OR NEW.birth_date IS DISTINCT FROM OLD.birth_date) THEN
    IF NEW.birth_date > public.fn_clinic_today() THEN
      RAISE EXCEPTION 'La fecha de nacimiento no puede estar en el futuro.';
    END IF;
    IF NEW.birth_date < DATE '1900-01-01' THEN
      RAISE EXCEPTION 'La fecha de nacimiento no es válida.';
    END IF;
  END IF;

  IF NEW.email IS NOT NULL AND btrim(NEW.email) <> ''
     AND (TG_OP = 'INSERT' OR NEW.email IS DISTINCT FROM OLD.email) THEN
    IF NEW.email !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
      RAISE EXCEPTION 'El correo electrónico del paciente no tiene un formato válido.';
    END IF;
  END IF;

  IF NEW.identity_number IS NOT NULL AND btrim(NEW.identity_number) = '' THEN
    NEW.identity_number := NULL;  -- evita violar UNIQUE con cadenas vacías
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_patients_rules ON public.patients;
CREATE TRIGGER trg_patients_rules
  BEFORE INSERT OR UPDATE ON public.patients
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_patients_rules();

-- has_alert siempre refleja si existen alergias activas
CREATE OR REPLACE FUNCTION public.fn_trg_sync_patient_alert_flag()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_pid BIGINT := COALESCE(NEW.patient_id, OLD.patient_id);
BEGIN
  UPDATE public.patients p
  SET has_alert = EXISTS (
    SELECT 1 FROM public.allergy_alerts a WHERE a.patient_id = p.id AND a.is_active
  )
  WHERE p.id = v_pid;

  IF TG_OP = 'UPDATE' AND OLD.patient_id IS DISTINCT FROM NEW.patient_id THEN
    UPDATE public.patients p
    SET has_alert = EXISTS (
      SELECT 1 FROM public.allergy_alerts a WHERE a.patient_id = p.id AND a.is_active
    )
    WHERE p.id = OLD.patient_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_patient_alert_flag ON public.allergy_alerts;
CREATE TRIGGER trg_sync_patient_alert_flag
  AFTER INSERT OR UPDATE OR DELETE ON public.allergy_alerts
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_sync_patient_alert_flag();

-- Sincronización inicial de la bandera de alerta
UPDATE public.patients p
SET has_alert = EXISTS (SELECT 1 FROM public.allergy_alerts a WHERE a.patient_id = p.id AND a.is_active)
WHERE p.has_alert IS DISTINCT FROM EXISTS (SELECT 1 FROM public.allergy_alerts a WHERE a.patient_id = p.id AND a.is_active);


-- ------------------------------------------------------------
-- 3. TRIGGERS: FINANZAS
--    * Folio automático, montos válidos
--    * Una cita solo se cobra una vez
--    * Cobro pagado => la cita pasa a Completada
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_financial_rules()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.amount IS NULL OR NEW.amount < 0 THEN
    RAISE EXCEPTION 'El monto de la transacción no puede ser negativo.';
  END IF;

  IF NEW.invoice_number IS NULL OR btrim(NEW.invoice_number) = '' THEN
    NEW.invoice_number := public.fn_next_invoice_number();
  END IF;

  IF NEW.appointment_id IS NOT NULL
     AND NEW.status = 'Paid'
     AND lower(COALESCE(NEW.transaction_type, 'Income')) NOT IN ('expense', 'gasto') THEN
    IF EXISTS (
      SELECT 1 FROM public.financial_transactions t
      WHERE t.appointment_id = NEW.appointment_id
        AND t.status = 'Paid'
        AND lower(COALESCE(t.transaction_type, 'Income')) NOT IN ('expense', 'gasto')
        AND t.id <> COALESCE(NEW.id, -1)
    ) THEN
      RAISE EXCEPTION 'Esta cita ya fue cobrada anteriormente.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_financial_rules ON public.financial_transactions;
CREATE TRIGGER trg_financial_rules
  BEFORE INSERT OR UPDATE ON public.financial_transactions
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_financial_rules();

CREATE OR REPLACE FUNCTION public.fn_trg_financial_after_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.appointment_id IS NOT NULL
     AND NEW.status = 'Paid'
     AND lower(COALESCE(NEW.transaction_type, 'Income')) NOT IN ('expense', 'gasto') THEN
    UPDATE public.appointments
    SET status = 'Completed'
    WHERE id = NEW.appointment_id
      AND status IN ('Waiting', 'Confirmed', 'In Progress');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_financial_after_change ON public.financial_transactions;
CREATE TRIGGER trg_financial_after_change
  AFTER INSERT OR UPDATE ON public.financial_transactions
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_financial_after_change();


-- ------------------------------------------------------------
-- 4. TRIGGER: SOAP (firma automática y bloqueo de consultas finalizadas)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_soap_rules()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND OLD.status = 'Finalized' THEN
    RAISE EXCEPTION 'Una consulta finalizada y firmada no puede modificarse.';
  END IF;

  IF NEW.status = 'Finalized' AND NEW.signed_at IS NULL THEN
    NEW.signed_at := CURRENT_TIMESTAMP;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_soap_rules ON public.soap_consultations;
CREATE TRIGGER trg_soap_rules
  BEFORE INSERT OR UPDATE ON public.soap_consultations
  FOR EACH ROW EXECUTE FUNCTION public.fn_trg_soap_rules();


-- ------------------------------------------------------------
-- 5. CORRECCIÓN: TRIGGER DENTAL -> LÍNEA DE TIEMPO CLÍNICA
--    (antes fallaba porque clinical_records.title es NOT NULL)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_sync_dental_to_clinical_timeline()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF (TG_OP = 'INSERT' AND NEW.status = 'Completed') OR
     (TG_OP = 'UPDATE' AND NEW.status = 'Completed' AND OLD.status IS DISTINCT FROM 'Completed') THEN
    INSERT INTO public.clinical_records (
      patient_id, doctor_id, record_type, title, description, record_date, tags
    ) VALUES (
      NEW.patient_id,
      NEW.provider_id,
      'Dental',
      'Procedimiento Odontológico: ' || NEW.procedure_name,
      'Procedimiento realizado en la pieza FDI ' || NEW.tooth_number || '. ' || COALESCE(NEW.notes, ''),
      COALESCE(NEW.finding_date, CURRENT_TIMESTAMP),
      jsonb_build_array('Odontología', 'Pieza ' || NEW.tooth_number)
    );
  END IF;
  RETURN NEW;
END;
$$;


-- ------------------------------------------------------------
-- 6. PROCEDIMIENTOS CORREGIDOS (misma firma que antes)
-- ------------------------------------------------------------

-- 6.1 Agendar cita con validaciones completas
CREATE OR REPLACE FUNCTION public.sp_book_appointment(
  p_patient_id BIGINT,
  p_doctor_id BIGINT,
  p_service_id BIGINT,
  p_appointment_date DATE,
  p_appointment_time TIME,
  p_notes TEXT DEFAULT NULL,
  p_status VARCHAR(50) DEFAULT 'Confirmed'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id BIGINT;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.services WHERE id = p_service_id AND is_active) THEN
    RETURN jsonb_build_object('success', FALSE, 'code', 'SERVICE_INVALID',
      'message', 'El servicio seleccionado no existe o está inactivo.');
  END IF;

  INSERT INTO public.appointments (
    patient_id, doctor_id, service_id, appointment_date, appointment_time, status, notes
  ) VALUES (
    p_patient_id, p_doctor_id, p_service_id, p_appointment_date, p_appointment_time,
    public.fn_normalize_appointment_status(p_status), p_notes
  ) RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', TRUE, 'appointment_id', v_id,
    'message', 'Cita agendada exitosamente');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM, 'message', SQLERRM);
END;
$$;

-- 6.2 Cambiar estado de cita (acepta estados en español)
CREATE OR REPLACE FUNCTION public.sp_update_appointment_status(
  p_appointment_id BIGINT,
  p_new_status VARCHAR(50),
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status TEXT := public.fn_normalize_appointment_status(p_new_status);
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.appointments WHERE id = p_appointment_id) THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Cita no encontrada', 'error', 'Cita no encontrada');
  END IF;

  UPDATE public.appointments SET
    status = v_status,
    notes = CASE
      WHEN p_notes IS NOT NULL AND p_notes <> '' THEN COALESCE(notes || E'\n', '') || p_notes
      ELSE notes
    END
  WHERE id = p_appointment_id;

  RETURN jsonb_build_object('success', TRUE, 'appointment_id', p_appointment_id,
    'new_status', v_status, 'message', 'Estado de la cita actualizado con éxito');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM, 'message', SQLERRM);
END;
$$;

-- 6.3 Consulta SOAP + signos vitales (usaba columnas inexistentes)
CREATE OR REPLACE FUNCTION public.sp_save_consultation_with_vitals(
  p_patient_id BIGINT,
  p_doctor_id BIGINT,
  p_subjective TEXT,
  p_objective TEXT,
  p_assessment TEXT,
  p_plan TEXT,
  p_icd10_code VARCHAR(20) DEFAULT NULL,
  p_status VARCHAR(50) DEFAULT 'Draft',
  p_consultation_id BIGINT DEFAULT NULL,
  p_bp_systolic INT DEFAULT NULL,
  p_bp_diastolic INT DEFAULT NULL,
  p_heart_rate INT DEFAULT NULL,
  p_temperature NUMERIC(4, 1) DEFAULT NULL,
  p_weight_kg NUMERIC(5, 2) DEFAULT NULL,
  p_height_cm NUMERIC(5, 2) DEFAULT NULL,
  p_respiratory_rate INT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_consultation_id BIGINT;
  v_doctor_name VARCHAR(150);
  v_has_vitals BOOLEAN;
  v_status TEXT := CASE WHEN p_status = 'Finalized' THEN 'Finalized' ELSE 'Draft' END;
BEGIN
  IF p_consultation_id IS NOT NULL AND p_consultation_id > 0 THEN
    UPDATE public.soap_consultations SET
      subjective = p_subjective, objective = p_objective, assessment = p_assessment,
      plan = p_plan, icd10_code = p_icd10_code, status = v_status
    WHERE id = p_consultation_id;
    v_consultation_id := p_consultation_id;
  ELSE
    INSERT INTO public.soap_consultations (
      patient_id, doctor_id, consultation_date, subjective, objective, assessment, plan, icd10_code, status
    ) VALUES (
      p_patient_id, p_doctor_id, CURRENT_TIMESTAMP, p_subjective, p_objective, p_assessment, p_plan, p_icd10_code, v_status
    ) RETURNING id INTO v_consultation_id;
  END IF;

  v_has_vitals := p_bp_systolic IS NOT NULL AND p_bp_diastolic IS NOT NULL AND p_heart_rate IS NOT NULL
                  AND p_temperature IS NOT NULL AND p_weight_kg IS NOT NULL AND p_height_cm IS NOT NULL;

  IF v_has_vitals THEN
    IF EXISTS (SELECT 1 FROM public.vital_signs WHERE consultation_id = v_consultation_id) THEN
      UPDATE public.vital_signs SET
        bp_systolic = p_bp_systolic, bp_diastolic = p_bp_diastolic, pulse = p_heart_rate,
        temperature = p_temperature, weight_kg = p_weight_kg, height_cm = p_height_cm,
        measured_at = CURRENT_TIMESTAMP
      WHERE consultation_id = v_consultation_id;
    ELSE
      INSERT INTO public.vital_signs (
        consultation_id, patient_id, bp_systolic, bp_diastolic, pulse,
        temperature, weight_kg, height_cm, measured_at
      ) VALUES (
        v_consultation_id, p_patient_id, p_bp_systolic, p_bp_diastolic, p_heart_rate,
        p_temperature, p_weight_kg, p_height_cm, CURRENT_TIMESTAMP
      );
    END IF;
  END IF;

  IF v_status = 'Finalized' THEN
    SELECT full_name INTO v_doctor_name FROM public.users WHERE id = p_doctor_id;

    INSERT INTO public.clinical_records (
      patient_id, doctor_id, record_type, title, description, record_date, tags
    ) VALUES (
      p_patient_id, p_doctor_id, 'CONSULTA GENERAL',
      COALESCE(NULLIF(btrim('Consulta: ' || COALESCE(p_assessment, '')), 'Consulta:'), 'Consulta Médica Finalizada'),
      format('Diagnóstico CIE-10: %s. Plan: %s', COALESCE(NULLIF(p_icd10_code, ''), 'N/A'), COALESCE(NULLIF(p_plan, ''), 'Sin plan específico')),
      CURRENT_TIMESTAMP,
      jsonb_build_array(COALESCE(v_doctor_name, 'Médico'), 'SOAP Finalizada')
    );

    UPDATE public.patients SET last_visit = CURRENT_TIMESTAMP WHERE id = p_patient_id;

    UPDATE public.appointments
    SET status = 'Completed'
    WHERE patient_id = p_patient_id
      AND appointment_date = public.fn_clinic_today()
      AND status IN ('Confirmed', 'Waiting', 'In Progress');
  END IF;

  RETURN jsonb_build_object('success', TRUE, 'consultation_id', v_consultation_id,
    'status', v_status, 'message', 'Consulta guardada exitosamente');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

-- 6.4 Registro atómico de paciente (código secuencial, sin colisiones aleatorias)
DROP FUNCTION IF EXISTS public.sp_register_patient_with_contact(
  VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, BOOLEAN, VARCHAR, VARCHAR, VARCHAR, VARCHAR
);

CREATE OR REPLACE FUNCTION public.sp_register_patient_with_contact(
  p_full_name VARCHAR(150),
  p_identity_number VARCHAR(50),
  p_birth_date DATE,
  p_gender VARCHAR(20),
  p_blood_type VARCHAR(10) DEFAULT NULL,
  p_phone VARCHAR(30) DEFAULT NULL,
  p_email VARCHAR(150) DEFAULT NULL,
  p_address TEXT DEFAULT NULL,
  p_has_alert BOOLEAN DEFAULT FALSE,
  p_patient_code VARCHAR(50) DEFAULT NULL,
  p_contact_name VARCHAR(150) DEFAULT NULL,
  p_contact_relationship VARCHAR(50) DEFAULT NULL,
  p_contact_phone VARCHAR(30) DEFAULT NULL,
  p_doctor_id BIGINT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_patient_id BIGINT;
  v_code TEXT;
  v_doctor BIGINT := p_doctor_id;
BEGIN
  IF p_identity_number IS NOT NULL AND btrim(p_identity_number) <> ''
     AND EXISTS (SELECT 1 FROM public.patients WHERE identity_number = btrim(p_identity_number)) THEN
    RETURN jsonb_build_object('success', FALSE,
      'error', 'Ya existe un paciente registrado con esa cédula.');
  END IF;

  INSERT INTO public.patients (
    patient_code, full_name, identity_number, birth_date, gender,
    blood_type, phone, email, address, is_active, has_alert
  ) VALUES (
    NULLIF(btrim(COALESCE(p_patient_code, '')), ''), p_full_name, NULLIF(btrim(COALESCE(p_identity_number, '')), ''),
    p_birth_date, p_gender, p_blood_type, p_phone, p_email, p_address, TRUE, COALESCE(p_has_alert, FALSE)
  ) RETURNING id, patient_code INTO v_patient_id, v_code;

  IF p_contact_name IS NOT NULL AND btrim(p_contact_name) <> '' THEN
    INSERT INTO public.emergency_contacts (patient_id, contact_name, relationship, phone)
    VALUES (v_patient_id, btrim(p_contact_name), COALESCE(NULLIF(btrim(p_contact_relationship), ''), 'Familiar'),
            COALESCE(p_contact_phone, ''));
  END IF;

  IF v_doctor IS NULL THEN
    SELECT u.id INTO v_doctor FROM public.users u WHERE u.is_active ORDER BY u.id LIMIT 1;
  END IF;

  IF v_doctor IS NOT NULL THEN
    INSERT INTO public.clinical_records (patient_id, doctor_id, record_type, title, description, record_date, tags)
    VALUES (v_patient_id, v_doctor, 'Consulta General', 'Apertura de Expediente Clínico',
            'Paciente registrado en el sistema.', CURRENT_TIMESTAMP,
            jsonb_build_array('Apertura', 'Expediente'));
  END IF;

  RETURN jsonb_build_object('success', TRUE, 'patient_id', v_patient_id,
    'patient_code', v_code, 'message', 'Paciente registrado exitosamente');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ------------------------------------------------------------
-- 7. NUEVO: COBRO ATÓMICO DE UNA CITA
--    Usa el costo del servicio si no se indica monto.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_charge_appointment(
  p_appointment_id BIGINT,
  p_amount NUMERIC DEFAULT NULL,
  p_payment_method VARCHAR(50) DEFAULT 'Cash',
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_apt   RECORD;
  v_amount NUMERIC;
  v_tx_id BIGINT;
  v_invoice TEXT;
BEGIN
  SELECT a.id, a.patient_id, a.status, s.name AS service_name, s.base_cost
  INTO v_apt
  FROM public.appointments a
  JOIN public.services s ON s.id = a.service_id
  WHERE a.id = p_appointment_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Cita no encontrada.');
  END IF;
  IF v_apt.status = 'Cancelled' THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'No se puede cobrar una cita cancelada.');
  END IF;

  v_amount := COALESCE(p_amount, v_apt.base_cost);
  IF v_amount IS NULL OR v_amount <= 0 THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'El monto a cobrar debe ser mayor que cero.');
  END IF;

  INSERT INTO public.financial_transactions (
    patient_id, appointment_id, concept, amount, payment_method, status, transaction_type, currency, notes, transaction_date
  ) VALUES (
    v_apt.patient_id, p_appointment_id, v_apt.service_name, v_amount,
    COALESCE(NULLIF(p_payment_method, ''), 'Cash'), 'Paid', 'Income', 'USD', p_notes, CURRENT_TIMESTAMP
  ) RETURNING id, invoice_number INTO v_tx_id, v_invoice;

  RETURN jsonb_build_object('success', TRUE, 'transaction_id', v_tx_id, 'invoice_number', v_invoice,
    'amount', v_amount, 'message', 'Cobro registrado correctamente');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ------------------------------------------------------------
-- 8. NUEVO: RESUMEN REAL DEL PANEL PRINCIPAL
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_get_dashboard_overview()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today DATE := public.fn_clinic_today();
  v_week_start DATE;
  v_weekly JSONB;
  v_apts INT;
  v_waiting INT;
  v_patients INT;
  v_income NUMERIC;
  v_pending_cnt INT;
  v_pending_amt NUMERIC;
BEGIN
  v_week_start := v_today - (extract(isodow FROM v_today)::int - 1);

  SELECT count(*) INTO v_apts FROM public.appointments
  WHERE appointment_date = v_today AND status <> 'Cancelled';

  SELECT count(*) INTO v_waiting FROM public.appointments
  WHERE appointment_date = v_today AND status = 'Waiting';

  SELECT count(*) INTO v_patients FROM public.patients WHERE is_active;

  SELECT COALESCE(sum(amount), 0) INTO v_income
  FROM public.financial_transactions
  WHERE status = 'Paid'
    AND lower(COALESCE(transaction_type, 'Income')) NOT IN ('expense', 'gasto')
    AND (transaction_date AT TIME ZONE 'America/Managua')::date = v_today;

  SELECT count(*), COALESCE(sum(amount), 0) INTO v_pending_cnt, v_pending_amt
  FROM public.financial_transactions
  WHERE status = 'Pending'
    AND lower(COALESCE(transaction_type, 'Income')) NOT IN ('expense', 'gasto');

  SELECT jsonb_agg(c ORDER BY g) INTO v_weekly
  FROM (
    SELECT g, (SELECT count(*) FROM public.appointments a
               WHERE a.appointment_date = v_week_start + g AND a.status <> 'Cancelled') AS c
    FROM generate_series(0, 5) AS g
  ) t;

  RETURN jsonb_build_object(
    'success', TRUE,
    'today', v_today,
    'appointments_today', v_apts,
    'waiting_today', v_waiting,
    'active_patients', v_patients,
    'daily_income', v_income,
    'pending_payments_count', v_pending_cnt,
    'pending_payments_amount', v_pending_amt,
    'weekly_activity', COALESCE(v_weekly, '[0,0,0,0,0,0]'::jsonb),
    'today_index', extract(isodow FROM v_today)::int - 1
  );
END;
$$;


-- ------------------------------------------------------------
-- 9. NUEVO: NOTIFICACIONES REALES (campana de la barra superior)
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_get_notifications()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today DATE := public.fn_clinic_today();
  v_result JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(n ORDER BY (n->>'priority')::int, n->>'key'), '[]'::jsonb) INTO v_result
  FROM (
    -- Pacientes en espera hoy
    SELECT jsonb_build_object(
      'key', 'waiting-today', 'priority', 2, 'type', 'waiting', 'severity', 'info',
      'title', 'Pacientes en espera',
      'message', c.n || CASE WHEN c.n = 1 THEN ' paciente espera' ELSE ' pacientes esperan' END || ' ser atendidos hoy.'
    ) AS n
    FROM (SELECT count(*) AS n FROM public.appointments WHERE appointment_date = v_today AND status = 'Waiting') c
    WHERE c.n > 0

    UNION ALL
    -- Citas de hoy de pacientes con alerta de alergia
    SELECT jsonb_build_object(
      'key', 'allergy-' || a.id, 'priority', 1, 'type', 'allergy', 'severity', 'danger',
      'title', 'Alerta de alergia',
      'message', p.full_name || ' tiene cita hoy y registra alergia a ' ||
        (SELECT string_agg(al.allergen, ', ') FROM public.allergy_alerts al WHERE al.patient_id = p.id AND al.is_active) || '.',
      'patient_id', p.id
    )
    FROM public.appointments a
    JOIN public.patients p ON p.id = a.patient_id
    WHERE a.appointment_date = v_today AND a.status <> 'Cancelled' AND p.has_alert

    UNION ALL
    -- Citas de días anteriores sin cerrar
    SELECT jsonb_build_object(
      'key', 'stale-appointments', 'priority', 3, 'type', 'stale', 'severity', 'warning',
      'title', 'Citas sin cerrar',
      'message', c.n || CASE WHEN c.n = 1 THEN ' cita de días anteriores sigue' ELSE ' citas de días anteriores siguen' END || ' sin completar o cancelar.'
    )
    FROM (SELECT count(*) AS n FROM public.appointments
          WHERE appointment_date < v_today AND status IN ('Waiting', 'Confirmed', 'In Progress')) c
    WHERE c.n > 0

    UNION ALL
    -- Cobros pendientes
    SELECT jsonb_build_object(
      'key', 'pending-payments', 'priority', 2, 'type', 'payment', 'severity', 'warning',
      'title', 'Cobros pendientes',
      'message', c.n || CASE WHEN c.n = 1 THEN ' cobro pendiente' ELSE ' cobros pendientes' END
                 || ' por un total de $' || to_char(c.total, 'FM999,999,990.00') || '.'
    )
    FROM (SELECT count(*) AS n, COALESCE(sum(amount), 0) AS total
          FROM public.financial_transactions
          WHERE status = 'Pending'
            AND lower(COALESCE(transaction_type, 'Income')) NOT IN ('expense', 'gasto')) c
    WHERE c.n > 0

    UNION ALL
    -- Consultas en borrador sin finalizar
    SELECT jsonb_build_object(
      'key', 'draft-consultations', 'priority', 3, 'type', 'draft', 'severity', 'info',
      'title', 'Consultas en borrador',
      'message', c.n || CASE WHEN c.n = 1 THEN ' consulta SOAP está' ELSE ' consultas SOAP están' END || ' pendiente(s) de finalizar.'
    )
    FROM (SELECT count(*) AS n FROM public.soap_consultations WHERE status = 'Draft') c
    WHERE c.n > 0
  ) x;

  RETURN v_result;
END;
$$;


-- ------------------------------------------------------------
-- 10. NUEVO: REPORTES REALES POR RANGO DE FECHAS
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_generate_report(
  p_report TEXT,
  p_start DATE,
  p_end DATE
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_headers JSONB;
  v_rows JSONB := '[]'::jsonb;
  v_total NUMERIC := NULL;
  v_tz TEXT := 'America/Managua';
BEGIN
  IF p_start IS NULL OR p_end IS NULL OR p_end < p_start THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'El rango de fechas no es válido.');
  END IF;

  IF p_report = 'Pacientes Nuevos' THEN
    v_headers := '["Fecha","Paciente","Código","Teléfono","Estado"]'::jsonb;
    SELECT COALESCE(jsonb_agg(jsonb_build_array(
             to_char((p.created_at AT TIME ZONE v_tz)::date, 'DD/MM/YYYY'),
             p.full_name, p.patient_code, COALESCE(p.phone, '—'),
             CASE WHEN p.is_active THEN 'Activo' ELSE 'Inactivo' END
           ) ORDER BY p.created_at), '[]'::jsonb)
    INTO v_rows
    FROM public.patients p
    WHERE (p.created_at AT TIME ZONE v_tz)::date BETWEEN p_start AND p_end;

  ELSIF p_report = 'Consultas Realizadas' THEN
    v_headers := '["Fecha","Paciente","Servicio","Médico","Diagnóstico"]'::jsonb;
    SELECT COALESCE(jsonb_agg(jsonb_build_array(
             to_char(a.appointment_date, 'DD/MM/YYYY'),
             p.full_name, s.name, u.full_name,
             COALESCE((SELECT NULLIF(btrim(COALESCE(sc.icd10_code, '') || ' ' || COALESCE(sc.assessment, '')), '')
                       FROM public.soap_consultations sc
                       WHERE sc.patient_id = a.patient_id
                         AND (sc.consultation_date AT TIME ZONE v_tz)::date = a.appointment_date
                       ORDER BY sc.id DESC LIMIT 1), '—')
           ) ORDER BY a.appointment_date, a.appointment_time), '[]'::jsonb)
    INTO v_rows
    FROM public.appointments a
    JOIN public.patients p ON p.id = a.patient_id
    JOIN public.services s ON s.id = a.service_id
    JOIN public.users u ON u.id = a.doctor_id
    WHERE a.status = 'Completed' AND a.appointment_date BETWEEN p_start AND p_end;

  ELSIF p_report = 'Ingresos por Período' THEN
    v_headers := '["Fecha","Paciente","Concepto","Método","Monto"]'::jsonb;
    SELECT COALESCE(jsonb_agg(jsonb_build_array(
             to_char((t.transaction_date AT TIME ZONE v_tz)::date, 'DD/MM/YYYY'),
             COALESCE(p.full_name, '—'), t.concept, t.payment_method,
             '$' || to_char(t.amount, 'FM999,999,990.00')
           ) ORDER BY t.transaction_date), '[]'::jsonb),
           COALESCE(sum(t.amount), 0)
    INTO v_rows, v_total
    FROM public.financial_transactions t
    LEFT JOIN public.patients p ON p.id = t.patient_id
    WHERE t.status = 'Paid'
      AND lower(COALESCE(t.transaction_type, 'Income')) NOT IN ('expense', 'gasto')
      AND (t.transaction_date AT TIME ZONE v_tz)::date BETWEEN p_start AND p_end;

  ELSIF p_report = 'Procedimientos' THEN
    v_headers := '["Fecha","Paciente","Pieza","Procedimiento","Costo"]'::jsonb;
    SELECT COALESCE(jsonb_agg(jsonb_build_array(
             to_char((f.finding_date AT TIME ZONE v_tz)::date, 'DD/MM/YYYY'),
             p.full_name, f.tooth_number::text, f.procedure_name,
             CASE WHEN f.cost IS NULL THEN '—' ELSE '$' || to_char(f.cost, 'FM999,999,990.00') END
           ) ORDER BY f.finding_date), '[]'::jsonb),
           COALESCE(sum(f.cost), 0)
    INTO v_rows, v_total
    FROM public.odontogram_findings f
    JOIN public.patients p ON p.id = f.patient_id
    WHERE f.status = 'Completed'
      AND (f.finding_date AT TIME ZONE v_tz)::date BETWEEN p_start AND p_end;

  ELSIF p_report = 'Control Pediátrico' THEN
    v_headers := '["Fecha","Paciente","Edad","Peso (kg)","Talla (cm)","P. Cefálico (cm)"]'::jsonb;
    SELECT COALESCE(jsonb_agg(jsonb_build_array(
             to_char(g.measurement_date, 'DD/MM/YYYY'),
             p.full_name, g.age_label, g.weight_kg::text, g.height_cm::text, g.head_circumference_cm::text
           ) ORDER BY g.measurement_date), '[]'::jsonb)
    INTO v_rows
    FROM public.pediatric_growth_records g
    JOIN public.patients p ON p.id = g.patient_id
    WHERE g.measurement_date BETWEEN p_start AND p_end;

  ELSIF p_report = 'Citas y Asistencia' THEN
    v_headers := '["Fecha","Hora","Paciente","Servicio","Estado"]'::jsonb;
    SELECT COALESCE(jsonb_agg(jsonb_build_array(
             to_char(a.appointment_date, 'DD/MM/YYYY'),
             to_char(a.appointment_time, 'HH12:MI AM'),
             p.full_name, s.name,
             CASE a.status WHEN 'Waiting' THEN 'En Espera' WHEN 'Confirmed' THEN 'Confirmada'
                           WHEN 'In Progress' THEN 'En Progreso' WHEN 'Completed' THEN 'Atendida'
                           WHEN 'Cancelled' THEN 'Cancelada' ELSE a.status END
           ) ORDER BY a.appointment_date, a.appointment_time), '[]'::jsonb)
    INTO v_rows
    FROM public.appointments a
    JOIN public.patients p ON p.id = a.patient_id
    JOIN public.services s ON s.id = a.service_id
    WHERE a.appointment_date BETWEEN p_start AND p_end;

  ELSE
    RETURN jsonb_build_object('success', FALSE, 'error', 'Reporte desconocido: ' || COALESCE(p_report, 'NULL'));
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'report', p_report,
    'headers', v_headers,
    'rows', v_rows,
    'count', jsonb_array_length(v_rows),
    'total', v_total
  );
END;
$$;


-- ------------------------------------------------------------
-- 11. RESTRICCIONES CHECK (NOT VALID: no rompen datos históricos,
--     pero validan toda fila nueva o modificada)
-- ------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_ft_amount_nonneg') THEN
    ALTER TABLE public.financial_transactions
      ADD CONSTRAINT chk_ft_amount_nonneg CHECK (amount >= 0) NOT VALID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_services_cost_nonneg') THEN
    ALTER TABLE public.services
      ADD CONSTRAINT chk_services_cost_nonneg CHECK (base_cost >= 0) NOT VALID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_vitals_ranges') THEN
    ALTER TABLE public.vital_signs
      ADD CONSTRAINT chk_vitals_ranges CHECK (
        bp_systolic BETWEEN 40 AND 300 AND bp_diastolic BETWEEN 20 AND 200
        AND pulse BETWEEN 20 AND 250 AND temperature BETWEEN 30 AND 45
        AND weight_kg BETWEEN 0.3 AND 500 AND height_cm BETWEEN 20 AND 260
      ) NOT VALID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_growth_ranges') THEN
    ALTER TABLE public.pediatric_growth_records
      ADD CONSTRAINT chk_growth_ranges CHECK (
        weight_kg > 0 AND height_cm > 0 AND head_circumference_cm > 0
        AND weight_percentile BETWEEN 0 AND 100 AND height_percentile BETWEEN 0 AND 100
      ) NOT VALID;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_odonto_tooth_range') THEN
    ALTER TABLE public.odontogram_findings
      ADD CONSTRAINT chk_odonto_tooth_range CHECK (tooth_number BETWEEN 11 AND 85) NOT VALID;
  END IF;
END $$;


-- ------------------------------------------------------------
-- 12. ÍNDICES DE RENDIMIENTO
-- ------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_appointments_date_status ON public.appointments (appointment_date, status);
CREATE INDEX IF NOT EXISTS idx_appointments_doctor_slot ON public.appointments (doctor_id, appointment_date, appointment_time);
CREATE INDEX IF NOT EXISTS idx_ft_status_date ON public.financial_transactions (status, transaction_date);
CREATE INDEX IF NOT EXISTS idx_ft_appointment ON public.financial_transactions (appointment_id);
CREATE INDEX IF NOT EXISTS idx_soap_patient_date ON public.soap_consultations (patient_id, consultation_date DESC);
CREATE INDEX IF NOT EXISTS idx_clinical_patient_date ON public.clinical_records (patient_id, record_date DESC);
CREATE INDEX IF NOT EXISTS idx_allergy_patient_active ON public.allergy_alerts (patient_id) WHERE is_active;


-- ------------------------------------------------------------
-- 13. PERMISOS Y RECARGA DEL CACHÉ DE LA API
-- ------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.fn_clinic_today() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_book_appointment(BIGINT, BIGINT, BIGINT, DATE, TIME, TEXT, VARCHAR) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_update_appointment_status(BIGINT, VARCHAR, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_save_consultation_with_vitals(BIGINT, BIGINT, TEXT, TEXT, TEXT, TEXT, VARCHAR, VARCHAR, BIGINT, INT, INT, INT, NUMERIC, NUMERIC, NUMERIC, INT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_register_patient_with_contact(VARCHAR, VARCHAR, DATE, VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, BOOLEAN, VARCHAR, VARCHAR, VARCHAR, VARCHAR, BIGINT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_charge_appointment(BIGINT, NUMERIC, VARCHAR, TEXT) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_get_dashboard_overview() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_get_notifications() TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_generate_report(TEXT, DATE, DATE) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

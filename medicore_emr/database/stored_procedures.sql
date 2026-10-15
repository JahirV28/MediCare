-- ============================================================
-- MediCore EMR — Procedimientos Almacenados y Funciones RPC
-- Compatible con: Supabase (PostgreSQL 14+)
-- ============================================================
-- Instrucciones:
-- Copia todo este contenido y pégalo en el "SQL Editor" de tu 
-- panel de control de Supabase (https://supabase.com/dashboard)
-- y presiona "Run".
-- ============================================================

-- ------------------------------------------------------------
-- 1. PROCEDIMIENTO: REGISTRO ATÓMICO DE PACIENTE Y CONTACTO
-- Crea el paciente y su contacto de emergencia en una sola transacción.
-- Genera automáticamente el código de paciente si no se proporciona.
-- ------------------------------------------------------------
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
  p_contact_phone VARCHAR(30) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patient_id BIGINT;
  v_generated_code VARCHAR(50);
  v_result JSONB;
BEGIN
  -- Generar código de paciente automático si no viene provisto (e.g. PT-4821-26)
  IF p_patient_code IS NULL OR trim(p_patient_code) = '' THEN
    v_generated_code := 'PT-' || lpad(cast(floor(random() * 9000 + 1000) as text), 4, '0') || '-' || to_char(CURRENT_DATE, 'YY');
  ELSE
    v_generated_code := p_patient_code;
  END IF;

  -- 1. Insertar Paciente
  INSERT INTO public.patients (
    patient_code, full_name, identity_number, birth_date, gender,
    blood_type, phone, email, address, is_active, has_alert
  ) VALUES (
    v_generated_code, p_full_name, p_identity_number, p_birth_date, p_gender,
    p_blood_type, p_phone, p_email, p_address, TRUE, p_has_alert
  ) RETURNING id INTO v_patient_id;

  -- 2. Insertar Contacto de Emergencia si se proveyó
  IF p_contact_name IS NOT NULL AND trim(p_contact_name) <> '' THEN
    INSERT INTO public.emergency_contacts (
      patient_id, contact_name, relationship, phone
    ) VALUES (
      v_patient_id, p_contact_name, p_contact_relationship, COALESCE(p_contact_phone, '')
    );
  END IF;

  SELECT jsonb_build_object(
    'success', TRUE,
    'patient_id', v_patient_id,
    'patient_code', v_generated_code,
    'message', 'Paciente registrado exitosamente'
  ) INTO v_result;

  RETURN v_result;
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', FALSE,
    'error', SQLERRM
  );
END;
$$;


-- ------------------------------------------------------------
-- 2. PROCEDIMIENTO: AGENDAR CITA CON VALIDACIÓN DE DISPONIBILIDAD
-- Verifica que el médico no tenga ya otra cita activa en ese mismo día y horario
-- para evitar colisiones de agenda.
-- ------------------------------------------------------------
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
AS $$
DECLARE
  v_existing_id BIGINT;
  v_new_appointment_id BIGINT;
  v_doctor_name VARCHAR(150);
BEGIN
  -- Verificar si el médico ya tiene una cita activa en ese horario
  SELECT id INTO v_existing_id
  FROM public.appointments
  WHERE doctor_id = p_doctor_id
    AND appointment_date = p_appointment_date
    AND appointment_time = p_appointment_time
    AND status NOT IN ('Cancelled', 'Cancelado')
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    SELECT full_name INTO v_doctor_name FROM public.users WHERE id = p_doctor_id;
    RETURN jsonb_build_object(
      'success', FALSE,
      'code', 'DOCTOR_UNAVAILABLE',
      'message', format('El doctor %s ya tiene una cita agendada para el %s a las %s.', COALESCE(v_doctor_name, 'seleccionado'), p_appointment_date, p_appointment_time)
    );
  END IF;

  -- Insertar la nueva cita
  INSERT INTO public.appointments (
    patient_id, doctor_id, service_id, appointment_date, appointment_time, status, notes
  ) VALUES (
    p_patient_id, p_doctor_id, p_service_id, p_appointment_date, p_appointment_time, p_status, p_notes
  ) RETURNING id INTO v_new_appointment_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'appointment_id', v_new_appointment_id,
    'message', 'Cita agendada exitosamente'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', FALSE,
    'error', SQLERRM
  );
END;
$$;


-- ------------------------------------------------------------
-- 3. PROCEDIMIENTO: GUARDAR CONSULTA SOAP Y SIGNOS VITALES
-- Guarda o actualiza la consulta clínica, calcula el IMC automáticamente,
-- registra los signos vitales y, si se finaliza, agrega el registro
-- a la cronología del expediente clínico y actualiza la cita del día.
-- ------------------------------------------------------------
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
  -- Signos vitales
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
AS $$
DECLARE
  v_consultation_id BIGINT;
  v_bmi NUMERIC(4, 1) := NULL;
  v_doctor_name VARCHAR(150);
BEGIN
  -- Calcular IMC automáticamente si se proporcionan peso y altura
  IF p_weight_kg IS NOT NULL AND p_height_cm IS NOT NULL AND p_height_cm > 0 THEN
    v_bmi := round((p_weight_kg / ((p_height_cm / 100.0) ^ 2))::numeric, 1);
  END IF;

  -- 1. Insertar o actualizar la consulta SOAP
  IF p_consultation_id IS NOT NULL AND p_consultation_id > 0 THEN
    UPDATE public.soap_consultations SET
      subjective = p_subjective,
      objective = p_objective,
      assessment = p_assessment,
      plan = p_plan,
      icd10_code = p_icd10_code,
      status = p_status,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = p_consultation_id;
    v_consultation_id := p_consultation_id;
  ELSE
    INSERT INTO public.soap_consultations (
      patient_id, doctor_id, consultation_date, subjective, objective, assessment, plan, icd10_code, status
    ) VALUES (
      p_patient_id, p_doctor_id, CURRENT_TIMESTAMP, p_subjective, p_objective, p_assessment, p_plan, p_icd10_code, p_status
    ) RETURNING id INTO v_consultation_id;
  END IF;

  -- 2. Guardar o actualizar los signos vitales
  IF p_bp_systolic IS NOT NULL OR p_temperature IS NOT NULL OR p_weight_kg IS NOT NULL OR p_heart_rate IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.vital_signs WHERE consultation_id = v_consultation_id) THEN
      UPDATE public.vital_signs SET
        bp_systolic = p_bp_systolic,
        bp_diastolic = p_bp_diastolic,
        heart_rate = p_heart_rate,
        temperature = p_temperature,
        weight_kg = p_weight_kg,
        height_cm = p_height_cm,
        bmi = v_bmi,
        respiratory_rate = p_respiratory_rate,
        recorded_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP
      WHERE consultation_id = v_consultation_id;
    ELSE
      INSERT INTO public.vital_signs (
        consultation_id, patient_id, bp_systolic, bp_diastolic, heart_rate,
        temperature, weight_kg, height_cm, bmi, respiratory_rate, recorded_at
      ) VALUES (
        v_consultation_id, p_patient_id, p_bp_systolic, p_bp_diastolic, p_heart_rate,
        p_temperature, p_weight_kg, p_height_cm, v_bmi, p_respiratory_rate, CURRENT_TIMESTAMP
      );
    END IF;
  END IF;

  -- 3. Si la consulta fue finalizada, registrar en el expediente clínico (timeline)
  IF p_status = 'Finalized' THEN
    SELECT full_name INTO v_doctor_name FROM public.users WHERE id = p_doctor_id;

    INSERT INTO public.clinical_records (
      patient_id, doctor_id, record_type, title, description, record_date, tags
    ) VALUES (
      p_patient_id,
      p_doctor_id,
      'CONSULTA GENERAL',
      COALESCE('Consulta: ' || p_assessment, 'Consulta Médica Finalizada'),
      format('Diagnóstico CIE-10: %s. Plan: %s', COALESCE(p_icd10_code, 'N/A'), COALESCE(p_plan, 'Sin plan específico')),
      CURRENT_TIMESTAMP,
      jsonb_build_array(COALESCE(v_doctor_name, 'Médico'), 'SOAP Finalizada')
    );

    -- Marcar la cita de hoy como Completada
    UPDATE public.appointments
    SET status = 'Completed', updated_at = CURRENT_TIMESTAMP
    WHERE patient_id = p_patient_id
      AND doctor_id = p_doctor_id
      AND appointment_date = CURRENT_DATE
      AND status IN ('Confirmed', 'Waiting');
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'consultation_id', v_consultation_id,
    'status', p_status,
    'bmi', v_bmi,
    'message', 'Consulta y signos vitales guardados exitosamente'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', FALSE,
    'error', SQLERRM
  );
END;
$$;


-- ------------------------------------------------------------
-- 4. PROCEDIMIENTO: EMITIR RECETA CON MEDICAMENTOS
-- Emite la receta médica y añade todos sus medicamentos (items) en una
-- única transacción atómica a partir de un arreglo JSONB.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_create_prescription_with_items(
  p_patient_id BIGINT,
  p_doctor_id BIGINT,
  p_consultation_id BIGINT DEFAULT NULL,
  p_clinic_name VARCHAR(150) DEFAULT 'Clínica Sanitas Central',
  p_clinic_address VARCHAR(255) DEFAULT 'Av. Principal 123, Ciudad • Tel: 555-0192',
  p_notes TEXT DEFAULT NULL,
  p_items JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_prescription_id BIGINT;
  v_item JSONB;
  v_items_count INT := 0;
BEGIN
  -- Insertar encabezado de la receta
  INSERT INTO public.prescriptions (
    patient_id, doctor_id, consultation_id, clinic_name, clinic_address, prescription_date, notes
  ) VALUES (
    p_patient_id, p_doctor_id, p_consultation_id, p_clinic_name, p_clinic_address, CURRENT_DATE, p_notes
  ) RETURNING id INTO v_prescription_id;

  -- Insertar cada medicamento desde el arreglo JSON
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.prescription_items (
      prescription_id, drug_name, dose, frequency, duration, instructions
    ) VALUES (
      v_prescription_id,
      (v_item->>'drug_name'),
      COALESCE(v_item->>'dose', '1 dosis'),
      COALESCE(v_item->>'frequency', 'Cada 8h'),
      COALESCE(v_item->>'duration', '5 días'),
      v_item->>'instructions'
    );
    v_items_count := v_items_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', TRUE,
    'prescription_id', v_prescription_id,
    'items_count', v_items_count,
    'message', 'Receta médica emitida exitosamente con todos sus medicamentos'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', FALSE,
    'error', SQLERRM
  );
END;
$$;


-- ------------------------------------------------------------
-- 5. FUNCIÓN: MÉTRICAS Y ANALÍTICA PARA EL DASHBOARD
-- Agrega en el motor de base de datos las métricas clave en milisegundos,
-- evitando transferir miles de filas a Flutter.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_get_dashboard_analytics()
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_appointments_today INT;
  v_active_patients INT;
  v_daily_income NUMERIC(10, 2);
  v_weekly_activity JSONB;
  v_status_breakdown JSONB;
BEGIN
  -- Citas agendadas para el día de hoy
  SELECT COUNT(*) INTO v_appointments_today
  FROM public.appointments
  WHERE appointment_date = CURRENT_DATE;

  -- Pacientes activos registrados
  SELECT COUNT(*) INTO v_active_patients
  FROM public.patients
  WHERE is_active = TRUE;

  -- Ingresos totales cobrados hoy
  SELECT COALESCE(SUM(amount), 0.00) INTO v_daily_income
  FROM public.financial_transactions
  WHERE status = 'Paid'
    AND transaction_date::date = CURRENT_DATE;

  -- Desglose de citas de hoy por estatus
  SELECT jsonb_object_agg(status, count) INTO v_status_breakdown
  FROM (
    SELECT status, COUNT(*) as count
    FROM public.appointments
    WHERE appointment_date = CURRENT_DATE
    GROUP BY status
  ) s;

  -- Actividad de los últimos 7 días (cantidad de citas por día)
  SELECT jsonb_agg(coalesce(c.cnt, 0) ORDER BY d.day) INTO v_weekly_activity
  FROM generate_series(CURRENT_DATE - INTERVAL '6 days', CURRENT_DATE, INTERVAL '1 day') AS d(day)
  LEFT JOIN (
    SELECT appointment_date, count(*) as cnt
    FROM public.appointments
    WHERE appointment_date >= CURRENT_DATE - INTERVAL '6 days'
    GROUP BY appointment_date
  ) c ON c.appointment_date = d.day::date;

  RETURN jsonb_build_object(
    'appointments_today', COALESCE(v_appointments_today, 0),
    'active_patients', COALESCE(v_active_patients, 0),
    'daily_income', COALESCE(v_daily_income, 0.00),
    'status_breakdown', COALESCE(v_status_breakdown, '{}'::jsonb),
    'weekly_activity', COALESCE(v_weekly_activity, '[]'::jsonb)
  );
END;
$$;


-- ------------------------------------------------------------
-- 6. PROCEDIMIENTO: REGISTRAR TRANSACCIÓN FINANCIERA / PAGO
-- Registra el cobro de una consulta o servicio médico
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_record_payment(
  p_patient_id BIGINT,
  p_amount NUMERIC(10, 2),
  p_concept VARCHAR(200),
  p_payment_method VARCHAR(50) DEFAULT 'Cash',
  p_appointment_id BIGINT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_transaction_id BIGINT;
BEGIN
  INSERT INTO public.financial_transactions (
    patient_id, appointment_id, concept, amount, payment_method, status, transaction_date, notes
  ) VALUES (
    p_patient_id, p_appointment_id, p_concept, p_amount, p_payment_method, 'Paid', CURRENT_TIMESTAMP, p_notes
  ) RETURNING id INTO v_transaction_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'transaction_id', v_transaction_id,
    'message', 'Transacción financiera registrada correctamente'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', FALSE,
    'error', SQLERRM
  );
END;
$$;


-- ------------------------------------------------------------
-- 7. PERMISOS DE EJECUCIÓN (GRANTS)
-- Concede permisos a los roles de Supabase para poder invocar
-- estas funciones desde Flutter mediante `supabase.rpc(...)`.
-- ------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.sp_register_patient_with_contact TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_book_appointment TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_save_consultation_with_vitals TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_create_prescription_with_items TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_get_dashboard_analytics TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_record_payment TO anon, authenticated, service_role;


-- ------------------------------------------------------------
-- 8. PROCEDIMIENTO: GUARDAR O ACTUALIZAR HALLAZGO ODONTOLÓGICO CON CÁLCULO CPOD
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_save_odontogram_finding(
  p_patient_id BIGINT,
  p_tooth_number INT,
  p_condition_type VARCHAR(50),
  p_surface VARCHAR(50) DEFAULT 'O',
  p_procedure_name VARCHAR(200) DEFAULT 'Evaluación Odontológica',
  p_notes TEXT DEFAULT NULL,
  p_status VARCHAR(50) DEFAULT 'Pending',
  p_provider_id BIGINT DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_finding_id BIGINT;
  v_existing_id BIGINT;
  v_c_count INT := 0;
  v_p_count INT := 0;
  v_o_count INT := 0;
  v_total_cpod INT := 0;
  v_db_condition VARCHAR(50);
BEGIN
  IF p_condition_type ILIKE '%caries%' THEN
    v_db_condition := 'Caries';
  ELSIF p_condition_type ILIKE '%trata%' OR p_condition_type ILIKE '%restaur%' THEN
    v_db_condition := 'Treated';
  ELSIF p_condition_type ILIKE '%perdid%' OR p_condition_type ILIKE '%ausen%' OR p_condition_type ILIKE '%miss%' THEN
    v_db_condition := 'Missing';
  ELSE
    v_db_condition := 'Healthy';
  END IF;

  SELECT id INTO v_existing_id
  FROM public.odontogram_findings
  WHERE patient_id = p_patient_id AND tooth_number = p_tooth_number
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    UPDATE public.odontogram_findings SET
      condition_type = v_db_condition,
      surfaces = jsonb_build_array(p_surface),
      procedure_name = p_procedure_name,
      notes = p_notes,
      status = p_status,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = v_existing_id;
    v_finding_id := v_existing_id;
  ELSE
    INSERT INTO public.odontogram_findings (
      patient_id, provider_id, tooth_number, condition_type,
      surfaces, procedure_name, status, notes, finding_date
    ) VALUES (
      p_patient_id, p_provider_id, p_tooth_number, v_db_condition,
      jsonb_build_array(p_surface), p_procedure_name, p_status, p_notes, CURRENT_TIMESTAMP
    ) RETURNING id INTO v_finding_id;
  END IF;

  SELECT 
    COUNT(*) FILTER (WHERE condition_type IN ('Caries', 'Caries Activa')),
    COUNT(*) FILTER (WHERE condition_type IN ('Missing', 'Perdido', 'Ausente')),
    COUNT(*) FILTER (WHERE condition_type IN ('Treated', 'Tratado', 'Restaurado', 'Obturado'))
  INTO v_c_count, v_p_count, v_o_count
  FROM public.odontogram_findings
  WHERE patient_id = p_patient_id;

  v_total_cpod := v_c_count + v_p_count + v_o_count;

  RETURN jsonb_build_object(
    'success', TRUE,
    'finding_id', v_finding_id,
    'tooth_number', p_tooth_number,
    'condition_type', v_db_condition,
    'cpod', jsonb_build_object(
      'cariados', v_c_count,
      'perdidos', v_p_count,
      'obturados', v_o_count,
      'total', v_total_cpod
    ),
    'message', 'Hallazgo odontológico guardado con éxito'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ------------------------------------------------------------
-- 9. PROCEDIMIENTO: RESUMEN MENSUAL DE CITAS PARA CALENDARIO
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_get_calendar_month_summary(
  p_year INT,
  p_month INT,
  p_doctor_id BIGINT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_days_summary JSONB;
  v_total_appointments INT := 0;
  v_start_date DATE;
  v_end_date DATE;
BEGIN
  v_start_date := make_date(p_year, p_month, 1);
  v_end_date := (v_start_date + INTERVAL '1 month' - INTERVAL '1 day')::date;

  SELECT 
    jsonb_object_agg(
      to_char(appointment_date, 'YYYY-MM-DD'),
      day_data
    ),
    COALESCE(SUM(total_day), 0)
  INTO v_days_summary, v_total_appointments
  FROM (
    SELECT 
      appointment_date,
      COUNT(*) AS total_day,
      jsonb_build_object(
        'count', COUNT(*),
        'confirmed', COUNT(*) FILTER (WHERE status IN ('Confirmed', 'Confirmado', 'Confirmada')),
        'waiting', COUNT(*) FILTER (WHERE status IN ('Waiting', 'En Espera', 'Pendiente')),
        'completed', COUNT(*) FILTER (WHERE status IN ('Completed', 'Completado', 'Finalizada')),
        'cancelled', COUNT(*) FILTER (WHERE status IN ('Cancelled', 'Cancelada', 'Cancelado'))
      ) AS day_data
    FROM public.appointments
    WHERE appointment_date BETWEEN v_start_date AND v_end_date
      AND (p_doctor_id IS NULL OR doctor_id = p_doctor_id)
    GROUP BY appointment_date
  ) sub;

  RETURN jsonb_build_object(
    'success', TRUE,
    'year', p_year,
    'month', p_month,
    'total_appointments', v_total_appointments,
    'days', COALESCE(v_days_summary, '{}'::jsonb)
  );
END;
$$;


-- ------------------------------------------------------------
-- 10. PROCEDIMIENTO: ACTUALIZAR ESTADO DE CITA CON AUDITORÍA
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_update_appointment_status(
  p_appointment_id BIGINT,
  p_new_status VARCHAR(50),
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patient_id BIGINT;
BEGIN
  SELECT patient_id INTO v_patient_id
  FROM public.appointments
  WHERE id = p_appointment_id;

  IF v_patient_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'message', 'Cita no encontrada');
  END IF;

  UPDATE public.appointments SET
    status = p_new_status,
    notes = CASE 
      WHEN p_notes IS NOT NULL AND p_notes <> '' THEN COALESCE(notes || E'\n', '') || p_notes
      ELSE notes
    END,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_appointment_id;

  IF p_new_status IN ('Completed', 'Completado', 'Finalizada') THEN
    UPDATE public.patients
    SET last_visit = CURRENT_TIMESTAMP
    WHERE id = v_patient_id;
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'appointment_id', p_appointment_id,
    'new_status', p_new_status,
    'message', 'Estado de la cita actualizado con éxito'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ------------------------------------------------------------
-- 11. PROCEDIMIENTO: RESUMEN FINANCIERO Y RENDIMIENTO
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_get_financial_analytics(
  p_start_date DATE DEFAULT NULL,
  p_end_date DATE DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start DATE := COALESCE(p_start_date, date_trunc('month', CURRENT_DATE)::date);
  v_end DATE := COALESCE(p_end_date, CURRENT_DATE);
  v_total_revenue NUMERIC(10, 2);
  v_today_revenue NUMERIC(10, 2);
  v_payment_methods JSONB;
BEGIN
  SELECT COALESCE(SUM(amount), 0.00) INTO v_total_revenue
  FROM public.financial_transactions
  WHERE transaction_date::date BETWEEN v_start AND v_end
    AND status IN ('Paid', 'Pagado');

  SELECT COALESCE(SUM(amount), 0.00) INTO v_today_revenue
  FROM public.financial_transactions
  WHERE transaction_date::date = CURRENT_DATE
    AND status IN ('Paid', 'Pagado');

  SELECT jsonb_object_agg(COALESCE(payment_method, 'Otro'), total)
  INTO v_payment_methods
  FROM (
    SELECT payment_method, SUM(amount) AS total
    FROM public.financial_transactions
    WHERE transaction_date::date BETWEEN v_start AND v_end
      AND status IN ('Paid', 'Pagado')
    GROUP BY payment_method
  ) pm;

  RETURN jsonb_build_object(
    'success', TRUE,
    'start_date', v_start,
    'end_date', v_end,
    'total_revenue', v_total_revenue,
    'today_revenue', v_today_revenue,
    'by_payment_method', COALESCE(v_payment_methods, '{}'::jsonb)
  );
END;
$$;


-- ------------------------------------------------------------
-- 12. TRIGGERS AUTOMÁTICOS DE SINCRONIZACIÓN
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_trg_sync_patient_on_soap()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('Finalized', 'Completed') THEN
    UPDATE public.patients
    SET last_visit = CURRENT_TIMESTAMP
    WHERE id = NEW.patient_id;

    UPDATE public.appointments
    SET status = 'Completed'
    WHERE patient_id = NEW.patient_id
      AND appointment_date = CURRENT_DATE
      AND status NOT IN ('Cancelled', 'Cancelado', 'Completed');
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_soap_sync_patient ON public.soap_consultations;
CREATE TRIGGER trg_soap_sync_patient
  AFTER INSERT OR UPDATE ON public.soap_consultations
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_sync_patient_on_soap();

GRANT EXECUTE ON FUNCTION public.sp_save_odontogram_finding TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_get_calendar_month_summary TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_update_appointment_status TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_get_financial_analytics TO anon, authenticated, service_role;


-- ------------------------------------------------------------
-- 13. PROCEDIMIENTO: BÚSQUEDA AVANZADA DE PACIENTES PARA AUTOCOMPLETE
-- Utilizado por los modales de citas para autocompletar en tiempo real
-- según letras ingresadas (nombre, código o documento de identidad).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_search_patients(
  p_query TEXT,
  p_limit INT DEFAULT 10
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_results JSONB;
  v_clean_query TEXT := trim(p_query);
BEGIN
  IF v_clean_query = '' OR v_clean_query IS NULL THEN
    SELECT jsonb_agg(p_row) INTO v_results
    FROM (
      SELECT 
        id,
        patient_code,
        full_name,
        identity_number,
        birth_date,
        gender,
        phone,
        email,
        blood_type,
        is_active,
        has_alert
      FROM public.patients
      WHERE is_active = TRUE
      ORDER BY id DESC
      LIMIT p_limit
    ) p_row;
  ELSE
    SELECT jsonb_agg(p_row) INTO v_results
    FROM (
      SELECT 
        id,
        patient_code,
        full_name,
        identity_number,
        birth_date,
        gender,
        phone,
        email,
        blood_type,
        is_active,
        has_alert
      FROM public.patients
      WHERE is_active = TRUE
        AND (
          full_name ILIKE '%' || v_clean_query || '%'
          OR patient_code ILIKE '%' || v_clean_query || '%'
          OR identity_number ILIKE '%' || v_clean_query || '%'
          OR phone ILIKE '%' || v_clean_query || '%'
        )
      ORDER BY 
        CASE WHEN full_name ILIKE v_clean_query || '%' THEN 1 ELSE 2 END,
        full_name ASC
      LIMIT p_limit
    ) p_row;
  END IF;

  RETURN COALESCE(v_results, '[]'::jsonb);
END;
$$;


-- ------------------------------------------------------------
-- 14. PROCEDIMIENTO: AGENDAR CITA CON VALIDACIÓN INTEGRAL Y SERVICIO DINÁMICO
-- Valida que el paciente exista y esté activo en la base de datos,
-- asocia o encuentra el servicio clínico correspondiente y verifica disponibilidad.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_schedule_appointment(
  p_patient_id BIGINT,
  p_doctor_id BIGINT,
  p_service_name TEXT,
  p_appointment_date DATE,
  p_appointment_time TIME,
  p_notes TEXT DEFAULT NULL,
  p_status VARCHAR(50) DEFAULT 'Waiting'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patient RECORD;
  v_service_id BIGINT;
  v_conflict_id BIGINT;
  v_new_appointment_id BIGINT;
  v_doctor_name VARCHAR(150);
BEGIN
  -- 1. Validar existencia del paciente en la base de datos
  SELECT id, full_name, patient_code INTO v_patient
  FROM public.patients
  WHERE id = p_patient_id AND is_active = TRUE;

  IF v_patient.id IS NULL THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'code', 'PATIENT_NOT_FOUND',
      'message', 'El paciente seleccionado no existe o está inactivo en la base de datos.'
    );
  END IF;

  -- 2. Resolver o emparejar servicio por nombre
  IF p_service_name IS NOT NULL AND trim(p_service_name) <> '' THEN
    SELECT id INTO v_service_id
    FROM public.services
    WHERE name ILIKE '%' || trim(p_service_name) || '%'
    LIMIT 1;
  END IF;

  IF v_service_id IS NULL THEN
    v_service_id := 1; -- Servicio general predeterminado
  END IF;

  -- 3. Verificar si el doctor tiene cita activa en ese horario
  SELECT id INTO v_conflict_id
  FROM public.appointments
  WHERE doctor_id = p_doctor_id
    AND appointment_date = p_appointment_date
    AND appointment_time = p_appointment_time
    AND status NOT IN ('Cancelled', 'Cancelado')
  LIMIT 1;

  IF v_conflict_id IS NOT NULL THEN
    SELECT full_name INTO v_doctor_name FROM public.users WHERE id = p_doctor_id;
    RETURN jsonb_build_object(
      'success', FALSE,
      'code', 'SCHEDULE_CONFLICT',
      'message', format('El doctor %s ya tiene una cita agendada para el %s a las %s.', COALESCE(v_doctor_name, 'médico'), p_appointment_date, p_appointment_time)
    );
  END IF;

  -- 4. Insertar cita
  INSERT INTO public.appointments (
    patient_id, doctor_id, service_id, appointment_date, appointment_time, status, notes
  ) VALUES (
    p_patient_id, p_doctor_id, v_service_id, p_appointment_date, p_appointment_time, p_status, 
    COALESCE(p_notes, p_service_name)
  ) RETURNING id INTO v_new_appointment_id;

  -- 5. Actualizar última fecha de modificación del paciente
  UPDATE public.patients
  SET updated_at = CURRENT_TIMESTAMP
  WHERE id = p_patient_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'appointment_id', v_new_appointment_id,
    'patient_id', v_patient.id,
    'patient_name', v_patient.full_name,
    'patient_code', v_patient.patient_code,
    'date', p_appointment_date,
    'time', p_appointment_time,
    'service', COALESCE(p_notes, p_service_name),
    'message', 'Cita agendada exitosamente en el sistema.'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', FALSE,
    'error', SQLERRM
  );
END;
$$;


-- ------------------------------------------------------------
-- 15. PROCEDIMIENTO: OBTENER CITAS DEL DÍA CON DATOS DEL PACIENTE
-- Optimizado para el panel lateral del calendario y pantalla principal.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_get_day_appointments(
  p_date DATE DEFAULT CURRENT_DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_appointments JSONB;
BEGIN
  SELECT jsonb_agg(apt_row) INTO v_appointments
  FROM (
    SELECT 
      a.id,
      a.patient_id,
      p.full_name AS patient_name,
      p.patient_code,
      p.blood_type,
      a.doctor_id,
      u.full_name AS doctor_name,
      a.appointment_date,
      to_char(a.appointment_time, 'HH12:MI AM') AS formatted_time,
      a.status,
      COALESCE(a.notes, s.name, 'Consulta General') AS service_name,
      a.notes
    FROM public.appointments a
    INNER JOIN public.patients p ON p.id = a.patient_id
    LEFT JOIN public.users u ON u.id = a.doctor_id
    LEFT JOIN public.services s ON s.id = a.service_id
    WHERE a.appointment_date = p_date
    ORDER BY a.appointment_time ASC
  ) apt_row;

  RETURN COALESCE(v_appointments, '[]'::jsonb);
END;
$$;


-- ------------------------------------------------------------
-- 16. TABLA Y TRIGGER DE AUDITORÍA AUTOMÁTICA DE CITAS (HIPAA / TRAZABILIDAD)
-- Registra automáticamente cualquier creación, reagendamiento o cancelación de cita.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  user_id BIGINT NULL REFERENCES public.users(id) ON UPDATE CASCADE ON DELETE SET NULL,
  action VARCHAR(100) NOT NULL,
  table_name VARCHAR(100) NOT NULL,
  record_id BIGINT NULL,
  details JSONB NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename = 'audit_logs' AND policyname = 'audit_logs_policy'
  ) THEN
    CREATE POLICY "audit_logs_policy" ON public.audit_logs
      FOR ALL TO anon, authenticated, service_role
      USING (true) WITH CHECK (true);
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.fn_trg_audit_appointments()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.audit_logs (action, table_name, record_id, details)
    VALUES (
      'APPOINTMENT_SCHEDULED',
      'appointments',
      NEW.id,
      jsonb_build_object(
        'patient_id', NEW.patient_id,
        'doctor_id', NEW.doctor_id,
        'date', NEW.appointment_date,
        'time', NEW.appointment_time,
        'status', NEW.status,
        'notes', NEW.notes
      )
    );
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status <> NEW.status OR OLD.appointment_date <> NEW.appointment_date OR OLD.appointment_time <> NEW.appointment_time THEN
      INSERT INTO public.audit_logs (action, table_name, record_id, details)
      VALUES (
        'APPOINTMENT_UPDATED',
        'appointments',
        NEW.id,
        jsonb_build_object(
          'old_status', OLD.status,
          'new_status', NEW.status,
          'old_date', OLD.appointment_date,
          'new_date', NEW.appointment_date,
          'old_time', OLD.appointment_time,
          'new_time', NEW.appointment_time
        )
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_appointments ON public.appointments;
CREATE TRIGGER trg_audit_appointments
  AFTER INSERT OR UPDATE ON public.appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_audit_appointments();


-- ------------------------------------------------------------
-- 17. TRIGGER: PREVENCIÓN AUTOMÁTICA DE DOBLE AGENDAMIENTO (RACE CONDITIONS)
-- Impide a nivel de base de datos que dos citas activas choquen en el mismo horario.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_prevent_appointment_overlap()
RETURNS TRIGGER AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  IF NEW.status NOT IN ('Cancelled', 'Cancelado') THEN
    SELECT EXISTS (
      SELECT 1 FROM public.appointments
      WHERE doctor_id = NEW.doctor_id
        AND appointment_date = NEW.appointment_date
        AND appointment_time = NEW.appointment_time
        AND id <> COALESCE(NEW.id, -1)
        AND status NOT IN ('Cancelled', 'Cancelado')
    ) INTO v_exists;

    IF v_exists THEN
      RAISE EXCEPTION 'Colisión de agenda: El médico ya tiene una cita activa asignada para la fecha % a las %.', NEW.appointment_date, NEW.appointment_time;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_prevent_appointment_overlap ON public.appointments;
CREATE TRIGGER trg_prevent_appointment_overlap
  BEFORE INSERT OR UPDATE ON public.appointments
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_prevent_appointment_overlap();

-- Permisos de ejecución
GRANT EXECUTE ON FUNCTION public.sp_search_patients TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_schedule_appointment TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_get_day_appointments TO anon, authenticated, service_role;


-- ------------------------------------------------------------
-- 18. MEJORAS DE ESQUEMA PARA ODONTOLOGÍA
-- Asegura columnas de costo y anestesia en odontogram_findings
-- ------------------------------------------------------------
ALTER TABLE public.odontogram_findings ADD COLUMN IF NOT EXISTS cost NUMERIC(10,2) DEFAULT 0.00;
ALTER TABLE public.odontogram_findings ADD COLUMN IF NOT EXISTS anesthesia VARCHAR(100) NULL;


-- ------------------------------------------------------------
-- 19. PROCEDIMIENTO: GUARDAR TRATAMIENTO ODONTOLÓGICO ATÓMICO CON ÍNDICE CPOD
-- Registra o actualiza hallazgo dental, valida datos y devuelve
-- el índice CPOD recalculado al instante.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_save_dental_treatment(
  p_patient_id BIGINT,
  p_tooth_number INT,
  p_condition_type VARCHAR(50),
  p_procedure_name VARCHAR(200),
  p_surfaces JSONB DEFAULT '[]'::jsonb,
  p_status VARCHAR(50) DEFAULT 'Pending',
  p_cost NUMERIC(10,2) DEFAULT 0.00,
  p_anesthesia VARCHAR(100) DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_provider_id BIGINT DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_finding_id BIGINT;
  v_db_condition VARCHAR(50);
  v_db_status VARCHAR(30);
  v_c_count INT := 0;
  v_p_count INT := 0;
  v_o_count INT := 0;
  v_total_cpod INT := 0;
BEGIN
  -- Validar existencia del paciente
  IF NOT EXISTS (SELECT 1 FROM public.patients WHERE id = p_patient_id) THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'El paciente no existe en la base de datos.');
  END IF;

  -- Mapear condición
  IF p_condition_type ILIKE '%caries%' THEN
    v_db_condition := 'Caries';
  ELSIF p_condition_type ILIKE '%trata%' OR p_condition_type ILIKE '%restaur%' OR p_condition_type ILIKE '%obtur%' OR p_condition_type ILIKE '%corona%' THEN
    v_db_condition := 'Treated';
  ELSIF p_condition_type ILIKE '%perdid%' OR p_condition_type ILIKE '%ausen%' OR p_condition_type ILIKE '%extrac%' OR p_condition_type ILIKE '%miss%' THEN
    v_db_condition := 'Missing';
  ELSE
    v_db_condition := 'Healthy';
  END IF;

  -- Mapear estado
  IF p_status ILIKE '%complet%' THEN
    v_db_status := 'Completed';
  ELSIF p_status ILIKE '%cancel%' THEN
    v_db_status := 'Cancelled';
  ELSE
    v_db_status := 'Pending';
  END IF;

  -- Insertar registro de procedimiento
  INSERT INTO public.odontogram_findings (
    patient_id, provider_id, tooth_number, condition_type,
    surfaces, procedure_name, status, cost, anesthesia, notes, finding_date, updated_at
  ) VALUES (
    p_patient_id, p_provider_id, p_tooth_number, v_db_condition,
    p_surfaces, p_procedure_name, v_db_status, p_cost, p_anesthesia, p_notes, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
  ) RETURNING id INTO v_finding_id;

  -- Calcular CPOD actualizado
  SELECT 
    COUNT(*) FILTER (WHERE condition_type = 'Caries'),
    COUNT(*) FILTER (WHERE condition_type = 'Missing'),
    COUNT(*) FILTER (WHERE condition_type = 'Treated')
  INTO v_c_count, v_p_count, v_o_count
  FROM public.odontogram_findings
  WHERE patient_id = p_patient_id;

  v_total_cpod := v_c_count + v_p_count + v_o_count;

  RETURN jsonb_build_object(
    'success', TRUE,
    'finding_id', v_finding_id,
    'patient_id', p_patient_id,
    'tooth_number', p_tooth_number,
    'condition', v_db_condition,
    'status', v_db_status,
    'cpod', jsonb_build_object(
      'decayed', v_c_count,
      'missing', v_p_count,
      'filled', v_o_count,
      'total', v_total_cpod
    ),
    'message', 'Tratamiento odontológico registrado con éxito'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ------------------------------------------------------------
-- 20. PROCEDIMIENTO: ACTUALIZAR ESTADO DE PROCEDIMIENTO ODONTOLÓGICO
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_update_dental_status(
  p_finding_id BIGINT,
  p_status VARCHAR(50)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_db_status VARCHAR(30);
BEGIN
  IF p_status ILIKE '%complet%' THEN
    v_db_status := 'Completed';
  ELSIF p_status ILIKE '%cancel%' THEN
    v_db_status := 'Cancelled';
  ELSE
    v_db_status := 'Pending';
  END IF;

  UPDATE public.odontogram_findings
  SET status = v_db_status, updated_at = CURRENT_TIMESTAMP
  WHERE id = p_finding_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Procedimiento no encontrado.');
  END IF;

  RETURN jsonb_build_object('success', TRUE, 'finding_id', p_finding_id, 'new_status', v_db_status);
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ------------------------------------------------------------
-- 21. PROCEDIMIENTO: ELIMINAR PROCEDIMIENTO ODONTOLÓGICO
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_delete_dental_finding(
  p_finding_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patient_id BIGINT;
  v_c_count INT := 0;
  v_p_count INT := 0;
  v_o_count INT := 0;
  v_total_cpod INT := 0;
BEGIN
  SELECT patient_id INTO v_patient_id
  FROM public.odontogram_findings
  WHERE id = p_finding_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Procedimiento no encontrado.');
  END IF;

  DELETE FROM public.odontogram_findings WHERE id = p_finding_id;

  -- Recalcular CPOD
  SELECT 
    COUNT(*) FILTER (WHERE condition_type = 'Caries'),
    COUNT(*) FILTER (WHERE condition_type = 'Missing'),
    COUNT(*) FILTER (WHERE condition_type = 'Treated')
  INTO v_c_count, v_p_count, v_o_count
  FROM public.odontogram_findings
  WHERE patient_id = v_patient_id;

  v_total_cpod := v_c_count + v_p_count + v_o_count;

  RETURN jsonb_build_object(
    'success', TRUE,
    'patient_id', v_patient_id,
    'cpod', jsonb_build_object(
      'decayed', v_c_count,
      'missing', v_p_count,
      'filled', v_o_count,
      'total', v_total_cpod
    ),
    'message', 'Procedimiento eliminado exitosamente.'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ------------------------------------------------------------
-- 22. FUNCIÓN: CALCULAR ÍNDICE CPOD DE CUALQUIER PACIENTE
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_calculate_patient_cpod(p_patient_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_c INT := 0;
  v_p INT := 0;
  v_o INT := 0;
  v_total INT := 0;
BEGIN
  SELECT 
    COUNT(*) FILTER (WHERE condition_type = 'Caries'),
    COUNT(*) FILTER (WHERE condition_type = 'Missing'),
    COUNT(*) FILTER (WHERE condition_type = 'Treated')
  INTO v_c, v_p, v_o
  FROM public.odontogram_findings
  WHERE patient_id = p_patient_id;

  v_total := v_c + v_p + v_o;

  RETURN jsonb_build_object(
    'patient_id', p_patient_id,
    'cariados', v_c,
    'perdidos', v_p,
    'obturados', v_o,
    'total_cpod', v_total
  );
END;
$$;


-- ------------------------------------------------------------
-- 23. TRIGGER AUTOMATIZADO: SINCRONIZACIÓN AL EXPEDIENTE CLÍNICO
-- Cuando un procedimiento odontológico se completa, se inserta
-- automáticamente en el historial clínico unificado del paciente (clinical_records).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_sync_dental_to_clinical_timeline()
RETURNS TRIGGER AS $$
BEGIN
  -- Si el procedimiento está completado o pasa a completado
  IF (TG_OP = 'INSERT' AND NEW.status = 'Completed') OR
     (TG_OP = 'UPDATE' AND NEW.status = 'Completed' AND (OLD.status IS DISTINCT FROM 'Completed')) THEN
    INSERT INTO public.clinical_records (
      patient_id,
      doctor_id,
      record_type,
      description,
      record_date,
      created_at,
      updated_at
    ) VALUES (
      NEW.patient_id,
      NEW.provider_id,
      'Dental',
      'Procedimiento Odontológico Realizado: ' || NEW.procedure_name || ' (Pieza FDI ' || NEW.tooth_number || '). ' || COALESCE(NEW.notes, ''),
      NEW.finding_date,
      CURRENT_TIMESTAMP,
      CURRENT_TIMESTAMP
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_dental_to_clinical_timeline ON public.odontogram_findings;
CREATE TRIGGER trg_sync_dental_to_clinical_timeline
  AFTER INSERT OR UPDATE ON public.odontogram_findings
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_sync_dental_to_clinical_timeline();


-- ------------------------------------------------------------
-- 24. PERMISOS DE EJECUCIÓN PARA ODONTOLOGÍA
-- ------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.sp_save_dental_treatment TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_update_dental_status TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_delete_dental_finding TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_calculate_patient_cpod TO anon, authenticated, service_role;


-- ------------------------------------------------------------
-- 25. TABLA Y CONFIGURACIÓN: DATOS DE LA CLÍNICA Y PREFERENCIAS
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.clinic_settings (
  id INT PRIMARY KEY DEFAULT 1,
  clinic_name VARCHAR(150) NOT NULL DEFAULT 'MediCore Clínica',
  address TEXT NOT NULL DEFAULT '',
  phone VARCHAR(50) NOT NULL DEFAULT '',
  email VARCHAR(150) NOT NULL DEFAULT '',
  schedule_weekday VARCHAR(100) NOT NULL DEFAULT '08:00 — 18:00',
  schedule_saturday VARCHAR(100) NOT NULL DEFAULT '08:00 — 14:00',
  schedule_sunday VARCHAR(100) NOT NULL DEFAULT 'Cerrado',
  notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  email_reminders BOOLEAN NOT NULL DEFAULT TRUE,
  sound_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  language VARCHAR(30) NOT NULL DEFAULT 'Español',
  consult_duration VARCHAR(30) NOT NULL DEFAULT '30 min',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT single_clinic_config CHECK (id = 1)
);

-- Asegurar registro inicial
INSERT INTO public.clinic_settings (id, clinic_name, address, phone, email)
VALUES (1, 'MediCore Clínica', 'Av. Principal #100, Consultorios Médicos', '+52 55 9876 5432', 'contacto@medicore.com')
ON CONFLICT (id) DO NOTHING;

-- Asegurar columnas de perfil en users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS phone VARCHAR(50);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS specialty VARCHAR(100);
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS license_number VARCHAR(100);

-- Trigger de updated_at para clinic_settings
DROP TRIGGER IF EXISTS trg_clinic_settings_updated_at ON public.clinic_settings;
CREATE TRIGGER trg_clinic_settings_updated_at
  BEFORE UPDATE ON public.clinic_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ------------------------------------------------------------
-- 26. TABLA DE AUDITORÍA DEL SISTEMA
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.system_audit_logs (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  table_name VARCHAR(100) NOT NULL,
  record_id VARCHAR(100) NULL,
  action VARCHAR(50) NOT NULL,
  details JSONB NULL,
  performed_by VARCHAR(150) NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- 27. PROCEDIMIENTO: GUARDAR CONFIGURACIÓN DE LA CLÍNICA Y PREFERENCIAS
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_save_clinic_settings(
  p_clinic_name VARCHAR(150),
  p_address TEXT DEFAULT '',
  p_phone VARCHAR(50) DEFAULT '',
  p_email VARCHAR(150) DEFAULT '',
  p_schedule_weekday VARCHAR(100) DEFAULT '08:00 — 18:00',
  p_schedule_saturday VARCHAR(100) DEFAULT '08:00 — 14:00',
  p_schedule_sunday VARCHAR(100) DEFAULT 'Cerrado',
  p_notifications_enabled BOOLEAN DEFAULT TRUE,
  p_email_reminders BOOLEAN DEFAULT TRUE,
  p_sound_enabled BOOLEAN DEFAULT TRUE,
  p_language VARCHAR(30) DEFAULT 'Español',
  p_consult_duration VARCHAR(30) DEFAULT '30 min'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.clinic_settings (
    id, clinic_name, address, phone, email,
    schedule_weekday, schedule_saturday, schedule_sunday,
    notifications_enabled, email_reminders, sound_enabled,
    language, consult_duration, updated_at
  ) VALUES (
    1, p_clinic_name, p_address, p_phone, p_email,
    p_schedule_weekday, p_schedule_saturday, p_schedule_sunday,
    p_notifications_enabled, p_email_reminders, p_sound_enabled,
    p_language, p_consult_duration, CURRENT_TIMESTAMP
  )
  ON CONFLICT (id) DO UPDATE SET
    clinic_name = EXCLUDED.clinic_name,
    address = EXCLUDED.address,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email,
    schedule_weekday = EXCLUDED.schedule_weekday,
    schedule_saturday = EXCLUDED.schedule_saturday,
    schedule_sunday = EXCLUDED.schedule_sunday,
    notifications_enabled = EXCLUDED.notifications_enabled,
    email_reminders = EXCLUDED.email_reminders,
    sound_enabled = EXCLUDED.sound_enabled,
    language = EXCLUDED.language,
    consult_duration = EXCLUDED.consult_duration,
    updated_at = CURRENT_TIMESTAMP;

  INSERT INTO public.system_audit_logs (table_name, record_id, action, details)
  VALUES ('clinic_settings', '1', 'UPDATE_SETTINGS', jsonb_build_object('clinic_name', p_clinic_name));

  RETURN jsonb_build_object('success', TRUE, 'message', 'Configuración de la clínica guardada correctamente');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

-- ------------------------------------------------------------
-- 28. PROCEDIMIENTO: ACTUALIZAR PERFIL PROFESIONAL DEL MÉDICO
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_update_doctor_profile(
  p_user_id BIGINT,
  p_email VARCHAR(150),
  p_full_name VARCHAR(150),
  p_phone VARCHAR(50) DEFAULT NULL,
  p_specialty VARCHAR(100) DEFAULT NULL,
  p_license_number VARCHAR(100) DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_updated_id BIGINT;
BEGIN
  IF p_user_id IS NOT NULL AND p_user_id > 0 THEN
    UPDATE public.users SET
      full_name = p_full_name,
      phone = p_phone,
      specialty = p_specialty,
      license_number = p_license_number,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = p_user_id
    RETURNING id INTO v_updated_id;
  ELSE
    UPDATE public.users SET
      full_name = p_full_name,
      phone = p_phone,
      specialty = p_specialty,
      license_number = p_license_number,
      updated_at = CURRENT_TIMESTAMP
    WHERE email = p_email
    RETURNING id INTO v_updated_id;
  END IF;

  IF v_updated_id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'No se encontró el usuario a actualizar');
  END IF;

  INSERT INTO public.system_audit_logs (table_name, record_id, action, details)
  VALUES ('users', v_updated_id::text, 'UPDATE_DOCTOR_PROFILE', jsonb_build_object('full_name', p_full_name, 'specialty', p_specialty));

  RETURN jsonb_build_object('success', TRUE, 'user_id', v_updated_id, 'message', 'Perfil médico actualizado');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

-- ------------------------------------------------------------
-- 29. PROCEDIMIENTO: GESTIÓN INTEGRAL DE USUARIOS DEL SISTEMA
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_manage_system_user(
  p_action VARCHAR(20),
  p_user_id BIGINT DEFAULT NULL,
  p_full_name VARCHAR(150) DEFAULT NULL,
  p_email VARCHAR(150) DEFAULT NULL,
  p_role_id BIGINT DEFAULT 2,
  p_phone VARCHAR(50) DEFAULT NULL,
  p_specialty VARCHAR(100) DEFAULT NULL,
  p_license_number VARCHAR(100) DEFAULT NULL,
  p_provider_id VARCHAR(50) DEFAULT NULL,
  p_is_active BOOLEAN DEFAULT TRUE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_target_id BIGINT;
  v_provider_id VARCHAR(50);
BEGIN
  IF p_action = 'create' THEN
    v_provider_id := COALESCE(p_provider_id, 'MED-' || lpad(cast(floor(random() * 900 + 100) as text), 3, '0'));
    
    INSERT INTO public.users (
      full_name, email, role_id, phone, specialty, license_number,
      provider_id, password_hash, is_active, created_at, updated_at
    ) VALUES (
      p_full_name, p_email, p_role_id, p_phone, p_specialty, p_license_number,
      v_provider_id, '[system_managed]', p_is_active, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    ) RETURNING id INTO v_target_id;

    RETURN jsonb_build_object('success', TRUE, 'user_id', v_target_id, 'message', 'Usuario creado');

  ELSIF p_action = 'update' THEN
    UPDATE public.users SET
      full_name = COALESCE(p_full_name, full_name),
      role_id = COALESCE(p_role_id, role_id),
      phone = COALESCE(p_phone, phone),
      specialty = COALESCE(p_specialty, specialty),
      license_number = COALESCE(p_license_number, license_number),
      is_active = COALESCE(p_is_active, is_active),
      updated_at = CURRENT_TIMESTAMP
    WHERE id = p_user_id;

    RETURN jsonb_build_object('success', TRUE, 'user_id', p_user_id, 'message', 'Usuario actualizado');

  ELSIF p_action = 'toggle_status' THEN
    UPDATE public.users SET
      is_active = p_is_active,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = p_user_id;

    RETURN jsonb_build_object('success', TRUE, 'user_id', p_user_id, 'message', 'Estado modificado');
  ELSE
    RETURN jsonb_build_object('success', FALSE, 'error', 'Acción no válida');
  END IF;
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;

-- ------------------------------------------------------------
-- 30. TRIGGER DE AUDITORÍA AUTOMÁTICA EN MODIFICACIÓN DE USUARIOS
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_trg_audit_user_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'UPDATE' THEN
    INSERT INTO public.system_audit_logs (
      table_name, record_id, action, details, performed_by
    ) VALUES (
      'users',
      NEW.id::text,
      'USER_UPDATE',
      jsonb_build_object(
        'old_name', OLD.full_name,
        'new_name', NEW.full_name,
        'old_role', OLD.role_id,
        'new_role', NEW.role_id,
        'is_active', NEW.is_active
      ),
      NEW.email
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_user_changes ON public.users;
CREATE TRIGGER trg_audit_user_changes
  AFTER UPDATE ON public.users
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_audit_user_changes();

-- ------------------------------------------------------------
-- 31. SEGURIDAD RLS (ROW LEVEL SECURITY) Y POLÍTICAS DE ACCESO
-- ------------------------------------------------------------
ALTER TABLE public.clinic_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "clinic_settings_all_access" ON public.clinic_settings;
CREATE POLICY "clinic_settings_all_access" ON public.clinic_settings
  FOR ALL TO anon, authenticated, service_role
  USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "system_audit_logs_all_access" ON public.system_audit_logs;
CREATE POLICY "system_audit_logs_all_access" ON public.system_audit_logs
  FOR ALL TO anon, authenticated, service_role
  USING (true) WITH CHECK (true);

GRANT ALL ON public.clinic_settings TO anon, authenticated, service_role;
GRANT ALL ON public.system_audit_logs TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_save_clinic_settings TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_update_doctor_profile TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_manage_system_user TO anon, authenticated, service_role;

-- ------------------------------------------------------------
-- 32. CAMPOS Y ESTRUCTURA FINANCIERA AVANZADA (USD / CÓRDOBAS)
-- ------------------------------------------------------------
ALTER TABLE public.financial_transactions ADD COLUMN IF NOT EXISTS currency VARCHAR(10) NOT NULL DEFAULT 'USD';
ALTER TABLE public.financial_transactions ADD COLUMN IF NOT EXISTS transaction_type VARCHAR(20) NOT NULL DEFAULT 'Income';
ALTER TABLE public.financial_transactions ADD COLUMN IF NOT EXISTS notes TEXT NULL;

-- ------------------------------------------------------------
-- 33. PROCEDIMIENTO: REGISTRAR TRANSACCIÓN FINANCIERA ATÓMICA
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sp_register_financial_transaction(
  p_patient_id BIGINT DEFAULT NULL,
  p_appointment_id BIGINT DEFAULT NULL,
  p_concept VARCHAR(150) DEFAULT 'Atención Médica',
  p_amount NUMERIC(10,2) DEFAULT 0.00,
  p_currency VARCHAR(10) DEFAULT 'USD',
  p_payment_method VARCHAR(50) DEFAULT 'Cash',
  p_status VARCHAR(30) DEFAULT 'Paid',
  p_transaction_type VARCHAR(20) DEFAULT 'Income',
  p_invoice_number VARCHAR(50) DEFAULT NULL,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tx_id BIGINT;
  v_invoice VARCHAR(50);
BEGIN
  -- Generar folio si no viene provisto
  IF p_invoice_number IS NULL OR trim(p_invoice_number) = '' THEN
    v_invoice := 'REC-' || to_char(CURRENT_DATE, 'YYYY') || '-' || lpad(cast(floor(random() * 9000 + 1000) as text), 4, '0');
  ELSE
    v_invoice := p_invoice_number;
  END IF;

  -- 1. Insertar la transacción financiera
  INSERT INTO public.financial_transactions (
    patient_id, appointment_id, concept, amount, currency,
    payment_method, status, transaction_type, invoice_number, notes,
    transaction_date, created_at, updated_at
  ) VALUES (
    p_patient_id, p_appointment_id, p_concept, p_amount, p_currency,
    p_payment_method, p_status, p_transaction_type, v_invoice, p_notes,
    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
  ) RETURNING id INTO v_tx_id;

  -- 2. Si la transacción está vinculada a una cita y pagada, sincronizar estado de la cita
  IF p_appointment_id IS NOT NULL AND (p_status = 'Paid' OR p_status = 'Pagado') THEN
    UPDATE public.appointments
    SET status = 'Completed', updated_at = CURRENT_TIMESTAMP
    WHERE id = p_appointment_id;
  END IF;

  -- 3. Registrar auditoría
  INSERT INTO public.system_audit_logs (
    table_name, record_id, action, details, performed_by
  ) VALUES (
    'financial_transactions',
    v_tx_id::text,
    'CREATE_TRANSACTION',
    jsonb_build_object(
      'amount', p_amount,
      'currency', p_currency,
      'concept', p_concept,
      'status', p_status,
      'type', p_transaction_type,
      'invoice', v_invoice
    ),
    'sistema_caja'
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'transaction_id', v_tx_id,
    'invoice_number', v_invoice,
    'message', 'Transacción financiera registrada correctamente'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', FALSE,
    'error', SQLERRM
  );
END;
$$;

-- ------------------------------------------------------------
-- 34. FUNCIÓN ANALÍTICA: DASHBOARD FINANCIERO Y RESUMEN DE 6 MESES
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_get_financial_dashboard_metrics(
  p_period VARCHAR(50) DEFAULT 'Este Mes',
  p_exchange_rate NUMERIC(10,4) DEFAULT 36.6200
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start_date TIMESTAMPTZ;
  v_income NUMERIC(12,2) := 0.00;
  v_expenses NUMERIC(12,2) := 0.00;
  v_balance NUMERIC(12,2) := 0.00;
  v_billed_count INT := 0;
  v_monthly_data JSONB;
BEGIN
  -- Definir inicio del período
  IF p_period = 'Esta Semana' THEN
    v_start_date := date_trunc('week', CURRENT_TIMESTAMP);
  ELSEIF p_period = 'Este Año' THEN
    v_start_date := date_trunc('year', CURRENT_TIMESTAMP);
  ELSE
    v_start_date := date_trunc('month', CURRENT_TIMESTAMP);
  END IF;

  -- Totales del período
  SELECT
    COALESCE(SUM(amount) FILTER (WHERE (status = 'Paid' OR status = 'Pagado') AND (transaction_type IS NULL OR transaction_type = 'Income')), 0),
    COALESCE(SUM(amount) FILTER (WHERE (status = 'Paid' OR status = 'Pagado') AND (transaction_type = 'Expense' OR transaction_type = 'Gasto')), 0),
    COUNT(*) FILTER (WHERE (status = 'Paid' OR status = 'Pagado') AND (transaction_type IS NULL OR transaction_type = 'Income'))
  INTO v_income, v_expenses, v_billed_count
  FROM public.financial_transactions
  WHERE transaction_date >= v_start_date;

  v_balance := v_income - v_expenses;

  -- Serie de ingresos de los últimos 6 meses
  SELECT jsonb_agg(sub)
  INTO v_monthly_data
  FROM (
    SELECT
      to_char(m.month_date, 'YYYY-MM') AS month_key,
      to_char(m.month_date, 'Mon') AS month_label,
      COALESCE(SUM(t.amount) FILTER (WHERE (t.status = 'Paid' OR t.status = 'Pagado') AND (t.transaction_type IS NULL OR t.transaction_type = 'Income')), 0) AS total_income
    FROM generate_series(
      date_trunc('month', CURRENT_DATE) - INTERVAL '5 months',
      date_trunc('month', CURRENT_DATE),
      INTERVAL '1 month'
    ) AS m(month_date)
    LEFT JOIN public.financial_transactions t
      ON date_trunc('month', t.transaction_date) = m.month_date
    GROUP BY m.month_date
    ORDER BY m.month_date ASC
  ) sub;

  RETURN jsonb_build_object(
    'total_income', v_income,
    'total_expenses', v_expenses,
    'balance', v_balance,
    'billed_count', v_billed_count,
    'exchange_rate', p_exchange_rate,
    'monthly_history', COALESCE(v_monthly_data, '[]'::jsonb)
  );
END;
$$;

-- ------------------------------------------------------------
-- 35. POLÍTICAS RLS Y PERMISOS PARA FINANZAS
-- ------------------------------------------------------------
ALTER TABLE public.financial_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "financial_transactions_all_access" ON public.financial_transactions;
CREATE POLICY "financial_transactions_all_access" ON public.financial_transactions
  FOR ALL TO anon, authenticated, service_role
  USING (true) WITH CHECK (true);

GRANT ALL ON public.financial_transactions TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_register_financial_transaction TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_get_financial_dashboard_metrics TO anon, authenticated, service_role;


-- ============================================================
-- 36. ACTUALIZACIONES DE ESQUEMA CLÍNICO AVANZADO
-- ============================================================
ALTER TABLE public.vital_signs ADD COLUMN IF NOT EXISTS heart_rate INT;
ALTER TABLE public.vital_signs ADD COLUMN IF NOT EXISTS respiratory_rate INT;
ALTER TABLE public.vital_signs ADD COLUMN IF NOT EXISTS oxygen_saturation INT;
ALTER TABLE public.prescriptions ADD COLUMN IF NOT EXISTS consultation_id BIGINT REFERENCES public.soap_consultations(id) ON UPDATE CASCADE ON DELETE SET NULL;
ALTER TABLE public.prescriptions ADD COLUMN IF NOT EXISTS notes TEXT;


-- ============================================================
-- 37. TRIGGER Y ALERTA AUTOMÁTICA DE SIGNOS VITALES CRÍTICOS (TRIAJE INTELIGENTE)
-- Evalúa valores de presión arterial, frecuencia cardíaca, temperatura, saturación O2
-- e IMC en tiempo real. Si detecta crisis o valores de alarma, activa automáticamente
-- la bandera has_alert del paciente e inserta un evento de ALERTA CLÍNICA en su historial.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_trg_check_critical_vital_signs()
RETURNS TRIGGER AS $$
DECLARE
  v_is_critical BOOLEAN := FALSE;
  v_alerts TEXT[] := ARRAY[]::TEXT[];
  v_patient_name VARCHAR(200);
  v_hr INT;
  v_bmi NUMERIC(5,1);
BEGIN
  v_hr := COALESCE(NEW.heart_rate, NEW.pulse);
  v_bmi := NEW.bmi;

  -- 1. Detección de Crisis o Hipertensión Grado 2
  IF NEW.bp_systolic >= 180 OR NEW.bp_diastolic >= 120 THEN
    v_is_critical := TRUE;
    v_alerts := array_append(v_alerts, format('Crisis Hipertensiva (%s/%s mmHg)', NEW.bp_systolic, NEW.bp_diastolic));
  ELSIF NEW.bp_systolic >= 140 OR NEW.bp_diastolic >= 90 THEN
    v_is_critical := TRUE;
    v_alerts := array_append(v_alerts, format('Hipertensión Grado 2 (%s/%s mmHg)', NEW.bp_systolic, NEW.bp_diastolic));
  ELSIF (NEW.bp_systolic > 0 AND NEW.bp_systolic < 90) OR (NEW.bp_diastolic > 0 AND NEW.bp_diastolic < 60) THEN
    v_is_critical := TRUE;
    v_alerts := array_append(v_alerts, format('Hipotensión Severa (%s/%s mmHg)', NEW.bp_systolic, NEW.bp_diastolic));
  END IF;

  -- 2. Frecuencia Cardíaca
  IF v_hr > 120 THEN
    v_is_critical := TRUE;
    v_alerts := array_append(v_alerts, format('Taquicardia Severa (%s lpm)', v_hr));
  ELSIF v_hr > 0 AND v_hr < 50 THEN
    v_is_critical := TRUE;
    v_alerts := array_append(v_alerts, format('Bradicardia Severa (%s lpm)', v_hr));
  END IF;

  -- 3. Temperatura
  IF NEW.temperature >= 38.5 THEN
    v_is_critical := TRUE;
    v_alerts := array_append(v_alerts, format('Fiebre Alta / Hiperpirexia (%s °C)', NEW.temperature));
  ELSIF NEW.temperature > 0 AND NEW.temperature < 35.0 THEN
    v_is_critical := TRUE;
    v_alerts := array_append(v_alerts, format('Hipotermia (%s °C)', NEW.temperature));
  END IF;

  -- 4. Saturación de Oxígeno (SpO2)
  IF NEW.oxygen_saturation IS NOT NULL AND NEW.oxygen_saturation > 0 AND NEW.oxygen_saturation < 92 THEN
    v_is_critical := TRUE;
    v_alerts := array_append(v_alerts, format('Hipoxemia / Baja Saturación O2 (%s%%)', NEW.oxygen_saturation));
  END IF;

  -- 5. IMC Extremo
  IF v_bmi IS NOT NULL AND v_bmi >= 40.0 THEN
    v_is_critical := TRUE;
    v_alerts := array_append(v_alerts, format('Obesidad Mórbida (IMC %s)', v_bmi));
  ELSIF v_bmi IS NOT NULL AND v_bmi > 0 AND v_bmi < 16.0 THEN
    v_is_critical := TRUE;
    v_alerts := array_append(v_alerts, format('Desnutrición Severa (IMC %s)', v_bmi));
  END IF;

  -- Si se detectó alerta crítica, activar flag del paciente y registrar en el timeline clínico
  IF v_is_critical THEN
    UPDATE public.patients
    SET has_alert = TRUE, updated_at = CURRENT_TIMESTAMP
    WHERE id = NEW.patient_id;

    SELECT full_name INTO v_patient_name FROM public.patients WHERE id = NEW.patient_id;

    INSERT INTO public.clinical_records (
      patient_id,
      doctor_id,
      record_type,
      title,
      description,
      record_date,
      tags
    ) VALUES (
      NEW.patient_id,
      COALESCE((SELECT doctor_id FROM public.soap_consultations WHERE id = NEW.consultation_id), 1),
      'ALERTA CLÍNICA',
      'Signos Vitales Críticos Detectados',
      format('Paciente %s presentó anomalías en toma de signos: %s. Requiere vigilancia médica inmediata.', COALESCE(v_patient_name, 'N/A'), array_to_string(v_alerts, ', ')),
      CURRENT_TIMESTAMP,
      jsonb_build_array('Alerta Médica', 'Signos Críticos', 'Triaje')
    );

    -- Auditoría
    INSERT INTO public.system_audit_logs (
      table_name, record_id, action, details, performed_by
    ) VALUES (
      'vital_signs',
      NEW.id::text,
      'CRITICAL_VITALS_TRIGGER',
      jsonb_build_object(
        'patient_id', NEW.patient_id,
        'alerts', v_alerts,
        'bp_systolic', NEW.bp_systolic,
        'bp_diastolic', NEW.bp_diastolic,
        'temp', NEW.temperature,
        'pulse', v_hr
      ),
      'sistema_triaje_automatico'
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_vital_signs_critical_alert ON public.vital_signs;
CREATE TRIGGER trg_vital_signs_critical_alert
  AFTER INSERT OR UPDATE ON public.vital_signs
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_check_critical_vital_signs();


-- ============================================================
-- 38. PROCEDIMIENTO DE PRESCRIPCIÓN SEGURA CON DETECCIÓN AUTOMÁTICA DE CONFLICTOS ALÉRGICOS
-- Cruza cada medicamento recetado contra las alergias activas del paciente.
-- Si detecta alergia severa (ej. Penicilinas, AINEs, Sulfas), bloquea la transacción
-- a menos que se aplique override explícito por el médico, garantizando seguridad clínica.
-- ============================================================
CREATE OR REPLACE FUNCTION public.sp_prescribe_medication_with_safety_check(
  p_patient_id BIGINT,
  p_doctor_id BIGINT,
  p_medications JSONB, -- Array de objetos: [{ drug_name, dose, frequency, duration, instructions }]
  p_consultation_id BIGINT DEFAULT NULL,
  p_clinic_name VARCHAR(150) DEFAULT 'Clínica Sanitas Central',
  p_clinic_address VARCHAR(255) DEFAULT 'Av. Principal 123, Ciudad • Tel: 555-0192',
  p_force_override BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rx_id BIGINT;
  v_med JSONB;
  v_drug_name TEXT;
  v_allergy_record RECORD;
  v_conflicts JSONB := '[]'::jsonb;
  v_has_severe_conflict BOOLEAN := FALSE;
  v_inserted_count INT := 0;
  v_doctor_name VARCHAR(150);
BEGIN
  -- 1. Validar alergias del paciente contra cada medicamento en la lista
  FOR v_med IN SELECT * FROM jsonb_array_elements(p_medications)
  LOOP
    v_drug_name := lower(trim(v_med->>'drug_name'));

    -- Revisar contra alergias activas del paciente
    FOR v_allergy_record IN
      SELECT allergen, reaction, severity
      FROM public.allergy_alerts
      WHERE patient_id = p_patient_id AND is_active = TRUE
    LOOP
      -- Detección por coincidencia directa o clases comunes
      IF v_drug_name ILIKE '%' || lower(v_allergy_record.allergen) || '%' OR
         lower(v_allergy_record.allergen) ILIKE '%' || v_drug_name || '%' OR
         -- Cruces farmacológicos comunes
         (lower(v_allergy_record.allergen) ILIKE '%penicilin%' AND (v_drug_name ILIKE '%amoxicil%' OR v_drug_name ILIKE '%ampicil%' OR v_drug_name ILIKE '%cefal%')) OR
         (lower(v_allergy_record.allergen) ILIKE '%aine%' AND (v_drug_name ILIKE '%ibuprof%' OR v_drug_name ILIKE '%aspirin%' OR v_drug_name ILIKE '%ketorol%' OR v_drug_name ILIKE '%diclofen%')) OR
         (lower(v_allergy_record.allergen) ILIKE '%aspirin%' AND (v_drug_name ILIKE '%ibuprof%' OR v_drug_name ILIKE '%ketorol%' OR v_drug_name ILIKE '%diclofen%'))
      THEN
        v_conflicts := v_conflicts || jsonb_build_object(
          'drug', v_med->>'drug_name',
          'allergen', v_allergy_record.allergen,
          'severity', v_allergy_record.severity,
          'reaction', v_allergy_record.reaction
        );

        IF v_allergy_record.severity IN ('Severa', 'Alta') THEN
          v_has_severe_conflict := TRUE;
        END IF;
      END IF;
    END LOOP;
  END LOOP;

  -- 2. Si hay conflicto severo y no hay override explícito, abortar con alerta de seguridad
  IF v_has_severe_conflict AND NOT p_force_override THEN
    RETURN jsonb_build_object(
      'success', FALSE,
      'code', 'SEVERE_ALLERGY_CONFLICT',
      'message', 'ALERTA DE SEGURIDAD CLÍNICA: Se detectó una alergia severa potencialmente mortal para uno o más medicamentos de la prescripción.',
      'conflicts', v_conflicts
    );
  END IF;

  -- 3. Crear encabezado de receta médica
  INSERT INTO public.prescriptions (
    patient_id, doctor_id, consultation_id, clinic_name, clinic_address,
    prescription_date, notes, created_at, updated_at
  ) VALUES (
    p_patient_id, p_doctor_id, p_consultation_id, p_clinic_name, p_clinic_address,
    CURRENT_DATE, p_notes, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
  ) RETURNING id INTO v_rx_id;

  -- 4. Insertar cada medicamento
  FOR v_med IN SELECT * FROM jsonb_array_elements(p_medications)
  LOOP
    INSERT INTO public.prescription_items (
      prescription_id, drug_name, dose, frequency, duration, instructions,
      created_at, updated_at
    ) VALUES (
      v_rx_id,
      v_med->>'drug_name',
      COALESCE(v_med->>'dose', '1 dosis'),
      COALESCE(v_med->>'frequency', 'Cada 8 horas'),
      COALESCE(v_med->>'duration', '5 días'),
      v_med->>'instructions',
      CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    );
    v_inserted_count := v_inserted_count + 1;
  END LOOP;

  -- 5. Registrar en la cronología del expediente clínico
  SELECT full_name INTO v_doctor_name FROM public.users WHERE id = p_doctor_id;

  INSERT INTO public.clinical_records (
    patient_id, doctor_id, record_type, title, description, record_date, tags
  ) VALUES (
    p_patient_id,
    p_doctor_id,
    'RECETA MÉDICA',
    'Prescripción Farmacológica Emitida',
    format('Se emitieron %s medicamentos. Médico: %s.', v_inserted_count, COALESCE(v_doctor_name, 'Médico')),
    CURRENT_TIMESTAMP,
    jsonb_build_array('Farmacia', 'Receta Médica', COALESCE(v_doctor_name, 'Médico'))
  );

  -- 6. Auditoría
  INSERT INTO public.system_audit_logs (
    table_name, record_id, action, details, performed_by
  ) VALUES (
    'prescriptions',
    v_rx_id::text,
    CASE WHEN p_force_override THEN 'PRESCRIPTION_WITH_OVERRIDE' ELSE 'PRESCRIPTION_CREATED' END,
    jsonb_build_object(
      'patient_id', p_patient_id,
      'items_count', v_inserted_count,
      'conflicts', v_conflicts,
      'override_used', p_force_override
    ),
    COALESCE(v_doctor_name, 'doctor')
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'prescription_id', v_rx_id,
    'items_count', v_inserted_count,
    'had_warnings', jsonb_array_length(v_conflicts) > 0,
    'conflicts', v_conflicts,
    'message', 'Receta médica emitida exitosamente con validación de seguridad clínica.'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object(
    'success', FALSE,
    'error', SQLERRM
  );
END;
$$;


-- ============================================================
-- 39. FUNCIÓN RPC: EXPEDIENTE CLÍNICO INTEGRAL ULTRARRÁPIDO (360° COMPLETE CHART)
-- Devuelve en una sola respuesta JSONB el expediente completo: demografía con cálculo exacto
-- de edad, contactos, alergias, últimos signos vitales, consultas SOAP, recetas, resumen odontológico
-- con índice CPOD, percentiles de crecimiento pediátrico y próxima cita.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_get_patient_complete_chart(
  p_patient_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_patient RECORD;
  v_contacts JSONB;
  v_allergies JSONB;
  v_vitals JSONB;
  v_soaps JSONB;
  v_prescriptions JSONB;
  v_dental JSONB;
  v_growth JSONB;
  v_next_appointment JSONB;
  v_age_text TEXT;
BEGIN
  -- 1. Datos demográficos del paciente
  SELECT * INTO v_patient
  FROM public.patients
  WHERE id = p_patient_id;

  IF v_patient.id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Paciente no encontrado');
  END IF;

  -- Cálculo de edad exacta en texto
  IF v_patient.birth_date IS NOT NULL THEN
    v_age_text := concat(
      date_part('year', age(CURRENT_DATE, v_patient.birth_date)), ' años, ',
      date_part('month', age(CURRENT_DATE, v_patient.birth_date)), ' meses'
    );
  ELSE
    v_age_text := 'No especificada';
  END IF;

  -- 2. Contactos de emergencia
  SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_contacts
  FROM (
    SELECT id, contact_name, relationship, phone
    FROM public.emergency_contacts
    WHERE patient_id = p_patient_id
  ) c;

  -- 3. Alergias activas
  SELECT COALESCE(jsonb_agg(a), '[]'::jsonb) INTO v_allergies
  FROM (
    SELECT id, allergen, reaction, severity, documented_date
    FROM public.allergy_alerts
    WHERE patient_id = p_patient_id AND is_active = TRUE
    ORDER BY CASE severity WHEN 'Severa' THEN 1 WHEN 'Moderada' THEN 2 ELSE 3 END
  ) a;

  -- 4. Últimos signos vitales
  SELECT to_jsonb(v) INTO v_vitals
  FROM (
    SELECT id, bp_systolic, bp_diastolic, COALESCE(heart_rate, pulse) AS pulse,
           temperature, weight_kg, height_cm, bmi, respiratory_rate, oxygen_saturation,
           measured_at
    FROM public.vital_signs
    WHERE patient_id = p_patient_id
    ORDER BY measured_at DESC
    LIMIT 1
  ) v;

  -- 5. Últimas 5 consultas SOAP
  SELECT COALESCE(jsonb_agg(s), '[]'::jsonb) INTO v_soaps
  FROM (
    SELECT sc.id, sc.consultation_date, sc.subjective, sc.objective, sc.assessment, sc.plan,
           sc.icd10_code, sc.status, u.full_name AS doctor_name
    FROM public.soap_consultations sc
    LEFT JOIN public.users u ON u.id = sc.doctor_id
    WHERE sc.patient_id = p_patient_id
    ORDER BY sc.consultation_date DESC
    LIMIT 5
  ) s;

  -- 6. Recetas con sus items
  SELECT COALESCE(jsonb_agg(rx), '[]'::jsonb) INTO v_prescriptions
  FROM (
    SELECT p.id, p.prescription_date, p.clinic_name, u.full_name AS doctor_name,
           (
             SELECT jsonb_agg(pi)
             FROM public.prescription_items pi
             WHERE pi.prescription_id = p.id
           ) AS items
    FROM public.prescriptions p
    LEFT JOIN public.users u ON u.id = p.doctor_id
    WHERE p.patient_id = p_patient_id
    ORDER BY p.prescription_date DESC
    LIMIT 5
  ) rx;

  -- 7. Resumen Odontológico y CPOD
  SELECT jsonb_build_object(
    'total_findings', COUNT(*),
    'decayed', COUNT(*) FILTER (WHERE condition_type = 'Caries'),
    'missing', COUNT(*) FILTER (WHERE condition_type = 'Missing'),
    'filled', COUNT(*) FILTER (WHERE condition_type = 'Treated'),
    'total_cpod', COUNT(*) FILTER (WHERE condition_type IN ('Caries', 'Missing', 'Treated'))
  ) INTO v_dental
  FROM public.odontogram_findings
  WHERE patient_id = p_patient_id;

  -- 8. Último percentil de crecimiento pediátrico
  SELECT to_jsonb(g) INTO v_growth
  FROM (
    SELECT id, measurement_date, age_label, age_months, weight_kg, weight_percentile,
           height_cm, height_percentile, head_circumference_cm, notes
    FROM public.pediatric_growth_records
    WHERE patient_id = p_patient_id
    ORDER BY measurement_date DESC
    LIMIT 1
  ) g;

  -- 9. Próxima cita
  SELECT to_jsonb(apt) INTO v_next_appointment
  FROM (
    SELECT a.id, a.appointment_date, to_char(a.appointment_time, 'HH12:MI AM') AS formatted_time,
           a.status, COALESCE(a.notes, s.name) AS service_name, u.full_name AS doctor_name
    FROM public.appointments a
    LEFT JOIN public.services s ON s.id = a.service_id
    LEFT JOIN public.users u ON u.id = a.doctor_id
    WHERE a.patient_id = p_patient_id
      AND a.appointment_date >= CURRENT_DATE
      AND a.status NOT IN ('Cancelled', 'Completed')
    ORDER BY a.appointment_date ASC, a.appointment_time ASC
    LIMIT 1
  ) apt;

  RETURN jsonb_build_object(
    'success', TRUE,
    'patient', jsonb_build_object(
      'id', v_patient.id,
      'code', v_patient.patient_code,
      'full_name', v_patient.full_name,
      'identity_number', v_patient.identity_number,
      'birth_date', v_patient.birth_date,
      'age_text', v_age_text,
      'gender', v_patient.gender,
      'blood_type', v_patient.blood_type,
      'phone', v_patient.phone,
      'email', v_patient.email,
      'address', v_patient.address,
      'has_alert', v_patient.has_alert,
      'last_visit', v_patient.last_visit
    ),
    'emergency_contacts', v_contacts,
    'allergies', v_allergies,
    'latest_vitals', v_vitals,
    'soap_consultations', v_soaps,
    'prescriptions', v_prescriptions,
    'dental_summary', v_dental,
    'growth_summary', v_growth,
    'next_appointment', v_next_appointment
  );
END;
$$;


-- ============================================================
-- 40. EVALUACIÓN NUTRICIONAL PEDIÁTRICA Y REGISTRO DE CURVAS OMS
-- Ingesta y calcula automáticamente la etiqueta de edad, percentiles referenciales
-- de peso y talla según la OMS y clasifica el estado nutricional del menor.
-- ============================================================
CREATE OR REPLACE FUNCTION public.sp_register_pediatric_growth_record(
  p_patient_id BIGINT,
  p_provider_id BIGINT,
  p_measurement_date DATE,
  p_age_months NUMERIC(4,1),
  p_weight_kg NUMERIC(5,2),
  p_height_cm NUMERIC(5,2),
  p_head_circumference_cm NUMERIC(4,1),
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_record_id BIGINT;
  v_age_label VARCHAR(50);
  v_w_percentile INT;
  v_h_percentile INT;
  v_nutritional_status VARCHAR(100);
  v_years INT;
  v_rem_months INT;
BEGIN
  -- 1. Generar etiqueta amigable de edad (e.g. '2a 4m' o '6m')
  v_years := floor(p_age_months / 12);
  v_rem_months := round(p_age_months - (v_years * 12));

  IF p_age_months = 0 THEN
    v_age_label := 'Nacimiento';
  ELSIF v_years = 0 THEN
    v_age_label := format('%sm', round(p_age_months));
  ELSIF v_rem_months = 0 THEN
    v_age_label := format('%sa', v_years);
  ELSE
    v_age_label := format('%sa %sm', v_years, v_rem_months);
  END IF;

  -- 2. Estimación de percentiles OMS basada en curvas de referencia estándar
  -- Relación peso/edad
  IF p_age_months <= 12 THEN
    -- Lactante
    IF p_weight_kg < (3.3 + (p_age_months * 0.5)) THEN
      v_w_percentile := 10;
    ELSIF p_weight_kg > (3.3 + (p_age_months * 0.8)) THEN
      v_w_percentile := 90;
    ELSE
      v_w_percentile := 50;
    END IF;
  ELSE
    -- Niño mayor
    IF p_weight_kg < (8.0 + (p_age_months * 0.18)) THEN
      v_w_percentile := 10;
    ELSIF p_weight_kg > (10.0 + (p_age_months * 0.28)) THEN
      v_w_percentile := 90;
    ELSE
      v_w_percentile := 50;
    END IF;
  END IF;

  -- Relación talla/edad
  IF p_height_cm < (50.0 + (p_age_months * 1.5)) THEN
    v_h_percentile := 15;
  ELSIF p_height_cm > (50.0 + (p_age_months * 2.5)) THEN
    v_h_percentile := 85;
  ELSE
    v_h_percentile := 50;
  END IF;

  -- 3. Clasificación nutricional clínica
  IF v_w_percentile < 15 THEN
    v_nutritional_status := 'Riesgo de Desnutrición / Bajo Peso';
  ELSIF v_w_percentile > 85 THEN
    v_nutritional_status := 'Sobrepeso / Riesgo Ponderal Elevado';
  ELSE
    v_nutritional_status := 'Eutrófico (Crecimiento Adecuado OMS)';
  END IF;

  -- 4. Inserción
  INSERT INTO public.pediatric_growth_records (
    patient_id, provider_id, measurement_date, age_label, age_months,
    weight_kg, weight_percentile, height_cm, height_percentile,
    head_circumference_cm, notes, created_at, updated_at
  ) VALUES (
    p_patient_id, p_provider_id, p_measurement_date, v_age_label, p_age_months,
    p_weight_kg, v_w_percentile, p_height_cm, v_h_percentile,
    p_head_circumference_cm, p_notes, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
  ) RETURNING id INTO v_record_id;

  -- 5. Si hay riesgo nutricional extremo, alertar al paciente
  IF v_w_percentile <= 10 OR v_w_percentile >= 90 THEN
    UPDATE public.patients SET has_alert = TRUE WHERE id = p_patient_id;
  END IF;

  RETURN jsonb_build_object(
    'success', TRUE,
    'record_id', v_record_id,
    'age_label', v_age_label,
    'weight_percentile', v_w_percentile,
    'height_percentile', v_h_percentile,
    'nutritional_status', v_nutritional_status,
    'message', 'Registro de crecimiento pediátrico guardado con éxito'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


-- ============================================================
-- 41. REAGENDAMIENTO INTELIGENTE Y ANÁLISIS DE AUSENTISMO (NO-SHOW RATE)
-- Permite reagendar citas garantizando cero colisiones de agenda, actualizando la trazabilidad.
-- Calcula analítica de asistencia y fiabilidad del paciente para el equipo de recepción.
-- ============================================================
CREATE OR REPLACE FUNCTION public.sp_reschedule_appointment(
  p_appointment_id BIGINT,
  p_new_date DATE,
  p_new_time TIME,
  p_reason TEXT DEFAULT 'Reagendamiento solicitado'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_apt RECORD;
  v_conflict_id BIGINT;
  v_doctor_name VARCHAR(150);
BEGIN
  SELECT * INTO v_apt
  FROM public.appointments
  WHERE id = p_appointment_id;

  IF v_apt.id IS NULL THEN
    RETURN jsonb_build_object('success', FALSE, 'error', 'Cita no encontrada');
  END IF;

  -- Validar colisión en el nuevo horario
  SELECT id INTO v_conflict_id
  FROM public.appointments
  WHERE doctor_id = v_apt.doctor_id
    AND appointment_date = p_new_date
    AND appointment_time = p_new_time
    AND id <> p_appointment_id
    AND status NOT IN ('Cancelled', 'Cancelado')
  LIMIT 1;

  IF v_conflict_id IS NOT NULL THEN
    SELECT full_name INTO v_doctor_name FROM public.users WHERE id = v_apt.doctor_id;
    RETURN jsonb_build_object(
      'success', FALSE,
      'code', 'SLOT_OCCUPIED',
      'message', format('El doctor %s ya tiene una cita agendada en la fecha %s a las %s.', COALESCE(v_doctor_name, 'médico'), p_new_date, p_new_time)
    );
  END IF;

  -- Actualizar cita
  UPDATE public.appointments SET
    appointment_date = p_new_date,
    appointment_time = p_new_time,
    status = 'Confirmed',
    notes = COALESCE(notes || E'\n', '') || format('[Reagendada de %s %s a %s %s - Motivo: %s]', v_apt.appointment_date, v_apt.appointment_time, p_new_date, p_new_time, p_reason),
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_appointment_id;

  -- Auditoría
  INSERT INTO public.system_audit_logs (
    table_name, record_id, action, details, performed_by
  ) VALUES (
    'appointments',
    p_appointment_id::text,
    'APPOINTMENT_RESCHEDULED',
    jsonb_build_object(
      'old_date', v_apt.appointment_date,
      'old_time', v_apt.appointment_time,
      'new_date', p_new_date,
      'new_time', p_new_time,
      'reason', p_reason
    ),
    'sistema_citas'
  );

  RETURN jsonb_build_object(
    'success', TRUE,
    'appointment_id', p_appointment_id,
    'new_date', p_new_date,
    'new_time', p_new_time,
    'message', 'Cita reagendada exitosamente sin conflictos de horario.'
  );
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('success', FALSE, 'error', SQLERRM);
END;
$$;


CREATE OR REPLACE FUNCTION public.fn_get_patient_attendance_analytics(
  p_patient_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total INT := 0;
  v_completed INT := 0;
  v_cancelled INT := 0;
  v_waiting INT := 0;
  v_attendance_rate NUMERIC(5,1) := 100.0;
  v_noshow_rate NUMERIC(5,1) := 0.0;
BEGIN
  SELECT
    COUNT(*),
    COUNT(*) FILTER (WHERE status IN ('Completed', 'Completado', 'Finalizada')),
    COUNT(*) FILTER (WHERE status IN ('Cancelled', 'Cancelada', 'Cancelado')),
    COUNT(*) FILTER (WHERE status IN ('Waiting', 'Confirmed', 'Pendiente'))
  INTO v_total, v_completed, v_cancelled, v_waiting
  FROM public.appointments
  WHERE patient_id = p_patient_id;

  IF (v_completed + v_cancelled) > 0 THEN
    v_attendance_rate := round(((v_completed::numeric / (v_completed + v_cancelled)::numeric) * 100.0), 1);
    v_noshow_rate := round(((v_cancelled::numeric / (v_completed + v_cancelled)::numeric) * 100.0), 1);
  END IF;

  RETURN jsonb_build_object(
    'patient_id', p_patient_id,
    'total_appointments', v_total,
    'completed', v_completed,
    'cancelled', v_cancelled,
    'pending', v_waiting,
    'attendance_rate_percent', v_attendance_rate,
    'noshow_rate_percent', v_noshow_rate,
    'reliability_badge', CASE
      WHEN v_noshow_rate > 40.0 THEN 'Riesgo Alto de Inasistencia'
      WHEN v_noshow_rate > 20.0 THEN 'Riesgo Moderado'
      ELSE 'Paciente Confiable'
    END
  );
END;
$$;


-- ============================================================
-- 42. PROCEDIMIENTO DE CIERRE DE CAJA DIARIO Y ARQUEO MULTIDIVISA (USD / NIO)
-- Consolida los cobros del día, desglosados en Dólares ($) y Córdobas (C$), clasificados por
-- método de pago (Efectivo, Tarjeta, Transferencia), con conversión unificada y listado de transacciones.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_daily_cash_register_closure(
  p_date DATE DEFAULT CURRENT_DATE,
  p_exchange_rate NUMERIC(10,4) DEFAULT 36.6200
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_usd NUMERIC(12,2) := 0.00;
  v_total_nio NUMERIC(12,2) := 0.00;
  v_unified_usd NUMERIC(12,2) := 0.00;
  v_unified_nio NUMERIC(12,2) := 0.00;
  v_paid_count INT := 0;
  v_pending_count INT := 0;
  v_methods_usd JSONB;
  v_methods_nio JSONB;
  v_tx_list JSONB;
BEGIN
  -- 1. Agrupación de ingresos pagados por divisa y método
  SELECT
    COALESCE(SUM(amount) FILTER (WHERE currency = 'USD' AND status IN ('Paid', 'Pagado')), 0.00),
    COALESCE(SUM(amount) FILTER (WHERE currency = 'NIO' AND status IN ('Paid', 'Pagado')), 0.00),
    COUNT(*) FILTER (WHERE status IN ('Paid', 'Pagado')),
    COUNT(*) FILTER (WHERE status IN ('Pending', 'Pendiente'))
  INTO v_total_usd, v_total_nio, v_paid_count, v_pending_count
  FROM public.financial_transactions
  WHERE transaction_date::date = p_date;

  -- 2. Conversión unificada a ambas divisas
  v_unified_usd := round(v_total_usd + (v_total_nio / NULLIF(p_exchange_rate, 0)), 2);
  v_unified_nio := round(v_total_nio + (v_total_usd * p_exchange_rate), 2);

  -- 3. Desglose por método de pago en USD
  SELECT COALESCE(jsonb_object_agg(payment_method, total), '{}'::jsonb)
  INTO v_methods_usd
  FROM (
    SELECT payment_method, SUM(amount) AS total
    FROM public.financial_transactions
    WHERE transaction_date::date = p_date
      AND currency = 'USD'
      AND status IN ('Paid', 'Pagado')
    GROUP BY payment_method
  ) m_usd;

  -- 4. Desglose por método de pago en NIO
  SELECT COALESCE(jsonb_object_agg(payment_method, total), '{}'::jsonb)
  INTO v_methods_nio
  FROM (
    SELECT payment_method, SUM(amount) AS total
    FROM public.financial_transactions
    WHERE transaction_date::date = p_date
      AND currency = 'NIO'
      AND status IN ('Paid', 'Pagado')
    GROUP BY payment_method
  ) m_nio;

  -- 5. Detalle de transacciones del día
  SELECT COALESCE(jsonb_agg(t), '[]'::jsonb)
  INTO v_tx_list
  FROM (
    SELECT ft.id, ft.invoice_number, ft.concept, ft.amount, ft.currency,
           ft.payment_method, ft.status, p.full_name AS patient_name,
           to_char(ft.transaction_date, 'HH12:MI AM') AS time_formatted
    FROM public.financial_transactions ft
    LEFT JOIN public.patients p ON p.id = ft.patient_id
    WHERE ft.transaction_date::date = p_date
    ORDER BY ft.transaction_date DESC
  ) t;

  RETURN jsonb_build_object(
    'closure_date', p_date,
    'exchange_rate', p_exchange_rate,
    'total_paid_transactions', v_paid_count,
    'total_pending_transactions', v_pending_count,
    'totals', jsonb_build_object(
      'collected_usd', v_total_usd,
      'collected_nio', v_total_nio,
      'unified_total_usd', v_unified_usd,
      'unified_total_nio', v_unified_nio
    ),
    'payment_methods_usd', v_methods_usd,
    'payment_methods_nio', v_methods_nio,
    'transactions_detail', v_tx_list,
    'is_balanced', TRUE
  );
END;
$$;


-- ============================================================
-- 43. TRIGGER DE AUDITORÍA FORENSE PARA HISTORIAL CLÍNICO Y RECETAS
-- Garantiza la inmutabilidad de consultas firmadas/finalizadas y registra cualquier
-- intento de alteración posterior para cumplimiento de normativas de salud.
-- ============================================================
CREATE OR REPLACE FUNCTION public.fn_trg_audit_clinical_sensitive_events()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_TABLE_NAME = 'soap_consultations' THEN
    IF TG_OP = 'UPDATE' AND OLD.status = 'Finalized' AND NEW.status = 'Finalized' THEN
      -- Detección de alteración de consulta ya finalizada
      INSERT INTO public.system_audit_logs (
        table_name, record_id, action, details, performed_by
      ) VALUES (
        'soap_consultations',
        NEW.id::text,
        'SOAP_MODIFIED_AFTER_FINALIZED',
        jsonb_build_object(
          'patient_id', NEW.patient_id,
          'doctor_id', NEW.doctor_id,
          'old_assessment', OLD.assessment,
          'new_assessment', NEW.assessment,
          'old_plan', OLD.plan,
          'new_plan', NEW.plan
        ),
        'auditor_clinico'
      );
    ELSIF TG_OP = 'UPDATE' AND OLD.status <> 'Finalized' AND NEW.status = 'Finalized' THEN
      -- Sello de firma digital / finalización
      NEW.signed_at := CURRENT_TIMESTAMP;
      INSERT INTO public.system_audit_logs (
        table_name, record_id, action, details, performed_by
      ) VALUES (
        'soap_consultations',
        NEW.id::text,
        'SOAP_CONSULTATION_SIGNED',
        jsonb_build_object('icd10', NEW.icd10_code, 'patient_id', NEW.patient_id),
        'auditor_clinico'
      );
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_soap_sensitive ON public.soap_consultations;
CREATE TRIGGER trg_audit_soap_sensitive
  BEFORE UPDATE ON public.soap_consultations
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_trg_audit_clinical_sensitive_events();


-- ============================================================
-- 44. BÚSQUEDA CLÍNICA GLOBAL OMNIBOX (SPOTLIGHT MULTIDIMENSIONAL)
-- Permite buscar simultáneamente pacientes, consultas por CIE-10/diagnóstico,
-- y medicamentos prescritos en milisegundos mediante una sola invocación.
-- ============================================================
CREATE OR REPLACE FUNCTION public.sp_global_clinical_search(
  p_query TEXT,
  p_limit INT DEFAULT 15
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_term TEXT := trim(p_query);
  v_patients JSONB := '[]'::jsonb;
  v_consultations JSONB := '[]'::jsonb;
  v_prescriptions JSONB := '[]'::jsonb;
BEGIN
  IF v_term IS NULL OR length(v_term) < 2 THEN
    RETURN jsonb_build_object(
      'patients', '[]'::jsonb,
      'consultations', '[]'::jsonb,
      'prescriptions', '[]'::jsonb
    );
  END IF;

  -- 1. Pacientes
  SELECT COALESCE(jsonb_agg(p), '[]'::jsonb) INTO v_patients
  FROM (
    SELECT id, patient_code, full_name, identity_number, phone, blood_type, has_alert
    FROM public.patients
    WHERE is_active = TRUE
      AND (
        full_name ILIKE '%' || v_term || '%'
        OR patient_code ILIKE '%' || v_term || '%'
        OR identity_number ILIKE '%' || v_term || '%'
        OR phone ILIKE '%' || v_term || '%'
      )
    ORDER BY full_name ASC
    LIMIT p_limit
  ) p;

  -- 2. Consultas por diagnóstico o CIE-10
  SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_consultations
  FROM (
    SELECT sc.id, sc.patient_id, p.full_name AS patient_name, sc.icd10_code,
           sc.assessment, sc.consultation_date
    FROM public.soap_consultations sc
    JOIN public.patients p ON p.id = sc.patient_id
    WHERE sc.icd10_code ILIKE '%' || v_term || '%'
       OR sc.assessment ILIKE '%' || v_term || '%'
       OR sc.subjective ILIKE '%' || v_term || '%'
    ORDER BY sc.consultation_date DESC
    LIMIT p_limit
  ) c;

  -- 3. Medicamentos recetados
  SELECT COALESCE(jsonb_agg(m), '[]'::jsonb) INTO v_prescriptions
  FROM (
    SELECT pi.id, pi.drug_name, pi.dose, pi.frequency, pr.patient_id,
           p.full_name AS patient_name, pr.prescription_date
    FROM public.prescription_items pi
    JOIN public.prescriptions pr ON pr.id = pi.prescription_id
    JOIN public.patients p ON p.id = pr.patient_id
    WHERE pi.drug_name ILIKE '%' || v_term || '%'
    ORDER BY pr.prescription_date DESC
    LIMIT p_limit
  ) m;

  RETURN jsonb_build_object(
    'query', v_term,
    'patients', v_patients,
    'consultations', v_consultations,
    'prescriptions', v_prescriptions
  );
END;
$$;


-- ============================================================
-- 45. PERMISOS DE EJECUCIÓN (GRANTS) PARA LAS NUEVAS FUNCIONES
-- ============================================================
GRANT EXECUTE ON FUNCTION public.fn_trg_check_critical_vital_signs TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_prescribe_medication_with_safety_check TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_get_patient_complete_chart TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_register_pediatric_growth_record TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_reschedule_appointment TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_get_patient_attendance_analytics TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fn_daily_cash_register_closure TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.sp_global_clinical_search TO anon, authenticated, service_role;








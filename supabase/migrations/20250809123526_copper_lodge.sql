/*
  # Create Missing Database Functions

  1. Functions Created
    - `get_available_times` - Returns available time slots for a barber on a specific date
    - `create_appointment_automated` - Creates appointments with automatic client creation
    - `search_appointments` - Advanced search for appointments
    - `get_barber_schedule` - Gets barber's schedule for a specific date
    - `create_or_get_client` - Creates or retrieves existing client

  2. Logic
    - Generate time slots from 8:00 to 18:00 in 30-minute intervals
    - Check for conflicts with existing appointments
    - Consider service duration when checking availability
    - Return time slots with availability status
*/

-- Function to get available times for a barber on a specific date
CREATE OR REPLACE FUNCTION get_available_times(
    p_barber_id INTEGER,
    p_date TEXT,
    p_duration_minutes INTEGER DEFAULT 30
)
RETURNS TABLE(time_slot TEXT, available BOOLEAN)
LANGUAGE plpgsql
AS $$
DECLARE
    slot_time TIME;
    slot_datetime TIMESTAMP;
    conflict_count INTEGER;
    end_time TIME;
BEGIN
    -- Generate time slots from 8:00 to 18:00 in 30-minute intervals
    FOR slot_time IN 
        SELECT generate_series('08:00'::TIME, '18:00'::TIME, '30 minutes'::INTERVAL)::TIME
    LOOP
        -- Calculate end time for this slot
        end_time := slot_time + (p_duration_minutes || ' minutes')::INTERVAL;
        
        -- Skip if end time goes beyond business hours (18:30)
        IF end_time > '18:30'::TIME THEN
            CONTINUE;
        END IF;
        
        -- Convert to full datetime
        slot_datetime := (p_date::DATE + slot_time::TIME);
        
        -- Check for conflicts with existing appointments
        SELECT COUNT(*)
        INTO conflict_count
        FROM appointments a
        WHERE a.barber_id = p_barber_id
          AND a.appointment_date = p_date::DATE
          AND a.status IN ('scheduled', 'confirmed')
          AND (
            -- New appointment starts during existing appointment
            (slot_time >= a.appointment_time AND slot_time < (a.appointment_time + INTERVAL '1 minute' * (
                SELECT COALESCE(SUM(s.duration_minutes), 30)
                FROM services s
                WHERE s.id = ANY(a.services_ids)
            )))
            OR
            -- New appointment ends during existing appointment
            (end_time > a.appointment_time AND end_time <= (a.appointment_time + INTERVAL '1 minute' * (
                SELECT COALESCE(SUM(s.duration_minutes), 30)
                FROM services s
                WHERE s.id = ANY(a.services_ids)
            )))
            OR
            -- New appointment completely contains existing appointment
            (slot_time <= a.appointment_time AND end_time >= (a.appointment_time + INTERVAL '1 minute' * (
                SELECT COALESCE(SUM(s.duration_minutes), 30)
                FROM services s
                WHERE s.id = ANY(a.services_ids)
            )))
          );
        
        -- Return the time slot with availability
        RETURN NEXT (slot_time::TEXT, conflict_count = 0);
    END LOOP;
END;
$$;

-- Function to create appointment with automatic client creation
CREATE OR REPLACE FUNCTION create_appointment_automated(
    p_client_name TEXT,
    p_client_phone TEXT,
    p_client_email TEXT DEFAULT NULL,
    p_barber_id INTEGER,
    p_appointment_datetime TIMESTAMP,
    p_service_ids INTEGER[],
    p_note TEXT DEFAULT NULL,
    p_auto_create_client BOOLEAN DEFAULT TRUE
)
RETURNS JSON
LANGUAGE plpgsql
AS $$
DECLARE
    v_client_id INTEGER;
    v_appointment_id INTEGER;
    v_total_price NUMERIC := 0;
    v_total_duration INTEGER := 0;
    v_service_id INTEGER;
    v_service_price NUMERIC;
    v_service_duration INTEGER;
    v_barber_commission NUMERIC;
    v_is_chemical BOOLEAN;
BEGIN
    -- Get or create client
    IF p_auto_create_client THEN
        -- Try to find existing client by phone
        SELECT id INTO v_client_id
        FROM clients
        WHERE phone = p_client_phone
        LIMIT 1;
        
        -- Create client if not found
        IF v_client_id IS NULL THEN
            INSERT INTO clients (name, phone, email)
            VALUES (p_client_name, p_client_phone, p_client_email)
            RETURNING id INTO v_client_id;
        END IF;
    ELSE
        -- Must provide existing client
        SELECT id INTO v_client_id
        FROM clients
        WHERE phone = p_client_phone
        LIMIT 1;
        
        IF v_client_id IS NULL THEN
            RETURN json_build_object(
                'success', false,
                'message', 'Cliente não encontrado'
            );
        END IF;
    END IF;
    
    -- Calculate total price and duration
    FOREACH v_service_id IN ARRAY p_service_ids
    LOOP
        SELECT price, duration_minutes, is_chemical
        INTO v_service_price, v_service_duration, v_is_chemical
        FROM services
        WHERE id = v_service_id;
        
        IF v_service_price IS NULL THEN
            RETURN json_build_object(
                'success', false,
                'message', 'Serviço não encontrado: ' || v_service_id
            );
        END IF;
        
        v_total_price := v_total_price + v_service_price;
        v_total_duration := v_total_duration + v_service_duration;
    END LOOP;
    
    -- Check for scheduling conflicts
    IF EXISTS (
        SELECT 1
        FROM appointments a
        WHERE a.barber_id = p_barber_id
          AND a.appointment_date = p_appointment_datetime::DATE
          AND a.status IN ('scheduled', 'confirmed')
          AND (
            (p_appointment_datetime::TIME >= a.appointment_time 
             AND p_appointment_datetime::TIME < (a.appointment_time + INTERVAL '1 minute' * (
                SELECT COALESCE(SUM(s.duration_minutes), 30)
                FROM services s
                WHERE s.id = ANY(a.services_ids)
             )))
            OR
            ((p_appointment_datetime::TIME + INTERVAL '1 minute' * v_total_duration) > a.appointment_time 
             AND (p_appointment_datetime::TIME + INTERVAL '1 minute' * v_total_duration) <= (a.appointment_time + INTERVAL '1 minute' * (
                SELECT COALESCE(SUM(s.duration_minutes), 30)
                FROM services s
                WHERE s.id = ANY(a.services_ids)
             )))
          )
    ) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Horário não disponível - conflito com outro agendamento'
        );
    END IF;
    
    -- Create appointment
    INSERT INTO appointments (
        client_id,
        barber_id,
        appointment_date,
        appointment_time,
        services_ids,
        total_price,
        note,
        status
    )
    VALUES (
        v_client_id,
        p_barber_id,
        p_appointment_datetime::DATE,
        p_appointment_datetime::TIME,
        p_service_ids,
        v_total_price,
        p_note,
        'scheduled'
    )
    RETURNING id INTO v_appointment_id;
    
    -- Create appointment_services records
    FOREACH v_service_id IN ARRAY p_service_ids
    LOOP
        SELECT price, is_chemical INTO v_service_price, v_is_chemical
        FROM services
        WHERE id = v_service_id;
        
        -- Get barber commission rate
        SELECT 
            CASE 
                WHEN v_is_chemical THEN commission_rate_chemical_service
                ELSE commission_rate_service
            END
        INTO v_barber_commission
        FROM barbers
        WHERE id = p_barber_id;
        
        INSERT INTO appointment_services (
            appointment_id,
            service_id,
            price_at_booking,
            commission_rate_applied
        )
        VALUES (
            v_appointment_id,
            v_service_id,
            v_service_price,
            v_barber_commission
        );
    END LOOP;
    
    RETURN json_build_object(
        'success', true,
        'appointment_id', v_appointment_id,
        'client_id', v_client_id,
        'total_price', v_total_price,
        'duration_minutes', v_total_duration,
        'message', 'Agendamento criado com sucesso'
    );
END;
$$;

-- Function to search appointments with multiple filters
CREATE OR REPLACE FUNCTION search_appointments(
    p_start_date TEXT DEFAULT NULL,
    p_end_date TEXT DEFAULT NULL,
    p_client_name TEXT DEFAULT NULL,
    p_client_phone TEXT DEFAULT NULL,
    p_barber_name TEXT DEFAULT NULL,
    p_service_name TEXT DEFAULT NULL,
    p_status TEXT DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE(
    id INTEGER,
    client_id INTEGER,
    barber_id INTEGER,
    client_name TEXT,
    client_phone TEXT,
    barber_name TEXT,
    services_names TEXT,
    services_ids INTEGER[],
    appointment_date DATE,
    appointment_time TIME,
    appointment_datetime TIMESTAMP,
    status TEXT,
    total_price NUMERIC,
    note TEXT,
    payment_method TEXT,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.client_id,
        a.barber_id,
        a.client_name::TEXT,
        a.client_phone::TEXT,
        a.barber_name::TEXT,
        a.services_names::TEXT,
        a.services_ids,
        a.appointment_date,
        a.appointment_time,
        a.appointment_datetime,
        a.status::TEXT,
        a.total_price,
        a.note::TEXT,
        a.payment_method::TEXT,
        a.created_at,
        a.updated_at
    FROM appointments a
    WHERE (p_start_date IS NULL OR a.appointment_date >= p_start_date::DATE)
      AND (p_end_date IS NULL OR a.appointment_date <= p_end_date::DATE)
      AND (p_client_name IS NULL OR a.client_name ILIKE '%' || p_client_name || '%')
      AND (p_client_phone IS NULL OR a.client_phone ILIKE '%' || p_client_phone || '%')
      AND (p_barber_name IS NULL OR a.barber_name ILIKE '%' || p_barber_name || '%')
      AND (p_service_name IS NULL OR a.services_names ILIKE '%' || p_service_name || '%')
      AND (p_status IS NULL OR a.status::TEXT = p_status)
    ORDER BY a.appointment_datetime DESC
    LIMIT p_limit;
END;
$$;

-- Function to get barber schedule for a specific date
CREATE OR REPLACE FUNCTION get_barber_schedule(
    p_barber_id INTEGER,
    p_date TEXT
)
RETURNS TABLE(
    id INTEGER,
    client_name TEXT,
    client_phone TEXT,
    services_names TEXT,
    appointment_time TIME,
    appointment_datetime TIMESTAMP,
    status TEXT,
    total_price NUMERIC,
    note TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.client_name::TEXT,
        a.client_phone::TEXT,
        a.services_names::TEXT,
        a.appointment_time,
        a.appointment_datetime,
        a.status::TEXT,
        a.total_price,
        a.note::TEXT
    FROM appointments a
    WHERE a.barber_id = p_barber_id
      AND a.appointment_date = p_date::DATE
      AND a.status IN ('scheduled', 'confirmed', 'completed')
    ORDER BY a.appointment_time;
END;
$$;

-- Function to create or get existing client
CREATE OR REPLACE FUNCTION create_or_get_client(
    p_name TEXT,
    p_phone TEXT,
    p_email TEXT DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_client_id INTEGER;
BEGIN
    -- Try to find existing client by phone
    SELECT id INTO v_client_id
    FROM clients
    WHERE phone = p_phone
    LIMIT 1;
    
    -- Create client if not found
    IF v_client_id IS NULL THEN
        INSERT INTO clients (name, phone, email)
        VALUES (p_name, p_phone, p_email)
        RETURNING id INTO v_client_id;
    END IF;
    
    RETURN v_client_id;
END;
$$;
/*
  # Funções Avançadas para Sistema de Agendamento

  1. Funções Automatizadas
    - `create_appointment_automated` - Cria agendamento completo automaticamente
    - `create_or_get_client` - Cria ou obtém cliente existente
    - `search_appointments` - Busca flexível com múltiplos filtros
    - `get_barber_schedule` - Agenda completa do barbeiro

  2. Views Otimizadas
    - `v_dashboard_stats` - Estatísticas do dashboard
    - `v_appointments_full` - Agendamentos com todas as informações

  3. Índices de Performance
    - Otimização para buscas rápidas
*/

-- Função para criar ou obter cliente
CREATE OR REPLACE FUNCTION create_or_get_client(
    p_name VARCHAR(255),
    p_phone VARCHAR(20),
    p_email VARCHAR(255) DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_client_id INTEGER;
BEGIN
    -- Tentar encontrar cliente existente por telefone
    SELECT id INTO v_client_id
    FROM clients
    WHERE phone = p_phone
    LIMIT 1;
    
    -- Se não encontrou, criar novo cliente
    IF v_client_id IS NULL THEN
        INSERT INTO clients (name, phone, email)
        VALUES (p_name, p_phone, p_email)
        RETURNING id INTO v_client_id;
    END IF;
    
    RETURN v_client_id;
END;
$$;

-- Função para criar agendamento automatizado
CREATE OR REPLACE FUNCTION create_appointment_automated(
    p_client_name VARCHAR(255),
    p_client_phone VARCHAR(20),
    p_client_email VARCHAR(255) DEFAULT NULL,
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
    v_total_price NUMERIC(10,2) := 0;
    v_duration_minutes INTEGER := 0;
    v_service_id INTEGER;
    v_service_price NUMERIC(10,2);
    v_service_duration INTEGER;
    v_barber_commission_service NUMERIC(5,2);
    v_barber_commission_chemical NUMERIC(5,2);
    v_is_chemical BOOLEAN;
    v_commission_rate NUMERIC(5,2);
BEGIN
    -- Validar barbeiro existe
    IF NOT EXISTS (SELECT 1 FROM barbers WHERE id = p_barber_id) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Barbeiro não encontrado'
        );
    END IF;
    
    -- Validar horário não está ocupado
    IF EXISTS (
        SELECT 1 FROM appointments 
        WHERE barber_id = p_barber_id 
        AND appointment_datetime = p_appointment_datetime
        AND status IN ('scheduled')
    ) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Horário já está ocupado'
        );
    END IF;
    
    -- Criar ou obter cliente
    IF p_auto_create_client THEN
        v_client_id := create_or_get_client(p_client_name, p_client_phone, p_client_email);
    ELSE
        SELECT id INTO v_client_id FROM clients WHERE phone = p_client_phone;
        IF v_client_id IS NULL THEN
            RETURN json_build_object(
                'success', false,
                'message', 'Cliente não encontrado'
            );
        END IF;
    END IF;
    
    -- Calcular preço total e duração
    FOREACH v_service_id IN ARRAY p_service_ids
    LOOP
        SELECT price, duration_minutes, is_chemical 
        INTO v_service_price, v_service_duration, v_is_chemical
        FROM services 
        WHERE id = v_service_id;
        
        IF v_service_price IS NULL THEN
            RETURN json_build_object(
                'success', false,
                'message', 'Serviço ID ' || v_service_id || ' não encontrado'
            );
        END IF;
        
        v_total_price := v_total_price + v_service_price;
        v_duration_minutes := v_duration_minutes + v_service_duration;
    END LOOP;
    
    -- Obter taxas de comissão do barbeiro
    SELECT commission_rate_service, commission_rate_chemical_service
    INTO v_barber_commission_service, v_barber_commission_chemical
    FROM barbers
    WHERE id = p_barber_id;
    
    -- Criar agendamento
    INSERT INTO appointments (
        client_id,
        barber_id,
        appointment_date,
        appointment_time,
        appointment_datetime,
        services_ids,
        total_price,
        note,
        status
    ) VALUES (
        v_client_id,
        p_barber_id,
        p_appointment_datetime::DATE,
        p_appointment_datetime::TIME,
        p_appointment_datetime,
        p_service_ids,
        v_total_price,
        p_note,
        'scheduled'
    ) RETURNING id INTO v_appointment_id;
    
    -- Inserir serviços do agendamento
    FOREACH v_service_id IN ARRAY p_service_ids
    LOOP
        SELECT price, is_chemical INTO v_service_price, v_is_chemical
        FROM services WHERE id = v_service_id;
        
        -- Determinar taxa de comissão
        v_commission_rate := CASE 
            WHEN v_is_chemical THEN v_barber_commission_chemical
            ELSE v_barber_commission_service
        END;
        
        INSERT INTO appointment_services (
            appointment_id,
            service_id,
            price_at_booking,
            commission_rate_applied
        ) VALUES (
            v_appointment_id,
            v_service_id,
            v_service_price,
            v_commission_rate
        );
    END LOOP;
    
    RETURN json_build_object(
        'success', true,
        'appointment_id', v_appointment_id,
        'client_id', v_client_id,
        'total_price', v_total_price,
        'duration_minutes', v_duration_minutes,
        'message', 'Agendamento criado com sucesso'
    );
END;
$$;

-- Função para busca avançada de agendamentos
CREATE OR REPLACE FUNCTION search_appointments(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_client_name VARCHAR(255) DEFAULT NULL,
    p_client_phone VARCHAR(20) DEFAULT NULL,
    p_barber_name VARCHAR(255) DEFAULT NULL,
    p_service_name VARCHAR(255) DEFAULT NULL,
    p_status appointment_status_enum DEFAULT NULL,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    id INTEGER,
    client_id INTEGER,
    client_name VARCHAR(255),
    client_phone VARCHAR(20),
    barber_id INTEGER,
    barber_name VARCHAR(255),
    appointment_date DATE,
    appointment_time TIME,
    appointment_datetime TIMESTAMP,
    services_names TEXT,
    services_ids INTEGER[],
    status appointment_status_enum,
    total_price NUMERIC(10,2),
    note TEXT,
    payment_method payment_method_enum,
    created_at TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        a.id,
        a.client_id,
        a.client_name,
        a.client_phone,
        a.barber_id,
        a.barber_name,
        a.appointment_date,
        a.appointment_time,
        a.appointment_datetime,
        a.services_names,
        a.services_ids,
        a.status,
        a.total_price,
        a.note,
        a.payment_method,
        a.created_at
    FROM appointments a
    WHERE 
        (p_start_date IS NULL OR a.appointment_date >= p_start_date)
        AND (p_end_date IS NULL OR a.appointment_date <= p_end_date)
        AND (p_client_name IS NULL OR a.client_name ILIKE '%' || p_client_name || '%')
        AND (p_client_phone IS NULL OR a.client_phone ILIKE '%' || p_client_phone || '%')
        AND (p_barber_name IS NULL OR a.barber_name ILIKE '%' || p_barber_name || '%')
        AND (p_service_name IS NULL OR a.services_names ILIKE '%' || p_service_name || '%')
        AND (p_status IS NULL OR a.status = p_status)
    ORDER BY a.appointment_datetime DESC
    LIMIT p_limit;
END;
$$;

-- Função para obter agenda do barbeiro
CREATE OR REPLACE FUNCTION get_barber_schedule(
    p_barber_id INTEGER,
    p_date DATE
)
RETURNS TABLE (
    time_slot TIME,
    is_available BOOLEAN,
    appointment_id INTEGER,
    client_name VARCHAR(255),
    services_names TEXT,
    total_price NUMERIC(10,2),
    status appointment_status_enum
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_time_slot TIME;
BEGIN
    -- Gerar horários de 8h às 18h (intervalos de 30 min)
    FOR v_time_slot IN 
        SELECT generate_series('08:00'::TIME, '18:00'::TIME, '30 minutes'::INTERVAL)::TIME
    LOOP
        RETURN QUERY
        SELECT 
            v_time_slot,
            CASE WHEN a.id IS NULL THEN TRUE ELSE FALSE END as is_available,
            a.id,
            a.client_name,
            a.services_names,
            a.total_price,
            a.status
        FROM (SELECT v_time_slot) t
        LEFT JOIN appointments a ON 
            a.barber_id = p_barber_id 
            AND a.appointment_date = p_date 
            AND a.appointment_time = v_time_slot
            AND a.status IN ('scheduled', 'confirmed');
    END LOOP;
END;
$$;

-- View para estatísticas do dashboard
CREATE OR REPLACE VIEW v_dashboard_stats AS
SELECT 
    -- Estatísticas de hoje
    (SELECT COUNT(*) FROM appointments WHERE appointment_date = CURRENT_DATE) as appointments_today,
    (SELECT COUNT(*) FROM appointments WHERE appointment_date = CURRENT_DATE AND status = 'scheduled') as scheduled_today,
    (SELECT COUNT(*) FROM appointments WHERE appointment_date = CURRENT_DATE AND status = 'completed') as completed_today,
    (SELECT COALESCE(SUM(total_price), 0) FROM appointments WHERE appointment_date = CURRENT_DATE AND status = 'completed') as revenue_today,
    
    -- Estatísticas do mês
    (SELECT COUNT(*) FROM appointments WHERE DATE_TRUNC('month', appointment_date) = DATE_TRUNC('month', CURRENT_DATE)) as appointments_month,
    (SELECT COALESCE(SUM(total_price), 0) FROM appointments WHERE DATE_TRUNC('month', appointment_date) = DATE_TRUNC('month', CURRENT_DATE) AND status = 'completed') as revenue_month,
    
    -- Estatísticas gerais
    (SELECT COUNT(*) FROM clients) as total_clients,
    (SELECT COUNT(*) FROM barbers WHERE id IN (SELECT DISTINCT user_id FROM barbers)) as active_barbers;

-- View completa de agendamentos
CREATE OR REPLACE VIEW v_appointments_full AS
SELECT 
    a.*,
    c.email as client_email,
    b.phone as barber_phone,
    b.email as barber_email,
    -- Calcular duração total dos serviços
    (SELECT SUM(s.duration_minutes) 
     FROM services s 
     WHERE s.id = ANY(a.services_ids)) as total_duration_minutes,
    -- Status formatado
    CASE a.status
        WHEN 'scheduled' THEN 'Agendado'
        WHEN 'confirmed' THEN 'Confirmado'
        WHEN 'completed' THEN 'Concluído'
        WHEN 'cancelled' THEN 'Cancelado'
        WHEN 'no_show' THEN 'Não Compareceu'
    END as status_formatted,
    -- Método de pagamento formatado
    CASE a.payment_method
        WHEN 'money' THEN 'Dinheiro'
        WHEN 'pix' THEN 'PIX'
        WHEN 'credit_card' THEN 'Cartão de Crédito'
        WHEN 'debit_card' THEN 'Cartão de Débito'
    END as payment_method_formatted
FROM appointments a
LEFT JOIN clients c ON a.client_id = c.id
LEFT JOIN barbers b ON a.barber_id = b.id;

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_appointments_search_client_name 
ON appointments USING gin(to_tsvector('portuguese', client_name));

CREATE INDEX IF NOT EXISTS idx_appointments_search_client_phone_pattern 
ON appointments (client_phone varchar_pattern_ops);

CREATE INDEX IF NOT EXISTS idx_appointments_search_barber_name_pattern 
ON appointments (barber_name varchar_pattern_ops);

CREATE INDEX IF NOT EXISTS idx_appointments_search_services_names 
ON appointments USING gin(to_tsvector('portuguese', services_names));

-- Função para obter horários disponíveis
CREATE OR REPLACE FUNCTION get_available_times(
    p_barber_id INTEGER,
    p_date DATE,
    p_duration_minutes INTEGER DEFAULT 30
)
RETURNS TABLE (
    time_slot TIME,
    available BOOLEAN
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_time_slot TIME;
    v_end_time TIME;
BEGIN
    -- Gerar horários de 8h às 18h
    FOR v_time_slot IN 
        SELECT generate_series('08:00'::TIME, '17:30'::TIME, '30 minutes'::INTERVAL)::TIME
    LOOP
        v_end_time := v_time_slot + (p_duration_minutes || ' minutes')::INTERVAL;
        
        RETURN QUERY
        SELECT 
            v_time_slot,
            NOT EXISTS (
                SELECT 1 FROM appointments 
                WHERE barber_id = p_barber_id 
                AND appointment_date = p_date
                AND status IN ('scheduled')
                AND (
                    (appointment_time <= v_time_slot AND appointment_time + INTERVAL '30 minutes' > v_time_slot)
                    OR (appointment_time < v_end_time AND appointment_time >= v_time_slot)
                )
            ) as available;
    END LOOP;
END;
$$;
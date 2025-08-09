/*
  # Atualizar função para intervalos dinâmicos baseados nos serviços

  1. Modificações
    - get_available_times agora usa a duração real dos serviços selecionados
    - Intervalos são calculados dinamicamente baseados nos serviços
    - Considera múltiplos serviços e suas durações individuais
    
  2. Lógica
    - Calcula duração total dos serviços selecionados
    - Gera slots baseados na menor duração de serviço (para flexibilidade)
    - Verifica se há tempo suficiente para todos os serviços
*/

-- Função atualizada para intervalos dinâmicos
CREATE OR REPLACE FUNCTION get_available_times(
    p_barber_id INTEGER,
    p_date DATE,
    p_service_ids INTEGER[] DEFAULT NULL
)
RETURNS TABLE(
    time_slot TIME,
    available BOOLEAN,
    duration_minutes INTEGER
) AS $$
DECLARE
    current_time TIME;
    end_time TIME;
    total_duration INTEGER := 30; -- Padrão se não houver serviços
    min_interval INTEGER := 15; -- Intervalo mínimo entre slots
    slot_duration INTEGER;
    is_available BOOLEAN;
    appointment_end TIME;
BEGIN
    -- Se serviços foram fornecidos, calcular duração total
    IF p_service_ids IS NOT NULL AND array_length(p_service_ids, 1) > 0 THEN
        SELECT COALESCE(SUM(duration_minutes), 30)
        INTO total_duration
        FROM services 
        WHERE id = ANY(p_service_ids);
        
        -- Usar o menor intervalo dos serviços para flexibilidade
        SELECT COALESCE(MIN(duration_minutes), 15)
        INTO min_interval
        FROM services 
        WHERE id = ANY(p_service_ids);
        
        -- Limitar intervalo mínimo a 15 minutos
        min_interval := GREATEST(min_interval, 15);
    END IF;

    -- Definir horários de funcionamento
    IF EXTRACT(DOW FROM p_date) = 0 THEN -- Domingo
        RETURN; -- Fechado aos domingos
    ELSE
        current_time := '08:00:00'::TIME;
        end_time := '21:00:00'::TIME;
    END IF;

    -- Gerar slots de tempo
    WHILE current_time + (total_duration || ' minutes')::INTERVAL <= end_time LOOP
        is_available := TRUE;
        appointment_end := current_time + (total_duration || ' minutes')::INTERVAL;

        -- Verificar conflitos com agendamentos existentes
        IF EXISTS (
            SELECT 1 
            FROM appointments a
            WHERE a.barber_id = p_barber_id
            AND a.appointment_date = p_date
            AND a.status IN ('scheduled', 'confirmed')
            AND (
                -- Novo agendamento começa durante um existente
                (current_time >= a.appointment_time AND current_time < a.appointment_time + (
                    SELECT COALESCE(SUM(s.duration_minutes), 30) || ' minutes'
                    FROM appointment_services aps
                    JOIN services s ON s.id = aps.service_id
                    WHERE aps.appointment_id = a.id
                )::INTERVAL)
                OR
                -- Novo agendamento termina durante um existente
                (appointment_end > a.appointment_time AND appointment_end <= a.appointment_time + (
                    SELECT COALESCE(SUM(s.duration_minutes), 30) || ' minutes'
                    FROM appointment_services aps
                    JOIN services s ON s.id = aps.service_id
                    WHERE aps.appointment_id = a.id
                )::INTERVAL)
                OR
                -- Novo agendamento engloba um existente
                (current_time <= a.appointment_time AND appointment_end >= a.appointment_time + (
                    SELECT COALESCE(SUM(s.duration_minutes), 30) || ' minutes'
                    FROM appointment_services aps
                    JOIN services s ON s.id = aps.service_id
                    WHERE aps.appointment_id = a.id
                )::INTERVAL)
            )
        ) THEN
            is_available := FALSE;
        END IF;

        -- Retornar o slot
        time_slot := current_time;
        available := is_available;
        duration_minutes := total_duration;
        RETURN NEXT;

        -- Avançar para o próximo slot baseado no intervalo mínimo
        current_time := current_time + (min_interval || ' minutes')::INTERVAL;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;
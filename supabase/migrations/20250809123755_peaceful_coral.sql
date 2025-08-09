/*
  # Atualizar horários de funcionamento

  1. Alterações
    - Segunda a sábado: 8h às 21h
    - Domingo: fechado
    - Intervalos de 30 em 30 minutos
    - Considera duração dos serviços para evitar conflitos

  2. Funcionalidade
    - Gera slots de horários disponíveis
    - Verifica conflitos com agendamentos existentes
    - Respeita duração total dos serviços selecionados
*/

-- Atualizar função get_available_times com novos horários
CREATE OR REPLACE FUNCTION get_available_times(
    p_barber_id INTEGER,
    p_date DATE,
    p_duration_minutes INTEGER DEFAULT 30
)
RETURNS TABLE(time_slot TIME, available BOOLEAN) AS $$
DECLARE
    current_time TIME;
    end_time TIME;
    day_of_week INTEGER;
    slot_end_time TIME;
BEGIN
    -- Obter dia da semana (0 = domingo, 1 = segunda, ..., 6 = sábado)
    day_of_week := EXTRACT(DOW FROM p_date);
    
    -- Verificar se é domingo (fechado)
    IF day_of_week = 0 THEN
        RETURN;
    END IF;
    
    -- Definir horários de funcionamento
    -- Segunda a sábado: 8h às 21h
    current_time := '08:00:00'::TIME;
    end_time := '21:00:00'::TIME;
    
    -- Gerar slots de 30 em 30 minutos
    WHILE current_time < end_time LOOP
        -- Calcular horário de fim do slot considerando a duração do serviço
        slot_end_time := current_time + (p_duration_minutes || ' minutes')::INTERVAL;
        
        -- Verificar se o slot cabe no horário de funcionamento
        IF slot_end_time <= end_time THEN
            -- Verificar se há conflito com agendamentos existentes
            IF NOT EXISTS (
                SELECT 1 
                FROM appointments 
                WHERE barber_id = p_barber_id 
                AND appointment_date = p_date
                AND status IN ('scheduled', 'confirmed')
                AND (
                    -- Verifica sobreposição de horários
                    (appointment_time <= current_time AND (appointment_time + (
                        SELECT COALESCE(SUM(duration_minutes), 30) 
                        FROM services s 
                        JOIN appointment_services aps ON s.id = aps.service_id 
                        WHERE aps.appointment_id = appointments.id
                    ) || ' minutes')::INTERVAL) > current_time)
                    OR
                    (appointment_time < slot_end_time AND appointment_time >= current_time)
                )
            ) THEN
                -- Slot disponível
                RETURN QUERY SELECT current_time, true;
            ELSE
                -- Slot ocupado
                RETURN QUERY SELECT current_time, false;
            END IF;
        END IF;
        
        -- Próximo slot (30 minutos depois)
        current_time := current_time + INTERVAL '30 minutes';
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;
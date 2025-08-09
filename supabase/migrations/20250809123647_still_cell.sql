/*
  # Corrigir função get_available_times

  1. Função Atualizada
    - Corrige a lógica de geração de horários
    - Melhora a verificação de conflitos
    - Adiciona horários de funcionamento padrão
    - Retorna formato correto para o frontend

  2. Melhorias
    - Horários de 8h às 18h (seg-sex) e 8h às 16h (sáb)
    - Intervalos de 30 minutos
    - Verificação de conflitos com agendamentos existentes
    - Considera duração total dos serviços
*/

-- Remove função existente se houver
DROP FUNCTION IF EXISTS get_available_times(INTEGER, DATE, INTEGER);

-- Cria função corrigida para buscar horários disponíveis
CREATE OR REPLACE FUNCTION get_available_times(
    p_barber_id INTEGER,
    p_date DATE,
    p_duration_minutes INTEGER DEFAULT 30
)
RETURNS TABLE(
    time_slot TIME,
    available BOOLEAN
) AS $$
DECLARE
    start_hour INTEGER;
    end_hour INTEGER;
    current_time TIME;
    slot_end_time TIME;
    conflict_count INTEGER;
    day_of_week INTEGER;
BEGIN
    -- Determinar dia da semana (0 = domingo, 1 = segunda, etc.)
    day_of_week := EXTRACT(DOW FROM p_date);
    
    -- Definir horários de funcionamento
    IF day_of_week = 0 THEN -- Domingo - fechado
        RETURN;
    ELSIF day_of_week = 6 THEN -- Sábado
        start_hour := 8;
        end_hour := 16;
    ELSE -- Segunda a sexta
        start_hour := 8;
        end_hour := 18;
    END IF;
    
    -- Gerar slots de 30 em 30 minutos
    current_time := (start_hour || ':00:00')::TIME;
    
    WHILE current_time < (end_hour || ':00:00')::TIME LOOP
        -- Calcular horário de fim do slot considerando a duração
        slot_end_time := current_time + (p_duration_minutes || ' minutes')::INTERVAL;
        
        -- Verificar se o slot não ultrapassa o horário de funcionamento
        IF slot_end_time <= (end_hour || ':00:00')::TIME THEN
            -- Verificar conflitos com agendamentos existentes
            SELECT COUNT(*)
            INTO conflict_count
            FROM appointments
            WHERE barber_id = p_barber_id
              AND appointment_date = p_date
              AND status IN ('scheduled', 'confirmed')
              AND (
                  -- Novo agendamento começa durante um existente
                  (current_time >= appointment_time AND current_time < appointment_time + (
                      SELECT COALESCE(SUM(duration_minutes), 30)
                      FROM services s
                      JOIN appointment_services aps ON s.id = aps.service_id
                      WHERE aps.appointment_id = appointments.id
                  ) * INTERVAL '1 minute')
                  OR
                  -- Novo agendamento termina durante um existente
                  (slot_end_time > appointment_time AND slot_end_time <= appointment_time + (
                      SELECT COALESCE(SUM(duration_minutes), 30)
                      FROM services s
                      JOIN appointment_services aps ON s.id = aps.service_id
                      WHERE aps.appointment_id = appointments.id
                  ) * INTERVAL '1 minute')
                  OR
                  -- Novo agendamento engloba um existente
                  (current_time <= appointment_time AND slot_end_time >= appointment_time + (
                      SELECT COALESCE(SUM(duration_minutes), 30)
                      FROM services s
                      JOIN appointment_services aps ON s.id = aps.service_id
                      WHERE aps.appointment_id = appointments.id
                  ) * INTERVAL '1 minute')
              );
            
            -- Retornar o slot
            time_slot := current_time;
            available := (conflict_count = 0);
            RETURN NEXT;
        END IF;
        
        -- Próximo slot (30 minutos depois)
        current_time := current_time + INTERVAL '30 minutes';
    END LOOP;
    
    RETURN;
END;
$$ LANGUAGE plpgsql;
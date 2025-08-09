/*
  # Improve time slot availability logic

  1. Enhanced Features
    - Better conflict detection considering service durations
    - Prevents overlapping appointments
    - Calculates exact time windows based on service durations
    - Considers existing appointment durations when checking conflicts

  2. Logic Improvements
    - Checks if new appointment would start during existing appointment
    - Checks if new appointment would end during existing appointment  
    - Checks if new appointment would completely overlap existing appointment
    - Considers the total duration of services in existing appointments
*/

-- Improved get_available_times function with proper conflict detection
CREATE OR REPLACE FUNCTION get_available_times(
    p_barber_id integer,
    p_date text,
    p_service_ids integer[]
)
RETURNS TABLE(
    time_slot text,
    available boolean,
    duration_minutes integer
) 
LANGUAGE plpgsql
AS $$
DECLARE
    slot_time time;
    total_duration integer := 0;
    min_interval integer := 15;
    slot_end_time time;
    day_of_week integer;
    is_available boolean;
    existing_appointment_duration integer;
    existing_start_time time;
    existing_end_time time;
BEGIN
    -- Calculate total duration of selected services
    SELECT COALESCE(SUM(s.duration_minutes), 30)
    INTO total_duration
    FROM services s
    WHERE s.id = ANY(p_service_ids);
    
    -- Get minimum interval (smallest service duration or 15 minutes)
    SELECT COALESCE(MIN(s.duration_minutes), 15)
    INTO min_interval
    FROM services s
    WHERE s.id = ANY(p_service_ids);
    
    -- Ensure minimum interval is at least 15 minutes
    IF min_interval < 15 THEN
        min_interval := 15;
    END IF;
    
    -- Get day of week (0 = Sunday, 1 = Monday, etc.)
    day_of_week := EXTRACT(DOW FROM p_date::date);
    
    -- Don't generate slots for Sunday (day 0)
    IF day_of_week = 0 THEN
        RETURN;
    END IF;
    
    -- Generate time slots from 8:00 to 21:00
    slot_time := '08:00:00'::time;
    
    WHILE slot_time <= '20:30:00'::time LOOP
        -- Calculate when this slot would end
        slot_end_time := slot_time + (total_duration * interval '1 minute');
        
        -- Only include slots that end by 21:00
        IF slot_end_time <= '21:00:00'::time THEN
            -- Initialize as available
            is_available := true;
            
            -- Check for conflicts with existing appointments
            FOR existing_start_time, existing_appointment_duration IN
                SELECT 
                    a.appointment_time,
                    COALESCE(
                        (SELECT SUM(s.duration_minutes) 
                         FROM appointment_services aps 
                         JOIN services s ON s.id = aps.service_id 
                         WHERE aps.appointment_id = a.id),
                        30
                    )
                FROM appointments a
                WHERE a.barber_id = p_barber_id
                  AND a.appointment_date = p_date::date
                  AND a.status IN ('scheduled', 'confirmed')
            LOOP
                -- Calculate existing appointment end time
                existing_end_time := existing_start_time + (existing_appointment_duration * interval '1 minute');
                
                -- Check for overlaps:
                -- 1. New appointment starts during existing appointment
                -- 2. New appointment ends during existing appointment
                -- 3. New appointment completely contains existing appointment
                -- 4. Existing appointment completely contains new appointment
                IF (slot_time >= existing_start_time AND slot_time < existing_end_time) OR
                   (slot_end_time > existing_start_time AND slot_end_time <= existing_end_time) OR
                   (slot_time <= existing_start_time AND slot_end_time >= existing_end_time) OR
                   (existing_start_time <= slot_time AND existing_end_time >= slot_end_time) THEN
                    is_available := false;
                    EXIT; -- No need to check more appointments
                END IF;
            END LOOP;
            
            -- Return the slot
            RETURN QUERY SELECT 
                slot_time::text,
                is_available,
                total_duration;
        END IF;
        
        -- Move to next slot
        slot_time := slot_time + (min_interval * interval '1 minute');
    END LOOP;
    
    RETURN;
END;
$$;

-- Create helper function to get appointment total duration
CREATE OR REPLACE FUNCTION get_appointment_duration(appointment_id_param integer)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    total_duration integer;
BEGIN
    SELECT COALESCE(SUM(s.duration_minutes), 30)
    INTO total_duration
    FROM appointment_services aps
    JOIN services s ON s.id = aps.service_id
    WHERE aps.appointment_id = appointment_id_param;
    
    RETURN total_duration;
END;
$$;
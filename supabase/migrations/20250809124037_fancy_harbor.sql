/*
  # Create get_available_times function

  1. New Function
    - `get_available_times(p_barber_id, p_date, p_service_ids)`
    - Returns available time slots for a barber on a specific date
    - Considers service durations and existing appointments
  
  2. Parameters
    - p_barber_id: integer (barber ID)
    - p_date: text (date in YYYY-MM-DD format)
    - p_service_ids: integer[] (array of service IDs)
  
  3. Returns
    - Array of objects with time_slot and available properties
*/

-- Drop function if exists to recreate with correct signature
DROP FUNCTION IF EXISTS get_available_times(integer, text, integer[]);

-- Create the get_available_times function
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
            -- Check if slot is available (no conflicts)
            SELECT NOT EXISTS (
                SELECT 1 FROM appointments a
                WHERE a.barber_id = p_barber_id
                  AND a.appointment_date = p_date::date
                  AND a.status = 'scheduled'
                  AND a.appointment_time = slot_time
            ) INTO is_available;
            
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
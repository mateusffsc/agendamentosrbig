/*
  # Add phone number validation constraint

  1. Changes
    - Add CHECK constraint to validate Brazilian phone format in clients table
    - Add CHECK constraint to validate Brazilian phone format in barbers table
    - Ensure all phone numbers follow the pattern (XX) 9XXXX-XXXX

  2. Format Requirements
    - Must be exactly 15 characters: (XX) 9XXXX-XXXX
    - Must start with area code in parentheses
    - Must have mobile prefix 9
    - Must be properly formatted with space and dash
*/

-- Add phone validation constraint to clients table
-- Format: (XX) 9XXXX-XXXX
ALTER TABLE clients 
ADD CONSTRAINT clients_phone_format_check 
CHECK (phone ~ '^\([0-9]{2}\) 9[0-9]{4}-[0-9]{4}$');

-- Add phone validation constraint to barbers table  
-- Format: (XX) 9XXXX-XXXX
ALTER TABLE barbers 
ADD CONSTRAINT barbers_phone_format_check 
CHECK (phone ~ '^\([0-9]{2}\) 9[0-9]{4}-[0-9]{4}$');

-- Create function to validate and format phone numbers
CREATE OR REPLACE FUNCTION format_brazilian_phone(input_phone TEXT)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    digits_only TEXT;
    formatted_phone TEXT;
BEGIN
    -- Extract only digits
    digits_only := regexp_replace(input_phone, '\D', '', 'g');
    
    -- Check if has exactly 11 digits
    IF length(digits_only) != 11 THEN
        RAISE EXCEPTION 'Phone number must have exactly 11 digits, got %', length(digits_only);
    END IF;
    
    -- Check if starts with mobile prefix (9)
    IF substring(digits_only from 3 for 1) != '9' THEN
        RAISE EXCEPTION 'Mobile phone must start with 9 after area code';
    END IF;
    
    -- Format as (XX) 9XXXX-XXXX
    formatted_phone := '(' || substring(digits_only from 1 for 2) || ') ' || 
                      substring(digits_only from 3 for 5) || '-' || 
                      substring(digits_only from 8 for 4);
    
    RETURN formatted_phone;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Invalid phone format: %', input_phone;
END;
$$;

-- Create trigger function to automatically format phone numbers on insert/update
CREATE OR REPLACE FUNCTION auto_format_phone()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Format phone in clients table
    IF TG_TABLE_NAME = 'clients' AND NEW.phone IS NOT NULL THEN
        NEW.phone := format_brazilian_phone(NEW.phone);
    END IF;
    
    -- Format phone in barbers table  
    IF TG_TABLE_NAME = 'barbers' AND NEW.phone IS NOT NULL THEN
        NEW.phone := format_brazilian_phone(NEW.phone);
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create triggers to automatically format phone numbers
DROP TRIGGER IF EXISTS clients_format_phone_trigger ON clients;
CREATE TRIGGER clients_format_phone_trigger
    BEFORE INSERT OR UPDATE ON clients
    FOR EACH ROW
    EXECUTE FUNCTION auto_format_phone();

DROP TRIGGER IF EXISTS barbers_format_phone_trigger ON barbers;
CREATE TRIGGER barbers_format_phone_trigger
    BEFORE INSERT OR UPDATE ON barbers  
    FOR EACH ROW
    EXECUTE FUNCTION auto_format_phone();
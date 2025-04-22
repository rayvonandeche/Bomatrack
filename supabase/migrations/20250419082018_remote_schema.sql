SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pgsodium" WITH SCHEMA "pgsodium";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgjwt" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."add_floors_with_units"("property_id" integer, "start_floor" integer, "floor_count" integer, "units_per_floor" integer, "custom_floor_units" integer DEFAULT NULL::integer) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
    org_id UUID;
    floor_index INT;
    unit_index INT;
    new_floor_id INT;
    floor_name TEXT;
    custom_floor_name TEXT;
BEGIN
    -- Step 1: Validate and set organization ID
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
    INTO org_id;
    
    IF org_id IS NULL THEN
        RAISE EXCEPTION 'Organization ID not found in user_metadata';
    END IF;
    
    -- Set the current organization ID for the session
    PERFORM set_config('myapp.current_organization_id', org_id::TEXT, TRUE);
    
    -- Check if the property belongs to the organization
    IF NOT EXISTS (SELECT 1 FROM properties WHERE id = property_id AND organization_id = org_id) THEN
        RAISE EXCEPTION 'Property does not belong to the organization';
    END IF;
    
    -- Step 2: Create standard floors and units
    FOR floor_index IN 0..(floor_count - 1) LOOP
        floor_name := CHR(65 + floor_index + start_floor - 1);
        
        INSERT INTO floors (property_id, organization_id, floor_number, floor_name, total_units)
        VALUES (property_id, org_id, start_floor + floor_index, floor_name, units_per_floor)
        RETURNING id INTO new_floor_id;
        
        FOR unit_index IN 1..units_per_floor LOOP
            INSERT INTO units (property_id, floor_id, organization_id, unit_number)
            VALUES (property_id, new_floor_id, org_id, CONCAT(floor_name, LPAD(unit_index::TEXT, 2, '0')));
        END LOOP;
    END LOOP;
    
    -- Step 3: Create custom floor if provided
    IF custom_floor_units IS NOT NULL THEN
        custom_floor_name := CHR(65 + floor_count + start_floor - 1);
        
        INSERT INTO floors (property_id, organization_id, floor_number, floor_name, total_units)
        VALUES (property_id, org_id, (start_floor + floor_count), custom_floor_name, custom_floor_units)
        RETURNING id INTO new_floor_id;
        
        FOR unit_index IN 1..custom_floor_units LOOP
            INSERT INTO units (property_id, floor_id, organization_id, unit_number)
            VALUES (property_id, new_floor_id, org_id, CONCAT(custom_floor_name, LPAD(unit_index::TEXT, 2, '0')));
        END LOOP;
    END IF;
    
    -- Step 4: Update the total_units in the property table
    UPDATE properties
    SET total_units = total_units + (floor_count * units_per_floor) + COALESCE(custom_floor_units, 0)
    WHERE id = property_id;
    
    -- Step 5: Update the available_units in the property table
    PERFORM update_property_available_units(property_id);
END;
$$;


ALTER FUNCTION "public"."add_floors_with_units"("property_id" integer, "start_floor" integer, "floor_count" integer, "units_per_floor" integer, "custom_floor_units" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_payment"("p_tenant_id" integer, "p_pending_payment_ids" integer[], "p_amount" numeric, "p_payment_date" "date", "p_payment_method" character varying, "p_reference_number" character varying, "p_description" "text" DEFAULT NULL::"text") RETURNS integer[]
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_org_id UUID;
    v_payment_ids INTEGER[];
    v_payment_record RECORD;
    v_is_deposit BOOLEAN;
BEGIN
    -- Fetch the current organization ID
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::uuid
    INTO v_org_id;

    IF v_org_id IS NULL THEN
        RAISE EXCEPTION 'Current organization is not set.';
    END IF;

    PERFORM set_config('myapp.current_organization_id', v_org_id::text, true);

    -- Validate payments belong to tenant
    FOR v_payment_record IN 
        SELECT * FROM validate_tenant_payments(p_tenant_id, p_pending_payment_ids)
    LOOP
        -- Check if payment is a deposit
        v_is_deposit := position('deposit' in COALESCE(v_payment_record.description, '')) > 0;
        
        -- For each payment, process with full amount
        v_payment_ids := array_append(v_payment_ids,
            process_single_payment(
                v_payment_record.unit_tenancy_id,
                p_amount,
                p_payment_date,
                p_payment_method,
                p_reference_number,
                p_description,
                v_payment_record.id
            )
        );
    END LOOP;

    RETURN v_payment_ids;
END;
$$;


ALTER FUNCTION "public"."add_payment"("p_tenant_id" integer, "p_pending_payment_ids" integer[], "p_amount" numeric, "p_payment_date" "date", "p_payment_method" character varying, "p_reference_number" character varying, "p_description" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_paymentt"("unit_tenancy_id" integer, "amount" numeric, "payment_date" "date", "payment_method" character varying, "reference_number" character varying, "description" "text" DEFAULT NULL::"text", "is_pending_payment_id" integer DEFAULT NULL::integer) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    org_id UUID;
    property_id INTEGER;
    payment_id INTEGER;
    tenancy_exists BOOLEAN;
    payment_exists BOOLEAN;
    tenant_id INTEGER;
    unit_id INTEGER;
    current_status VARCHAR(50);
    monthly_rent NUMERIC(10, 2);
    current_due_date DATE;
    next_due_date DATE;
    tenancy_status VARCHAR(50);
    tenancy_end_date DATE;
    payment_description TEXT;
    remaining_balance NUMERIC(10, 2);
    original_payment_date DATE;
    total_paid_for_period NUMERIC(10, 2) := 0.00;
    next_payment_exists BOOLEAN := FALSE;
    next_payment_id INTEGER;
    unit_start_date DATE;
    overpayment NUMERIC(10, 2) := 0.00;
    pending_amount NUMERIC(10, 2);
    next_interval_amount NUMERIC(10, 2);
    pending_payment_amount NUMERIC(10, 2);
    is_deposit_payment BOOLEAN := FALSE;
BEGIN
    -- Fetch the current organization ID
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::uuid
    INTO org_id;

    IF org_id IS NULL THEN
        RAISE EXCEPTION 'Current organization is not set.';
    END IF;

    PERFORM set_config('myapp.current_organization_id', org_id::text, true);

    -- Determine if we're processing an existing payment or creating a new one
    IF is_pending_payment_id IS NOT NULL THEN
        -- We're processing a pending payment

        -- Check if the payment exists and belongs to the current organization
        SELECT EXISTS(
            SELECT 1
            FROM   payments
            WHERE  id = is_pending_payment_id
                   AND organization_id = org_id
        ) INTO   payment_exists;

        IF NOT payment_exists THEN
            RAISE EXCEPTION 'Payment % does not exist or does not belong to the current organization.', is_pending_payment_id;
        END IF;

        -- Get payment details
        SELECT p.payment_status,
               p.unit_tenancy_id,
               p.property_id,
               p.due_date,
               p.amount,
               p.description,
               p.payment_date
        INTO   current_status,
               unit_tenancy_id,
               property_id,
               current_due_date,
               pending_payment_amount,
               payment_description,
               original_payment_date
        FROM   payments p
        WHERE  p.id = is_pending_payment_id;

        -- Check if this is a deposit payment
        is_deposit_payment := COALESCE(position('deposit' in LOWER(payment_description)) > 0, FALSE);

        -- Validate payment is in 'pending', 'overdue' or 'partial' status
        IF current_status NOT IN ('pending', 'overdue', 'partial') THEN
            RAISE EXCEPTION 'Payment % is not in pending, overdue or partial status. Current status: %.', is_pending_payment_id, current_status;
        END IF;

        -- Get the tenancy information
        SELECT ut.tenant_id,
               ut.unit_id,
               ut.monthly_rent,
               ut.status,
               ut.end_date,
               ut.start_date
        INTO   tenant_id,
               unit_id,
               monthly_rent,
               tenancy_status,
               tenancy_end_date,
               unit_start_date
        FROM   unit_tenancy ut
        WHERE  ut.id = unit_tenancy_id;

        -- Calculate total paid for the current period (exclude this current payment)
        SELECT COALESCE(SUM(p.amount), 0.00)
        INTO   total_paid_for_period
        FROM   payments p
        WHERE  p.unit_tenancy_id = add_paymentt.unit_tenancy_id
               AND p.due_date = current_due_date
               AND p.payment_status IN ('paid', 'partial');

        -- Add current payment to total_paid_for_period
        total_paid_for_period := total_paid_for_period + amount;
        remaining_balance := pending_payment_amount - amount;

        -- Case 1: Full payment of the pending amount
        IF amount = pending_payment_amount THEN
            -- Mark the current payment as paid
            UPDATE payments
            SET    payment_status = 'paid',
                   payment_date = add_paymentt.payment_date,
                   payment_method = add_paymentt.payment_method,
                   reference_number = add_paymentt.reference_number,
                   updated_at = CURRENT_TIMESTAMP
            WHERE  id = is_pending_payment_id
                   AND organization_id = org_id
            RETURNING id INTO payment_id;

            -- Check if total payments for this period >= monthly rent
            -- Only create next month's payment if this is NOT a deposit payment
            IF total_paid_for_period >= monthly_rent AND 
               tenancy_status = 'active' AND
               (tenancy_end_date IS NULL OR tenancy_end_date > current_due_date) AND
               NOT is_deposit_payment THEN
                
                -- Create next month's pending payment
                next_due_date := current_due_date + INTERVAL '30 days';
                
                -- Check if next payment already exists
                SELECT EXISTS(
                    SELECT 1
                    FROM   payments
                    WHERE  payments.unit_tenancy_id = add_paymentt.unit_tenancy_id
                           AND due_date = next_due_date
                           AND payment_status IN ('pending', 'overdue')
                ) INTO   next_payment_exists;
                
                IF NOT next_payment_exists THEN
                    -- Never apply overpayment to the next month automatically
                    -- Just create a standard pending payment for the next month
                    INSERT INTO payments (
                        unit_tenancy_id,
                        amount,
                        due_date,
                        payment_status,
                        description,
                        organization_id,
                        property_id
                    )
                    VALUES (
                        unit_tenancy_id,
                        monthly_rent, -- Always use full monthly rent for next month
                        next_due_date,
                        'pending',
                        'Monthly rent payment',
                        org_id,
                        property_id
                    );
                END IF;
            END IF;
        
        -- Case 2: Partial payment
        ELSIF amount < pending_payment_amount THEN
            -- Insert a new partial payment record
            INSERT INTO payments (
                unit_tenancy_id,
                amount,
                payment_date,
                due_date,
                payment_status,
                payment_method,
                reference_number,
                description,
                organization_id,
                property_id
            )
            VALUES (
                unit_tenancy_id,
                amount,
                payment_date,
                current_due_date,
                'partial',
                payment_method,
                reference_number,
                COALESCE(description, 
                       CASE WHEN is_deposit_payment THEN 'Partial security deposit payment' 
                            ELSE 'Partial payment' END),
                org_id,
                property_id
            )
            RETURNING id INTO payment_id;
            
            -- Update the pending payment amount
            UPDATE payments
            SET    amount = remaining_balance,
                   payment_status = 'pending',
                   updated_at = CURRENT_TIMESTAMP
            WHERE  id = is_pending_payment_id
                   AND organization_id = org_id;
            
            -- Check if total payments for this period >= monthly rent
            -- Only create next month's payment if this is NOT a deposit payment
            IF total_paid_for_period >= monthly_rent AND 
               tenancy_status = 'active' AND
               (tenancy_end_date IS NULL OR tenancy_end_date > current_due_date) AND
               NOT is_deposit_payment THEN
                
                -- Create next month's pending payment
                next_due_date := current_due_date + INTERVAL '30 days';
                
                -- Check if next payment already exists
                SELECT EXISTS(
                    SELECT 1
                    FROM   payments
                    WHERE  payments.unit_tenancy_id = add_paymentt.unit_tenancy_id
                           AND due_date = next_due_date
                           AND payment_status IN ('pending', 'overdue')
                ) INTO   next_payment_exists;
                
                IF NOT next_payment_exists THEN
                    -- Calculate overpayment to apply to next month
                    overpayment := GREATEST(total_paid_for_period - monthly_rent, 0);
                    next_interval_amount := GREATEST(monthly_rent - overpayment, 0);
                    
                    -- Only create next payment if there's an amount due
                    IF next_interval_amount > 0 THEN
                        INSERT INTO payments (
                            unit_tenancy_id,
                            amount,
                            due_date,
                            payment_status,
                            description,
                            organization_id,
                            property_id
                        )
                        VALUES (
                            unit_tenancy_id,
                            next_interval_amount,
                            next_due_date,
                            'pending',
                            'Monthly rent payment',
                            org_id,
                            property_id
                        );
                    ELSE
                        -- If overpayment covers entire next month, create a fully paid record
                        INSERT INTO payments (
                            unit_tenancy_id,
                            amount,
                            due_date,
                            payment_date,
                            payment_status,
                            description,
                            organization_id,
                            property_id
                        )
                        VALUES (
                            unit_tenancy_id,
                            monthly_rent,
                            next_due_date,
                            add_paymentt.payment_date, -- Use the current payment date for the pre-paid payment
                            'paid',
                            'Monthly rent payment (pre-paid)',
                            org_id,
                            property_id
                        );
                    END IF;
                END IF;
            END IF;
            
        -- Case 3: Payment exceeds pending amount (overpayment)
        ELSE -- amount > pending_payment_amount
            -- Mark the current payment as paid
            UPDATE payments
            SET    payment_status = 'paid',
                   payment_date = add_paymentt.payment_date,
                   payment_method = add_paymentt.payment_method,
                   reference_number = add_paymentt.reference_number,
                   updated_at = CURRENT_TIMESTAMP,
                   amount = pending_payment_amount -- Keep the original amount
            WHERE  id = is_pending_payment_id
                   AND organization_id = org_id
            RETURNING id INTO payment_id;
            
            -- Record the overpayment as a separate payment with the same due date
            INSERT INTO payments (
                unit_tenancy_id,
                amount,
                payment_date,
                due_date,
                payment_status,
                payment_method,
                reference_number,
                description,
                organization_id,
                property_id
            )
            VALUES (
                unit_tenancy_id,
                amount - pending_payment_amount,
                payment_date,
                current_due_date,
                'partial',
                payment_method,
                reference_number,
                COALESCE(description, 
                       CASE WHEN is_deposit_payment THEN 'Overpayment applied to security deposit' 
                            ELSE 'Overpayment applied to current period' END),
                org_id,
                property_id
            );
            
            -- Check if total payments for this period >= monthly rent
            -- Only create next month's payment if this is NOT a deposit payment
            IF total_paid_for_period >= monthly_rent AND 
               tenancy_status = 'active' AND
               (tenancy_end_date IS NULL OR tenancy_end_date > current_due_date) AND
               NOT is_deposit_payment THEN
                
                -- Create next month's pending payment
                next_due_date := current_due_date + INTERVAL '30 days';
                
                -- Check if next payment already exists
                SELECT EXISTS(
                    SELECT 1
                    FROM   payments
                    WHERE  payments.unit_tenancy_id = add_paymentt.unit_tenancy_id
                           AND due_date = next_due_date
                           AND payment_status IN ('pending', 'overdue')
                ) INTO   next_payment_exists;
                
                IF NOT next_payment_exists THEN
                    -- Calculate overpayment to apply to next month
                    overpayment := GREATEST(total_paid_for_period - monthly_rent, 0);
                    next_interval_amount := GREATEST(monthly_rent - overpayment, 0);
                    
                    -- Only create next payment if there's an amount due
                    IF next_interval_amount > 0 THEN
                        INSERT INTO payments (
                            unit_tenancy_id,
                            amount,
                            due_date,
                            payment_status,
                            description,
                            organization_id,
                            property_id
                        )
                        VALUES (
                            unit_tenancy_id,
                            next_interval_amount,
                            next_due_date,
                            'pending',
                            'Monthly rent payment',
                            org_id,
                            property_id
                        );
                    ELSE
                        -- If overpayment covers entire next month, create a fully paid record
                        INSERT INTO payments (
                            unit_tenancy_id,
                            amount,
                            due_date,
                            payment_date,
                            payment_status,
                            description,
                            organization_id,
                            property_id
                        )
                        VALUES (
                            unit_tenancy_id,
                            monthly_rent,
                            next_due_date,
                            add_paymentt.payment_date, -- Use the current payment date for the pre-paid payment
                            'paid',
                            'Monthly rent payment (pre-paid)',
                            org_id,
                            property_id
                        );
                    END IF;
                END IF;
            END IF;
        END IF;
    ELSE
        -- Creating a new ad-hoc payment (no pending payment specified)
        -- Validate that the unit_tenancy exists and belongs to the current organization
        SELECT EXISTS(
            SELECT 1
            FROM   unit_tenancy
            WHERE  id = unit_tenancy_id
                   AND organization_id = org_id
        ) INTO   tenancy_exists;

        IF NOT tenancy_exists THEN
            RAISE EXCEPTION 'Unit tenancy % does not exist or does not belong to the current organization.', unit_tenancy_id;
        END IF;

        -- Get the property_id and monthly rent from the unit_tenancy record
        SELECT ut.property_id,
               ut.tenant_id,
               ut.unit_id,
               ut.monthly_rent,
               ut.start_date,
               ut.status,
               ut.end_date
        INTO   property_id,
               tenant_id,
               unit_id,
               monthly_rent,
               unit_start_date,
               tenancy_status,
               tenancy_end_date
        FROM   unit_tenancy ut
        WHERE  ut.id = unit_tenancy_id;

        -- Check if this is a deposit payment
        is_deposit_payment := COALESCE(position('deposit' in LOWER(COALESCE(description, ''))) > 0, FALSE);
        
        -- For ad-hoc payments, determine appropriate due date based on payment context
        -- Check if this is an initial rent payment (first payment after lease start)
        IF payment_date <= unit_start_date + INTERVAL '15 days' AND NOT is_deposit_payment THEN
            -- This appears to be the first month's rent payment
            current_due_date := DATE_TRUNC('month', unit_start_date)::DATE;
        ELSE
            -- Normal payment - use current month
            current_due_date := DATE_TRUNC('month', payment_date)::DATE;
        END IF;
        
        -- Insert the ad-hoc payment record
        INSERT INTO payments (
            unit_tenancy_id,
            amount,
            payment_date,
            due_date,
            payment_status,
            payment_method,
            reference_number,
            description,
            organization_id,
            property_id
        )
        VALUES (
            unit_tenancy_id,
            amount,
            payment_date,
            current_due_date,
            'paid', -- Mark ad-hoc payments as paid, since they're being made now
            payment_method,
            reference_number,
            COALESCE(description, 
                   CASE WHEN is_deposit_payment THEN 'Security deposit payment' 
                        ELSE 'Monthly rent payment' END),
            org_id,
            property_id
        )
        RETURNING id INTO payment_id;
        
        -- Calculate total paid for this period including this payment
        SELECT COALESCE(SUM(p.amount), 0.00)
        INTO   total_paid_for_period
        FROM   payments p
        WHERE  p.unit_tenancy_id = add_paymentt.unit_tenancy_id
               AND p.due_date = current_due_date
               AND p.payment_status IN ('paid', 'partial');
        
        -- Check if total payments for this period >= monthly rent
        -- Only create next month's payment if this is NOT a deposit payment
        IF total_paid_for_period >= monthly_rent AND 
           tenancy_status = 'active' AND
           (tenancy_end_date IS NULL OR tenancy_end_date > current_due_date) AND
           NOT is_deposit_payment THEN
            
            -- Create next month's pending payment (always one month after the current due date)
            next_due_date := DATE_TRUNC('month', current_due_date + INTERVAL '1 month')::DATE;
            
            -- Check if next payment already exists
            SELECT EXISTS(
                SELECT 1
                FROM   payments
                WHERE  payments.unit_tenancy_id = add_paymentt.unit_tenancy_id
                       AND due_date = next_due_date
                ) INTO   next_payment_exists;
            
            IF NOT next_payment_exists THEN
                -- Never apply overpayment to the next month's rent for initial setup
                -- Just create a standard pending payment for the full monthly rent
                
                INSERT INTO payments (
                    unit_tenancy_id,
                    amount,
                    due_date,
                    payment_status,
                    description,
                    organization_id,
                    property_id
                )
                VALUES (
                    unit_tenancy_id,
                    monthly_rent, -- Always use full monthly rent for next month's pending payment
                    next_due_date,
                    'pending', -- Always create as pending, never set payment_date for pending payments
                    'Monthly rent payment',
                    org_id,
                    property_id
                );
            END IF;
        END IF;
    END IF;

    RETURN payment_id;
END;
$$;


ALTER FUNCTION "public"."add_paymentt"("unit_tenancy_id" integer, "amount" numeric, "payment_date" "date", "payment_method" character varying, "reference_number" character varying, "description" "text", "is_pending_payment_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_property"("property_name" "text", "property_address" "text", "f_count" integer, "units_p_floor" integer, "start_f" integer DEFAULT 1, "custom_f_units" integer DEFAULT NULL::integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
DECLARE 
    org_id UUID; 
    new_property_id INT; 
BEGIN
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::uuid INTO org_id; 
    
    IF org_id IS NULL THEN 
        RAISE EXCEPTION 'Organization ID not found in user_metadata'; 
    END IF; 
    
    PERFORM set_config('myapp.current_organization_id', org_id::text, TRUE); 
    
    INSERT INTO public.properties (name, address) 
    VALUES (property_name, property_address) 
    RETURNING id INTO new_property_id; 
    
    PERFORM add_floors_with_units(
        property_id := new_property_id, 
        start_floor := start_f, 
        floor_count := f_count, 
        units_per_floor := units_p_floor,
        custom_floor_units := custom_f_units
    ); 
    
    RAISE NOTICE 'Property created successfully with ID: %', new_property_id; 
    
    EXCEPTION 
        WHEN OTHERS THEN 
            RAISE EXCEPTION 'Error creating property: %', SQLERRM; 
END;
$$;


ALTER FUNCTION "public"."create_property"("property_name" "text", "property_address" "text", "f_count" integer, "units_p_floor" integer, "start_f" integer, "custom_f_units" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_property"("property_name" "text", "property_address" "text", "f_count" integer, "units_p_floor" integer, "rent" numeric, "start_f" integer DEFAULT 1, "custom_f_units" integer DEFAULT NULL::integer, "custom_f_rent" integer DEFAULT NULL::integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$declare 
org_id UUID;
new_property_id INT;
begin
select(auth.jwt() -> 'user_metadata' ->> 'organization')::uuid
into org_id;

if org_id is null then
raise exception 'Organization ID not found in user_metadata';
end if;

perform set_config('myapp.current_organization_id', org_id::text, true);

insert into public.properties (name, address)
values (property_name, property_address)
returning id into new_property_id;

perform add_floors_with_units(
  property_id := new_property_id,
  start_floor := start_f,
  floor_count := f_count,
  units_per_floor := units_p_floor,
  default_rent := rent,
  custom_floor_units := custom_f_units,
  custom_floor_rent := custom_f_rent
);

raise notice 'Propert created successfully with ID: %', new_property_id;
exception when others then raise exception 'Error createing property: %', sqlerrm;

end;$$;


ALTER FUNCTION "public"."create_property"("property_name" "text", "property_address" "text", "f_count" integer, "units_p_floor" integer, "rent" numeric, "start_f" integer, "custom_f_units" integer, "custom_f_rent" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_unit_tenancy"("p_property_id" integer, "p_unit_ids" integer[], "p_first_name" character varying, "p_last_name" character varying, "p_monthly_rent" integer, "p_email" character varying DEFAULT NULL::character varying, "p_phone" character varying DEFAULT NULL::character varying, "p_id_number" character varying DEFAULT NULL::character varying, "p_emergency_contact" "text" DEFAULT NULL::"text", "p_start_date" "date" DEFAULT CURRENT_DATE) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_organization_id UUID;
    v_tenant_id INTEGER;
    v_unit_id INTEGER;
    v_unit_tenancy_id INTEGER;
BEGIN
    -- Get current organization ID
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID 
    INTO v_organization_id;

    -- Validate organization ID
    IF v_organization_id IS NULL THEN
        RAISE EXCEPTION 'Organization ID not found in JWT token';
    END IF;

    -- Set configuration for current organization
    PERFORM set_config('myapp.current_organization_id', v_organization_id::TEXT, TRUE);

    -- Start transaction
    BEGIN
        -- Insert new tenant
        INSERT INTO tenants (
            organization_id, 
            property_id, 
            first_name, 
            last_name, 
            email, 
            phone, 
            id_number, 
            emergency_contact
        ) VALUES (
            v_organization_id,
            p_property_id,
            p_first_name,
            p_last_name,
            p_email,
            p_phone,
            p_id_number,
            p_emergency_contact
        ) RETURNING id INTO v_tenant_id;

        -- Process each unit
        FOREACH v_unit_id IN ARRAY p_unit_ids
        LOOP
            -- Create unit tenancy record
            INSERT INTO unit_tenancy (
                organization_id,
                property_id,
                unit_id,
                tenant_id,
                start_date,
                monthly_rent,
                status
            ) VALUES (
                v_organization_id,
                p_property_id,
                v_unit_id,
                v_tenant_id,
                p_start_date,
                p_monthly_rent,
                'active'
            ) RETURNING id INTO v_unit_tenancy_id;

            -- Update unit status to occupied
            UPDATE units 
            SET status = 'occupied' 
            WHERE id = v_unit_id;
            
            -- Create pending deposit payment record
            INSERT INTO payments (
                unit_tenancy_id,
                amount,
                due_date,
                payment_status,
                description,
                organization_id,
                property_id
            ) VALUES (
                v_unit_tenancy_id,
                p_monthly_rent, -- Deposit amount equal to monthly rent
                p_start_date,
                'pending',
                'Security deposit payment',
                v_organization_id,
                p_property_id
            );
            
            -- Create pending payment for first month's rent
            INSERT INTO payments (
                unit_tenancy_id,
                amount,
                due_date,
                payment_status,
                description,
                organization_id,
                property_id
            ) VALUES (
                v_unit_tenancy_id,
                p_monthly_rent,
                p_start_date,
                'pending',
                'Monthly rent payment',
                v_organization_id,
                p_property_id
            );
        END LOOP;

        RETURN v_tenant_id;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE EXCEPTION 'Error creating unit tenancy: %', SQLERRM;
    END;
END;
$$;


ALTER FUNCTION "public"."create_unit_tenancy"("p_property_id" integer, "p_unit_ids" integer[], "p_first_name" character varying, "p_last_name" character varying, "p_monthly_rent" integer, "p_email" character varying, "p_phone" character varying, "p_id_number" character varying, "p_emergency_contact" "text", "p_start_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_tenant"("t_id" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$BEGIN
    UPDATE public.units 
    SET status = 'available' 
    WHERE id IN (
        SELECT unit_id 
        FROM public.unit_tenancy 
        WHERE tenant_id = t_id
    );
    UPDATE public.unit_tenancy 
    SET end_date = now() 
    WHERE tenant_id IN (
        SELECT id 
        FROM public.tenants 
        WHERE id = t_id
    );
    UPDATE public.unit_tenancy
    SET status = 'ended'
    WHERE tenant_id IN (
        SELECT id 
        FROM public.tenants 
        WHERE id = t_id
    );

END;$$;


ALTER FUNCTION "public"."delete_tenant"("t_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_tenant_and_related_records"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Delete all related unit tenancy records
    DELETE FROM unit_tenancy 
    WHERE tenant_id = OLD.id;

    -- Delete all related payments
    DELETE FROM payments 
    WHERE unit_tenancy_id IN (
        SELECT id FROM unit_tenancy 
        WHERE tenant_id = OLD.id
    );

    -- Update units to available that were occupied by this tenant
    UPDATE units u
    SET status = 'available'
    WHERE u.id IN (
        SELECT unit_id 
        FROM unit_tenancy ut
        WHERE ut.tenant_id = OLD.id
    );

    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."delete_tenant_and_related_records"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_tenant_and_update_units"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Delete related unit tenancy records
  DELETE FROM unit_tenancy
  WHERE tenant_id = OLD.id;

  -- Update the availability of the units associated with the deleted tenant
  UPDATE units
  SET status = 'available'
  WHERE id IN (SELECT unit_id FROM unit_tenancy WHERE tenant_id = OLD.id);

  -- Finally, delete the tenant
  DELETE FROM tenants
  WHERE id = OLD.id;

  RETURN NULL; -- Triggers that do not modify the row must return NULL
END;
$$;


ALTER FUNCTION "public"."delete_tenant_and_update_units"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."floors" (
    "id" integer NOT NULL,
    "property_id" integer,
    "floor_number" integer NOT NULL,
    "floor_name" "text" NOT NULL,
    "total_units" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "organization_id" "uuid" NOT NULL
);


ALTER TABLE "public"."floors" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fetch_floors"() RETURNS SETOF "public"."floors"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  org_id UUID;
BEGIN
  -- Extract the organization_id from the JWT
  SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
  INTO org_id;

  -- Check if organization_id was successfully extracted
  IF org_id IS NULL THEN
    RAISE EXCEPTION 'Organization ID not found in user_metadata';
  END IF;

  -- Set the current organization ID for the session
  PERFORM set_config('myapp.current_organization_id', org_id::TEXT, TRUE);

  -- Return the filtered floors
  RETURN QUERY SELECT * FROM floors WHERE organization_id = org_id;
END;
$$;


ALTER FUNCTION "public"."fetch_floors"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fetch_floorss"("prop_id" integer) RETURNS SETOF "public"."floors"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  org_id UUID;
BEGIN
  -- Extract the organization_id from the JWT
  SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
  INTO org_id;

  IF org_id IS NULL THEN
    RAISE EXCEPTION 'Organization ID not found in user_metadata';
  END IF;

  -- Set the current organization ID for the session
  PERFORM set_config('myapp.current_organization_id', org_id::TEXT, TRUE);

  -- Return the filtered floors for the specified property
  RETURN QUERY SELECT * 
  FROM floors 
  WHERE organization_id = org_id AND property_id = prop_id;
END;
$$;


ALTER FUNCTION "public"."fetch_floorss"("prop_id" integer) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."properties" (
    "id" integer NOT NULL,
    "name" character varying(255) NOT NULL,
    "address" "text",
    "total_units" integer DEFAULT 0 NOT NULL,
    "available_units" integer DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "organization_id" "uuid" NOT NULL
);


ALTER TABLE "public"."properties" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fetch_properties"() RETURNS SETOF "public"."properties"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  org_id UUID;
BEGIN
  -- Extract the organization_id from the JWT
  SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
  INTO org_id;

  -- Check if organization_id was successfully extracted
  IF org_id IS NULL THEN
    RAISE EXCEPTION 'Organization ID not found in user_metadata';
  END IF;

  -- Set the current organization ID for the session
  PERFORM set_config('myapp.current_organization_id', org_id::TEXT, TRUE);

  -- Return the filtered properties
  RETURN QUERY SELECT * FROM properties WHERE organization_id = org_id;
END;
$$;


ALTER FUNCTION "public"."fetch_properties"() OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tenants" (
    "id" integer NOT NULL,
    "first_name" character varying(100) NOT NULL,
    "last_name" character varying(100) NOT NULL,
    "email" character varying(255),
    "phone" character varying(20),
    "id_number" character varying(50),
    "emergency_contact" "text",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "organization_id" "uuid" NOT NULL,
    "property_id" integer NOT NULL
);


ALTER TABLE "public"."tenants" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fetch_tenants"() RETURNS SETOF "public"."tenants"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  org_id UUID;
BEGIN
  -- Extract the organization_id from the JWT
  SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
  INTO org_id;

  -- Check if organization_id was successfully extracted
  IF org_id IS NULL THEN
    RAISE EXCEPTION 'Organization ID not found in user_metadata';
  END IF;

  -- Set the current organization ID for the session
  PERFORM set_config('myapp.current_organization_id', org_id::TEXT, TRUE);

  -- Return the filtered tenants
  RETURN QUERY SELECT * FROM tenants WHERE organization_id = org_id;
END;
$$;


ALTER FUNCTION "public"."fetch_tenants"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fetch_tenantss"("prop_id" integer) RETURNS SETOF "public"."tenants"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  org_id UUID;
BEGIN
  -- Extract the organization_id from the JWT
  SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
  INTO org_id;

  IF org_id IS NULL THEN
    RAISE EXCEPTION 'Organization ID not found in user_metadata';
  END IF;

  -- Set the current organization ID for the session
  PERFORM set_config('myapp.current_organization_id', org_id::TEXT, TRUE);

  -- Return the filtered floors for the specified property
  RETURN QUERY SELECT * 
  FROM tenants
  WHERE organization_id = org_id AND property_id = prop_id;
END;
$$;


ALTER FUNCTION "public"."fetch_tenantss"("prop_id" integer) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."unit_tenancy" (
    "id" integer NOT NULL,
    "unit_id" integer,
    "tenant_id" integer,
    "start_date" "date" NOT NULL,
    "end_date" "date",
    "monthly_rent" numeric(10,2) NOT NULL,
    "status" character varying(50) DEFAULT 'active'::character varying,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "organization_id" "uuid" NOT NULL,
    "property_id" integer,
    CONSTRAINT "unit_tenancy_status_check" CHECK ((("status")::"text" = ANY (ARRAY[('active'::character varying)::"text", ('ended'::character varying)::"text", ('terminated'::character varying)::"text"])))
);


ALTER TABLE "public"."unit_tenancy" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fetch_unit_tenancy"("prop_id" integer) RETURNS SETOF "public"."unit_tenancy"
    LANGUAGE "plpgsql"
    AS $$
declare org_id uuid;
begin
select (auth.jwt()-> 'user_metadata' ->> 'organization')::uuid
into org_id;

if org_id is null then 
raise exception 'Organization ID not found in user_metadata';
end if;

perform set_config('myapp.current_organization_id', org_id::text, true);

return query select * from unit_tenancy where organization_id = org_id and property_id = prop_id;
end;
$$;


ALTER FUNCTION "public"."fetch_unit_tenancy"("prop_id" integer) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."units" (
    "id" integer NOT NULL,
    "floor_id" integer,
    "unit_number" "text" NOT NULL,
    "status" character varying(50) DEFAULT 'available'::character varying,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "organization_id" "uuid" NOT NULL,
    "property_id" integer,
    CONSTRAINT "unit_status_check" CHECK ((("status")::"text" = ANY (ARRAY[('available'::character varying)::"text", ('occupied'::character varying)::"text", ('maintenance'::character varying)::"text"])))
);


ALTER TABLE "public"."units" OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fetch_units"() RETURNS SETOF "public"."units"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  org_id UUID;
BEGIN
  -- Extract the organization_id from the JWT
  SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
  INTO org_id;

  -- Check if organization_id was successfully extracted
  IF org_id IS NULL THEN
    RAISE EXCEPTION 'Organization ID not found in user_metadata';
  END IF;

  -- Set the current organization ID for the session
  PERFORM set_config('myapp.current_organization_id', org_id::TEXT, TRUE);

  -- Return the filtered units
  RETURN QUERY SELECT * FROM units WHERE organization_id = org_id;
END;
$$;


ALTER FUNCTION "public"."fetch_units"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."fetch_unitss"("prop_id" integer) RETURNS SETOF "public"."units"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  org_id UUID;
BEGIN
  -- Extract the organization_id from the JWT
  SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
  INTO org_id;

  IF org_id IS NULL THEN
    RAISE EXCEPTION 'Organization ID not found in user_metadata';
  END IF;

  -- Set the current organization ID for the session
  PERFORM set_config('myapp.current_organization_id', org_id::TEXT, TRUE);

  -- Return the filtered units for the specified property
  RETURN QUERY SELECT * 
  FROM units 
  WHERE organization_id = org_id AND property_id = prop_id;
END;
$$;


ALTER FUNCTION "public"."fetch_unitss"("prop_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."process_single_payment"("p_unit_tenancy_id" integer, "p_amount" numeric, "p_payment_date" "date", "p_payment_method" character varying, "p_reference_number" character varying, "p_description" "text", "p_pending_payment_id" integer) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_org_id UUID;
    v_property_id INTEGER;
    v_payment_id INTEGER;
    v_payment_exists BOOLEAN;
    v_tenant_id INTEGER;
    v_unit_id INTEGER;
    v_current_status VARCHAR(50);
    v_monthly_rent NUMERIC(10, 2);
    v_current_due_date DATE;
    v_next_due_date DATE;
    v_tenancy_status VARCHAR(50);
    v_tenancy_end_date DATE;
    v_payment_description TEXT;
    v_remaining_balance NUMERIC(10, 2);
    v_original_payment_date DATE;
    v_total_paid_for_period NUMERIC(10, 2) := 0.00;
    v_next_payment_exists BOOLEAN := FALSE;
    v_unit_start_date DATE;
    v_overpayment NUMERIC(10, 2) := 0.00;
    v_pending_payment_amount NUMERIC(10, 2);
    v_next_interval_amount NUMERIC(10, 2);
BEGIN
    -- Fetch the current organization ID
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::uuid
    INTO v_org_id;

    IF v_org_id IS NULL THEN
        RAISE EXCEPTION 'Current organization is not set.';
    END IF;

    PERFORM set_config('myapp.current_organization_id', v_org_id::text, true);

    -- Check if the payment exists and belongs to the current organization
    SELECT EXISTS(
        SELECT 1
        FROM   payments
        WHERE  id = p_pending_payment_id
                AND organization_id = v_org_id
    ) INTO v_payment_exists;

    IF NOT v_payment_exists THEN
        RAISE EXCEPTION 'Payment % does not exist or does not belong to the current organization.', p_pending_payment_id;
    END IF;

    -- Get payment details for the specific pending payment
    SELECT p.payment_status,
            p.unit_tenancy_id,
            p.property_id,
            p.due_date,
            p.amount,
            p.description,
            p.payment_date
    INTO   v_current_status,
            p_unit_tenancy_id,
            v_property_id,
            v_current_due_date,
            v_pending_payment_amount,
            v_payment_description,
            v_original_payment_date
    FROM   payments p
    WHERE  p.id = p_pending_payment_id;

    -- Get the tenancy information
    SELECT ut.tenant_id,
            ut.unit_id,
            ut.monthly_rent,
            ut.status,
            ut.end_date,
            ut.start_date
    INTO   v_tenant_id,
            v_unit_id,
            v_monthly_rent,
            v_tenancy_status,
            v_tenancy_end_date,
            v_unit_start_date
    FROM   unit_tenancy ut
    WHERE  ut.id = p_unit_tenancy_id;

    -- Calculate total paid for the current period (exclude deposits and this current payment)
    SELECT COALESCE(SUM(p.amount), 0.00)
    INTO   v_total_paid_for_period
    FROM   payments p
    WHERE  p.unit_tenancy_id = p_unit_tenancy_id
            AND p.due_date = v_current_due_date
            AND p.payment_status IN ('paid', 'partial')
            AND position('deposit' in COALESCE(p.description, '')) = 0;

    -- Only add current payment to total_paid_for_period if it's not a deposit
    IF position('deposit' in COALESCE(p_description, '')) = 0 THEN
        v_total_paid_for_period := v_total_paid_for_period + p_amount;
    END IF;

    v_remaining_balance := v_pending_payment_amount - p_amount;

    -- Process payment based on amount
    IF p_amount = v_pending_payment_amount THEN
        -- Full payment case
        UPDATE payments
        SET    payment_status = 'paid',
                payment_date = p_payment_date,
                payment_method = p_payment_method,
                reference_number = p_reference_number,
                updated_at = CURRENT_TIMESTAMP
        WHERE  id = p_pending_payment_id
                AND organization_id = v_org_id
        RETURNING id INTO v_payment_id;

    ELSIF p_amount < v_pending_payment_amount THEN
        -- Partial payment case
        INSERT INTO payments (
            unit_tenancy_id,
            amount,
            payment_date,
            due_date,
            payment_status,
            payment_method,
            reference_number,
            description,
            organization_id,
            property_id
        )
        VALUES (
            p_unit_tenancy_id,
            p_amount,
            p_payment_date,
            v_current_due_date,
            'partial',
            p_payment_method,
            p_reference_number,
            COALESCE(p_description, 'Partial payment'),
            v_org_id,
            v_property_id
        )
        RETURNING id INTO v_payment_id;
        
        UPDATE payments
        SET    amount = v_remaining_balance,
                payment_status = 'pending',
                updated_at = CURRENT_TIMESTAMP
        WHERE  id = p_pending_payment_id
                AND organization_id = v_org_id;

    ELSE
        -- Overpayment case
        UPDATE payments
        SET    payment_status = 'paid',
                payment_date = p_payment_date,
                payment_method = p_payment_method,
                reference_number = p_reference_number,
                updated_at = CURRENT_TIMESTAMP,
                amount = v_pending_payment_amount
        WHERE  id = p_pending_payment_id
                AND organization_id = v_org_id
        RETURNING id INTO v_payment_id;
        
        INSERT INTO payments (
            unit_tenancy_id,
            amount,
            payment_date,
            due_date,
            payment_status,
            payment_method,
            reference_number,
            description,
            organization_id,
            property_id
        )
        VALUES (
            p_unit_tenancy_id,
            p_amount - v_pending_payment_amount,
            p_payment_date,
            v_current_due_date,
            'partial',
            p_payment_method,
            p_reference_number,
            COALESCE(p_description, 'Overpayment applied to current period'),
            v_org_id,
            v_property_id
        );
    END IF;

    -- Check if we should create next month's payment
    -- Modified condition to check only non-deposit payments for the total
    IF v_total_paid_for_period >= v_monthly_rent AND 
       v_tenancy_status = 'active' AND
       (v_tenancy_end_date IS NULL OR v_tenancy_end_date > v_current_due_date) THEN
        
        v_next_due_date := v_current_due_date + INTERVAL '30 days';
        
        SELECT EXISTS(
            SELECT 1
            FROM   payments
            WHERE  payments.unit_tenancy_id = p_unit_tenancy_id
                    AND due_date = v_next_due_date
                    AND payment_status IN ('pending', 'overdue')
        ) INTO   v_next_payment_exists;
        
        IF NOT v_next_payment_exists THEN
            v_overpayment := GREATEST(v_total_paid_for_period - v_monthly_rent, 0);
            v_next_interval_amount := GREATEST(v_monthly_rent - v_overpayment, 0);
            
            IF v_next_interval_amount > 0 THEN
                INSERT INTO payments (
                    unit_tenancy_id,
                    amount,
                    due_date,
                    payment_status,
                    description,
                    organization_id,
                    property_id
                )
                VALUES (
                    p_unit_tenancy_id,
                    v_next_interval_amount,
                    v_next_due_date,
                    'pending',
                    'Monthly rent payment',
                    v_org_id,
                    v_property_id
                );
            ELSE
                INSERT INTO payments (
                    unit_tenancy_id,
                    amount,
                    due_date,
                    payment_date,
                    payment_status,
                    description,
                    organization_id,
                    property_id
                )
                VALUES (
                    p_unit_tenancy_id,
                    v_monthly_rent,
                    v_next_due_date,
                    CURRENT_DATE,
                    'paid',
                    'Monthly rent payment (pre-paid)',
                    v_org_id,
                    v_property_id
                );
            END IF;
        END IF;
    END IF;

    RETURN v_payment_id;
END;
$$;


ALTER FUNCTION "public"."process_single_payment"("p_unit_tenancy_id" integer, "p_amount" numeric, "p_payment_date" "date", "p_payment_method" character varying, "p_reference_number" character varying, "p_description" "text", "p_pending_payment_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_unit"("p_unit_id" integer, "p_new_monthly_rent" integer) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$ 
DECLARE
    v_tenant_id integer;
BEGIN
    -- Update the status of the unit to 'available'
    UPDATE public.units 
    SET status = 'available' 
    WHERE id = p_unit_id;

    -- Update the end date and status for the unit tenancy associated with the given unit_id
    UPDATE public.unit_tenancy 
    SET end_date = now(), 
        status = 'ended'
    WHERE unit_id = p_unit_id AND status = 'active';

    -- Retrieve the tenant ID for the remaining active tenancies
    SELECT tenant_id INTO v_tenant_id
    FROM public.unit_tenancy
    WHERE unit_id = p_unit_id AND status = 'active';

    -- Update the monthly rent for all remaining unit tenancies
    UPDATE public.unit_tenancy
    SET monthly_rent = p_new_monthly_rent
    WHERE tenant_id = v_tenant_id AND status = 'active';

    RETURN p_unit_id;
END;
$$;


ALTER FUNCTION "public"."remove_unit"("p_unit_id" integer, "p_new_monthly_rent" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_current_organization"() RETURNS "uuid"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
DECLARE
  organization_id UUID;
BEGIN
  -- Extract the organization_id from the JWT
  SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
  INTO organization_id;

  -- Set the current organization ID for the session
  IF organization_id IS NOT NULL THEN
    PERFORM set_config('myapp.current_organization_id', organization_id::TEXT, TRUE);
    -- Return the organization_id
    RETURN organization_id;
  ELSE
    RAISE EXCEPTION 'Organization ID not found in user_metadata';
  END IF;
END;
$$;


ALTER FUNCTION "public"."set_current_organization"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_organization_for_operations"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    org_id UUID;
BEGIN
    -- Extract organization ID from the JWT claims
    SELECT (current_setting('request.jwt.claims', true)::json -> 'user_metadata' ->> 'organization')::UUID
    INTO org_id;

    -- Set the organization ID in the session
    PERFORM set_config('myapp.current_organization_id', org_id, true);

    -- Proceed with the original operation
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_organization_for_operations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_organization_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.organization_id := (auth.jwt() -> 'user_metadata' ->> 'organization')::uuid;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."set_organization_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_organization_on_login"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$BEGIN
  -- Set the current organization_id using the raw metadata
  PERFORM set_config(
    'myapp.current_organization_id',
    NEW.raw_user_meta_data->>'organization',
    TRUE
  );

  RETURN NEW;
END;$$;


ALTER FUNCTION "public"."set_organization_on_login"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_unit_status_available"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Update the status of the unit associated with the deleted tenant
    UPDATE public.units
    SET status = 'available'
    WHERE id IN (SELECT unit_id FROM public.unit_tenancy WHERE tenant_id = OLD.id);
    
    RETURN OLD;
END;
$$;


ALTER FUNCTION "public"."set_unit_status_available"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_available_units"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE properties
    SET available_units = (SELECT COUNT(*) FROM units WHERE property_id = NEW.property_id AND status = 'available')
    WHERE id = NEW.property_id;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_available_units"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_overdue_payments"() RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  -- Update all pending payments whose due date has passed to 'overdue'
  UPDATE payments
  SET 
    payment_status = 'overdue',
    updated_at = CURRENT_TIMESTAMP
  WHERE 
    payment_status = 'pending' AND
    due_date < CURRENT_DATE;
    
  GET DIAGNOSTICS updated_count = ROW_COUNT;
  
  RAISE NOTICE 'Updated % payments to overdue status', updated_count;
  RETURN updated_count;
END;
$$;


ALTER FUNCTION "public"."update_overdue_payments"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_payment_status"("p_payment_id" integer, "p_status" character varying, "p_reference_number" character varying DEFAULT NULL::character varying) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    UPDATE payment
    SET 
        payment_status = p_status,
        reference_number = COALESCE(p_reference_number, reference_number),
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_payment_id;
END;
$$;


ALTER FUNCTION "public"."update_payment_status"("p_payment_id" integer, "p_status" character varying, "p_reference_number" character varying) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_property_available_units"("p_property_id" integer) RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$BEGIN
    UPDATE properties
    SET available_units = (
        SELECT COUNT(*) 
        FROM units u
        JOIN floors f ON u.floor_id = f.id
        WHERE f.property_id = p_property_id
        AND u.status = 'available'
    )
    WHERE id = p_property_id;
END;$$;


ALTER FUNCTION "public"."update_property_available_units"("p_property_id" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_unit_on_tenant_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  -- Check if the deleted tenant is associated with any unit tenancy
  IF EXISTS (SELECT 1 FROM unit_tenancy WHERE tenant_id = OLD.id) THEN
    -- Perform your update logic here
    -- For example, you might want to update the unit status or log the deletion
    -- Example: Update unit status to 'available' if needed
    UPDATE units
    SET status = 'available'
    WHERE id IN (SELECT unit_id FROM unit_tenancy WHERE tenant_id = OLD.id);
  END IF;

  RETURN NULL; -- Triggers that do not modify the row must return NULL
END;
$$;


ALTER FUNCTION "public"."update_unit_on_tenant_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_unit_status_on_tenant_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Update the availability of the units associated with the deleted tenant
    UPDATE units
    SET status = 'available'
    WHERE id IN (SELECT unit_id FROM unit_tenancy WHERE tenant_id = OLD.id);
    
    RETURN NULL; -- Triggers that do not modify the row must return NULL
END;
$$;


ALTER FUNCTION "public"."update_unit_status_on_tenant_delete"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_tenant_payments"("p_tenant_id" integer, "p_pending_payment_ids" integer[]) RETURNS TABLE("id" integer, "unit_tenancy_id" integer, "payment_status" character varying, "amount" numeric, "description" "text")
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT p.id, p.unit_tenancy_id, p.payment_status, p.amount, p.description
    FROM payments p
    JOIN unit_tenancy ut ON ut.id = p.unit_tenancy_id
    WHERE p.id = ANY(p_pending_payment_ids)
    AND ut.tenant_id = p_tenant_id;
END;
$$;


ALTER FUNCTION "public"."validate_tenant_payments"("p_tenant_id" integer, "p_pending_payment_ids" integer[]) OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."floor_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."floor_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."floor_id_seq" OWNED BY "public"."floors"."id";



CREATE TABLE IF NOT EXISTS "public"."organizations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "code" "text" DEFAULT "concat"("chr"((("floor"(("random"() * (26)::double precision)))::integer + 65)), "chr"((("floor"(("random"() * (26)::double precision)))::integer + 97)), "left"("md5"(("random"())::"text"), 4)) NOT NULL
);


ALTER TABLE "public"."organizations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."payments" (
    "id" integer NOT NULL,
    "unit_tenancy_id" integer,
    "amount" numeric(10,2) NOT NULL,
    "payment_date" "date",
    "due_date" "date" NOT NULL,
    "payment_status" character varying(50),
    "payment_method" character varying(50),
    "reference_number" character varying(100),
    "description" "text",
    "created_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    "organization_id" "uuid" NOT NULL,
    "property_id" integer,
    CONSTRAINT "payment_method_check" CHECK ((("payment_method")::"text" = ANY (ARRAY['cash'::"text", 'bank'::"text", 'mpesa'::"text"]))),
    CONSTRAINT "payment_status_check" CHECK ((("payment_status")::"text" = ANY (ARRAY['pending'::"text", 'paid'::"text", 'overdue'::"text", 'partial'::"text"])))
);


ALTER TABLE "public"."payments" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."payments_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."payments_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."payments_id_seq" OWNED BY "public"."payments"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."property_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."property_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."property_id_seq" OWNED BY "public"."properties"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."tenant_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."tenant_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."tenant_id_seq" OWNED BY "public"."tenants"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."unit_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."unit_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."unit_id_seq" OWNED BY "public"."units"."id";



CREATE SEQUENCE IF NOT EXISTS "public"."unit_tenancy_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "public"."unit_tenancy_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."unit_tenancy_id_seq" OWNED BY "public"."unit_tenancy"."id";



ALTER TABLE ONLY "public"."floors" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."floor_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."payments" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."payments_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."properties" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."property_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."tenants" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."tenant_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."unit_tenancy" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."unit_tenancy_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."units" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."unit_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."floors"
    ADD CONSTRAINT "floor_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."floors"
    ADD CONSTRAINT "floor_property_id_floor_name_key" UNIQUE ("property_id", "floor_name");



ALTER TABLE ONLY "public"."floors"
    ADD CONSTRAINT "floor_property_id_floor_number_key" UNIQUE ("property_id", "floor_number");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "organizations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payment_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."properties"
    ADD CONSTRAINT "property_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenant_id_number_key" UNIQUE ("id_number");



ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "tenant_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."organizations"
    ADD CONSTRAINT "unique_organization_code" UNIQUE ("code");



ALTER TABLE ONLY "public"."units"
    ADD CONSTRAINT "unit_floor_id_unit_number_key" UNIQUE ("floor_id", "unit_number");



ALTER TABLE ONLY "public"."units"
    ADD CONSTRAINT "unit_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."unit_tenancy"
    ADD CONSTRAINT "unit_tenancy_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."unit_tenancy"
    ADD CONSTRAINT "unit_tenancy_unit_id_tenant_id_start_date_key" UNIQUE ("unit_id", "tenant_id", "start_date");



CREATE OR REPLACE TRIGGER "after_tenant_delete" AFTER DELETE ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."set_unit_status_available"();



CREATE OR REPLACE TRIGGER "populate_organization_id" BEFORE INSERT ON "public"."properties" FOR EACH ROW EXECUTE FUNCTION "public"."set_organization_id"();



CREATE OR REPLACE TRIGGER "tenant_delete_trigger" AFTER DELETE ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."update_unit_on_tenant_delete"();



CREATE OR REPLACE TRIGGER "tenant_full_deletion_trigger" AFTER DELETE ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."delete_tenant_and_related_records"();



CREATE OR REPLACE TRIGGER "units_update_trigger" AFTER INSERT OR DELETE OR UPDATE ON "public"."units" FOR EACH ROW EXECUTE FUNCTION "public"."update_available_units"();



CREATE OR REPLACE TRIGGER "update_floor_modtime" BEFORE UPDATE ON "public"."floors" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_org_modtime" BEFORE UPDATE ON "public"."organizations" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_payment_modtime" BEFORE UPDATE ON "public"."payments" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_property_modtime" BEFORE UPDATE ON "public"."properties" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_tenant_modtime" BEFORE UPDATE ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_unit_modtime" BEFORE UPDATE ON "public"."units" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_unit_status" AFTER DELETE ON "public"."tenants" FOR EACH ROW EXECUTE FUNCTION "public"."update_unit_status_on_tenant_delete"();



CREATE OR REPLACE TRIGGER "update_unit_tenancy_modtime" BEFORE UPDATE ON "public"."unit_tenancy" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."floors"
    ADD CONSTRAINT "fk_floors_organization" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "fk_payments_organization" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."properties"
    ADD CONSTRAINT "fk_properties_organization" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "fk_tenants_organization" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."tenants"
    ADD CONSTRAINT "fk_tenants_property" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."unit_tenancy"
    ADD CONSTRAINT "fk_unit_tenancy_organization" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."unit_tenancy"
    ADD CONSTRAINT "fk_unit_tenancy_property" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."units"
    ADD CONSTRAINT "fk_units_organization" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."units"
    ADD CONSTRAINT "fk_units_property" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."floors"
    ADD CONSTRAINT "floor_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payment_unit_tenancy_id_fkey" FOREIGN KEY ("unit_tenancy_id") REFERENCES "public"."unit_tenancy"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."payments"
    ADD CONSTRAINT "payments_property_id_fkey" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."units"
    ADD CONSTRAINT "unit_floor_id_fkey" FOREIGN KEY ("floor_id") REFERENCES "public"."floors"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."unit_tenancy"
    ADD CONSTRAINT "unit_tenancy_tenant_id_fkey" FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."unit_tenancy"
    ADD CONSTRAINT "unit_tenancy_unit_id_fkey" FOREIGN KEY ("unit_id") REFERENCES "public"."units"("id") ON DELETE CASCADE;



CREATE POLICY "floor_organization_policy" ON "public"."floors" TO "authenticated" USING (("organization_id" = ((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'organization'::"text"))::"uuid"));



ALTER TABLE "public"."floors" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."payments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "payments_organization_policy" ON "public"."payments" TO "authenticated" USING (("organization_id" = ((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'organization'::"text"))::"uuid"));



ALTER TABLE "public"."properties" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "properties_organization_policy" ON "public"."properties" TO "authenticated" USING (("organization_id" = ((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'organization'::"text"))::"uuid"));



ALTER TABLE "public"."tenants" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "tenants_organization_policy" ON "public"."tenants" TO "authenticated" USING (("organization_id" = ((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'organization'::"text"))::"uuid"));



ALTER TABLE "public"."unit_tenancy" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "unit_tenancy_organization_policy" ON "public"."unit_tenancy" TO "authenticated" USING (("organization_id" = ((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'organization'::"text"))::"uuid"));



ALTER TABLE "public"."units" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "units_organization_policy" ON "public"."units" USING (("organization_id" = ((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'organization'::"text"))::"uuid"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


CREATE PUBLICATION "supabase_realtime_messages_publication" WITH (publish = 'insert, update, delete, truncate');


ALTER PUBLICATION "supabase_realtime_messages_publication" OWNER TO "supabase_admin";


ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."properties";






GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";









































































































































































































GRANT ALL ON FUNCTION "public"."add_floors_with_units"("property_id" integer, "start_floor" integer, "floor_count" integer, "units_per_floor" integer, "custom_floor_units" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."add_floors_with_units"("property_id" integer, "start_floor" integer, "floor_count" integer, "units_per_floor" integer, "custom_floor_units" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_floors_with_units"("property_id" integer, "start_floor" integer, "floor_count" integer, "units_per_floor" integer, "custom_floor_units" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."add_payment"("p_tenant_id" integer, "p_pending_payment_ids" integer[], "p_amount" numeric, "p_payment_date" "date", "p_payment_method" character varying, "p_reference_number" character varying, "p_description" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."add_payment"("p_tenant_id" integer, "p_pending_payment_ids" integer[], "p_amount" numeric, "p_payment_date" "date", "p_payment_method" character varying, "p_reference_number" character varying, "p_description" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_payment"("p_tenant_id" integer, "p_pending_payment_ids" integer[], "p_amount" numeric, "p_payment_date" "date", "p_payment_method" character varying, "p_reference_number" character varying, "p_description" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."add_paymentt"("unit_tenancy_id" integer, "amount" numeric, "payment_date" "date", "payment_method" character varying, "reference_number" character varying, "description" "text", "is_pending_payment_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."add_paymentt"("unit_tenancy_id" integer, "amount" numeric, "payment_date" "date", "payment_method" character varying, "reference_number" character varying, "description" "text", "is_pending_payment_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."add_paymentt"("unit_tenancy_id" integer, "amount" numeric, "payment_date" "date", "payment_method" character varying, "reference_number" character varying, "description" "text", "is_pending_payment_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_property"("property_name" "text", "property_address" "text", "f_count" integer, "units_p_floor" integer, "start_f" integer, "custom_f_units" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."create_property"("property_name" "text", "property_address" "text", "f_count" integer, "units_p_floor" integer, "start_f" integer, "custom_f_units" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_property"("property_name" "text", "property_address" "text", "f_count" integer, "units_p_floor" integer, "start_f" integer, "custom_f_units" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_property"("property_name" "text", "property_address" "text", "f_count" integer, "units_p_floor" integer, "rent" numeric, "start_f" integer, "custom_f_units" integer, "custom_f_rent" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."create_property"("property_name" "text", "property_address" "text", "f_count" integer, "units_p_floor" integer, "rent" numeric, "start_f" integer, "custom_f_units" integer, "custom_f_rent" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_property"("property_name" "text", "property_address" "text", "f_count" integer, "units_p_floor" integer, "rent" numeric, "start_f" integer, "custom_f_units" integer, "custom_f_rent" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."create_unit_tenancy"("p_property_id" integer, "p_unit_ids" integer[], "p_first_name" character varying, "p_last_name" character varying, "p_monthly_rent" integer, "p_email" character varying, "p_phone" character varying, "p_id_number" character varying, "p_emergency_contact" "text", "p_start_date" "date") TO "anon";
GRANT ALL ON FUNCTION "public"."create_unit_tenancy"("p_property_id" integer, "p_unit_ids" integer[], "p_first_name" character varying, "p_last_name" character varying, "p_monthly_rent" integer, "p_email" character varying, "p_phone" character varying, "p_id_number" character varying, "p_emergency_contact" "text", "p_start_date" "date") TO "authenticated";
GRANT ALL ON FUNCTION "public"."create_unit_tenancy"("p_property_id" integer, "p_unit_ids" integer[], "p_first_name" character varying, "p_last_name" character varying, "p_monthly_rent" integer, "p_email" character varying, "p_phone" character varying, "p_id_number" character varying, "p_emergency_contact" "text", "p_start_date" "date") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_tenant"("t_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."delete_tenant"("t_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_tenant"("t_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_tenant_and_related_records"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_tenant_and_related_records"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_tenant_and_related_records"() TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_tenant_and_update_units"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_tenant_and_update_units"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_tenant_and_update_units"() TO "service_role";



GRANT ALL ON TABLE "public"."floors" TO "anon";
GRANT ALL ON TABLE "public"."floors" TO "authenticated";
GRANT ALL ON TABLE "public"."floors" TO "service_role";



GRANT ALL ON FUNCTION "public"."fetch_floors"() TO "anon";
GRANT ALL ON FUNCTION "public"."fetch_floors"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fetch_floors"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fetch_floorss"("prop_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."fetch_floorss"("prop_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."fetch_floorss"("prop_id" integer) TO "service_role";



GRANT ALL ON TABLE "public"."properties" TO "anon";
GRANT ALL ON TABLE "public"."properties" TO "authenticated";
GRANT ALL ON TABLE "public"."properties" TO "service_role";



GRANT ALL ON FUNCTION "public"."fetch_properties"() TO "anon";
GRANT ALL ON FUNCTION "public"."fetch_properties"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fetch_properties"() TO "service_role";



GRANT ALL ON TABLE "public"."tenants" TO "anon";
GRANT ALL ON TABLE "public"."tenants" TO "authenticated";
GRANT ALL ON TABLE "public"."tenants" TO "service_role";



GRANT ALL ON FUNCTION "public"."fetch_tenants"() TO "anon";
GRANT ALL ON FUNCTION "public"."fetch_tenants"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fetch_tenants"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fetch_tenantss"("prop_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."fetch_tenantss"("prop_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."fetch_tenantss"("prop_id" integer) TO "service_role";



GRANT ALL ON TABLE "public"."unit_tenancy" TO "anon";
GRANT ALL ON TABLE "public"."unit_tenancy" TO "authenticated";
GRANT ALL ON TABLE "public"."unit_tenancy" TO "service_role";



GRANT ALL ON FUNCTION "public"."fetch_unit_tenancy"("prop_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."fetch_unit_tenancy"("prop_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."fetch_unit_tenancy"("prop_id" integer) TO "service_role";



GRANT ALL ON TABLE "public"."units" TO "anon";
GRANT ALL ON TABLE "public"."units" TO "authenticated";
GRANT ALL ON TABLE "public"."units" TO "service_role";



GRANT ALL ON FUNCTION "public"."fetch_units"() TO "anon";
GRANT ALL ON FUNCTION "public"."fetch_units"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."fetch_units"() TO "service_role";



GRANT ALL ON FUNCTION "public"."fetch_unitss"("prop_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."fetch_unitss"("prop_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."fetch_unitss"("prop_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."process_single_payment"("p_unit_tenancy_id" integer, "p_amount" numeric, "p_payment_date" "date", "p_payment_method" character varying, "p_reference_number" character varying, "p_description" "text", "p_pending_payment_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."process_single_payment"("p_unit_tenancy_id" integer, "p_amount" numeric, "p_payment_date" "date", "p_payment_method" character varying, "p_reference_number" character varying, "p_description" "text", "p_pending_payment_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."process_single_payment"("p_unit_tenancy_id" integer, "p_amount" numeric, "p_payment_date" "date", "p_payment_method" character varying, "p_reference_number" character varying, "p_description" "text", "p_pending_payment_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."remove_unit"("p_unit_id" integer, "p_new_monthly_rent" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."remove_unit"("p_unit_id" integer, "p_new_monthly_rent" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."remove_unit"("p_unit_id" integer, "p_new_monthly_rent" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_current_organization"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_current_organization"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_current_organization"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_organization_for_operations"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_organization_for_operations"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_organization_for_operations"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_organization_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_organization_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_organization_id"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_organization_on_login"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_organization_on_login"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_organization_on_login"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_unit_status_available"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_unit_status_available"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_unit_status_available"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_available_units"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_available_units"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_available_units"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_overdue_payments"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_overdue_payments"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_overdue_payments"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_payment_status"("p_payment_id" integer, "p_status" character varying, "p_reference_number" character varying) TO "anon";
GRANT ALL ON FUNCTION "public"."update_payment_status"("p_payment_id" integer, "p_status" character varying, "p_reference_number" character varying) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_payment_status"("p_payment_id" integer, "p_status" character varying, "p_reference_number" character varying) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_property_available_units"("p_property_id" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."update_property_available_units"("p_property_id" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_property_available_units"("p_property_id" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."update_unit_on_tenant_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_unit_on_tenant_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_unit_on_tenant_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_unit_status_on_tenant_delete"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_unit_status_on_tenant_delete"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_unit_status_on_tenant_delete"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."validate_tenant_payments"("p_tenant_id" integer, "p_pending_payment_ids" integer[]) TO "anon";
GRANT ALL ON FUNCTION "public"."validate_tenant_payments"("p_tenant_id" integer, "p_pending_payment_ids" integer[]) TO "authenticated";
GRANT ALL ON FUNCTION "public"."validate_tenant_payments"("p_tenant_id" integer, "p_pending_payment_ids" integer[]) TO "service_role";
























GRANT ALL ON SEQUENCE "public"."floor_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."floor_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."floor_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."organizations" TO "anon";
GRANT ALL ON TABLE "public"."organizations" TO "authenticated";
GRANT ALL ON TABLE "public"."organizations" TO "service_role";



GRANT ALL ON TABLE "public"."payments" TO "anon";
GRANT ALL ON TABLE "public"."payments" TO "authenticated";
GRANT ALL ON TABLE "public"."payments" TO "service_role";



GRANT ALL ON SEQUENCE "public"."payments_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."payments_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."payments_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."property_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."property_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."property_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."tenant_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."tenant_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."tenant_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."unit_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."unit_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."unit_id_seq" TO "service_role";



GRANT ALL ON SEQUENCE "public"."unit_tenancy_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."unit_tenancy_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."unit_tenancy_id_seq" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS  TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES  TO "service_role";






























CREATE OR REPLACE FUNCTION "public"."add_unit_to_tenant"(
  "p_tenant_id" integer,
  "p_unit_id" integer,
  "p_monthly_rent" numeric,
  "p_start_date" date DEFAULT CURRENT_DATE
) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_organization_id UUID;
    v_property_id INTEGER;
    v_unit_tenancy_id INTEGER;
    v_tenant_exists BOOLEAN;
    v_unit_exists BOOLEAN;
    v_unit_available BOOLEAN;
BEGIN
    -- Get current organization ID
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID 
    INTO v_organization_id;

    -- Validate organization ID
    IF v_organization_id IS NULL THEN
        RAISE EXCEPTION 'Organization ID not found in JWT token';
    END IF;

    -- Set configuration for current organization
    PERFORM set_config('myapp.current_organization_id', v_organization_id::TEXT, TRUE);

    -- Check if tenant exists and belongs to the organization
    SELECT EXISTS(
        SELECT 1 FROM tenants 
        WHERE id = p_tenant_id AND organization_id = v_organization_id
    ) INTO v_tenant_exists;
    
    IF NOT v_tenant_exists THEN
        RAISE EXCEPTION 'Tenant does not exist or does not belong to your organization';
    END IF;
    
    -- Check if unit exists and belongs to the organization
    SELECT EXISTS(
        SELECT 1 FROM units 
        WHERE id = p_unit_id AND organization_id = v_organization_id
    ) INTO v_unit_exists;
    
    IF NOT v_unit_exists THEN
        RAISE EXCEPTION 'Unit does not exist or does not belong to your organization';
    END IF;
    
    -- Check if unit is available
    SELECT status = 'available' 
    FROM units 
    WHERE id = p_unit_id
    INTO v_unit_available;
    
    IF NOT v_unit_available THEN
        RAISE EXCEPTION 'Unit % is not available', p_unit_id;
    END IF;
    
    -- Get property_id from the unit
    SELECT property_id
    FROM units
    WHERE id = p_unit_id
    INTO v_property_id;
    
    -- Create unit tenancy record
    INSERT INTO unit_tenancy (
        organization_id,
        property_id,
        unit_id,
        tenant_id,
        start_date,
        monthly_rent,
        status
    ) VALUES (
        v_organization_id,
        v_property_id,
        p_unit_id,
        p_tenant_id,
        p_start_date,
        p_monthly_rent,
        'active'
    ) RETURNING id INTO v_unit_tenancy_id;

    -- Update unit status to occupied
    UPDATE units 
    SET status = 'occupied' 
    WHERE id = p_unit_id;
    
    -- Create pending deposit payment record
    INSERT INTO payments (
        unit_tenancy_id,
        amount,
        due_date,
        payment_status,
        description,
        organization_id,
        property_id
    ) VALUES (
        v_unit_tenancy_id,
        p_monthly_rent, -- Deposit amount equal to monthly rent
        p_start_date,
        'pending',
        'Security deposit payment',
        v_organization_id,
        v_property_id
    );
    
    -- Create pending payment for first month's rent
    INSERT INTO payments (
        unit_tenancy_id,
        amount,
        due_date,
        payment_status,
        description,
        organization_id,
        property_id
    ) VALUES (
        v_unit_tenancy_id,
        p_monthly_rent,
        p_start_date,
        'pending',
        'Monthly rent payment',
        v_organization_id,
        v_property_id
    );

    -- Update property available units count
    PERFORM update_property_available_units(v_property_id);

    RETURN v_unit_tenancy_id;
END;
$$;


ALTER FUNCTION "public"."add_unit_to_tenant"("p_tenant_id" integer, "p_unit_id" integer, "p_monthly_rent" numeric, "p_start_date" date) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."change_tenant_unit"(
  "p_tenant_id" integer,
  "p_old_unit_id" integer,
  "p_new_unit_id" integer,
  "p_monthly_rent" numeric,
  "p_start_date" date DEFAULT CURRENT_DATE
) RETURNS integer
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_organization_id UUID;
    v_property_id INTEGER;
    v_unit_tenancy_id INTEGER;
    v_new_unit_tenancy_id INTEGER;
    v_tenant_exists BOOLEAN;
    v_unit_exists BOOLEAN;
    v_unit_available BOOLEAN;
    v_old_tenancy_exists BOOLEAN;
BEGIN
    -- Get current organization ID
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID 
    INTO v_organization_id;

    -- Validate organization ID
    IF v_organization_id IS NULL THEN
        RAISE EXCEPTION 'Organization ID not found in JWT token';
    END IF;

    -- Set configuration for current organization
    PERFORM set_config('myapp.current_organization_id', v_organization_id::TEXT, TRUE);

    -- Check if tenant exists and belongs to the organization
    SELECT EXISTS(
        SELECT 1 FROM tenants 
        WHERE id = p_tenant_id AND organization_id = v_organization_id
    ) INTO v_tenant_exists;
    
    IF NOT v_tenant_exists THEN
        RAISE EXCEPTION 'Tenant does not exist or does not belong to your organization';
    END IF;
    
    -- Check if the new unit exists and belongs to the organization
    SELECT EXISTS(
        SELECT 1 FROM units 
        WHERE id = p_new_unit_id AND organization_id = v_organization_id
    ) INTO v_unit_exists;
    
    IF NOT v_unit_exists THEN
        RAISE EXCEPTION 'New unit does not exist or does not belong to your organization';
    END IF;
    
    -- Check if the new unit is available
    SELECT status = 'available' 
    FROM units 
    WHERE id = p_new_unit_id
    INTO v_unit_available;
    
    IF NOT v_unit_available THEN
        RAISE EXCEPTION 'New unit % is not available', p_new_unit_id;
    END IF;
    
    -- Check if the old unit tenancy exists
    SELECT EXISTS(
        SELECT 1 FROM unit_tenancy
        WHERE tenant_id = p_tenant_id 
        AND unit_id = p_old_unit_id
        AND status = 'active'
    ) INTO v_old_tenancy_exists;
    
    IF NOT v_old_tenancy_exists THEN
        RAISE EXCEPTION 'No active tenancy found for tenant % in unit %', p_tenant_id, p_old_unit_id;
    END IF;

    -- Get the current unit_tenancy_id
    SELECT id 
    FROM unit_tenancy
    WHERE tenant_id = p_tenant_id 
    AND unit_id = p_old_unit_id
    AND status = 'active'
    INTO v_unit_tenancy_id;
    
    -- Get property_id from the new unit
    SELECT property_id
    FROM units
    WHERE id = p_new_unit_id
    INTO v_property_id;

    -- End the old tenancy
    UPDATE unit_tenancy
    SET 
        end_date = p_start_date,
        status = 'ended',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_unit_tenancy_id;

    -- Create a new tenancy record for the new unit
    INSERT INTO unit_tenancy (
        organization_id,
        property_id,
        unit_id,
        tenant_id,
        start_date,
        monthly_rent,
        status
    ) VALUES (
        v_organization_id,
        v_property_id,
        p_new_unit_id,
        p_tenant_id,
        p_start_date,
        p_monthly_rent,
        'active'
    ) RETURNING id INTO v_new_unit_tenancy_id;

    -- Update old unit status to available
    UPDATE units 
    SET status = 'available' 
    WHERE id = p_old_unit_id;

    -- Update new unit status to occupied
    UPDATE units 
    SET status = 'occupied' 
    WHERE id = p_new_unit_id;

    -- Transfer any remaining security deposit to the new tenancy
    -- Note: This could be handled based on your specific business rules

    -- Create a new pending payment for first month's rent in new unit
    INSERT INTO payments (
        unit_tenancy_id,
        amount,
        due_date,
        payment_status,
        description,
        organization_id,
        property_id
    ) VALUES (
        v_new_unit_tenancy_id,
        p_monthly_rent,
        p_start_date,
        'pending',
        'Monthly rent payment (new unit)',
        v_organization_id,
        v_property_id
    );

    -- Update property available units counts
    PERFORM update_property_available_units(v_property_id);

    RETURN v_new_unit_tenancy_id;
END;
$$;


ALTER FUNCTION "public"."change_tenant_unit"("p_tenant_id" integer, "p_old_unit_id" integer, "p_new_unit_id" integer, "p_monthly_rent" numeric, "p_start_date" date) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_unit_from_tenant"(
  "p_tenant_id" integer,
  "p_unit_id" integer,
  "p_end_date" date DEFAULT CURRENT_DATE
) RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_organization_id UUID;
    v_property_id INTEGER;
    v_unit_tenancy_id INTEGER;
    v_tenant_exists BOOLEAN;
    v_unit_exists BOOLEAN;
    v_tenancy_exists BOOLEAN;
BEGIN
    -- Get current organization ID
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID 
    INTO v_organization_id;

    -- Validate organization ID
    IF v_organization_id IS NULL THEN
        RAISE EXCEPTION 'Organization ID not found in JWT token';
    END IF;

    -- Set configuration for current organization
    PERFORM set_config('myapp.current_organization_id', v_organization_id::TEXT, TRUE);

    -- Check if tenant exists and belongs to the organization
    SELECT EXISTS(
        SELECT 1 FROM tenants 
        WHERE id = p_tenant_id AND organization_id = v_organization_id
    ) INTO v_tenant_exists;
    
    IF NOT v_tenant_exists THEN
        RAISE EXCEPTION 'Tenant does not exist or does not belong to your organization';
    END IF;
    
    -- Check if unit exists and belongs to the organization
    SELECT EXISTS(
        SELECT 1 FROM units 
        WHERE id = p_unit_id AND organization_id = v_organization_id
    ) INTO v_unit_exists;
    
    IF NOT v_unit_exists THEN
        RAISE EXCEPTION 'Unit does not exist or does not belong to your organization';
    END IF;
    
    -- Check if there is an active tenancy for this tenant and unit
    SELECT EXISTS(
        SELECT 1 FROM unit_tenancy
        WHERE tenant_id = p_tenant_id 
        AND unit_id = p_unit_id
        AND status = 'active'
    ) INTO v_tenancy_exists;
    
    IF NOT v_tenancy_exists THEN
        RAISE EXCEPTION 'No active tenancy found for tenant % in unit %', p_tenant_id, p_unit_id;
    END IF;

    -- Get the unit_tenancy_id and property_id
    SELECT ut.id, ut.property_id 
    FROM unit_tenancy ut
    WHERE ut.tenant_id = p_tenant_id 
    AND ut.unit_id = p_unit_id
    AND ut.status = 'active'
    INTO v_unit_tenancy_id, v_property_id;

    -- End the tenancy
    UPDATE unit_tenancy
    SET 
        end_date = p_end_date,
        status = 'ended',
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_unit_tenancy_id;

    -- Update unit status to available
    UPDATE units 
    SET status = 'available' 
    WHERE id = p_unit_id;
    
    -- Mark any pending payments as canceled for this unit_tenancy
    UPDATE payments
    SET 
        payment_status = 'canceled',
        description = description || ' (tenancy ended)',
        updated_at = CURRENT_TIMESTAMP
    WHERE unit_tenancy_id = v_unit_tenancy_id
    AND payment_status IN ('pending', 'overdue');

    -- Update property available units count
    PERFORM update_property_available_units(v_property_id);

    RETURN TRUE;
END;
$$;


ALTER FUNCTION "public"."remove_unit_from_tenant"("p_tenant_id" integer, "p_unit_id" integer, "p_end_date" date) OWNER TO "postgres";


RESET ALL;

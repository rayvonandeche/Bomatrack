-- This migration adds support for tenant group discounts when renting multiple units

-- Table to track tenant discount groups
CREATE TABLE IF NOT EXISTS "public"."tenant_discount_groups" (
    "id" SERIAL PRIMARY KEY,
    "tenant_id" INTEGER NOT NULL,
    "discount_name" VARCHAR(255) NOT NULL,
    "discount_type" VARCHAR(50) NOT NULL CHECK (discount_type IN ('flat', 'percentage')),
    "discount_value" DECIMAL(10, 2) NOT NULL,
    "organization_id" UUID NOT NULL,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY ("tenant_id") REFERENCES "public"."tenants"("id") ON DELETE CASCADE,
    FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE
);

-- Add group_id to unit_tenancy table
ALTER TABLE "public"."unit_tenancy" 
ADD COLUMN IF NOT EXISTS "discount_group_id" INTEGER NULL,
ADD CONSTRAINT "fk_unit_tenancy_discount_group" 
    FOREIGN KEY ("discount_group_id") 
    REFERENCES "public"."tenant_discount_groups"("id") 
    ON DELETE SET NULL;

-- Add a new check to payments table to indicate "bundle payment"
ALTER TABLE "public"."payments"
ADD COLUMN IF NOT EXISTS "is_bundle_payment" BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS "discount_group_id" INTEGER NULL,
ADD CONSTRAINT "fk_payments_discount_group"
    FOREIGN KEY ("discount_group_id")
    REFERENCES "public"."tenant_discount_groups"("id")
    ON DELETE SET NULL;

-- Create a function to create discounted unit tenancy group
CREATE OR REPLACE FUNCTION "public"."create_discounted_tenancy_group"(
    "p_tenant_id" INTEGER,
    "p_unit_ids" INTEGER[],
    "p_discount_name" VARCHAR(255),
    "p_discount_type" VARCHAR(50),
    "p_discount_value" DECIMAL(10, 2),
    "p_monthly_rent" DECIMAL(10, 2),
    "p_start_date" DATE DEFAULT CURRENT_DATE
) RETURNS INTEGER
LANGUAGE "plpgsql"
AS $$
DECLARE
    v_organization_id UUID;
    v_property_id INTEGER;
    v_discount_group_id INTEGER;
    v_unit_tenancy_id INTEGER;
    v_tenant_exists BOOLEAN;
    v_total_standard_rent DECIMAL(10, 2) := 0;
    v_discounted_amount DECIMAL(10, 2);
    v_unit_id INTEGER;
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
    
    -- Get property ID from the first unit (assuming all units are from the same property)
    SELECT property_id
    FROM units
    WHERE id = p_unit_ids[1]
    INTO v_property_id;

    -- Calculate total standard rent (for reference)
    SELECT SUM(rent)
    FROM units
    WHERE id = ANY(p_unit_ids)
    INTO v_total_standard_rent;
    
    -- Create discount group record
    INSERT INTO tenant_discount_groups (
        tenant_id,
        discount_name,
        discount_type,
        discount_value,
        organization_id
    ) VALUES (
        p_tenant_id,
        p_discount_name,
        p_discount_type,
        p_discount_value,
        v_organization_id
    ) RETURNING id INTO v_discount_group_id;
    
    -- Process each unit
    FOREACH v_unit_id IN ARRAY p_unit_ids
    LOOP
        -- Check if unit is available
        IF NOT EXISTS (
            SELECT 1 FROM units 
            WHERE id = v_unit_id 
            AND status = 'available'
            AND organization_id = v_organization_id
        ) THEN
            RAISE EXCEPTION 'Unit % is not available', v_unit_id;
        END IF;
        
        -- Create unit tenancy record with discount group ID
        INSERT INTO unit_tenancy (
            organization_id,
            property_id,
            unit_id,
            tenant_id,
            discount_group_id,
            start_date,
            monthly_rent,
            status
        ) VALUES (
            v_organization_id,
            v_property_id,
            v_unit_id,
            p_tenant_id,
            v_discount_group_id,
            p_start_date,
            p_monthly_rent / array_length(p_unit_ids, 1), -- Divide rent evenly among units for record-keeping
            'active'
        ) RETURNING id INTO v_unit_tenancy_id;

        -- Update unit status to occupied
        UPDATE units 
        SET status = 'occupied' 
        WHERE id = v_unit_id;
    END LOOP;

    -- Create a single bundle payment record for the deposit
    INSERT INTO payments (
        unit_tenancy_id, -- Link to the first unit_tenancy (for reference)
        amount,
        due_date,
        payment_status,
        description,
        organization_id,
        property_id,
        is_bundle_payment,
        discount_group_id
    ) VALUES (
        v_unit_tenancy_id,
        p_monthly_rent, -- Use the discounted amount
        p_start_date,
        'pending',
        'Security deposit payment (Bundled Units: ' || array_length(p_unit_ids, 1) || ')',
        v_organization_id,
        v_property_id,
        TRUE,
        v_discount_group_id
    );
    
    -- Create a single bundle payment record for the first month's rent
    INSERT INTO payments (
        unit_tenancy_id,
        amount,
        due_date,
        payment_status,
        description,
        organization_id,
        property_id,
        is_bundle_payment,
        discount_group_id
    ) VALUES (
        v_unit_tenancy_id,
        p_monthly_rent,
        p_start_date,
        'pending',
        'Monthly rent payment (Bundled Units: ' || array_length(p_unit_ids, 1) || ')',
        v_organization_id,
        v_property_id,
        TRUE,
        v_discount_group_id
    );

    -- Update property available units count
    PERFORM update_property_available_units(v_property_id);

    RETURN v_discount_group_id;
END;
$$;

-- Create a function to get tenant discount groups with units
CREATE OR REPLACE FUNCTION "public"."get_tenant_discount_groups"(
    "p_tenant_id" INTEGER
) RETURNS TABLE (
    "group_id" INTEGER,
    "group_name" VARCHAR,
    "discount_type" VARCHAR,
    "discount_value" DECIMAL,
    "monthly_rent" DECIMAL,
    "unit_ids" INTEGER[],
    "unit_numbers" TEXT[]
)
LANGUAGE "plpgsql"
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        tdg.id AS group_id,
        tdg.discount_name AS group_name,
        tdg.discount_type,
        tdg.discount_value,
        (SELECT SUM(ut.monthly_rent) FROM unit_tenancy ut WHERE ut.discount_group_id = tdg.id) AS monthly_rent,
        array_agg(DISTINCT u.id) AS unit_ids,
        array_agg(DISTINCT u.unit_number) AS unit_numbers
    FROM 
        tenant_discount_groups tdg
    JOIN 
        unit_tenancy ut ON tdg.id = ut.discount_group_id
    JOIN 
        units u ON ut.unit_id = u.id
    WHERE 
        tdg.tenant_id = p_tenant_id
    GROUP BY 
        tdg.id, tdg.discount_name, tdg.discount_type, tdg.discount_value;
END;
$$;
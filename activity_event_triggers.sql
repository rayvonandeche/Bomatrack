-- Trigger for payment status changing to paid
CREATE OR REPLACE FUNCTION public.notify_on_payment_add()
RETURNS TRIGGER AS $$
DECLARE
    v_unit_number TEXT;
    v_tenant_name TEXT;
    v_property_name TEXT;
BEGIN
    -- Only trigger when payment status changes to 'paid'
    IF (TG_OP = 'INSERT' AND NEW.payment_status = 'paid') OR 
       (TG_OP = 'UPDATE' AND OLD.payment_status IN ('pending', 'overdue') AND NEW.payment_status = 'paid') THEN
        -- Get unit and tenant information
        SELECT 
            u.unit_number, 
            p.name,
            CONCAT(t.first_name, ' ', t.last_name)
        INTO 
            v_unit_number,
            v_property_name, 
            v_tenant_name
        FROM unit_tenancy ut
        JOIN units u ON ut.unit_id = u.id
        JOIN tenants t ON ut.tenant_id = t.id
        JOIN properties p ON u.property_id = p.id
        WHERE ut.id = NEW.unit_tenancy_id;

        -- Insert into activity_events
        PERFORM create_activity_event(
            p_event_type := 'payment_received',
            p_entity_type := 'payment',
            p_entity_id := NEW.id,
            p_property_id := NEW.property_id,
            p_unit_id := (SELECT unit_id FROM unit_tenancy WHERE id = NEW.unit_tenancy_id),
            p_tenant_id := (SELECT tenant_id FROM unit_tenancy WHERE id = NEW.unit_tenancy_id),
            p_title := 'Payment Received',
            p_description := CONCAT('Payment of ', NEW.amount, ' received for Unit ', v_unit_number, ' from ', v_tenant_name),
            p_data := jsonb_build_object(
                'payment_amount', NEW.amount,
                'payment_method', NEW.payment_method,
                'reference_number', NEW.reference_number,
                'unit_number', v_unit_number,
                'tenant_name', v_tenant_name,
                'property_name', v_property_name
            )
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS payment_notification_trigger ON payments;

CREATE TRIGGER payment_notification_trigger
AFTER INSERT OR UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION public.notify_on_payment_add();

-- Trigger for new tenant assignment
CREATE OR REPLACE FUNCTION public.notify_on_tenant_assignment()
RETURNS TRIGGER AS $$
DECLARE
    v_unit_number TEXT;
    v_tenant_name TEXT;
    v_property_name TEXT;
BEGIN
    -- Get unit and tenant information
    SELECT 
        u.unit_number, 
        p.name,
        CONCAT(t.first_name, ' ', t.last_name)
    INTO 
        v_unit_number,
        v_property_name, 
        v_tenant_name
    FROM units u
    JOIN tenants t ON NEW.tenant_id = t.id
    JOIN properties p ON NEW.property_id = p.id
    WHERE u.id = NEW.unit_id;

    -- Insert into activity_events
    PERFORM create_activity_event(
        p_event_type := 'tenant_assigned',
        p_entity_type := 'unit_tenancy',
        p_entity_id := NEW.id,
        p_property_id := NEW.property_id,
        p_unit_id := NEW.unit_id,
        p_tenant_id := NEW.tenant_id,
        p_title := 'New Tenant Assigned',
        p_description := CONCAT(v_tenant_name, ' has been assigned to Unit ', v_unit_number, ' at ', v_property_name),
        p_data := jsonb_build_object(
            'tenant_name', v_tenant_name,
            'unit_number', v_unit_number,
            'monthly_rent', NEW.monthly_rent,
            'start_date', NEW.start_date,
            'property_name', v_property_name
        )
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tenant_assignment_notification_trigger
AFTER INSERT ON unit_tenancy
FOR EACH ROW
EXECUTE FUNCTION public.notify_on_tenant_assignment();

-- Trigger for tenant vacating a unit
CREATE OR REPLACE FUNCTION public.notify_on_tenant_vacate()
RETURNS TRIGGER AS $$
DECLARE
    v_unit_number TEXT;
    v_tenant_name TEXT;
    v_property_name TEXT;
BEGIN
    -- Only trigger when status is changed to 'ended'
    IF OLD.status = 'active' AND NEW.status = 'ended' THEN
        -- Get unit and tenant information
        SELECT 
            u.unit_number, 
            p.name,
            CONCAT(t.first_name, ' ', t.last_name)
        INTO 
            v_unit_number,
            v_property_name, 
            v_tenant_name
        FROM units u
        JOIN tenants t ON NEW.tenant_id = t.id
        JOIN properties p ON NEW.property_id = p.id
        WHERE u.id = NEW.unit_id;

        -- Insert into activity_events
        PERFORM create_activity_event(
            p_event_type := 'tenant_vacated',
            p_entity_type := 'unit_tenancy',
            p_entity_id := NEW.id,
            p_property_id := NEW.property_id,
            p_unit_id := NEW.unit_id,
            p_tenant_id := NEW.tenant_id,
            p_title := 'Tenant Vacated',
            p_description := CONCAT(v_tenant_name, ' has vacated Unit ', v_unit_number, ' at ', v_property_name),
            p_data := jsonb_build_object(
                'tenant_name', v_tenant_name,
                'unit_number', v_unit_number,
                'end_date', NEW.end_date,
                'property_name', v_property_name
            ),
            p_requires_action := true
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tenant_vacate_notification_trigger
AFTER UPDATE ON unit_tenancy
FOR EACH ROW
EXECUTE FUNCTION public.notify_on_tenant_vacate();

-- Trigger for overdue payments
CREATE OR REPLACE FUNCTION public.notify_on_payment_overdue()
RETURNS TRIGGER AS $$
DECLARE
    v_unit_number TEXT;
    v_tenant_name TEXT;
    v_property_name TEXT;
BEGIN
    -- Only trigger when payment status changes to 'overdue'
    IF OLD.payment_status != 'overdue' AND NEW.payment_status = 'overdue' THEN
        -- Get unit and tenant information
        SELECT 
            u.unit_number, 
            p.name,
            CONCAT(t.first_name, ' ', t.last_name)
        INTO 
            v_unit_number,
            v_property_name, 
            v_tenant_name
        FROM unit_tenancy ut
        JOIN units u ON ut.unit_id = u.id
        JOIN tenants t ON ut.tenant_id = t.id
        JOIN properties p ON u.property_id = p.id
        WHERE ut.id = NEW.unit_tenancy_id;

        -- Insert into activity_events
        PERFORM create_activity_event(
            p_event_type := 'payment_overdue',
            p_entity_type := 'payment',
            p_entity_id := NEW.id,
            p_property_id := NEW.property_id,
            p_unit_id := (SELECT unit_id FROM unit_tenancy WHERE id = NEW.unit_tenancy_id),
            p_tenant_id := (SELECT tenant_id FROM unit_tenancy WHERE id = NEW.unit_tenancy_id),
            p_title := 'Payment Overdue',
            p_description := CONCAT('Payment of ', NEW.amount, ' for Unit ', v_unit_number, ' from ', v_tenant_name, ' is overdue'),
            p_data := jsonb_build_object(
                'payment_amount', NEW.amount,
                'due_date', NEW.due_date,
                'days_overdue', (CURRENT_DATE - NEW.due_date::date),
                'unit_number', v_unit_number,
                'tenant_name', v_tenant_name,
                'property_name', v_property_name
            ),
            p_requires_action := true
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER payment_overdue_notification_trigger
AFTER UPDATE ON payments
FOR EACH ROW
EXECUTE FUNCTION public.notify_on_payment_overdue();

-- Trigger for new property
CREATE OR REPLACE FUNCTION public.notify_on_property_add()
RETURNS TRIGGER AS $$
BEGIN
    -- Insert into activity_events
    PERFORM create_activity_event(
        p_event_type := 'property_added',
        p_entity_type := 'property',
        p_entity_id := NEW.id,
        p_property_id := NEW.id,
        p_title := 'Property Added',
        p_description := CONCAT('New property "', NEW.name, '" has been added at ', NEW.address),
        p_data := jsonb_build_object(
            'property_name', NEW.name,
            'property_address', NEW.address,
            'total_units', NEW.total_units
        )
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER property_add_notification_trigger
AFTER INSERT ON properties
FOR EACH ROW
EXECUTE FUNCTION public.notify_on_property_add();
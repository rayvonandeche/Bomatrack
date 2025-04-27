-- Create activity_events table for tracking notifications
CREATE TABLE IF NOT EXISTS "public"."activity_events" (
    "id" SERIAL PRIMARY KEY,
    "organization_id" UUID NOT NULL,
    "event_type" VARCHAR(50) NOT NULL,
    "entity_type" VARCHAR(50) NOT NULL, 
    "entity_id" INTEGER NOT NULL,
    "property_id" INTEGER,
    "unit_id" INTEGER,
    "tenant_id" INTEGER,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "data" JSONB,
    "is_read" BOOLEAN DEFAULT FALSE,
    "requires_action" BOOLEAN DEFAULT FALSE,
    "created_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add organization foreign key
ALTER TABLE ONLY "public"."activity_events"
    ADD CONSTRAINT "fk_activity_events_organization" FOREIGN KEY ("organization_id") REFERENCES "public"."organizations"("id") ON DELETE CASCADE;

-- Add property foreign key if exists
ALTER TABLE ONLY "public"."activity_events"
    ADD CONSTRAINT "fk_activity_events_property" FOREIGN KEY ("property_id") REFERENCES "public"."properties"("id") ON DELETE CASCADE;

-- Add indexes for better performance
CREATE INDEX "idx_activity_events_organization_id" ON "public"."activity_events" ("organization_id");
CREATE INDEX "idx_activity_events_property_id" ON "public"."activity_events" ("property_id");
CREATE INDEX "idx_activity_events_created_at" ON "public"."activity_events" ("created_at");
CREATE INDEX "idx_activity_events_event_type" ON "public"."activity_events" ("event_type");
CREATE INDEX "idx_activity_events_entity" ON "public"."activity_events" ("entity_type", "entity_id");

-- Enable RLS
ALTER TABLE "public"."activity_events" ENABLE ROW LEVEL SECURITY;

-- Add RLS policy
CREATE POLICY "activity_events_organization_policy" ON "public"."activity_events" 
  TO "authenticated" USING (("organization_id" = ((("auth"."jwt"() -> 'user_metadata'::"text") ->> 'organization'::"text"))::"uuid"));

-- Add updated_at trigger
CREATE TRIGGER "update_activity_events_modtime" BEFORE UPDATE ON "public"."activity_events" 
  FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();

-- Add the organization_id trigger
CREATE TRIGGER "populate_organization_id" BEFORE INSERT ON "public"."activity_events" 
  FOR EACH ROW EXECUTE FUNCTION "public"."set_organization_id"();

-- Create a function to add a new activity event
CREATE OR REPLACE FUNCTION "public"."create_activity_event"(
    "p_event_type" VARCHAR(50),
    "p_entity_type" VARCHAR(50),
    "p_entity_id" INTEGER,
    "p_property_id" INTEGER,
    "p_unit_id" INTEGER DEFAULT NULL,
    "p_tenant_id" INTEGER DEFAULT NULL,
    "p_title" TEXT,
    "p_description" TEXT,
    "p_data" JSONB DEFAULT NULL,
    "p_requires_action" BOOLEAN DEFAULT FALSE
) RETURNS INTEGER
LANGUAGE "plpgsql"
AS $$
DECLARE
    v_organization_id UUID;
    v_event_id INTEGER;
BEGIN
    -- Get organization ID from JWT
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
    INTO v_organization_id;

    IF v_organization_id IS NULL THEN
        RAISE EXCEPTION 'Organization ID not found in JWT token';
    END IF;

    -- Set configuration for current organization
    PERFORM set_config('myapp.current_organization_id', v_organization_id::TEXT, TRUE);

    -- Insert the activity event
    INSERT INTO activity_events (
        organization_id,
        event_type,
        entity_type,
        entity_id,
        property_id,
        unit_id,
        tenant_id,
        title,
        description,
        data,
        requires_action
    ) VALUES (
        v_organization_id,
        p_event_type,
        p_entity_type,
        p_entity_id,
        p_property_id,
        p_unit_id,
        p_tenant_id,
        p_title,
        p_description,
        p_data,
        p_requires_action
    ) RETURNING id INTO v_event_id;

    RETURN v_event_id;
END;
$$;

-- Create a function to fetch recent activity
CREATE OR REPLACE FUNCTION "public"."fetch_recent_activity"(
    "p_limit" INTEGER DEFAULT 10,
    "p_property_id" INTEGER DEFAULT NULL
) RETURNS SETOF "public"."activity_events"
LANGUAGE "plpgsql"
AS $$
DECLARE
    v_organization_id UUID;
BEGIN
    -- Get organization ID from JWT
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
    INTO v_organization_id;

    IF v_organization_id IS NULL THEN
        RAISE EXCEPTION 'Organization ID not found in JWT token';
    END IF;

    -- Set configuration for current organization
    PERFORM set_config('myapp.current_organization_id', v_organization_id::TEXT, TRUE);

    -- Return filtered activity events
    IF p_property_id IS NULL THEN
        RETURN QUERY
        SELECT *
        FROM activity_events
        WHERE organization_id = v_organization_id
        ORDER BY created_at DESC
        LIMIT p_limit;
    ELSE
        RETURN QUERY
        SELECT *
        FROM activity_events
        WHERE organization_id = v_organization_id
          AND property_id = p_property_id
        ORDER BY created_at DESC
        LIMIT p_limit;
    END IF;
END;
$$;

-- Create a function to mark events as read
CREATE OR REPLACE FUNCTION "public"."mark_activity_as_read"(
    "p_event_ids" INTEGER[]
) RETURNS VOID
LANGUAGE "plpgsql"
AS $$
DECLARE
    v_organization_id UUID;
BEGIN
    -- Get organization ID from JWT
    SELECT (auth.jwt() -> 'user_metadata' ->> 'organization')::UUID
    INTO v_organization_id;

    IF v_organization_id IS NULL THEN
        RAISE EXCEPTION 'Organization ID not found in JWT token';
    END IF;

    -- Set configuration for current organization
    PERFORM set_config('myapp.current_organization_id', v_organization_id::TEXT, TRUE);

    -- Update the is_read status
    UPDATE activity_events
    SET is_read = TRUE,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = ANY(p_event_ids)
      AND organization_id = v_organization_id;
END;
$$;
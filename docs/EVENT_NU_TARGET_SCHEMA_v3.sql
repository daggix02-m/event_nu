-- Event Nu target logical schema
-- DOCUMENTATION ONLY. Do not apply directly to production without review.
-- This is a forward-looking target schema derived from the implementation
-- specification; it is intentionally separate from the current migration history.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TYPE user_role AS ENUM ('user', 'admin');
CREATE TYPE user_status AS ENUM ('active', 'suspended', 'deactivated');
CREATE TYPE organizer_application_status AS ENUM ('pending', 'approved', 'rejected', 'needs_more_information', 'withdrawn');
CREATE TYPE organizer_status AS ENUM ('active', 'suspended', 'archived');
CREATE TYPE venue_status AS ENUM ('active', 'under_review', 'disabled', 'archived');
CREATE TYPE media_kind AS ENUM ('event_poster', 'event_teaser', 'event_gallery', 'organizer_logo', 'avatar', 'story');
CREATE TYPE media_status AS ENUM ('pending', 'processing', 'ready', 'failed');
CREATE TYPE event_status AS ENUM ('draft', 'published', 'cancelled', 'completed', 'archived');
CREATE TYPE moderation_status AS ENUM ('clean', 'reported', 'under_review', 'blocked', 'restored');
CREATE TYPE event_action_type AS ENUM ('open_entry', 'reservation', 'external_link', 'contact');
CREATE TYPE featured_section AS ENUM ('editors_choice', 'trending', 'new_and_noteworthy');
CREATE TYPE comment_status AS ENUM ('visible', 'hidden', 'blocked', 'deleted');
CREATE TYPE rsvp_status AS ENUM ('confirmed', 'waitlisted', 'cancelled', 'attended', 'no_show');
CREATE TYPE order_status AS ENUM ('pending', 'paid', 'failed', 'cancelled', 'refunded');
CREATE TYPE ticket_status AS ENUM ('issued', 'used', 'cancelled', 'refunded');
CREATE TYPE payment_status AS ENUM ('pending', 'authorized', 'paid', 'failed', 'refunded', 'cancelled');
CREATE TYPE review_status AS ENUM ('published', 'hidden', 'blocked', 'deleted');
CREATE TYPE report_entity_type AS ENUM ('event', 'user', 'venue', 'comment', 'organizer');
CREATE TYPE report_status AS ENUM ('open', 'under_review', 'resolved', 'rejected');
CREATE TYPE notification_type AS ENUM ('event_reminder', 'event_update', 'organizer_update', 'comment', 'like', 'follow', 'rsvp', 'ticket', 'moderation', 'system');
CREATE TYPE reminder_status AS ENUM ('scheduled', 'sent', 'cancelled', 'failed');
CREATE TYPE device_platform AS ENUM ('ios', 'android');
CREATE TYPE idempotency_status AS ENUM ('processing', 'completed', 'failed');
CREATE TYPE magic_link_purpose AS ENUM ('login', 'verify', 'reset_password');

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  password_hash text,
  username text UNIQUE,
  bio text,
  photo_url text,
  role user_role NOT NULL DEFAULT 'user',
  is_verified boolean NOT NULL DEFAULT false,
  privacy jsonb NOT NULL DEFAULT '{}',
  status user_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE magic_link_tokens (
  token_hash text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purpose magic_link_purpose NOT NULL,
  expires_at timestamptz NOT NULL,
  used_at timestamptz
);

CREATE TABLE auth_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_hash text NOT NULL UNIQUE,
  user_agent text,
  ip_hash text,
  device_name text,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE organizer_applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  requested_name text NOT NULL,
  requested_slug text,
  bio text,
  supporting_data jsonb NOT NULL DEFAULT '{}',
  status organizer_application_status NOT NULL DEFAULT 'pending',
  reviewed_by uuid REFERENCES users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  review_notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE organizers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  bio text,
  logo_media_id uuid,
  profile jsonb NOT NULL DEFAULT '{}',
  status organizer_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  name text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE venues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_id uuid REFERENCES organizers(id) ON DELETE RESTRICT,
  name text NOT NULL,
  address text,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  place_id text,
  city text,
  country_code text,
  metadata jsonb NOT NULL DEFAULT '{}',
  status venue_status NOT NULL DEFAULT 'active',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT venues_latitude_chk CHECK (latitude BETWEEN -90 AND 90),
  CONSTRAINT venues_longitude_chk CHECK (longitude BETWEEN -180 AND 180)
);

CREATE TABLE media_assets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  uploader_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  kind media_kind NOT NULL,
  storage_bucket text NOT NULL,
  storage_key text NOT NULL,
  content_type text NOT NULL,
  byte_size bigint,
  width integer,
  height integer,
  blurhash text,
  status media_status NOT NULL DEFAULT 'pending',
  error_message text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE media_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  media_asset_id uuid NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
  variant text NOT NULL,
  density text NOT NULL DEFAULT '1x',
  format text NOT NULL,
  width integer NOT NULL,
  height integer NOT NULL,
  storage_key text NOT NULL,
  cdn_url text NOT NULL,
  byte_size bigint,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (media_asset_id, variant, density, format)
);

CREATE TABLE media_processing_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  media_asset_id uuid NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'queued',
  attempts integer NOT NULL DEFAULT 0,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE organizers
  ADD CONSTRAINT organizers_logo_media_fk
  FOREIGN KEY (logo_media_id) REFERENCES media_assets(id) ON DELETE SET NULL;

CREATE TABLE events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organizer_id uuid NOT NULL REFERENCES organizers(id) ON DELETE RESTRICT,
  venue_id uuid REFERENCES venues(id) ON DELETE SET NULL,
  category_id uuid REFERENCES categories(id) ON DELETE SET NULL,
  title text NOT NULL,
  description text,
  poster_media_id uuid REFERENCES media_assets(id) ON DELETE SET NULL,
  teaser_media_id uuid REFERENCES media_assets(id) ON DELETE SET NULL,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz,
  price_is_free boolean NOT NULL DEFAULT false,
  price_display text,
  action_type event_action_type NOT NULL DEFAULT 'open_entry',
  action_target text,
  status event_status NOT NULL DEFAULT 'draft',
  moderation_status moderation_status NOT NULL DEFAULT 'clean',
  featured featured_section,
  max_attendees integer,
  search_vector tsvector GENERATED ALWAYS AS (
    to_tsvector('english', coalesce(title, '') || ' ' || coalesce(description, ''))
  ) STORED,
  embedding vector(1536),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT events_end_after_start_chk CHECK (ends_at IS NULL OR ends_at >= starts_at),
  CONSTRAINT events_max_attendees_chk CHECK (max_attendees IS NULL OR max_attendees > 0)
);

CREATE TABLE event_gallery_items (
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  media_asset_id uuid NOT NULL REFERENCES media_assets(id) ON DELETE CASCADE,
  sort_order integer NOT NULL DEFAULT 0,
  PRIMARY KEY (event_id, media_asset_id)
);

CREATE TABLE comments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES comments(id) ON DELETE CASCADE,
  body text NOT NULL,
  status comment_status NOT NULL DEFAULT 'visible',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE likes (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, event_id)
);

CREATE TABLE save_folders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE saves (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  folder_id uuid REFERENCES save_folders(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, event_id)
);

CREATE TABLE shares (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  channel text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE organizer_follows (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  organizer_id uuid NOT NULL REFERENCES organizers(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, organizer_id)
);

CREATE TABLE event_rsvps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status rsvp_status NOT NULL DEFAULT 'confirmed',
  quantity integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  cancelled_at timestamptz,
  UNIQUE (user_id, event_id),
  CONSTRAINT event_rsvps_quantity_chk CHECK (quantity > 0)
);

CREATE TABLE ticket_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  price_minor bigint NOT NULL,
  currency char(3) NOT NULL,
  quantity_total integer,
  quantity_sold integer NOT NULL DEFAULT 0,
  sales_start timestamptz,
  sales_end timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ticket_types_price_chk CHECK (price_minor >= 0),
  CONSTRAINT ticket_types_quantity_chk CHECK (quantity_total IS NULL OR quantity_total >= 0),
  CONSTRAINT ticket_types_sold_chk CHECK (quantity_sold >= 0),
  CONSTRAINT ticket_types_sold_le_total_chk CHECK (quantity_total IS NULL OR quantity_sold <= quantity_total),
  CONSTRAINT ticket_types_sales_window_chk CHECK (sales_end IS NULL OR sales_start IS NULL OR sales_end >= sales_start)
);

-- C2: atomic inventory reservation. The Go service calls this inside the order
-- transaction instead of doing a read-then-write of quantity_sold. Returns true
-- and reserves the quantity when inventory is available (or unlimited); returns
-- false and reserves nothing otherwise. This is the only sanctioned way to move
-- quantity_sold for a purchase — never issue a raw UPDATE from application code.
CREATE OR REPLACE FUNCTION reserve_ticket_inventory(
  p_ticket_type_id uuid,
  p_quantity integer
) RETURNS boolean
LANGUAGE plpgsql
AS $$
DECLARE
  v_reserved boolean;
BEGIN
  IF p_quantity <= 0 THEN
    RAISE EXCEPTION 'reserve_ticket_inventory: quantity must be positive';
  END IF;

  UPDATE ticket_types
  SET quantity_sold = quantity_sold + p_quantity
  WHERE id = p_ticket_type_id
    AND is_active
    AND (quantity_total IS NULL OR quantity_sold + p_quantity <= quantity_total)
  RETURNING true INTO v_reserved;

  RETURN coalesce(v_reserved, false);
END;
$$;

-- Mirror release path for cancellations/refunds prior to the ticket being used.
CREATE OR REPLACE FUNCTION release_ticket_inventory(
  p_ticket_type_id uuid,
  p_quantity integer
) RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  IF p_quantity <= 0 THEN
    RAISE EXCEPTION 'release_ticket_inventory: quantity must be positive';
  END IF;

  UPDATE ticket_types
  SET quantity_sold = GREATEST(quantity_sold - p_quantity, 0)
  WHERE id = p_ticket_type_id;
END;
$$;

CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
  status order_status NOT NULL DEFAULT 'pending',
  currency char(3) NOT NULL,
  subtotal_minor bigint NOT NULL,
  total_minor bigint NOT NULL,
  payment_provider text,
  provider_ref text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  paid_at timestamptz,
  cancelled_at timestamptz,
  CONSTRAINT orders_amounts_chk CHECK (subtotal_minor >= 0 AND total_minor >= 0)
);

CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  ticket_type_id uuid NOT NULL REFERENCES ticket_types(id) ON DELETE RESTRICT,
  quantity integer NOT NULL,
  currency char(3) NOT NULL,
  unit_price bigint NOT NULL,
  subtotal bigint NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT order_items_quantity_chk CHECK (quantity > 0),
  CONSTRAINT order_items_price_chk CHECK (unit_price >= 0 AND subtotal >= 0)
);

CREATE TABLE tickets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_item_id uuid NOT NULL REFERENCES order_items(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE RESTRICT,
  ticket_type_id uuid NOT NULL REFERENCES ticket_types(id) ON DELETE RESTRICT,
  code_hash text NOT NULL UNIQUE,
  status ticket_status NOT NULL DEFAULT 'issued',
  issued_at timestamptz NOT NULL DEFAULT now(),
  used_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE RESTRICT,
  provider text NOT NULL,
  provider_payment_id text NOT NULL,
  status payment_status NOT NULL DEFAULT 'pending',
  amount_minor bigint NOT NULL,
  currency char(3) NOT NULL,
  raw_reference jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  paid_at timestamptz,
  failed_at timestamptz,
  UNIQUE (provider, provider_payment_id),
  CONSTRAINT payments_amount_chk CHECK (amount_minor >= 0)
);

-- C3: currency consistency across the purchase chain. CHECK constraints cannot
-- reference other tables, so this invariant is enforced with triggers instead.
-- The Go service must still validate the same invariant before commit — this is
-- the database backstop, not the primary defense.

CREATE OR REPLACE FUNCTION enforce_order_item_currency() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_currency char(3);
  v_ticket_currency char(3);
BEGIN
  SELECT currency INTO v_order_currency FROM orders WHERE id = NEW.order_id;
  SELECT currency INTO v_ticket_currency FROM ticket_types WHERE id = NEW.ticket_type_id;

  IF v_order_currency IS NULL OR v_ticket_currency IS NULL THEN
    RAISE EXCEPTION 'enforce_order_item_currency: referenced order or ticket_type not found';
  END IF;

  IF NEW.currency IS DISTINCT FROM v_order_currency THEN
    RAISE EXCEPTION 'order_item currency % does not match order currency %', NEW.currency, v_order_currency;
  END IF;

  IF NEW.currency IS DISTINCT FROM v_ticket_currency THEN
    RAISE EXCEPTION 'order_item currency % does not match ticket_type currency %', NEW.currency, v_ticket_currency;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER order_items_currency_chk
  BEFORE INSERT OR UPDATE OF currency, order_id, ticket_type_id ON order_items
  FOR EACH ROW
  EXECUTE FUNCTION enforce_order_item_currency();

CREATE OR REPLACE FUNCTION enforce_payment_currency() RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_currency char(3);
BEGIN
  SELECT currency INTO v_order_currency FROM orders WHERE id = NEW.order_id;

  IF v_order_currency IS NULL THEN
    RAISE EXCEPTION 'enforce_payment_currency: referenced order not found';
  END IF;

  IF NEW.currency IS DISTINCT FROM v_order_currency THEN
    RAISE EXCEPTION 'payment currency % does not match order currency %', NEW.currency, v_order_currency;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER payments_currency_chk
  BEFORE INSERT OR UPDATE OF currency, order_id ON payments
  FOR EACH ROW
  EXECUTE FUNCTION enforce_payment_currency();

CREATE TABLE reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating smallint NOT NULL,
  body text,
  status review_status NOT NULL DEFAULT 'published',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  UNIQUE (user_id, event_id),
  CONSTRAINT reviews_rating_chk CHECK (rating BETWEEN 1 AND 5)
);

CREATE TABLE reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  entity_type report_entity_type NOT NULL,
  entity_id uuid NOT NULL,
  reason_code text NOT NULL,
  description text,
  status report_status NOT NULL DEFAULT 'open',
  assigned_to uuid REFERENCES users(id) ON DELETE SET NULL,
  resolution text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE TABLE notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type notification_type NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb NOT NULL DEFAULT '{}',
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE event_reminders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  remind_at timestamptz NOT NULL,
  status reminder_status NOT NULL DEFAULT 'scheduled',
  notification_id uuid REFERENCES notifications(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  sent_at timestamptz,
  UNIQUE (user_id, event_id, remind_at)
);

CREATE TABLE user_devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  platform device_platform NOT NULL,
  push_token text NOT NULL,
  device_name text,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz
);

CREATE TABLE stories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  media_asset_id uuid NOT NULL REFERENCES media_assets(id) ON DELETE RESTRICT,
  category text,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '24 hours'
);

CREATE UNLOGGED TABLE story_views (
  story_id uuid NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
  viewer_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  viewed_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (story_id, viewer_id)
);

CREATE TABLE announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  message text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE pages (
  slug text PRIMARY KEY,
  content jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES users(id) ON DELETE SET NULL
);

CREATE UNLOGGED TABLE rate_limits (
  key text PRIMARY KEY,
  count integer NOT NULL DEFAULT 1,
  window_start timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE idempotency_keys (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  key text NOT NULL,
  request_hash text NOT NULL,
  operation text NOT NULL,
  status idempotency_status NOT NULL DEFAULT 'processing',
  response_code integer,
  response_body jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  UNIQUE (user_id, key)
);

CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX auth_sessions_user_idx ON auth_sessions(user_id);
CREATE INDEX auth_sessions_active_idx ON auth_sessions(user_id, expires_at) WHERE revoked_at IS NULL;
CREATE INDEX organizer_applications_status_idx ON organizer_applications(status, created_at);
CREATE INDEX organizer_applications_user_idx ON organizer_applications(user_id, created_at);
CREATE INDEX organizers_owner_idx ON organizers(owner_user_id);
CREATE INDEX venues_organizer_idx ON venues(organizer_id);
CREATE INDEX venues_status_idx ON venues(status);
CREATE INDEX media_assets_uploader_idx ON media_assets(uploader_id);
CREATE INDEX media_assets_status_idx ON media_assets(status);
CREATE INDEX media_variants_asset_idx ON media_variants(media_asset_id);
CREATE INDEX media_jobs_status_idx ON media_processing_jobs(status, updated_at);
CREATE INDEX events_organizer_idx ON events(organizer_id);
CREATE INDEX events_venue_idx ON events(venue_id);
CREATE INDEX events_category_idx ON events(category_id);
CREATE INDEX events_starts_at_idx ON events(starts_at) WHERE deleted_at IS NULL;
CREATE INDEX events_status_idx ON events(status) WHERE deleted_at IS NULL;
CREATE INDEX events_moderation_idx ON events(moderation_status) WHERE deleted_at IS NULL;
CREATE INDEX events_search_idx ON events USING GIN(search_vector);
-- m/ef_construction are initial targets; benchmark and tune against corpus size,
-- build time, recall, and query latency before production. hnsw.ef_search is a
-- separate, query-time GUC and is not set here.
CREATE INDEX events_embedding_idx ON events USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);
CREATE INDEX comments_event_idx ON comments(event_id, created_at);
CREATE INDEX comments_user_idx ON comments(user_id, created_at);
CREATE INDEX likes_event_idx ON likes(event_id);
CREATE INDEX saves_user_idx ON saves(user_id, created_at);
CREATE INDEX organizer_follows_organizer_idx ON organizer_follows(organizer_id);
CREATE INDEX event_rsvps_event_idx ON event_rsvps(event_id, status);
CREATE INDEX event_rsvps_user_idx ON event_rsvps(user_id, status);
CREATE INDEX ticket_types_event_idx ON ticket_types(event_id, is_active);
CREATE INDEX orders_user_idx ON orders(user_id, created_at);
CREATE INDEX orders_event_idx ON orders(event_id, created_at);
CREATE INDEX order_items_order_idx ON order_items(order_id);
CREATE INDEX tickets_user_idx ON tickets(user_id, status);
CREATE INDEX tickets_event_idx ON tickets(event_id, status);
CREATE INDEX reviews_event_idx ON reviews(event_id, status);
CREATE INDEX reports_queue_idx ON reports(status, created_at);
CREATE INDEX reports_target_idx ON reports(entity_type, entity_id, created_at);
CREATE INDEX notifications_user_idx ON notifications(user_id, created_at DESC);
CREATE INDEX notifications_unread_idx ON notifications(user_id, created_at DESC) WHERE read_at IS NULL;
CREATE INDEX reminders_due_idx ON event_reminders(remind_at, status);
CREATE INDEX devices_user_idx ON user_devices(user_id, revoked_at);
CREATE INDEX stories_active_idx ON stories(user_id, expires_at);
CREATE INDEX stories_media_asset_idx ON stories(media_asset_id);
CREATE INDEX idempotency_expiry_idx ON idempotency_keys(expires_at);
CREATE INDEX audit_logs_entity_idx ON audit_logs(entity_type, entity_id, created_at);
CREATE INDEX audit_logs_actor_idx ON audit_logs(actor_user_id, created_at);

-- =============================================================================
-- C4: Row-Level Security
-- =============================================================================
-- RLS is defense-in-depth (architectural rule #12), not the primary
-- authorization mechanism. Go performs its own authorization check before
-- issuing any query; these policies exist to contain the blast radius of an
-- authorization bug, an unreviewed query, or a compromised credential.
--
-- Role model:
--   <neon owner / migration role> -> schema management only, never used at request time
--   app_user         -> Go REST API (regular users and organizers)
--   worker_role       -> Go background worker (media processing, reminders, jobs,
--                        payment webhooks) -- connects with app.role = 'service'
--   admin_dashboard   -> Next.js admin app via Prisma, and Go acting on an admin's behalf
--
-- Every request-scoped transaction sets, before any other statement:
--   SELECT set_config('app.user_id', $1, true);
--   SELECT set_config('app.role', $2, true);
--   SELECT set_config('app.organizer_id', $3, true);  -- only when acting for an organizer
-- The third argument (`true` = is_local) makes each setting transaction-local,
-- so pooled connections cannot leak context across requests once the
-- transaction commits or rolls back.

DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_user') THEN
    CREATE ROLE app_user LOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'worker_role') THEN
    CREATE ROLE worker_role LOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'admin_dashboard') THEN
    CREATE ROLE admin_dashboard LOGIN;
  END IF;
END
$$;
-- Passwords/connection strings for these roles are provisioned per environment
-- (Neon role management) and never stored in migrations or source control.

-- ---- Context helper functions ----------------------------------------------

CREATE OR REPLACE FUNCTION current_app_user_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('app.user_id', true), '')::uuid;
$$;

CREATE OR REPLACE FUNCTION current_app_role() RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('app.role', true), '');
$$;

CREATE OR REPLACE FUNCTION current_app_organizer_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('app.organizer_id', true), '')::uuid;
$$;

-- True for the Next.js/Prisma admin path.
CREATE OR REPLACE FUNCTION is_admin() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT current_app_role() = 'admin';
$$;

-- True for admin OR the Go worker's own internal transactions (media jobs,
-- reminder dispatch, payment-webhook processing) -- contexts that are not an
-- end user but are still fully trusted backend code paths.
CREATE OR REPLACE FUNCTION is_privileged() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT current_app_role() IN ('admin', 'service');
$$;

-- ---- users -------------------------------------------------------------
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON users TO app_user, admin_dashboard;
GRANT SELECT ON users TO worker_role;

CREATE POLICY users_select_own ON users FOR SELECT
  USING (id = current_app_user_id() OR is_privileged());
-- Registration happens before app.user_id exists; row ownership of the new
-- record is meaningless at insert time, so INSERT is gated by the connecting
-- role (app_user/admin_dashboard) via GRANT rather than by row content.
CREATE POLICY users_insert ON users FOR INSERT
  WITH CHECK (true);
CREATE POLICY users_update_own ON users FOR UPDATE
  USING (id = current_app_user_id() OR is_privileged())
  WITH CHECK (id = current_app_user_id() OR is_privileged());
-- NOTE: public-facing profile fields (username, photo_url) shown alongside
-- comments/reviews/organizer pages are exposed via a dedicated read path
-- (a view or a Go query selecting only public columns) -- RLS restricts rows,
-- not columns, so it cannot itself limit which fields a matched row exposes.

-- ---- magic_link_tokens / auth_sessions ----------------------------------
ALTER TABLE magic_link_tokens ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON magic_link_tokens TO app_user;
CREATE POLICY magic_link_tokens_own ON magic_link_tokens FOR ALL
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

ALTER TABLE auth_sessions ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON auth_sessions TO app_user;
CREATE POLICY auth_sessions_own ON auth_sessions FOR ALL
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

-- ---- organizer_applications ----------------------------------------------
ALTER TABLE organizer_applications ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON organizer_applications TO app_user, admin_dashboard;

CREATE POLICY organizer_applications_select ON organizer_applications FOR SELECT
  USING (user_id = current_app_user_id() OR is_privileged());
CREATE POLICY organizer_applications_insert ON organizer_applications FOR INSERT
  WITH CHECK (user_id = current_app_user_id());
-- Applicants may only withdraw their own application (status transition is
-- enforced by Go); reviewing (approve/reject) requires admin.
CREATE POLICY organizer_applications_update ON organizer_applications FOR UPDATE
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

-- ---- organizers ------------------------------------------------------------
ALTER TABLE organizers ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON organizers TO app_user, admin_dashboard;

CREATE POLICY organizers_select_public ON organizers FOR SELECT
  USING (status = 'active' AND deleted_at IS NULL);
CREATE POLICY organizers_select_own ON organizers FOR SELECT
  USING (owner_user_id = current_app_user_id() OR id = current_app_organizer_id() OR is_privileged());
-- Organizer creation requires admin approval (architectural rule #7); Go
-- performs the INSERT inside the approval transaction while set as admin.
CREATE POLICY organizers_insert ON organizers FOR INSERT
  WITH CHECK (is_privileged());
CREATE POLICY organizers_update ON organizers FOR UPDATE
  USING (owner_user_id = current_app_user_id() OR id = current_app_organizer_id() OR is_privileged())
  WITH CHECK (owner_user_id = current_app_user_id() OR id = current_app_organizer_id() OR is_privileged());

-- ---- categories (low-sensitivity reference data) --------------------------
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON categories TO app_user, worker_role;
GRANT SELECT, INSERT, UPDATE ON categories TO admin_dashboard;

CREATE POLICY categories_select ON categories FOR SELECT USING (true);
CREATE POLICY categories_write ON categories FOR INSERT WITH CHECK (is_privileged());
CREATE POLICY categories_update ON categories FOR UPDATE
  USING (is_privileged()) WITH CHECK (is_privileged());

-- ---- venues ----------------------------------------------------------------
ALTER TABLE venues ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON venues TO app_user, admin_dashboard;

CREATE POLICY venues_select_public ON venues FOR SELECT
  USING (status = 'active' AND deleted_at IS NULL);
CREATE POLICY venues_select_own ON venues FOR SELECT
  USING (organizer_id = current_app_organizer_id() OR is_privileged());
CREATE POLICY venues_insert ON venues FOR INSERT
  WITH CHECK (organizer_id = current_app_organizer_id() OR is_privileged());
CREATE POLICY venues_update ON venues FOR UPDATE
  USING (organizer_id = current_app_organizer_id() OR is_privileged())
  WITH CHECK (organizer_id = current_app_organizer_id() OR is_privileged());

-- ---- media_assets / media_variants / media_processing_jobs -----------------
ALTER TABLE media_assets ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON media_assets TO app_user, admin_dashboard;
GRANT SELECT, UPDATE ON media_assets TO worker_role;

CREATE POLICY media_assets_select_own ON media_assets FOR SELECT
  USING (uploader_id = current_app_user_id() OR is_privileged());
-- Processed media is meant to be publicly displayed (event posters, organizer
-- logos, avatars, gallery images) once it's finished processing -- without
-- this, no non-owner could ever render a poster/avatar and public event
-- browsing would be broken. Un-processed rows (pending/processing/failed)
-- stay owner+admin-only via the policy above; a draft event's still-processing
-- poster is protected by that window, not by publish status, which RLS on
-- this table does not track. Go's own event/organizer visibility checks are
-- the primary control for "should this poster be shown yet."
CREATE POLICY media_assets_select_ready ON media_assets FOR SELECT
  USING (status = 'ready');
CREATE POLICY media_assets_insert ON media_assets FOR INSERT
  WITH CHECK (uploader_id = current_app_user_id() OR is_privileged());
CREATE POLICY media_assets_update ON media_assets FOR UPDATE
  USING (uploader_id = current_app_user_id() OR is_privileged())
  WITH CHECK (uploader_id = current_app_user_id() OR is_privileged());
-- Once a media asset is attached (event poster, gallery item, organizer logo,
-- avatar, story), other users need to be able to resolve it for display.
-- That fan-out read happens through the owning entity's own policy (events,
-- organizers, stories, etc.) and a Go-side join/URL resolution step, not by
-- broadening media_assets_select itself.

ALTER TABLE media_variants ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON media_variants TO app_user;
GRANT SELECT, INSERT, UPDATE ON media_variants TO worker_role, admin_dashboard;
CREATE POLICY media_variants_select ON media_variants FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM media_assets a
    WHERE a.id = media_variants.media_asset_id
      AND (a.uploader_id = current_app_user_id() OR a.status = 'ready' OR is_privileged())
  ));
CREATE POLICY media_variants_write ON media_variants FOR INSERT
  WITH CHECK (is_privileged());
CREATE POLICY media_variants_update ON media_variants FOR UPDATE
  USING (is_privileged()) WITH CHECK (is_privileged());

ALTER TABLE media_processing_jobs ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON media_processing_jobs TO worker_role, admin_dashboard;
CREATE POLICY media_processing_jobs_privileged ON media_processing_jobs FOR ALL
  USING (is_privileged()) WITH CHECK (is_privileged());

-- ---- events / event_gallery_items ------------------------------------------
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON events TO app_user, admin_dashboard;

CREATE POLICY events_select_public ON events FOR SELECT
  USING (status = 'published' AND moderation_status != 'blocked' AND deleted_at IS NULL);
CREATE POLICY events_select_own ON events FOR SELECT
  USING (organizer_id = current_app_organizer_id() OR is_privileged());
CREATE POLICY events_insert ON events FOR INSERT
  WITH CHECK (organizer_id = current_app_organizer_id() OR is_privileged());
CREATE POLICY events_update ON events FOR UPDATE
  USING (organizer_id = current_app_organizer_id() OR is_privileged())
  WITH CHECK (organizer_id = current_app_organizer_id() OR is_privileged());

ALTER TABLE event_gallery_items ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON event_gallery_items TO app_user, admin_dashboard;
CREATE POLICY event_gallery_items_select_public ON event_gallery_items FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = event_gallery_items.event_id
      AND e.status = 'published' AND e.moderation_status != 'blocked' AND e.deleted_at IS NULL
  ));
CREATE POLICY event_gallery_items_manage ON event_gallery_items FOR ALL
  USING (EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = event_gallery_items.event_id
      AND (e.organizer_id = current_app_organizer_id() OR is_privileged())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = event_gallery_items.event_id
      AND (e.organizer_id = current_app_organizer_id() OR is_privileged())
  ));

-- ---- comments ----------------------------------------------------------------
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON comments TO app_user, admin_dashboard;

CREATE POLICY comments_select ON comments FOR SELECT
  USING (status = 'visible' OR user_id = current_app_user_id() OR is_privileged());
CREATE POLICY comments_insert ON comments FOR INSERT
  WITH CHECK (user_id = current_app_user_id());
CREATE POLICY comments_update ON comments FOR UPDATE
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

-- ---- likes / saves / save_folders / shares / organizer_follows -------------
-- These are "own rows" tables per the policy matrix. NOTE: aggregate counts
-- (e.g. an event's total like count, an organizer's follower count) must be
-- served either from a maintained counter column/materialized view or a
-- SECURITY DEFINER function -- a plain COUNT(*) run as app_user would only
-- see the requester's own row under these policies, not the true total.
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON likes TO app_user, admin_dashboard;
CREATE POLICY likes_own ON likes FOR ALL
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

ALTER TABLE save_folders ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON save_folders TO app_user, admin_dashboard;
CREATE POLICY save_folders_own ON save_folders FOR ALL
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

ALTER TABLE saves ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON saves TO app_user, admin_dashboard;
CREATE POLICY saves_own ON saves FOR ALL
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

ALTER TABLE shares ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT ON shares TO app_user, admin_dashboard;
CREATE POLICY shares_select ON shares FOR SELECT
  USING (user_id = current_app_user_id() OR is_privileged());
CREATE POLICY shares_insert ON shares FOR INSERT
  WITH CHECK (user_id = current_app_user_id() OR user_id IS NULL);

ALTER TABLE organizer_follows ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON organizer_follows TO app_user, admin_dashboard;
CREATE POLICY organizer_follows_own ON organizer_follows FOR ALL
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

-- ---- event_rsvps -------------------------------------------------------------
-- Per the policy matrix, organizer visibility into RSVPs for their own events
-- is "read through controlled Go operations," not raw row access -- so there
-- is deliberately no organizer_id-based SELECT policy here. That read path is
-- a SECURITY DEFINER function/service query, kept auditable and separate from
-- ordinary row-level access.
ALTER TABLE event_rsvps ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON event_rsvps TO app_user, admin_dashboard;
CREATE POLICY event_rsvps_select_own ON event_rsvps FOR SELECT
  USING (user_id = current_app_user_id() OR is_privileged());
CREATE POLICY event_rsvps_insert ON event_rsvps FOR INSERT
  WITH CHECK (user_id = current_app_user_id());
CREATE POLICY event_rsvps_update ON event_rsvps FOR UPDATE
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

-- ---- ticket_types / orders / order_items / tickets / payments --------------
-- Not explicitly enumerated in the doc's policy matrix; extended here using
-- the same ownership pattern, since RLS defaults to deny-all once enabled and
-- every table app_user writes to needs an explicit policy or the app breaks.
ALTER TABLE ticket_types ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON ticket_types TO app_user, admin_dashboard;
CREATE POLICY ticket_types_select_public ON ticket_types FOR SELECT
  USING (is_active);
CREATE POLICY ticket_types_select_own ON ticket_types FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = ticket_types.event_id AND e.organizer_id = current_app_organizer_id()
  ) OR is_privileged());
CREATE POLICY ticket_types_write ON ticket_types FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = ticket_types.event_id AND e.organizer_id = current_app_organizer_id()
  ) OR is_privileged());
CREATE POLICY ticket_types_update ON ticket_types FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = ticket_types.event_id AND e.organizer_id = current_app_organizer_id()
  ) OR is_privileged())
  WITH CHECK (EXISTS (
    SELECT 1 FROM events e
    WHERE e.id = ticket_types.event_id AND e.organizer_id = current_app_organizer_id()
  ) OR is_privileged());

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON orders TO app_user, admin_dashboard;
GRANT SELECT, UPDATE ON orders TO worker_role;
CREATE POLICY orders_select ON orders FOR SELECT
  USING (
    user_id = current_app_user_id()
    OR EXISTS (SELECT 1 FROM events e WHERE e.id = orders.event_id AND e.organizer_id = current_app_organizer_id())
    OR is_privileged()
  );
CREATE POLICY orders_insert ON orders FOR INSERT
  WITH CHECK (user_id = current_app_user_id());
-- Status transitions (pending -> paid/failed/refunded) are payment-provider
-- driven; the worker connects with app.role = 'service' (covered by
-- is_privileged()) rather than as the purchasing user.
CREATE POLICY orders_update ON orders FOR UPDATE
  USING (is_privileged() OR user_id = current_app_user_id())
  WITH CHECK (is_privileged() OR user_id = current_app_user_id());

ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT ON order_items TO app_user, admin_dashboard, worker_role;
CREATE POLICY order_items_rw ON order_items FOR ALL
  USING (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_items.order_id
      AND (o.user_id = current_app_user_id() OR is_privileged())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM orders o
    WHERE o.id = order_items.order_id
      AND (o.user_id = current_app_user_id() OR is_privileged())
  ));

ALTER TABLE tickets ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON tickets TO app_user, admin_dashboard, worker_role;
CREATE POLICY tickets_select ON tickets FOR SELECT
  USING (
    user_id = current_app_user_id()
    OR EXISTS (SELECT 1 FROM events e WHERE e.id = tickets.event_id AND e.organizer_id = current_app_organizer_id())
    OR is_privileged()
  );
CREATE POLICY tickets_write ON tickets FOR INSERT WITH CHECK (is_privileged());
-- Ticket state changes (used/cancelled/refunded) happen through the check-in
-- and refund services, not directly by the ticket holder.
CREATE POLICY tickets_update ON tickets FOR UPDATE
  USING (is_privileged()) WITH CHECK (is_privileged());

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON payments TO admin_dashboard, worker_role;
GRANT SELECT ON payments TO app_user;
-- Payments are the most sensitive financial record; regular users get
-- read-only visibility into their own order's payment status, never write
-- access. Writes are provider-webhook-driven (worker_role/service context).
CREATE POLICY payments_select ON payments FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM orders o WHERE o.id = payments.order_id AND o.user_id = current_app_user_id())
    OR is_privileged()
  );
CREATE POLICY payments_write ON payments FOR INSERT WITH CHECK (is_privileged());
CREATE POLICY payments_update ON payments FOR UPDATE
  USING (is_privileged()) WITH CHECK (is_privileged());

-- ---- reviews -----------------------------------------------------------------
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON reviews TO app_user, admin_dashboard;
CREATE POLICY reviews_select ON reviews FOR SELECT
  USING (status = 'published' OR user_id = current_app_user_id() OR is_privileged());
CREATE POLICY reviews_insert ON reviews FOR INSERT
  WITH CHECK (user_id = current_app_user_id());
CREATE POLICY reviews_update ON reviews FOR UPDATE
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

-- ---- reports -------------------------------------------------------------
ALTER TABLE reports ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON reports TO app_user, admin_dashboard;
CREATE POLICY reports_select ON reports FOR SELECT
  USING (reporter_user_id = current_app_user_id() OR is_privileged());
CREATE POLICY reports_insert ON reports FOR INSERT
  WITH CHECK (reporter_user_id = current_app_user_id());
-- Only admins resolve/assign reports.
CREATE POLICY reports_update ON reports FOR UPDATE
  USING (is_privileged()) WITH CHECK (is_privileged());

-- ---- notifications / event_reminders / user_devices ------------------------
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
GRANT SELECT, UPDATE ON notifications TO app_user;
GRANT SELECT, INSERT, UPDATE ON notifications TO worker_role, admin_dashboard;
CREATE POLICY notifications_select_own ON notifications FOR SELECT
  USING (user_id = current_app_user_id() OR is_privileged());
CREATE POLICY notifications_insert ON notifications FOR INSERT
  WITH CHECK (is_privileged());
-- Users may only mark their own notifications read, not alter their content.
CREATE POLICY notifications_update_own ON notifications FOR UPDATE
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

ALTER TABLE event_reminders ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON event_reminders TO app_user;
GRANT SELECT, UPDATE ON event_reminders TO worker_role;
GRANT SELECT ON event_reminders TO admin_dashboard;
CREATE POLICY event_reminders_own ON event_reminders FOR ALL
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON user_devices TO app_user;
GRANT SELECT ON user_devices TO worker_role;
CREATE POLICY user_devices_own ON user_devices FOR ALL
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

-- ---- stories / story_views --------------------------------------------------
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON stories TO app_user, admin_dashboard;
CREATE POLICY stories_select_active ON stories FOR SELECT
  USING (expires_at > now() OR user_id = current_app_user_id() OR is_privileged());
CREATE POLICY stories_insert ON stories FOR INSERT
  WITH CHECK (user_id = current_app_user_id());
CREATE POLICY stories_delete ON stories FOR DELETE
  USING (user_id = current_app_user_id() OR is_privileged());

ALTER TABLE story_views ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT ON story_views TO app_user, admin_dashboard;
CREATE POLICY story_views_viewer_write ON story_views FOR INSERT
  WITH CHECK (viewer_id = current_app_user_id());
-- A story's author may see who viewed it; the viewer can see their own view
-- record; RLS again does not attempt to serve the aggregate "N views" count
-- (same caveat as likes/follows above).
CREATE POLICY story_views_select ON story_views FOR SELECT
  USING (
    viewer_id = current_app_user_id()
    OR EXISTS (SELECT 1 FROM stories s WHERE s.id = story_views.story_id AND s.user_id = current_app_user_id())
    OR is_privileged()
  );

-- ---- announcements / pages (CMS, admin-authored) ----------------------------
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON announcements TO app_user;
GRANT SELECT, INSERT, UPDATE ON announcements TO admin_dashboard;
CREATE POLICY announcements_select_public ON announcements FOR SELECT
  USING (is_active OR is_privileged());
CREATE POLICY announcements_write ON announcements FOR INSERT WITH CHECK (is_privileged());
CREATE POLICY announcements_update ON announcements FOR UPDATE
  USING (is_privileged()) WITH CHECK (is_privileged());

ALTER TABLE pages ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON pages TO app_user;
GRANT SELECT, INSERT, UPDATE ON pages TO admin_dashboard;
CREATE POLICY pages_select_public ON pages FOR SELECT USING (true);
CREATE POLICY pages_write ON pages FOR INSERT WITH CHECK (is_privileged());
CREATE POLICY pages_update ON pages FOR UPDATE
  USING (is_privileged()) WITH CHECK (is_privileged());

-- ---- rate_limits / idempotency_keys / audit_logs (operational) -------------
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON rate_limits TO app_user, worker_role;
CREATE POLICY rate_limits_service ON rate_limits FOR ALL
  USING (true) WITH CHECK (true);
-- rate_limits has no user_id column by design (keys are composite, e.g.
-- "login:{ip_hash}"); access control here is via GRANT (connecting role) only.

ALTER TABLE idempotency_keys ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE ON idempotency_keys TO app_user;
CREATE POLICY idempotency_keys_own ON idempotency_keys FOR ALL
  USING (user_id = current_app_user_id() OR is_privileged())
  WITH CHECK (user_id = current_app_user_id() OR is_privileged());

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT ON audit_logs TO app_user, worker_role, admin_dashboard;
-- Audit logs are append-only and admin-readable; no UPDATE/DELETE grant to
-- any role, and no policy permits either -- RLS default-deny applies.
CREATE POLICY audit_logs_insert ON audit_logs FOR INSERT WITH CHECK (true);
CREATE POLICY audit_logs_select ON audit_logs FOR SELECT USING (is_privileged());

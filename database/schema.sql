-- ============================================================
-- OpenSpot Database Schema — Clean Rebuild
-- Run this entire file in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- 1. PROFILES
-- Extends auth.users — auto-created on signup via trigger
-- ============================================================
CREATE TABLE IF NOT EXISTS profiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email         TEXT UNIQUE,
  full_name     TEXT,
  phone         TEXT,
  avatar_url    TEXT,
  role          TEXT NOT NULL DEFAULT 'user',  -- 'user' | 'landlord' | 'agency' | 'admin'
  is_verified   BOOLEAN NOT NULL DEFAULT false,
  onboarding_completed BOOLEAN NOT NULL DEFAULT false,
  preferences   JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);
CREATE INDEX IF NOT EXISTS idx_profiles_role  ON profiles(role);

-- Auto-create profile on new user signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- ============================================================
-- 2. PROPERTIES
-- ============================================================
CREATE TABLE IF NOT EXISTS properties (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Basic
  title           TEXT NOT NULL,
  description     TEXT,
  property_type   TEXT NOT NULL,   -- apartment | house | studio | bedsitter | warehouse | office | shop | land
  category        TEXT NOT NULL,   -- residential | commercial | industrial | agricultural | land
  listing_type    TEXT NOT NULL,   -- rent | sale

  -- Location
  location        TEXT NOT NULL,
  address         TEXT,
  neighborhood    TEXT,
  city            TEXT NOT NULL DEFAULT 'Nairobi',
  latitude        DECIMAL(10,8),
  longitude       DECIMAL(11,8),

  -- Pricing
  price           DECIMAL(12,2) NOT NULL CHECK (price > 0),
  currency        TEXT NOT NULL DEFAULT 'KES',
  deposit         DECIMAL(12,2) CHECK (deposit IS NULL OR deposit >= 0),

  -- Details
  bedrooms        INTEGER CHECK (bedrooms IS NULL OR bedrooms >= 0),
  bathrooms       INTEGER CHECK (bathrooms IS NULL OR bathrooms >= 0),
  area            DECIMAL(10,2) CHECK (area IS NULL OR area > 0),
  floor_number    INTEGER,
  total_floors    INTEGER,
  parking_spaces  INTEGER,

  -- Features
  amenities           JSONB NOT NULL DEFAULT '[]'::jsonb,
  utilities_included  JSONB NOT NULL DEFAULT '[]'::jsonb,

  -- Media
  images          JSONB NOT NULL DEFAULT '[]'::jsonb,
  thumbnail_url   TEXT,
  video_url       TEXT,

  -- Landlord
  landlord_id     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  landlord_name   TEXT,
  landlord_phone  TEXT,
  landlord_email  TEXT,
  landlord_verified BOOLEAN NOT NULL DEFAULT false,

  -- Availability
  available       BOOLEAN NOT NULL DEFAULT true,
  available_from  DATE,
  lease_duration  TEXT,   -- monthly | yearly | flexible

  -- Status
  status          TEXT NOT NULL DEFAULT 'active',  -- active | pending | rented | sold | inactive
  verified        BOOLEAN NOT NULL DEFAULT false,
  featured        BOOLEAN NOT NULL DEFAULT false,

  -- Analytics
  views           INTEGER NOT NULL DEFAULT 0,
  likes           INTEGER NOT NULL DEFAULT 0,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_property_type   CHECK (property_type IN ('apartment','house','studio','bedsitter','warehouse','office','shop','land')),
  CONSTRAINT chk_category        CHECK (category IN ('residential','commercial','industrial','agricultural','land')),
  CONSTRAINT chk_listing_type    CHECK (listing_type IN ('rent','sale')),
  CONSTRAINT chk_status          CHECK (status IN ('active','pending','rented','sold','inactive'))
);

CREATE INDEX IF NOT EXISTS idx_properties_landlord    ON properties(landlord_id);
CREATE INDEX IF NOT EXISTS idx_properties_location    ON properties(location);
CREATE INDEX IF NOT EXISTS idx_properties_category    ON properties(category);
CREATE INDEX IF NOT EXISTS idx_properties_price       ON properties(price);
CREATE INDEX IF NOT EXISTS idx_properties_status      ON properties(status);
CREATE INDEX IF NOT EXISTS idx_properties_created_at  ON properties(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_properties_active      ON properties(created_at DESC) WHERE status = 'active' AND available = true;
CREATE INDEX IF NOT EXISTS idx_properties_fulltext    ON properties USING gin(to_tsvector('english', title || ' ' || COALESCE(description,'') || ' ' || location));

-- ============================================================
-- 3. FAVORITES
-- ============================================================
CREATE TABLE IF NOT EXISTS favorites (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, property_id)
);

CREATE INDEX IF NOT EXISTS idx_favorites_user     ON favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_favorites_property ON favorites(property_id);

-- ============================================================
-- 4. REVIEWS
-- ============================================================
CREATE TABLE IF NOT EXISTS reviews (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id     UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  rating              INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  title               TEXT,
  comment             TEXT,
  cleanliness_rating  INTEGER CHECK (cleanliness_rating IS NULL OR cleanliness_rating BETWEEN 1 AND 5),
  location_rating     INTEGER CHECK (location_rating IS NULL OR location_rating BETWEEN 1 AND 5),
  value_rating        INTEGER CHECK (value_rating IS NULL OR value_rating BETWEEN 1 AND 5),
  landlord_rating     INTEGER CHECK (landlord_rating IS NULL OR landlord_rating BETWEEN 1 AND 5),

  is_anonymous    BOOLEAN NOT NULL DEFAULT false,
  verified_tenant BOOLEAN NOT NULL DEFAULT false,
  helpful_count   INTEGER NOT NULL DEFAULT 0,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  UNIQUE(property_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_reviews_property ON reviews(property_id);
CREATE INDEX IF NOT EXISTS idx_reviews_user     ON reviews(user_id);

-- ============================================================
-- 5. BOOKINGS
-- ============================================================
CREATE TABLE IF NOT EXISTS bookings (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id     UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  check_in_date   DATE NOT NULL,
  check_out_date  DATE CHECK (check_out_date IS NULL OR check_out_date > check_in_date),
  duration_months INTEGER CHECK (duration_months IS NULL OR duration_months > 0),
  total_amount    DECIMAL(12,2) NOT NULL CHECK (total_amount > 0),

  status          TEXT NOT NULL DEFAULT 'pending',   -- pending | confirmed | cancelled | completed
  payment_status  TEXT NOT NULL DEFAULT 'pending',   -- pending | paid | partial | refunded

  contact_name    TEXT NOT NULL,
  contact_phone   TEXT NOT NULL,
  contact_email   TEXT,
  notes           TEXT,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_booking_status  CHECK (status IN ('pending','confirmed','cancelled','completed')),
  CONSTRAINT chk_payment_status  CHECK (payment_status IN ('pending','paid','partial','refunded'))
);

CREATE INDEX IF NOT EXISTS idx_bookings_property ON bookings(property_id);
CREATE INDEX IF NOT EXISTS idx_bookings_user     ON bookings(user_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status   ON bookings(status);
CREATE INDEX IF NOT EXISTS idx_bookings_pending  ON bookings(property_id, created_at DESC) WHERE status = 'pending';

-- ============================================================
-- 6. MESSAGES
-- ============================================================
CREATE TABLE IF NOT EXISTS messages (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  content     TEXT NOT NULL,
  media_url   TEXT,
  media_type  TEXT,   -- image | audio | file
  read        BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_messages_sender   ON messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_receiver ON messages(receiver_id);
CREATE INDEX IF NOT EXISTS idx_messages_created  ON messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_convo    ON messages(sender_id, receiver_id, created_at DESC);

-- ============================================================
-- 7. NOTIFICATIONS
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,   -- message | property | inquiry | system | payment | alert
  title       TEXT NOT NULL,
  description TEXT,
  is_read     BOOLEAN NOT NULL DEFAULT false,
  action_url  TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user   ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(user_id, created_at DESC) WHERE is_read = false;

-- ============================================================
-- 8. ROOMMATE PROFILES
-- ============================================================
CREATE TABLE IF NOT EXISTS roommate_profiles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,

  name        TEXT NOT NULL,
  age         INTEGER CHECK (age IS NULL OR (age >= 16 AND age <= 100)),
  gender      TEXT CHECK (gender IN ('male','female','non-binary','prefer-not-to-say')),
  bio         TEXT,
  profile_image TEXT,

  campus      TEXT,
  university  TEXT,
  course      TEXT,
  year_of_study INTEGER,

  budget_min  DECIMAL(10,2),
  budget_max  DECIMAL(10,2),
  preferred_location TEXT,
  move_in_date DATE,

  interests             JSONB NOT NULL DEFAULT '[]'::jsonb,
  lifestyle_preferences JSONB NOT NULL DEFAULT '{}'::jsonb,

  phone       TEXT,
  whatsapp    TEXT,

  is_active   BOOLEAN NOT NULL DEFAULT true,
  looking_for TEXT NOT NULL DEFAULT 'roommate',  -- roommate | room | both
  verified    BOOLEAN NOT NULL DEFAULT false,

  views       INTEGER NOT NULL DEFAULT 0,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_roommate_budget      CHECK (budget_min IS NULL OR budget_max IS NULL OR budget_max >= budget_min),
  CONSTRAINT chk_roommate_looking_for CHECK (looking_for IN ('roommate','room','both'))
);

CREATE INDEX IF NOT EXISTS idx_roommate_user    ON roommate_profiles(user_id);
CREATE INDEX IF NOT EXISTS idx_roommate_campus  ON roommate_profiles(campus);
CREATE INDEX IF NOT EXISTS idx_roommate_gender  ON roommate_profiles(gender);
CREATE INDEX IF NOT EXISTS idx_roommate_active  ON roommate_profiles(created_at DESC) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_roommate_fulltext ON roommate_profiles USING gin(to_tsvector('english', name || ' ' || COALESCE(bio,'') || ' ' || COALESCE(campus,'')));

-- ============================================================
-- 9. ROOMMATE MATCHES
-- ============================================================
CREATE TABLE IF NOT EXISTS roommate_matches (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  matched_user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status          TEXT NOT NULL DEFAULT 'pending',  -- pending | accepted | rejected | blocked
  match_score     INTEGER,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, matched_user_id),
  CONSTRAINT chk_match_status CHECK (status IN ('pending','accepted','rejected','blocked'))
);

CREATE INDEX IF NOT EXISTS idx_matches_user         ON roommate_matches(user_id);
CREATE INDEX IF NOT EXISTS idx_matches_matched_user ON roommate_matches(matched_user_id);

-- ============================================================
-- 10. MARKETPLACE ITEMS
-- ============================================================
CREATE TABLE IF NOT EXISTS marketplace_items (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  seller_id   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,

  title       TEXT NOT NULL,
  description TEXT,
  category    TEXT NOT NULL,   -- furniture | electronics | books | clothing | kitchen | sports | other
  condition   TEXT NOT NULL,   -- new | like-new | good | fair | poor
  price       DECIMAL(10,2) NOT NULL CHECK (price > 0),
  currency    TEXT NOT NULL DEFAULT 'KES',

  images      JSONB NOT NULL DEFAULT '[]'::jsonb,
  location    TEXT,
  campus      TEXT,

  is_sold     BOOLEAN NOT NULL DEFAULT false,
  is_active   BOOLEAN NOT NULL DEFAULT true,

  views       INTEGER NOT NULL DEFAULT 0,

  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT chk_item_category  CHECK (category IN ('furniture','electronics','books','clothing','kitchen','sports','other')),
  CONSTRAINT chk_item_condition CHECK (condition IN ('new','like-new','good','fair','poor'))
);

CREATE INDEX IF NOT EXISTS idx_marketplace_seller   ON marketplace_items(seller_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_category ON marketplace_items(category);
CREATE INDEX IF NOT EXISTS idx_marketplace_active   ON marketplace_items(created_at DESC) WHERE is_active = true AND is_sold = false;
CREATE INDEX IF NOT EXISTS idx_marketplace_fulltext ON marketplace_items USING gin(to_tsvector('english', title || ' ' || COALESCE(description,'')));

-- ============================================================
-- 11. PROPERTY VIEWS (analytics)
-- ============================================================
CREATE TABLE IF NOT EXISTS property_views (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  property_id UUID NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES profiles(id) ON DELETE SET NULL,
  session_id  TEXT,
  viewed_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pviews_property ON property_views(property_id);
CREATE INDEX IF NOT EXISTS idx_pviews_date     ON property_views(viewed_at DESC);

-- ============================================================
-- 12. UPDATED_AT TRIGGER (shared)
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DO $$ BEGIN
  CREATE TRIGGER trg_profiles_updated_at    BEFORE UPDATE ON profiles    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_properties_updated_at  BEFORE UPDATE ON properties  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_reviews_updated_at     BEFORE UPDATE ON reviews     FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_bookings_updated_at    BEFORE UPDATE ON bookings    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_roommate_updated_at    BEFORE UPDATE ON roommate_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_matches_updated_at     BEFORE UPDATE ON roommate_matches  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE TRIGGER trg_marketplace_updated_at BEFORE UPDATE ON marketplace_items FOR EACH ROW EXECUTE FUNCTION update_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- 13. INCREMENT VIEWS FUNCTION
-- ============================================================
CREATE OR REPLACE FUNCTION increment_property_views(property_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE properties SET views = views + 1 WHERE id = property_id;
END;
$$;

-- ============================================================
-- 14. ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE profiles          ENABLE ROW LEVEL SECURITY;
ALTER TABLE properties        ENABLE ROW LEVEL SECURITY;
ALTER TABLE favorites         ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews           ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings          ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages          ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications     ENABLE ROW LEVEL SECURITY;
ALTER TABLE roommate_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE roommate_matches  ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE property_views    ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE POLICY "profiles_select_own"  ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "profiles_update_own"  ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "profiles_insert_own"  ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Properties — public read, landlord write
CREATE POLICY "properties_select_all"    ON properties FOR SELECT USING (true);
CREATE POLICY "properties_insert_own"    ON properties FOR INSERT WITH CHECK (auth.uid() = landlord_id);
CREATE POLICY "properties_update_own"    ON properties FOR UPDATE USING (auth.uid() = landlord_id);
CREATE POLICY "properties_delete_own"    ON properties FOR DELETE USING (auth.uid() = landlord_id);

-- Favorites
CREATE POLICY "favorites_select_own" ON favorites FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "favorites_insert_own" ON favorites FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "favorites_delete_own" ON favorites FOR DELETE USING (auth.uid() = user_id);

-- Reviews — public read
CREATE POLICY "reviews_select_all"   ON reviews FOR SELECT USING (true);
CREATE POLICY "reviews_insert_own"   ON reviews FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "reviews_update_own"   ON reviews FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "reviews_delete_own"   ON reviews FOR DELETE USING (auth.uid() = user_id);

-- Bookings
CREATE POLICY "bookings_select_own"  ON bookings FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "bookings_insert_own"  ON bookings FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "bookings_update_own"  ON bookings FOR UPDATE USING (auth.uid() = user_id);

-- Messages — sender or receiver
CREATE POLICY "messages_select_own"  ON messages FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = receiver_id);
CREATE POLICY "messages_insert_own"  ON messages FOR INSERT WITH CHECK (auth.uid() = sender_id);
CREATE POLICY "messages_delete_own"  ON messages FOR DELETE USING (auth.uid() = sender_id);

-- Notifications
CREATE POLICY "notifs_select_own"    ON notifications FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "notifs_update_own"    ON notifications FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "notifs_delete_own"    ON notifications FOR DELETE USING (auth.uid() = user_id);

-- Roommate profiles — public read for active
CREATE POLICY "roommate_select_all"  ON roommate_profiles FOR SELECT USING (is_active = true OR auth.uid() = user_id);
CREATE POLICY "roommate_insert_own"  ON roommate_profiles FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "roommate_update_own"  ON roommate_profiles FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "roommate_delete_own"  ON roommate_profiles FOR DELETE USING (auth.uid() = user_id);

-- Roommate matches
CREATE POLICY "matches_select_own"   ON roommate_matches FOR SELECT USING (auth.uid() = user_id OR auth.uid() = matched_user_id);
CREATE POLICY "matches_insert_own"   ON roommate_matches FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "matches_update_own"   ON roommate_matches FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "matches_delete_own"   ON roommate_matches FOR DELETE USING (auth.uid() = user_id);

-- Marketplace — public read for active
CREATE POLICY "market_select_all"    ON marketplace_items FOR SELECT USING (is_active = true OR auth.uid() = seller_id);
CREATE POLICY "market_insert_own"    ON marketplace_items FOR INSERT WITH CHECK (auth.uid() = seller_id);
CREATE POLICY "market_update_own"    ON marketplace_items FOR UPDATE USING (auth.uid() = seller_id);
CREATE POLICY "market_delete_own"    ON marketplace_items FOR DELETE USING (auth.uid() = seller_id);

-- Property views — anyone can insert
CREATE POLICY "pviews_insert_all"    ON property_views FOR INSERT WITH CHECK (true);
CREATE POLICY "pviews_select_own"    ON property_views FOR SELECT USING (auth.uid() = user_id OR user_id IS NULL);

-- ============================================================
-- 15. STORAGE BUCKETS
-- ============================================================
INSERT INTO storage.buckets (id, name, public) VALUES ('property-images', 'property-images', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('avatars', 'avatars', true) ON CONFLICT (id) DO NOTHING;
INSERT INTO storage.buckets (id, name, public) VALUES ('marketplace-images', 'marketplace-images', true) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "property_images_public_read"  ON storage.objects FOR SELECT USING (bucket_id = 'property-images');
CREATE POLICY "property_images_auth_upload"  ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'property-images' AND auth.role() = 'authenticated');
CREATE POLICY "property_images_owner_delete" ON storage.objects FOR DELETE USING (bucket_id = 'property-images' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "avatars_public_read"   ON storage.objects FOR SELECT USING (bucket_id = 'avatars');
CREATE POLICY "avatars_auth_upload"   ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');
CREATE POLICY "avatars_owner_update"  ON storage.objects FOR UPDATE USING (bucket_id = 'avatars' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "market_images_public_read"  ON storage.objects FOR SELECT USING (bucket_id = 'marketplace-images');
CREATE POLICY "market_images_auth_upload"  ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'marketplace-images' AND auth.role() = 'authenticated');

-- ============================================================
-- DONE — Tables created:
--   profiles, properties, favorites, reviews, bookings,
--   messages, notifications, roommate_profiles,
--   roommate_matches, marketplace_items, property_views
-- ============================================================

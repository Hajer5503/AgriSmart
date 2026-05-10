-- PostgreSQL minimal schema for AgriSmart API (server.js)
-- Usage: psql "$DATABASE_URL" -f schema.sql

CREATE TABLE IF NOT EXISTS users (
  id         SERIAL PRIMARY KEY,
  email      TEXT UNIQUE NOT NULL,
  password   TEXT NOT NULL,
  name       TEXT,
  role       TEXT NOT NULL DEFAULT 'farmer'
    CHECK (role IN ('farmer','breeder','vet','agronomist','admin')),
  phone      TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS farms (
  id            SERIAL PRIMARY KEY,
  owner_id      INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  location      TEXT,
  area_hectares DOUBLE PRECISION,
  farm_type     TEXT NOT NULL DEFAULT 'Polyculture'
    CHECK (farm_type IN ('Polyculture','Maraichage','Cereales','Elevage','Arboriculture','Autre')),
  latitude      DOUBLE PRECISION,
  longitude     DOUBLE PRECISION,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS fields (
  id            SERIAL PRIMARY KEY,
  farm_id       INT NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  area_hectares DOUBLE PRECISION,
  soil_type     TEXT,
  current_crop  TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS alerts (
  id          SERIAL PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  farm_id     INT REFERENCES farms(id) ON DELETE SET NULL,
  alert_type  TEXT NOT NULL,
  severity    TEXT NOT NULL,
  title       TEXT,
  message     TEXT NOT NULL,
  is_read     BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS tasks (
  id          SERIAL PRIMARY KEY,
  user_id     INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title       TEXT NOT NULL,
  description TEXT,
  priority    TEXT,
  due_date    DATE,
  category    TEXT,
  done        BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS animals (
  id             SERIAL PRIMARY KEY,
  farm_id        INT NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  tag_number     TEXT,
  species        TEXT NOT NULL,
  breed          TEXT,
  birth_date     DATE,
  gender         TEXT,
  weight_kg      DOUBLE PRECISION,
  health_status  TEXT DEFAULT 'healthy',
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_farms_owner ON farms(owner_id);
CREATE INDEX IF NOT EXISTS idx_fields_farm ON fields(farm_id);
CREATE INDEX IF NOT EXISTS idx_alerts_user ON alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_user ON tasks(user_id);
CREATE INDEX IF NOT EXISTS idx_animals_farm ON animals(farm_id);

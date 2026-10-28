BEGIN;

CREATE TYPE staff_role     AS ENUM ('gate','floor','admin');
CREATE TYPE guardian_role  AS ENUM ('primary','authorized');
CREATE TYPE link_status    AS ENUM ('pending','active','revoked','expired');
CREATE TYPE request_source AS ENUM ('app','manual');
CREATE TYPE pickup_status  AS ENUM ('waiting','called','handed','missing','cancelled');

CREATE TABLE classes (
  id serial PRIMARY KEY,
  code text NOT NULL UNIQUE,
  grade text NOT NULL,
  floor smallint NOT NULL CHECK (floor BETWEEN 0 AND 9),
  active boolean NOT NULL DEFAULT true
);

CREATE TABLE students (
  id serial PRIMARY KEY,
  code text UNIQUE,
  full_name text NOT NULL,
  class_id int NOT NULL REFERENCES classes(id),
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ON students (class_id);

CREATE TABLE staff (
  id serial PRIMARY KEY,
  full_name text NOT NULL,
  username text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  role staff_role NOT NULL,
  floors smallint[] NOT NULL DEFAULT '{}',
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE guardians (
  id serial PRIMARY KEY,
  full_name text NOT NULL,
  phone text NOT NULL UNIQUE,
  pin_hash text,
  photo_path text,
  active boolean NOT NULL DEFAULT true,
  registered_at timestamptz,
  failed_pins smallint NOT NULL DEFAULT 0,
  locked_until timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE guardian_students (
  id serial PRIMARY KEY,
  guardian_id int NOT NULL REFERENCES guardians(id) ON DELETE CASCADE,
  student_id  int NOT NULL REFERENCES students(id)  ON DELETE CASCADE,
  relationship text NOT NULL,
  role   guardian_role NOT NULL DEFAULT 'authorized',
  status link_status   NOT NULL DEFAULT 'pending',
  expires_on date,
  requested_by int REFERENCES guardians(id),
  approved_by  int REFERENCES staff(id),
  approved_at  timestamptz,
  revoked_at   timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (guardian_id, student_id)
);
CREATE INDEX ON guardian_students (student_id);

CREATE TABLE registration_tokens (
  id serial PRIMARY KEY,
  guardian_id int NOT NULL REFERENCES guardians(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  created_by int REFERENCES staff(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guardian_id int REFERENCES guardians(id) ON DELETE CASCADE,
  staff_id    int REFERENCES staff(id)     ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  CHECK ((guardian_id IS NOT NULL) <> (staff_id IS NOT NULL))
);

CREATE TABLE pickup_requests (
  id serial PRIMARY KEY,
  day date NOT NULL DEFAULT (now() AT TIME ZONE 'Africa/Cairo')::date,
  number int NOT NULL,
  guardian_id int NOT NULL REFERENCES guardians(id),
  source request_source NOT NULL DEFAULT 'app',
  manual_reason text,
  created_by_staff int REFERENCES staff(id),
  location_verified boolean NOT NULL DEFAULT false,
  distance_m int,
  created_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz,
  UNIQUE (day, number)
);
CREATE INDEX ON pickup_requests (day, closed_at);

CREATE TABLE pickup_students (
  id serial PRIMARY KEY,
  request_id int NOT NULL REFERENCES pickup_requests(id) ON DELETE CASCADE,
  student_id int NOT NULL REFERENCES students(id),
  status pickup_status NOT NULL DEFAULT 'waiting',
  called_at timestamptz, called_by int REFERENCES staff(id),
  handed_at timestamptz, handed_by int REFERENCES staff(id),
  note text,
  UNIQUE (request_id, student_id)
);
CREATE UNIQUE INDEX one_active_per_student
  ON pickup_students (student_id) WHERE status IN ('waiting','called');

CREATE TABLE events (
  id bigserial PRIMARY KEY,
  at timestamptz NOT NULL DEFAULT now(),
  request_id int REFERENCES pickup_requests(id) ON DELETE SET NULL,
  student_id int REFERENCES students(id),
  actor_type text NOT NULL,
  actor_id int,
  event text NOT NULL,
  detail jsonb
);
CREATE INDEX ON events (request_id);
CREATE INDEX ON events (at DESC);

CREATE TABLE settings (
  key text PRIMARY KEY,
  value text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO settings (key,value) VALUES
  ('school_lat','0'), ('school_lng','0'), ('geofence_m','250'),
  ('dismissal_start','12:30'), ('dismissal_end','16:30'),
  ('stale_minutes','8'), ('token_hours','48');

COMMIT;

-- Workspace data is separate from the existing in-memory service.
CREATE TABLE workspace_users (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email text NOT NULL UNIQUE CHECK (email = lower(btrim(email)) AND email <> ''),
    password_hash text NOT NULL
);

CREATE TABLE workspace_sessions (
    token_hash bytea PRIMARY KEY CHECK (octet_length(token_hash) = 32),
    user_id bigint NOT NULL REFERENCES workspace_users(id) ON DELETE CASCADE,
    expires_at timestamptz NOT NULL
);

CREATE INDEX workspace_sessions_user_id_idx ON workspace_sessions (user_id);

CREATE TABLE workspace_items (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id bigint NOT NULL REFERENCES workspace_users(id) ON DELETE CASCADE,
    title text NOT NULL CHECK (char_length(title) <= 200 AND btrim(title) <> ''),
    description text NOT NULL DEFAULT '' CHECK (char_length(description) <= 2000),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX workspace_items_user_id_id_idx ON workspace_items (user_id, id);

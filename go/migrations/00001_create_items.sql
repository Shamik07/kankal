-- +goose Up
CREATE TABLE items (
    id text PRIMARY KEY CHECK (length(id) = 32),
    creation_order bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
    title text NOT NULL CHECK (length(title) BETWEEN 1 AND 200 AND btrim(title) <> ''),
    description text NOT NULL DEFAULT '' CHECK (length(description) <= 2000)
);

-- +goose Down
-- +goose StatementBegin
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM items) THEN
        RAISE EXCEPTION 'refusing to remove a nonempty items table';
    END IF;
END;
$$;
-- +goose StatementEnd
DROP TABLE items;

package main

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostgresStore struct{ pool *pgxpool.Pool }

func NewPostgresStore(ctx context.Context, url string) (*PostgresStore, error) {
	config, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, err
	}
	config.MaxConns = 10
	config.ConnConfig.ConnectTimeout = 5 * time.Second
	pool, err := pgxpool.NewWithConfig(ctx, config)
	if err != nil {
		return nil, err
	}
	store := &PostgresStore{pool: pool}
	if err := store.Ping(ctx); err != nil {
		store.Close()
		return nil, err
	}
	// Fail startup when migrations have not been applied.
	if _, err := pool.Exec(ctx, "SELECT id, title, description FROM items LIMIT 0"); err != nil {
		store.Close()
		return nil, err
	}
	return store, nil
}

func (s *PostgresStore) Close()                         { s.pool.Close() }
func (s *PostgresStore) Ping(ctx context.Context) error { return s.pool.Ping(ctx) }

func (s *PostgresStore) Create(ctx context.Context, input itemInput) (Item, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	item := Item{ID: newID(), Title: input.Title, Description: input.Description}
	_, err := s.pool.Exec(ctx, "INSERT INTO items (id, title, description) VALUES ($1, $2, $3)", item.ID, item.Title, item.Description)
	return item, err
}

func (s *PostgresStore) List(ctx context.Context) ([]Item, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	rows, err := s.pool.Query(ctx, "SELECT id, title, description FROM items ORDER BY creation_order")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	items := make([]Item, 0)
	for rows.Next() {
		var item Item
		if err := rows.Scan(&item.ID, &item.Title, &item.Description); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *PostgresStore) Get(ctx context.Context, id string) (Item, bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	var item Item
	err := s.pool.QueryRow(ctx, "SELECT id, title, description FROM items WHERE id = $1", id).Scan(&item.ID, &item.Title, &item.Description)
	if errors.Is(err, pgx.ErrNoRows) {
		return Item{}, false, nil
	}
	return item, err == nil, err
}

func (s *PostgresStore) Replace(ctx context.Context, id string, input itemInput) (Item, bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	var item Item
	err := s.pool.QueryRow(ctx, "UPDATE items SET title = $2, description = $3 WHERE id = $1 RETURNING id, title, description", id, input.Title, input.Description).Scan(&item.ID, &item.Title, &item.Description)
	if errors.Is(err, pgx.ErrNoRows) {
		return Item{}, false, nil
	}
	return item, err == nil, err
}

func (s *PostgresStore) Delete(ctx context.Context, id string) (bool, error) {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	result, err := s.pool.Exec(ctx, "DELETE FROM items WHERE id = $1", id)
	return err == nil && result.RowsAffected() != 0, err
}

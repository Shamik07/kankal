package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"sync"
)

type ItemStore interface {
	Ping(context.Context) error
	Create(context.Context, itemInput) (Item, error)
	List(context.Context) ([]Item, error)
	Get(context.Context, string) (Item, bool, error)
	Replace(context.Context, string, itemInput) (Item, bool, error)
	Delete(context.Context, string) (bool, error)
}

type Item struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description"`
}
type itemInput struct {
	Title       string `json:"title"`
	Description string `json:"description"`
}

type MemoryStore struct {
	mu    sync.RWMutex
	items map[string]Item
	order []string
}

func NewMemoryStore() *MemoryStore                { return &MemoryStore{items: make(map[string]Item)} }
func (s *MemoryStore) Ping(context.Context) error { return nil }
func (s *MemoryStore) Create(_ context.Context, input itemInput) (Item, error) {
	item := Item{ID: newID(), Title: input.Title, Description: input.Description}
	s.mu.Lock()
	s.items[item.ID] = item
	s.order = append(s.order, item.ID)
	s.mu.Unlock()
	return item, nil
}
func (s *MemoryStore) List(context.Context) ([]Item, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	result := make([]Item, 0, len(s.order))
	for _, id := range s.order {
		if item, ok := s.items[id]; ok {
			result = append(result, item)
		}
	}
	return result, nil
}
func (s *MemoryStore) Get(_ context.Context, id string) (Item, bool, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	item, ok := s.items[id]
	return item, ok, nil
}
func (s *MemoryStore) Replace(_ context.Context, id string, input itemInput) (Item, bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.items[id]; !ok {
		return Item{}, false, nil
	}
	item := Item{ID: id, Title: input.Title, Description: input.Description}
	s.items[id] = item
	return item, true, nil
}
func (s *MemoryStore) Delete(_ context.Context, id string) (bool, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if _, ok := s.items[id]; !ok {
		return false, nil
	}
	delete(s.items, id)
	return true, nil
}
func newID() string {
	var b [16]byte
	if _, err := rand.Read(b[:]); err != nil {
		panic("id generation failed")
	}
	return hex.EncodeToString(b[:])
}

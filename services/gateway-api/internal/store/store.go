package store

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

func Open(dsn string) (*gorm.DB, error) {
	return gorm.Open(postgres.Open(dsn), &gorm.Config{})
}

// Migrate applies db/migrations/*.sql in lexical order, tracked in schema_migrations.
func Migrate(db *gorm.DB, dir string) error {
	if err := db.Exec(`CREATE TABLE IF NOT EXISTS schema_migrations (
		filename text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())`).Error; err != nil {
		return err
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	var files []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ".sql") {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)
	for _, f := range files {
		var count int64
		db.Raw(`SELECT count(*) FROM schema_migrations WHERE filename = ?`, f).Scan(&count)
		if count > 0 {
			continue
		}
		sql, err := os.ReadFile(filepath.Join(dir, f))
		if err != nil {
			return err
		}
		if err := db.Transaction(func(tx *gorm.DB) error {
			if err := tx.Exec(string(sql)).Error; err != nil {
				return fmt.Errorf("apply %s: %w", f, err)
			}
			return tx.Exec(`INSERT INTO schema_migrations (filename) VALUES (?)`, f).Error
		}); err != nil {
			return err
		}
	}
	return nil
}

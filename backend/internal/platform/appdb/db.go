// Package appdb exposes the process DB handle for wiring/bootstrap.
// Prefer injecting *gorm.DB into services; do not call utils.GetDB from new code.
package appdb

import (
	"fmt"

	"backend/utils"

	"gorm.io/gorm"
)

// Open ensures the shared DB is initialized and returns it.
func Open() (*gorm.DB, error) {
	if err := utils.EnsureDB(); err != nil {
		return nil, fmt.Errorf("appdb open: %w", err)
	}
	if utils.DB == nil {
		return nil, fmt.Errorf("appdb open: database not initialized")
	}
	return utils.DB, nil
}

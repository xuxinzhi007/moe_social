package adminbiz_test

import (
	"context"
	"testing"

	adminbiz "backend/internal/biz/admin"
	admindata "backend/internal/data/admin"
	"backend/model"
)

func TestUpdateUserRole(t *testing.T) {
	db := openAdminListDB(t)
	user := model.User{Username: "u1", Email: "u1@test.com", Role: "user"}
	if err := db.Create(&user).Error; err != nil {
		t.Fatal(err)
	}
	store := admindata.NewStore(db)
	out, err := adminbiz.UpdateUser(context.Background(), store, adminbiz.UpdateUserInput{
		UserID: user.ID,
		Role:   "admin",
	})
	if err != nil {
		t.Fatalf("update: %v", err)
	}
	if out.GetRole() != "admin" {
		t.Fatalf("expected admin role, got %q", out.GetRole())
	}
}

func TestUpsertAndDeleteMenu(t *testing.T) {
	db := openAdminListDB(t)
	store := admindata.NewStore(db)
	item, err := adminbiz.UpsertMenu(context.Background(), store, adminbiz.UpsertMenuInput{
		Key: "ops.test", Kind: "item", Label: "Test", SortOrder: 1, Enabled: true,
	})
	if err != nil {
		t.Fatalf("upsert: %v", err)
	}
	if item.GetKey() != "ops.test" {
		t.Fatalf("unexpected key %q", item.GetKey())
	}
	if err := adminbiz.DeleteMenu(context.Background(), store, "ops.test"); err != nil {
		t.Fatalf("delete: %v", err)
	}
}

package adminbiz_test

import (
	"context"
	"testing"

	adminbiz "backend/internal/biz/admin"
	"backend/model"
)

func TestUpdateUserRole(t *testing.T) {
	db := openAdminListDB(t)
	user := model.User{Username: "u1", Email: "u1@test.com", Role: "user"}
	if err := db.Create(&user).Error; err != nil {
		t.Fatal(err)
	}
	out, err := adminbiz.UpdateUser(context.Background(), db, adminbiz.UpdateUserInput{
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
	item, err := adminbiz.UpsertMenu(context.Background(), db, adminbiz.UpsertMenuInput{
		Key: "ops.test", Kind: "item", Label: "Test", SortOrder: 1, Enabled: true,
	})
	if err != nil {
		t.Fatalf("upsert: %v", err)
	}
	if item.GetKey() != "ops.test" {
		t.Fatalf("unexpected key %q", item.GetKey())
	}
	if err := adminbiz.DeleteMenu(context.Background(), db, "ops.test"); err != nil {
		t.Fatalf("delete: %v", err)
	}
}

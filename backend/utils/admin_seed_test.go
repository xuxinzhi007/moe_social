package utils

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"backend/model"
	"backend/pkg/conf"

	"gorm.io/gorm"
)

// withAdminBootstrap 把全局 conf 指向一份只含 admin.bootstrap 的夹具配置。
// conf 是包级缓存，所以每个用例前后都要 Reset；这些用例不得 t.Parallel()。
func withAdminBootstrap(t *testing.T, username, password string) {
	t.Helper()
	body := fmt.Sprintf("admin:\n  bootstrap:\n    username: %q\n    password: %q\n", username, password)
	p := filepath.Join(t.TempDir(), "config.yaml")
	if err := os.WriteFile(p, []byte(body), 0o600); err != nil {
		t.Fatal(err)
	}
	conf.ResetForTest()
	t.Cleanup(conf.ResetForTest)
	if _, err := conf.LoadFile(p); err != nil {
		t.Fatalf("加载夹具配置: %v", err)
	}
	if got := conf.Get().Admin.Bootstrap.Password; got != password {
		t.Fatalf("前置条件不成立：夹具 password = %q, want %q", got, password)
	}
}

func adminSeedDB(t *testing.T) *gorm.DB {
	t.Helper()
	db := testMigrateDB(t)
	if err := db.AutoMigrate(&model.AdminAccount{}); err != nil {
		if strings.Contains(err.Error(), "CGO_ENABLED") {
			t.Skip("sqlite driver requires cgo on this platform")
		}
		t.Fatalf("建 admin_accounts 表: %v", err)
	}
	return db
}

// TestSeedAdminAccountRefusesWithoutPassword 钉住「口令类配置不允许有兜底默认值」。
//
// 判别力：把回落到 "admin123" 的旧分支加回来就会失败。旧实现在 password 为空时静默创建
// admin/admin123，而它当时唯一的调用方是免鉴权的 POST /api/admin/bootstrap/account，
// 等于任何人在空库部署上一条 curl 就能拿到 super_admin。
func TestSeedAdminAccountRefusesWithoutPassword(t *testing.T) {
	withAdminBootstrap(t, "admin", "")
	db := adminSeedDB(t)

	if err := SeedAdminAccount(db); !errors.Is(err, ErrAdminBootstrapPasswordUnset) {
		t.Fatalf("err = %v, want ErrAdminBootstrapPasswordUnset", err)
	}
	var n int64
	if err := db.Unscoped().Model(&model.AdminAccount{}).Count(&n).Error; err != nil {
		t.Fatal(err)
	}
	if n != 0 {
		t.Errorf("拒绝种账号却写进了 %d 行", n)
	}
}

// TestSeedAdminAccountHashesConfiguredPassword 确认落库的是 bcrypt 而非明文，
// 且配置里的口令确实能登录、众所周知的 admin123 不能。
//
// 最后一条断言是这次修复的直接判别点：只要代码里还留着任何 admin123 兜底，
// 或者夹具口令被忽略而回落到了默认值，CheckPassword("admin123") 就会为真。
func TestSeedAdminAccountHashesConfiguredPassword(t *testing.T) {
	const raw = "s3cret-from-config"
	withAdminBootstrap(t, "root", raw)
	db := adminSeedDB(t)

	if err := SeedAdminAccount(db); err != nil {
		t.Fatalf("SeedAdminAccount: %v", err)
	}
	var row model.AdminAccount
	if err := db.First(&row).Error; err != nil {
		t.Fatalf("读回账号: %v", err)
	}
	if row.Username != "root" {
		t.Errorf("username = %q, want root", row.Username)
	}
	if row.Role != "super_admin" {
		t.Errorf("role = %q, want super_admin", row.Role)
	}
	if row.Password == raw {
		t.Error("口令以明文落库，BeforeSave 钩子没有生效")
	}
	if !row.CheckPassword(raw) {
		t.Error("CheckPassword(配置口令) = false，种出来的账号登不进去")
	}
	if row.CheckPassword("admin123") {
		t.Error("admin123 仍能通过校验，代码级兜底没有真正摘掉")
	}
}

// TestSeedAdminAccountDoesNotResurrectAfterSoftDelete 钉住「软删全部管理员不能重新打开种账号」。
//
// 判别力：把 Count 的 Unscoped() 去掉就会失败 —— 软删行不计入 count，表看起来是空的，于是
// 再种一个；而 username 上的 uniqueIndex 仍被软删行占着，Create 必然撞唯一键。旧的免鉴权
// 端点正是靠这条把「已部署」退回「可被匿名接管」的状态。
func TestSeedAdminAccountDoesNotResurrectAfterSoftDelete(t *testing.T) {
	withAdminBootstrap(t, "admin", "first-password")
	db := adminSeedDB(t)
	if err := SeedAdminAccount(db); err != nil {
		t.Fatalf("首次种账号: %v", err)
	}
	if err := db.Where("username = ?", "admin").Delete(&model.AdminAccount{}).Error; err != nil {
		t.Fatalf("软删: %v", err)
	}

	var visible int64
	if err := db.Model(&model.AdminAccount{}).Count(&visible).Error; err != nil {
		t.Fatal(err)
	}
	if visible != 0 {
		t.Fatalf("前置条件不成立：软删后可见行数应为 0，实测 %d", visible)
	}

	if err := SeedAdminAccount(db); err != nil {
		t.Fatalf("软删后应安静跳过，实际返错: %v", err)
	}
	var total int64
	if err := db.Unscoped().Model(&model.AdminAccount{}).Count(&total).Error; err != nil {
		t.Fatal(err)
	}
	if total != 1 {
		t.Errorf("总行数 = %d, want 1（既没新增，也没顶替掉软删行）", total)
	}
}

// TestRunAutoMigrateSeedsAdminOnFullMigration 是「种账号真的接进了迁移」的正向对照。
//
// 判别力：删掉 RunAutoMigrate 末尾那次 SeedAdminAccount 调用就会失败。没有这条，
// 上面三个用例只证明 helper 本身正确，证不出它有人调 —— 端点删掉之后，迁移是首次超管
// 的唯一入口，接线断了就等于新部署永远登不进管理后台。
func TestRunAutoMigrateSeedsAdminOnFullMigration(t *testing.T) {
	withAdminBootstrap(t, "admin", "migrate-password")
	db := testMigrateDB(t)

	if err := RunAutoMigrate(db, MigrateOptions{Enabled: true}); err != nil {
		t.Fatalf("全量迁移失败: %v", err)
	}
	var row model.AdminAccount
	if err := db.Where("username = ?", "admin").First(&row).Error; err != nil {
		t.Fatalf("全量迁移后应存在 super_admin: %v", err)
	}
	if row.Role != "super_admin" {
		t.Errorf("role = %q, want super_admin", row.Role)
	}
	if !row.CheckPassword("migrate-password") {
		t.Error("迁移种出的账号口令与配置不符")
	}
}

// TestRunAutoMigrateSkipsSeedingWhenAdminAccountsOutOfScope 钉住局部迁移不去碰没建的表。
//
// 判别力：去掉 migrateEntriesInclude 那道守卫就会失败 —— Models 只含 users 时
// admin_accounts 表并不存在，SeedAdminAccount 的 Count 会报错，而那不是
// ErrAdminBootstrapPasswordUnset，于是整次迁移失败。
func TestRunAutoMigrateSkipsSeedingWhenAdminAccountsOutOfScope(t *testing.T) {
	withAdminBootstrap(t, "", "")
	db := testMigrateDB(t)

	if err := RunAutoMigrate(db, MigrateOptions{Enabled: true, Models: []string{"users"}}); err != nil {
		t.Fatalf("按 users 局部迁移失败: %v", err)
	}
	if db.Migrator().HasTable(&model.AdminAccount{}) {
		t.Error("按 users 过滤却建出了 admin_accounts 表")
	}
}

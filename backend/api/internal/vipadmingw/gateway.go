package vipadmingw

import (
	"context"
	"errors"

	vipbiz "backend/internal/biz/vip"
	vipadmin "backend/internal/service/vip"
	"backend/model"
)

var errNoBackend = errors.New("VIP 后端未配置")

// Gateway Admin / 公开 VIP 套餐路由：kratos HTTP（灰度）→ 进程内 biz。
type Gateway struct {
	kratos *KratosHTTPClient
	local  *vipadmin.AdminService
}

// New 构造网关；kratos 非 nil 且启用时，ListPlans 走纯 Kratos HTTP（PK-2）。
func New(local *vipadmin.AdminService, kratos *KratosHTTPClient) *Gateway {
	return &Gateway{local: local, kratos: kratos}
}

// Available 是否至少有一个后端。
func (g *Gateway) Available() bool {
	return g != nil && (g.kratosHTTPReady() || g.local != nil)
}

func (g *Gateway) kratosHTTPReady() bool {
	return g != nil && g.kratos != nil && g.kratos.enabled()
}

// Route 当前优先路由（日志/观测）。
func (g *Gateway) Route() string {
	if g == nil {
		return "none"
	}
	if g.kratosHTTPReady() {
		return "kratos_http"
	}
	if g.local != nil {
		return "in_process"
	}
	return "none"
}

func (g *Gateway) ListPlans(ctx context.Context, f vipbiz.ListPlansFilter) ([]model.VipPlan, int64, error) {
	if g == nil {
		return nil, 0, errNoBackend
	}
	if g.kratosHTTPReady() {
		return g.kratos.ListPlans(ctx, f)
	}
	if g.local != nil {
		return g.local.ListPlans(ctx, f)
	}
	return nil, 0, errNoBackend
}

func (g *Gateway) ListAllPlans(ctx context.Context) ([]model.VipPlan, error) {
	if g == nil {
		return nil, errNoBackend
	}
	if g.local != nil {
		return g.local.ListAllPlans(ctx)
	}
	return nil, errNoBackend
}

func (g *Gateway) GetPlan(ctx context.Context, planID string) (model.VipPlan, error) {
	if g == nil {
		return model.VipPlan{}, errNoBackend
	}
	id, err := vipbiz.ParsePlanID(planID)
	if err != nil {
		return model.VipPlan{}, err
	}
	if g.local != nil {
		return g.local.GetPlan(ctx, id)
	}
	return model.VipPlan{}, errNoBackend
}

func (g *Gateway) CreatePlan(ctx context.Context, in vipbiz.CreatePlanInput) (model.VipPlan, error) {
	if g == nil {
		return model.VipPlan{}, errNoBackend
	}
	if g.local != nil {
		return g.local.CreatePlan(ctx, in)
	}
	return model.VipPlan{}, errNoBackend
}

func (g *Gateway) UpdatePlan(ctx context.Context, planID string, patch vipbiz.UpdatePlanPatch) (model.VipPlan, error) {
	if g == nil {
		return model.VipPlan{}, errNoBackend
	}
	if g.local != nil {
		id, err := vipbiz.ParsePlanID(planID)
		if err != nil {
			return model.VipPlan{}, err
		}
		return g.local.UpdatePlan(ctx, id, patch)
	}
	return model.VipPlan{}, errNoBackend
}

func (g *Gateway) DeletePlan(ctx context.Context, planID string) error {
	if g == nil {
		return errNoBackend
	}
	if g.local != nil {
		id, err := vipbiz.ParsePlanID(planID)
		if err != nil {
			return err
		}
		return g.local.DeletePlan(ctx, id)
	}
	return errNoBackend
}

func (g *Gateway) BootstrapPlans(ctx context.Context) (int, error) {
	if g == nil {
		return 0, errNoBackend
	}
	if g.local != nil {
		return g.local.BootstrapPlans(ctx)
	}
	return 0, errNoBackend
}

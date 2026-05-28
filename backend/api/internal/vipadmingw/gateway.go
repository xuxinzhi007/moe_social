package vipadmingw

import (
	"context"
	"errors"

	vipbiz "backend/internal/biz/vip"
	vipadmin "backend/internal/service/vip"
	"backend/model"
	"backend/rpc/pb/super"
)

var errNoBackend = errors.New("VIP 后端未配置")

// Gateway Admin / 公开 VIP 套餐路由：kratos HTTP（灰度）→ 进程内 biz → legacy super。
type Gateway struct {
	kratos *KratosHTTPClient
	local  *vipadmin.AdminService
	super  super.SuperClient
}

// New 构造网关；kratos 非 nil 且启用时，ListPlans 走纯 Kratos HTTP（PK-2）。
func New(local *vipadmin.AdminService, legacy super.SuperClient, kratos *KratosHTTPClient) *Gateway {
	return &Gateway{local: local, super: legacy, kratos: kratos}
}

// Available 是否至少有一个后端。
func (g *Gateway) Available() bool {
	return g != nil && (g.kratosHTTPReady() || g.local != nil || g.super != nil)
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
	if g.super != nil {
		return "super"
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
	if g.super == nil {
		return nil, 0, errNoBackend
	}
	rep, err := g.super.AdminListVipPlans(ctx, &super.AdminListVipPlansReq{
		Page:           int32(f.Page),
		PageSize:       int32(f.PageSize),
		Keyword:        f.Keyword,
		IncludeDeleted: f.IncludeDeleted,
	})
	if err != nil {
		return nil, 0, err
	}
	out := make([]model.VipPlan, 0, len(rep.GetPlans()))
	for _, p := range rep.GetPlans() {
		out = append(out, vipPlanProtoToModel(p))
	}
	return out, int64(rep.GetTotal()), nil
}

func (g *Gateway) ListAllPlans(ctx context.Context) ([]model.VipPlan, error) {
	if g == nil {
		return nil, errNoBackend
	}
	if g.local != nil {
		return g.local.ListAllPlans(ctx)
	}
	if g.super == nil {
		return nil, errNoBackend
	}
	rep, err := g.super.GetVipPlans(ctx, &super.GetVipPlansReq{})
	if err != nil {
		return nil, err
	}
	out := make([]model.VipPlan, 0, len(rep.GetPlans()))
	for _, p := range rep.GetPlans() {
		out = append(out, vipPlanProtoToModel(p))
	}
	return out, nil
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
	if g.super == nil {
		return model.VipPlan{}, errNoBackend
	}
	rep, err := g.super.AdminGetVipPlan(ctx, &super.AdminGetVipPlanReq{PlanId: planID})
	if err != nil {
		return model.VipPlan{}, err
	}
	return vipPlanProtoToModel(rep.GetPlan()), nil
}

func (g *Gateway) CreatePlan(ctx context.Context, in vipbiz.CreatePlanInput) (model.VipPlan, error) {
	if g == nil {
		return model.VipPlan{}, errNoBackend
	}
	if g.local != nil {
		return g.local.CreatePlan(ctx, in)
	}
	if g.super == nil {
		return model.VipPlan{}, errNoBackend
	}
	rep, err := g.super.CreateVipPlan(ctx, &super.CreateVipPlanReq{
		Name:         in.Name,
		Description:  in.Description,
		Price:        float32(in.Price),
		DurationDays: int32(in.DurationDays),
	})
	if err != nil {
		return model.VipPlan{}, err
	}
	return vipPlanProtoToModel(rep.GetPlan()), nil
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
	if g.super == nil {
		return model.VipPlan{}, errNoBackend
	}
	rep, err := g.super.AdminUpdateVipPlan(ctx, &super.AdminUpdateVipPlanReq{
		PlanId:             planID,
		Name:               patch.Name,
		Description:        patch.Description,
		Price:              float32(patch.Price),
		DurationDays:       int32(patch.DurationDays),
		UpdateName:         patch.UpdateName,
		UpdateDescription:  patch.UpdateDescription,
		UpdatePrice:        patch.UpdatePrice,
		UpdateDurationDays: patch.UpdateDurationDays,
	})
	if err != nil {
		return model.VipPlan{}, err
	}
	return vipPlanProtoToModel(rep.GetPlan()), nil
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
	if g.super == nil {
		return errNoBackend
	}
	_, err := g.super.AdminDeleteVipPlan(ctx, &super.AdminDeleteVipPlanReq{PlanId: planID})
	return err
}

func (g *Gateway) BootstrapPlans(ctx context.Context) (int, error) {
	if g == nil {
		return 0, errNoBackend
	}
	if g.local != nil {
		return g.local.BootstrapPlans(ctx)
	}
	if g.super == nil {
		return 0, errNoBackend
	}
	rep, err := g.super.AdminBootstrapVipPlans(ctx, &super.AdminBootstrapVipPlansReq{})
	if err != nil {
		return 0, err
	}
	return int(rep.GetCreated()), nil
}

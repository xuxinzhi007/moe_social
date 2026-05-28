package vipadmingw

import (
	"strconv"
	"time"

	"backend/api/internal/types"
	"backend/model"
	"backend/rpc/pb/moe"
)

func vipPlanProtoToModel(p *moe.VipPlan) model.VipPlan {
	if p == nil {
		return model.VipPlan{}
	}
	id, _ := strconv.ParseUint(p.GetId(), 10, 64)
	plan := model.VipPlan{
		ID:       uint(id),
		Name:     p.GetName(),
		Features: p.GetDescription(),
		Price:    float64(p.GetPrice()),
		Duration: int(p.GetDurationDays()),
	}
	if t, err := time.ParseInLocation("2006-01-02 15:04:05", p.GetCreatedAt(), time.Local); err == nil {
		plan.CreatedAt = t
	}
	if t, err := time.ParseInLocation("2006-01-02 15:04:05", p.GetUpdatedAt(), time.Local); err == nil {
		plan.UpdatedAt = t
	}
	return plan
}

func vipPlanTypesToModel(p types.VipPlan) model.VipPlan {
	id, _ := strconv.ParseUint(p.Id, 10, 64)
	plan := model.VipPlan{
		ID:       uint(id),
		Name:     p.Name,
		Features: p.Description,
		Price:    p.Price,
		Duration: p.DurationDays,
	}
	if t, err := time.ParseInLocation("2006-01-02 15:04:05", p.CreatedAt, time.Local); err == nil {
		plan.CreatedAt = t
	}
	if t, err := time.ParseInLocation("2006-01-02 15:04:05", p.UpdatedAt, time.Local); err == nil {
		plan.UpdatedAt = t
	}
	return plan
}

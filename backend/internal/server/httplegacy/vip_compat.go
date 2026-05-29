package httplegacy

import (
	"net/http"
	"strconv"

	"backend/internal/apilegacy/common"
	"backend/internal/legacy/types"
	vipbiz "backend/internal/biz/vip"
	vipdata "backend/internal/data/vip"
	"backend/model"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"gorm.io/gorm"
)

// RegisterVipCompat D2：ListPlans 已迁入 RegisterVipReadAdminHTTPServer。
func RegisterVipCompat(srv *khttp.Server, db *gorm.DB) {
	_ = srv
	_ = db
}

func adminListVipPlans(db *gorm.DB) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		q := ctx.Request().URL.Query()
		page, _ := strconv.Atoi(q.Get("page"))
		pageSize, _ := strconv.Atoi(q.Get("page_size"))
		includeDeleted := q.Get("include_deleted") == "true" || q.Get("include_deleted") == "1"

		store := vipdata.NewStore(db)
		rows, total, err := vipbiz.ListPlans(ctx, store, vipbiz.ListPlansFilter{
			Page: page, PageSize: pageSize,
			Keyword: q.Get("keyword"), IncludeDeleted: includeDeleted,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListVipPlansResp{
				BaseResp: common.HandleError(err),
			})
		}
		items := make([]types.VipPlan, 0, len(rows))
		for _, p := range rows {
			items = append(items, vipPlanModelToTypes(p))
		}
		return ctx.JSON(http.StatusOK, types.AdminListVipPlansResp{
			BaseResp: common.HandleError(nil),
			Data:     types.AdminListVipPlansData{Items: items, Total: int(total)},
		})
	}
}

func vipPlanModelToTypes(p model.VipPlan) types.VipPlan {
	return types.VipPlan{
		Id:           strconv.FormatUint(uint64(p.ID), 10),
		Name:         p.Name,
		Description:  p.Features,
		Price:        p.Price,
		DurationDays: p.Duration,
		CreatedAt:    p.CreatedAt.Format("2006-01-02 15:04:05"),
		UpdatedAt:    p.UpdatedAt.Format("2006-01-02 15:04:05"),
	}
}

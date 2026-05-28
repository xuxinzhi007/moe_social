package moehttp

import (
	"net/http"
	"strconv"

	"backend/api/internal/common"
	"backend/api/internal/types"
	vipbiz "backend/internal/biz/vip"
	"backend/model"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"gorm.io/gorm"
)

// RegisterVipCompat VIP 只读 Admin HTTP（试点 :19032，与 super.api 同路径）。
func RegisterVipCompat(srv *khttp.Server, db *gorm.DB) {
	if srv == nil || db == nil {
		return
	}
	r := srv.Route("/")
	r.GET("/api/admin/vip/plans", adminListVipPlans(db))
}

func adminListVipPlans(db *gorm.DB) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		q := ctx.Request().URL.Query()
		page, _ := strconv.Atoi(q.Get("page"))
		pageSize, _ := strconv.Atoi(q.Get("page_size"))
		includeDeleted := q.Get("include_deleted") == "true" || q.Get("include_deleted") == "1"

		rows, total, err := vipbiz.ListPlans(ctx, db, vipbiz.ListPlansFilter{
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

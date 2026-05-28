package moehttp

import (
	"fmt"
	"net/http"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	checkinapp "backend/internal/service/checkin"
	adminapp "backend/internal/service/admin"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// PilotNativeCheckinCompatRoutes 签到域 Kratos HTTP（internal/service）。
const PilotNativeCheckinCompatRoutes = 7

// RegisterCheckinCompat 签到 + Admin 签到奖励配置。
func RegisterCheckinCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	checkin := svcCtx.CheckInApp
	if checkin != nil {
		r := srv.Route("/")
		r.POST("/api/user/:user_id/check-in", checkIn(checkin))
		r.GET("/api/user/:user_id/level", getUserLevel(checkin))
		r.GET("/api/user/:user_id/check-in/status", getCheckInStatus(checkin))
		r.GET("/api/user/:user_id/check-in/history", getCheckInHistory(checkin))
		r.GET("/api/user/:user_id/exp/logs", getExpLogs(checkin))
	}
	admin := svcCtx.AdminApp
	if admin != nil {
		r := srv.Route("/")
		r.GET("/api/admin/growth/check-in-rewards", adminListCheckInRewards(admin))
		r.PUT("/api/admin/growth/check-in-rewards/:reward_id", adminUpdateCheckInReward(admin, svcCtx))
	}
}

func checkIn(app *checkinapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CheckInReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CheckInResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.CheckIn(ctx, &moe.CheckInReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.CheckInResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		return ctx.JSON(http.StatusOK, types.CheckInResp{
			BaseResp: types.BaseResp{Code: 0, Message: "签到成功", Success: true},
			Data: types.CheckInData{
				ExpGained:       int(rpcResp.ExpGained),
				NewLevel:        int(rpcResp.NewLevel),
				ConsecutiveDays: int(rpcResp.ConsecutiveDays),
				LevelUp:         rpcResp.LevelUp,
				SpecialReward:   rpcResp.SpecialReward,
				NewAchievements: achievementUnlocksFromRPC(rpcResp.NewAchievements),
			},
		})
	}
}

func getCheckInStatus(app *checkinapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetCheckInStatusReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetCheckInStatusResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetCheckInStatus(ctx, &moe.GetCheckInStatusReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetCheckInStatusResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		st := rpcResp.GetStatus()
		return ctx.JSON(http.StatusOK, types.GetCheckInStatusResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取签到状态成功", Success: true},
			Data: types.CheckInStatus{
				HasCheckedToday: st.GetHasCheckedToday(),
				ConsecutiveDays: int(st.GetConsecutiveDays()),
				TodayReward:     int(st.GetTodayReward()),
				NextDayReward:   int(st.GetNextDayReward()),
				CanCheckIn:      st.GetCanCheckIn(),
			},
		})
	}
}

func getCheckInHistory(app *checkinapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetCheckInHistoryReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetCheckInHistoryResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetCheckInHistory(ctx, &moe.GetCheckInHistoryReq{
			UserId: req.UserId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetCheckInHistoryResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		records := make([]types.CheckInRecord, 0, len(rpcResp.GetRecords()))
		for _, record := range rpcResp.GetRecords() {
			records = append(records, types.CheckInRecord{
				CheckInDate:       record.GetCheckInDate(),
				ConsecutiveDays:   int(record.GetConsecutiveDays()),
				ExpReward:         int(record.GetExpReward()),
				IsSpecialReward:   record.GetIsSpecialReward(),
				SpecialRewardDesc: record.GetSpecialRewardDesc(),
			})
		}
		return ctx.JSON(http.StatusOK, types.GetCheckInHistoryResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取签到历史成功", Success: true},
			Data:     records,
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func getExpLogs(app *checkinapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetExpLogsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetExpLogsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetExpLogs(ctx, &moe.GetExpLogsReq{
			UserId: req.UserId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetExpLogsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		logs := make([]types.ExpLogRecord, 0, len(rpcResp.GetLogs()))
		for _, log := range rpcResp.GetLogs() {
			logs = append(logs, types.ExpLogRecord{
				Id:          log.GetId(),
				ExpChange:   int(log.GetExpChange()),
				Source:      log.GetSource(),
				Description: log.GetDescription(),
				CreatedAt:   log.GetCreatedAt(),
			})
		}
		return ctx.JSON(http.StatusOK, types.GetExpLogsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取经验日志成功", Success: true},
			Data:     logs,
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func getUserLevel(app *checkinapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserLevelReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserLevelResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserLevel(ctx, &moe.GetUserLevelReq{UserId: req.UserId})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.GetUserLevelResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		info := rpcResp.GetLevelInfo()
		return ctx.JSON(http.StatusOK, types.GetUserLevelResp{
			BaseResp: types.BaseResp{Code: 0, Message: "获取用户等级成功", Success: true},
			Data: types.UserLevelInfo{
				Level:        int(info.GetLevel()),
				Experience:   int(info.GetExperience()),
				TotalExp:     int(info.GetTotalExp()),
				NextLevelExp: int(info.GetNextLevelExp()),
				LevelTitle:   info.GetLevelTitle(),
				BadgeUrl:     info.GetBadgeUrl(),
				Progress:     info.GetProgress(),
			},
		})
	}
}

func adminListCheckInRewards(app *adminapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if _, br := common.RequireAdminToken(ctx.Request()); br != nil {
			return ctx.JSON(http.StatusOK, types.AdminListCheckInRewardsResp{BaseResp: *br})
		}
		rpcResp, err := app.ListCheckInRewards(ctx, &moe.AdminListCheckInRewardsReq{})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminListCheckInRewardsResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
		}
		items := make([]types.AdminCheckInRewardItem, len(rpcResp.GetItems()))
		for i, item := range rpcResp.GetItems() {
			items[i] = common.RpcAdminCheckInRewardToTypes(item)
		}
		return ctx.JSON(http.StatusOK, types.AdminListCheckInRewardsResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     items,
		})
	}
}

func adminUpdateCheckInReward(app *adminapp.AppService, svcCtx *svc.ServiceContext) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		if _, br := common.RequireAdminToken(ctx.Request()); br != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateCheckInRewardResp{BaseResp: *br})
		}
		var req types.AdminUpdateCheckInRewardReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.AdminUpdateCheckInRewardResp{
				BaseResp: common.HandleError(err),
			})
		}
		rpcResp, err := app.UpdateCheckInReward(ctx, &moe.AdminUpdateCheckInRewardReq{
			Id:                    req.RewardId,
			ConsecutiveDays:       int32(req.ConsecutiveDays),
			ExpReward:             int32(req.ExpReward),
			ExtraReward:           req.ExtraReward,
			UpdateConsecutiveDays: req.UpdateConsecutiveDays,
			UpdateExpReward:       req.UpdateExpReward,
			UpdateExtraReward:     req.UpdateExtraReward,
		})
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AdminUpdateCheckInRewardResp{
				BaseResp: common.HandleRPCError(err, ""),
			})
		}
		resp := types.AdminUpdateCheckInRewardResp{
			BaseResp: common.HandleRPCError(nil, "ok"),
			Data:     common.RpcAdminCheckInRewardToTypes(rpcResp.GetItem()),
		}
		if resp.BaseResp.Success && svcCtx != nil {
			common.TryRecordAdminAudit(ctx, svcCtx, "update", "check_in_reward", fmt.Sprintf("%d", req.RewardId), "更新签到奖励")
		}
		return ctx.JSON(http.StatusOK, resp)
	}
}

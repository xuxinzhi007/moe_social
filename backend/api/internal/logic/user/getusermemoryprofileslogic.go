// Code scaffolded by goctl. Safe to edit.
// goctl 1.10.1

package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserMemoryProfilesLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserMemoryProfilesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserMemoryProfilesLogic {
	return &GetUserMemoryProfilesLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserMemoryProfilesLogic) GetUserMemoryProfiles(req *types.GetUserMemoryProfilesReq) (resp *types.GetUserMemoryProfilesResp, err error) {
	rpcResp, err := l.svcCtx.LLMGW.GetUserMemoryProfiles(l.ctx, &super.GetUserMemoryProfilesReq{
		UserId: req.UserId,
		Limit:  int32(req.Limit),
	})
	if err != nil {
		return &types.GetUserMemoryProfilesResp{
			BaseResp: common.HandleRPCError(err, ""),
		}, nil
	}
	profiles := make([]types.UserMemoryProfile, 0, len(rpcResp.Profiles))
	for _, p := range rpcResp.Profiles {
		profiles = append(profiles, types.UserMemoryProfile{
			MemoryType: p.MemoryType,
			Summary:    p.Summary,
			ItemCount:  int(p.ItemCount),
			Confidence: p.Confidence,
		})
	}

	return &types.GetUserMemoryProfilesResp{
		BaseResp: common.HandleRPCError(nil, "获取用户画像摘要成功"),
		Data:     profiles,
	}, nil
}

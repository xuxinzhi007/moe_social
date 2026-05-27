package user

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserMemoriesDisplayLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetUserMemoriesDisplayLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserMemoriesDisplayLogic {
	return &GetUserMemoriesDisplayLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetUserMemoriesDisplayLogic) GetUserMemoriesDisplay(req *types.GetUserMemoriesReq) (*UserMemoryDisplayData, error) {
	const listLimit = 200
	memResp, err := l.svcCtx.LLMGW.GetUserMemories(l.ctx, &super.GetUserMemoriesReq{
		UserId: req.UserId,
		Limit:  listLimit,
		Offset: 0,
	})
	if err != nil {
		return nil, err
	}

	profResp, err := l.svcCtx.LLMGW.GetUserMemoryProfiles(l.ctx, &super.GetUserMemoryProfilesReq{
		UserId: req.UserId,
		Limit:  12,
	})
	if err != nil {
		return nil, err
	}

	data := BuildUserMemoryDisplay(memResp.Memories, profResp.Profiles)
	return &data, nil
}

func (l *GetUserMemoriesDisplayLogic) GetUserMemoriesDisplayResp(req *types.GetUserMemoriesReq) (map[string]interface{}, error) {
	data, err := l.GetUserMemoriesDisplay(req)
	if err != nil {
		return map[string]interface{}{
			"code":    common.HandleRPCError(err, "").Code,
			"message": common.HandleRPCError(err, "").Message,
			"success": false,
		}, nil
	}
	base := common.HandleRPCError(nil, "获取记忆展示数据成功")
	return map[string]interface{}{
		"code":    base.Code,
		"message": base.Message,
		"success": base.Success,
		"data":    data,
	}, nil
}

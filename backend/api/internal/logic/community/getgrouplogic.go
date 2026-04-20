package community

import (
	"context"
	"strconv"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGroupLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGroupLogic {
	return &GetGroupLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetGroupLogic) GetGroup(req *types.GetGroupReq) (resp *types.GetGroupResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetGroup(l.ctx, &super.GetGroupReq{
		GroupId: req.GroupId,
		UserId:  req.UserId,
	})
	if err != nil {
		return nil, err
	}

	if !rpcResp.Success {
		return &types.GetGroupResp{
			BaseResp: types.BaseResp{
				Code:    1,
				Message: rpcResp.Message,
				Success: false,
			},
		}, nil
	}

	return &types.GetGroupResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: rpcResp.Message,
			Success: true,
		},
		Data: types.Group{
			Id:          strconv.FormatUint(rpcResp.Group.Id, 10),
			Name:        rpcResp.Group.Name,
			Description: rpcResp.Group.Description,
			Avatar:      rpcResp.Group.Avatar,
			Cover:       rpcResp.Group.Cover,
			CreatorId:   strconv.FormatUint(rpcResp.Group.CreatorId, 10),
			CreatorName: rpcResp.Group.CreatorName,
			MemberCount: int(rpcResp.Group.MemberCount),
			IsPublic:    rpcResp.Group.IsPublic,
			Status:      rpcResp.Group.Status,
			CreatedAt:   rpcResp.Group.CreatedAt,
			IsJoined:    rpcResp.Group.IsJoined,
			UserRole:    rpcResp.Group.UserRole,
		},
	}, nil
}

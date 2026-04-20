package community

import (
	"context"
	"strconv"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type CreateGroupLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewCreateGroupLogic(ctx context.Context, svcCtx *svc.ServiceContext) *CreateGroupLogic {
	return &CreateGroupLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *CreateGroupLogic) CreateGroup(req *types.CreateGroupReq) (resp *types.CreateGroupResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.CreateGroup(l.ctx, &super.CreateGroupReq{
		Name:        req.Name,
		Description: req.Description,
		Avatar:      req.Avatar,
		Cover:       req.Cover,
		UserId:      req.UserId,
		IsPublic:    req.IsPublic,
	})
	if err != nil {
		return nil, err
	}

	return &types.CreateGroupResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: rpcResp.Message,
			Success: rpcResp.Success,
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

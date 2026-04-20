package community

import (
	"context"
	"strconv"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGroupsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetGroupsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGroupsLogic {
	return &GetGroupsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetGroupsLogic) GetGroups(req *types.GetGroupsReq) (resp *types.GetGroupsResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetGroups(l.ctx, &super.GetGroupsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		Keyword:  req.Keyword,
		IsPublic: req.IsPublic,
		UserId:  req.UserId,
	})
	if err != nil {
		return nil, err
	}

	groups := make([]types.Group, len(rpcResp.Groups))
	for i, g := range rpcResp.Groups {
		groups[i] = types.Group{
			Id:          strconv.FormatUint(g.Id, 10),
			Name:        g.Name,
			Description: g.Description,
			Avatar:      g.Avatar,
			Cover:       g.Cover,
			CreatorId:   strconv.FormatUint(g.CreatorId, 10),
			CreatorName: g.CreatorName,
			MemberCount: int(g.MemberCount),
			IsPublic:    g.IsPublic,
			Status:      g.Status,
			CreatedAt:   g.CreatedAt,
			IsJoined:    g.IsJoined,
			UserRole:    g.UserRole,
		}
	}

	return &types.GetGroupsResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data:  groups,
		Total: int(rpcResp.Total),
	}, nil
}

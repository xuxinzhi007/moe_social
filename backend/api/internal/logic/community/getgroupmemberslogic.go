package community

import (
	"context"
	"strconv"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetGroupMembersLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetGroupMembersLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetGroupMembersLogic {
	return &GetGroupMembersLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetGroupMembersLogic) GetGroupMembers(req *types.GetGroupMembersReq) (resp *types.GetGroupMembersResp, err error) {
	rpcResp, err := l.svcCtx.SuperRpcClient.GetGroupMembers(l.ctx, &super.GetGroupMembersReq{
		GroupId:  req.GroupId,
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
	})
	if err != nil {
		return nil, err
	}

	members := make([]types.GroupMember, len(rpcResp.Members))
	for i, m := range rpcResp.Members {
		members[i] = types.GroupMember{
			Id:         strconv.FormatUint(m.Id, 10),
			GroupId:    strconv.FormatUint(m.GroupId, 10),
			UserId:     strconv.FormatUint(m.UserId, 10),
			UserName:   m.UserName,
			UserAvatar: m.UserAvatar,
			Role:       m.Role,
			JoinAt:     m.JoinAt,
			CreatedAt:  m.CreatedAt,
		}
	}

	return &types.GetGroupMembersResp{
		BaseResp: types.BaseResp{
			Code:    0,
			Message: "success",
			Success: true,
		},
		Data:  members,
		Total: int(rpcResp.Total),
	}, nil
}

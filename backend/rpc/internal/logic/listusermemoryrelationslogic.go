package logic

import (
	"context"

	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type ListUserMemoryRelationsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewListUserMemoryRelationsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *ListUserMemoryRelationsLogic {
	return &ListUserMemoryRelationsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *ListUserMemoryRelationsLogic) ListUserMemoryRelations(in *super.ListUserMemoryRelationsReq) (*super.ListUserMemoryRelationsResp, error) {
	userID, err := parseUserIDUint(in.UserId)
	if err != nil || userID == 0 {
		return nil, errorx.InvalidArgument("无效的user_id")
	}
	rels, err := listMemoryRelations(l.svcCtx.DB, userID)
	if err != nil {
		return nil, errorx.Internal("读取记忆图谱失败")
	}
	items := make([]*super.UserMemoryRelationItem, 0, len(rels))
	for _, r := range rels {
		items = append(items, &super.UserMemoryRelationItem{
			FromKey:  r.FromKey,
			ToKey:    r.ToKey,
			Relation: r.Relation,
			Weight:   r.Weight,
		})
	}
	return &super.ListUserMemoryRelationsResp{Items: items}, nil
}

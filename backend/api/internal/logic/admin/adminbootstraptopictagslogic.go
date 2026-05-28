package admin

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminBootstrapTopicTagsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminBootstrapTopicTagsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminBootstrapTopicTagsLogic {
	return &AdminBootstrapTopicTagsLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *AdminBootstrapTopicTagsLogic) AdminBootstrapTopicTags(_ *types.EmptyReq) (resp *types.AdminBootstrapTopicTagsResp, err error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminBootstrapTopicTags(l.ctx, &moe.AdminBootstrapTopicTagsReq{})
	if err != nil {
		return &types.AdminBootstrapTopicTagsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	msg := "话题表已有数据，未导入"
	if rpcResp.GetCreated() > 0 {
		msg = "已导入官方话题标签"
	}
	resp = &types.AdminBootstrapTopicTagsResp{
		BaseResp: common.HandleRPCError(nil, msg),
		Data:     types.AdminBootstrapTopicTagsData{Created: int(rpcResp.GetCreated())},
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "bootstrap", "topic_tag", "", "导入官方话题标签")
	}
	return resp, nil
}

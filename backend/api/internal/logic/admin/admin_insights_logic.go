package admin

import (
	"context"
	"strconv"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

func parseAdminPathID(raw string) (uint64, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, strconv.ErrSyntax
	}
	return strconv.ParseUint(raw, 10, 64)
}

// —— AI 对话日志 ——

type AdminListAiChatSessionsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListAiChatSessionsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAiChatSessionsLogic {
	return &AdminListAiChatSessionsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListAiChatSessionsLogic) AdminListAiChatSessions(req *types.AdminListAiChatSessionsReq) (*types.AdminListAiChatSessionsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListAiChatSessions(l.ctx, &super.AdminListAiChatSessionsReq{
		Page:      int32(req.Page),
		PageSize:  int32(req.PageSize),
		UserId:    req.UserId,
		SessionId: req.SessionId,
		From:      req.From,
		To:        req.To,
	})
	if err != nil {
		return &types.AdminListAiChatSessionsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminAiChatSessionItem, 0, len(rpcResp.GetItems()))
	for _, row := range rpcResp.GetItems() {
		items = append(items, common.RpcAdminAiChatSessionToTypes(row))
	}
	return &types.AdminListAiChatSessionsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListAiChatSessionsData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}

type AdminListAiChatMessagesLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListAiChatMessagesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAiChatMessagesLogic {
	return &AdminListAiChatMessagesLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListAiChatMessagesLogic) AdminListAiChatMessages(req *types.AdminListAiChatMessagesReq) (*types.AdminListAiChatMessagesResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListAiChatMessages(l.ctx, &super.AdminListAiChatMessagesReq{
		Page:      int32(req.Page),
		PageSize:  int32(req.PageSize),
		UserId:    req.UserId,
		SessionId: req.SessionId,
		Role:      req.Role,
		Keyword:   req.Keyword,
		From:      req.From,
		To:        req.To,
	})
	if err != nil {
		return &types.AdminListAiChatMessagesResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminAiChatMessageItem, 0, len(rpcResp.GetItems()))
	for _, row := range rpcResp.GetItems() {
		items = append(items, common.RpcAdminAiChatMessageToTypes(row))
	}
	return &types.AdminListAiChatMessagesResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListAiChatMessagesData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}

type AdminExportAiChatMessagesLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminExportAiChatMessagesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminExportAiChatMessagesLogic {
	return &AdminExportAiChatMessagesLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminExportAiChatMessagesLogic) AdminExportAiChatMessages(req *types.AdminExportAiChatMessagesReq) (*types.AdminExportAiChatMessagesResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminExportAiChatMessages(l.ctx, &super.AdminExportAiChatMessagesReq{
		UserId:    req.UserId,
		SessionId: req.SessionId,
		Role:      req.Role,
		Keyword:   req.Keyword,
		From:      req.From,
		To:        req.To,
		Limit:     int32(req.Limit),
	})
	if err != nil {
		return &types.AdminExportAiChatMessagesResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminExportAiChatMessagesResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminExportAiChatMessagesData{
			Csv:       rpcResp.GetCsv(),
			RowCount:  int(rpcResp.GetRowCount()),
			Truncated: rpcResp.GetTruncated(),
		},
	}, nil
}

// —— 数据分析 ——

type AdminAnalyticsOverviewLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminAnalyticsOverviewLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminAnalyticsOverviewLogic {
	return &AdminAnalyticsOverviewLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminAnalyticsOverviewLogic) AdminAnalyticsOverview(_ *types.EmptyReq) (*types.AdminAnalyticsOverviewResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminAnalyticsOverview(l.ctx, &super.AdminGetMemoryStatsReq{})
	if err != nil {
		return &types.AdminAnalyticsOverviewResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	return &types.AdminAnalyticsOverviewResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     common.RpcAdminAnalyticsOverviewToTypes(rpcResp),
	}, nil
}

// —— 话题标签 ——

type AdminListTopicTagsLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListTopicTagsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListTopicTagsLogic {
	return &AdminListTopicTagsLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListTopicTagsLogic) AdminListTopicTags(req *types.AdminListTopicTagsReq) (*types.AdminListTopicTagsResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListTopicTags(l.ctx, &super.AdminListTopicTagsReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		Keyword:  req.Keyword,
	})
	if err != nil {
		return &types.AdminListTopicTagsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.TopicTag, 0, len(rpcResp.GetItems()))
	for _, row := range rpcResp.GetItems() {
		items = append(items, common.RpcTopicTagToTypes(row))
	}
	return &types.AdminListTopicTagsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListTopicTagsData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}

type AdminCreateTopicTagLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminCreateTopicTagLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateTopicTagLogic {
	return &AdminCreateTopicTagLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminCreateTopicTagLogic) AdminCreateTopicTag(req *types.AdminCreateTopicTagReq) (*types.AdminCreateTopicTagResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminCreateTopicTag(l.ctx, &super.AdminCreateTopicTagReq{
		Name:  req.Name,
		Color: req.Color,
	})
	if err != nil {
		return &types.AdminCreateTopicTagResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminCreateTopicTagResp{
		BaseResp: common.HandleRPCError(nil, "创建成功"),
		Data:     common.RpcTopicTagToTypes(rpcResp.GetItem()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "create", "topic_tag", resp.Data.Id, "创建话题标签")
	}
	return resp, nil
}

type AdminUpdateTopicTagLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateTopicTagLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateTopicTagLogic {
	return &AdminUpdateTopicTagLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminUpdateTopicTagLogic) AdminUpdateTopicTag(req *types.AdminUpdateTopicTagReq) (*types.AdminUpdateTopicTagResp, error) {
	tagID, err := parseAdminPathID(req.TagId)
	if err != nil {
		return &types.AdminUpdateTopicTagResp{BaseResp: common.HandleRPCError(err, "标签 ID 无效")}, nil
	}
	rpcResp, err := l.svcCtx.AdminGW.AdminUpdateTopicTag(l.ctx, &super.AdminUpdateTopicTagReq{
		TagId: tagID,
		Name:  req.Name,
		Color: req.Color,
	})
	if err != nil {
		return &types.AdminUpdateTopicTagResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminUpdateTopicTagResp{
		BaseResp: common.HandleRPCError(nil, "更新成功"),
		Data:     common.RpcTopicTagToTypes(rpcResp.GetItem()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "topic_tag", req.TagId, "更新话题标签")
	}
	return resp, nil
}

type AdminDeleteTopicTagLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteTopicTagLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteTopicTagLogic {
	return &AdminDeleteTopicTagLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminDeleteTopicTagLogic) AdminDeleteTopicTag(req *types.AdminDeleteTopicTagReq) (*types.AdminDeleteTopicTagResp, error) {
	tagID, err := parseAdminPathID(req.TagId)
	if err != nil {
		return &types.AdminDeleteTopicTagResp{BaseResp: common.HandleRPCError(err, "标签 ID 无效")}, nil
	}
	_, err = l.svcCtx.AdminGW.AdminDeleteTopicTag(l.ctx, &super.AdminDeleteTopicTagReq{TagId: tagID})
	if err != nil {
		return &types.AdminDeleteTopicTagResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminDeleteTopicTagResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "topic_tag", req.TagId, "删除话题标签")
	}
	return resp, nil
}

// —— 标签字典 ——

type AdminListTagDictionaryLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminListTagDictionaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListTagDictionaryLogic {
	return &AdminListTagDictionaryLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminListTagDictionaryLogic) AdminListTagDictionary(req *types.AdminListTagDictionaryReq) (*types.AdminListTagDictionaryResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminListTagDictionary(l.ctx, &super.AdminListTagDictionaryReq{
		Page:     int32(req.Page),
		PageSize: int32(req.PageSize),
		Category: req.Category,
		Keyword:  req.Keyword,
	})
	if err != nil {
		return &types.AdminListTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items := make([]types.AdminTagDictionaryItem, 0, len(rpcResp.GetItems()))
	for _, row := range rpcResp.GetItems() {
		items = append(items, common.RpcAdminTagDictionaryToTypes(row))
	}
	return &types.AdminListTagDictionaryResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data: types.AdminListTagDictionaryData{
			Items: items,
			Total: int(rpcResp.GetTotal()),
		},
	}, nil
}

type AdminCreateTagDictionaryLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminCreateTagDictionaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateTagDictionaryLogic {
	return &AdminCreateTagDictionaryLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminCreateTagDictionaryLogic) AdminCreateTagDictionary(req *types.AdminCreateTagDictionaryReq) (*types.AdminCreateTagDictionaryResp, error) {
	rpcResp, err := l.svcCtx.AdminGW.AdminCreateTagDictionary(l.ctx, &super.AdminCreateTagDictionaryReq{
		Category:  req.Category,
		Tag:       req.Tag,
		Label:     req.Label,
		Note:      req.Note,
		SortOrder: int32(req.SortOrder),
		Enabled:   req.Enabled,
	})
	if err != nil {
		return &types.AdminCreateTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminCreateTagDictionaryResp{
		BaseResp: common.HandleRPCError(nil, "创建成功"),
		Data:     common.RpcAdminTagDictionaryToTypes(rpcResp.GetItem()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "create", "tag_dictionary", resp.Data.Id, "创建 Bot 策略标签")
	}
	return resp, nil
}

type AdminUpdateTagDictionaryLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminUpdateTagDictionaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateTagDictionaryLogic {
	return &AdminUpdateTagDictionaryLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminUpdateTagDictionaryLogic) AdminUpdateTagDictionary(req *types.AdminUpdateTagDictionaryReq) (*types.AdminUpdateTagDictionaryResp, error) {
	entryID, err := parseAdminPathID(req.EntryId)
	if err != nil {
		return &types.AdminUpdateTagDictionaryResp{BaseResp: common.HandleRPCError(err, "条目 ID 无效")}, nil
	}
	rpcReq := &super.AdminUpdateTagDictionaryReq{
		EntryId:       entryID,
		Category:      req.Category,
		Tag:           req.Tag,
		Label:         req.Label,
		Note:          req.Note,
		SortOrder:     int32(req.SortOrder),
		Enabled:       req.Enabled,
		UpdateEnabled: req.UpdateEnabled,
	}
	rpcResp, err := l.svcCtx.AdminGW.AdminUpdateTagDictionary(l.ctx, rpcReq)
	if err != nil {
		return &types.AdminUpdateTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminUpdateTagDictionaryResp{
		BaseResp: common.HandleRPCError(nil, "更新成功"),
		Data:     common.RpcAdminTagDictionaryToTypes(rpcResp.GetItem()),
	}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "update", "tag_dictionary", req.EntryId, "更新 Bot 策略标签")
	}
	return resp, nil
}

type AdminDeleteTagDictionaryLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewAdminDeleteTagDictionaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteTagDictionaryLogic {
	return &AdminDeleteTagDictionaryLogic{Logger: logx.WithContext(ctx), ctx: ctx, svcCtx: svcCtx}
}

func (l *AdminDeleteTagDictionaryLogic) AdminDeleteTagDictionary(req *types.AdminDeleteTagDictionaryReq) (*types.AdminDeleteTagDictionaryResp, error) {
	entryID, err := parseAdminPathID(req.EntryId)
	if err != nil {
		return &types.AdminDeleteTagDictionaryResp{BaseResp: common.HandleRPCError(err, "条目 ID 无效")}, nil
	}
	_, err = l.svcCtx.AdminGW.AdminDeleteTagDictionary(l.ctx, &super.AdminDeleteTagDictionaryReq{EntryId: entryID})
	if err != nil {
		return &types.AdminDeleteTagDictionaryResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	resp := &types.AdminDeleteTagDictionaryResp{BaseResp: common.HandleRPCError(nil, "删除成功")}
	if resp.BaseResp.Success {
		common.TryRecordAdminAudit(l.ctx, l.svcCtx, "delete", "tag_dictionary", req.EntryId, "删除 Bot 策略标签")
	}
	return resp, nil
}

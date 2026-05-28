package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAiChatSessionsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAiChatSessionsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAiChatSessionsLogic {
	return &AdminListAiChatSessionsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAiChatSessionsLogic) AdminListAiChatSessions(in *moe.AdminListAiChatSessionsReq) (*moe.AdminListAiChatSessionsResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).ListAiChatSessions(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminListAiChatMessagesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAiChatMessagesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAiChatMessagesLogic {
	return &AdminListAiChatMessagesLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAiChatMessagesLogic) AdminListAiChatMessages(in *moe.AdminListAiChatMessagesReq) (*moe.AdminListAiChatMessagesResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).ListAiChatMessages(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminExportAiChatMessagesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminExportAiChatMessagesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminExportAiChatMessagesLogic {
	return &AdminExportAiChatMessagesLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminExportAiChatMessagesLogic) AdminExportAiChatMessages(in *moe.AdminExportAiChatMessagesReq) (*moe.AdminExportAiChatMessagesResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).ExportAiChatMessages(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminAnalyticsOverviewLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminAnalyticsOverviewLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminAnalyticsOverviewLogic {
	return &AdminAnalyticsOverviewLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminAnalyticsOverviewLogic) AdminAnalyticsOverview(in *moe.AdminGetMemoryStatsReq) (*moe.AdminAnalyticsOverviewResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).AnalyticsOverview(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminListTopicTagsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListTopicTagsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListTopicTagsLogic {
	return &AdminListTopicTagsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListTopicTagsLogic) AdminListTopicTags(in *moe.AdminListTopicTagsReq) (*moe.AdminListTopicTagsResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).ListTopicTags(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminCreateTopicTagLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminCreateTopicTagLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateTopicTagLogic {
	return &AdminCreateTopicTagLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminCreateTopicTagLogic) AdminCreateTopicTag(in *moe.AdminCreateTopicTagReq) (*moe.AdminCreateTopicTagResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).CreateTopicTag(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminUpdateTopicTagLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateTopicTagLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateTopicTagLogic {
	return &AdminUpdateTopicTagLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateTopicTagLogic) AdminUpdateTopicTag(in *moe.AdminUpdateTopicTagReq) (*moe.AdminUpdateTopicTagResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).UpdateTopicTag(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminDeleteTopicTagLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteTopicTagLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteTopicTagLogic {
	return &AdminDeleteTopicTagLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteTopicTagLogic) AdminDeleteTopicTag(in *moe.AdminDeleteTopicTagReq) (*moe.AdminDeleteTopicTagResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).DeleteTopicTag(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminListTagDictionaryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListTagDictionaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListTagDictionaryLogic {
	return &AdminListTagDictionaryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListTagDictionaryLogic) AdminListTagDictionary(in *moe.AdminListTagDictionaryReq) (*moe.AdminListTagDictionaryResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).ListTagDictionary(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminCreateTagDictionaryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminCreateTagDictionaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminCreateTagDictionaryLogic {
	return &AdminCreateTagDictionaryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminCreateTagDictionaryLogic) AdminCreateTagDictionary(in *moe.AdminCreateTagDictionaryReq) (*moe.AdminCreateTagDictionaryResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).CreateTagDictionary(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminUpdateTagDictionaryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminUpdateTagDictionaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminUpdateTagDictionaryLogic {
	return &AdminUpdateTagDictionaryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminUpdateTagDictionaryLogic) AdminUpdateTagDictionary(in *moe.AdminUpdateTagDictionaryReq) (*moe.AdminUpdateTagDictionaryResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).UpdateTagDictionary(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

type AdminDeleteTagDictionaryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminDeleteTagDictionaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminDeleteTagDictionaryLogic {
	return &AdminDeleteTagDictionaryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminDeleteTagDictionaryLogic) AdminDeleteTagDictionary(in *moe.AdminDeleteTagDictionaryReq) (*moe.AdminDeleteTagDictionaryResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).DeleteTagDictionary(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

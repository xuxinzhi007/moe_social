package logic

import (
	"context"

	adminapp "backend/internal/service/admin"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

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

func (l *AdminListAiChatSessionsLogic) AdminListAiChatSessions(in *super.AdminListAiChatSessionsReq) (*super.AdminListAiChatSessionsResp, error) {
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

func (l *AdminListAiChatMessagesLogic) AdminListAiChatMessages(in *super.AdminListAiChatMessagesReq) (*super.AdminListAiChatMessagesResp, error) {
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

func (l *AdminExportAiChatMessagesLogic) AdminExportAiChatMessages(in *super.AdminExportAiChatMessagesReq) (*super.AdminExportAiChatMessagesResp, error) {
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

func (l *AdminAnalyticsOverviewLogic) AdminAnalyticsOverview(in *super.AdminGetMemoryStatsReq) (*super.AdminAnalyticsOverviewResp, error) {
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

func (l *AdminListTopicTagsLogic) AdminListTopicTags(in *super.AdminListTopicTagsReq) (*super.AdminListTopicTagsResp, error) {
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

func (l *AdminCreateTopicTagLogic) AdminCreateTopicTag(in *super.AdminCreateTopicTagReq) (*super.AdminCreateTopicTagResp, error) {
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

func (l *AdminUpdateTopicTagLogic) AdminUpdateTopicTag(in *super.AdminUpdateTopicTagReq) (*super.AdminUpdateTopicTagResp, error) {
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

func (l *AdminDeleteTopicTagLogic) AdminDeleteTopicTag(in *super.AdminDeleteTopicTagReq) (*super.AdminDeleteTopicTagResp, error) {
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

func (l *AdminListTagDictionaryLogic) AdminListTagDictionary(in *super.AdminListTagDictionaryReq) (*super.AdminListTagDictionaryResp, error) {
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

func (l *AdminCreateTagDictionaryLogic) AdminCreateTagDictionary(in *super.AdminCreateTagDictionaryReq) (*super.AdminCreateTagDictionaryResp, error) {
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

func (l *AdminUpdateTagDictionaryLogic) AdminUpdateTagDictionary(in *super.AdminUpdateTagDictionaryReq) (*super.AdminUpdateTagDictionaryResp, error) {
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

func (l *AdminDeleteTagDictionaryLogic) AdminDeleteTagDictionary(in *super.AdminDeleteTagDictionaryReq) (*super.AdminDeleteTagDictionaryResp, error) {
	resp, err := adminapp.New(l.svcCtx.DB).DeleteTagDictionary(l.ctx, in)
	return resp, mapAdminInsightsErr(err)
}

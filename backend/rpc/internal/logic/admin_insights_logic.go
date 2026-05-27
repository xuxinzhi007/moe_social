package logic

import (
	"context"
	"encoding/csv"
	"fmt"
	"strconv"
	"strings"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	moebiz "backend/internal/biz/moe"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

// —— AI 对话日志 ——

type AdminListAiChatSessionsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAiChatSessionsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAiChatSessionsLogic {
	return &AdminListAiChatSessionsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAiChatSessionsLogic) AdminListAiChatSessions(in *super.AdminListAiChatSessionsReq) (*super.AdminListAiChatSessionsResp, error) {
	if l.svcCtx.DB == nil {
		return nil, errorx.Internal("数据库未就绪")
	}
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := l.svcCtx.DB.Model(&model.AiChatSession{})
	if uid := parseUintID(in.GetUserId()); uid > 0 {
		q = q.Where("user_id = ?", uid)
	}
	if sid := strings.TrimSpace(in.GetSessionId()); sid != "" {
		q = q.Where("session_id = ?", sid)
	}
	if from, ok := parseAdminDate(in.GetFrom()); ok {
		q = q.Where("updated_at >= ?", from)
	}
	if to, ok := parseAdminDateEnd(in.GetTo()); ok {
		q = q.Where("updated_at < ?", to)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, errorx.Internal("查询会话失败")
	}
	var rows []model.AiChatSession
	offset := int((page - 1) * pageSize)
	if err := q.Order("updated_at DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, errorx.Internal("查询会话失败")
	}
	names := loadUsernames(l.svcCtx.DB, sessionUserIDs(rows))
	type msgAgg struct {
		SessionID string
		Cnt       int64
		LastAt    time.Time
	}
	aggMap := map[string]msgAgg{}
	if len(rows) > 0 {
		sids := make([]string, 0, len(rows))
		for _, r := range rows {
			sids = append(sids, r.SessionID)
		}
		var aggs []struct {
			SessionID string
			Cnt       int64
			LastAt    time.Time
		}
		_ = l.svcCtx.DB.Model(&model.AiChatMessage{}).
			Select("session_id, COUNT(*) as cnt, MAX(created_at) as last_at").
			Where("session_id IN ?", sids).
			Group("session_id").
			Scan(&aggs).Error
		for _, a := range aggs {
			aggMap[a.SessionID] = msgAgg{SessionID: a.SessionID, Cnt: a.Cnt, LastAt: a.LastAt}
		}
	}
	out := &super.AdminListAiChatSessionsResp{Total: int32(total)}
	for _, row := range rows {
		item := &super.AdminAiChatSessionItem{
			Id:        strconv.FormatUint(uint64(row.ID), 10),
			UserId:    strconv.FormatUint(uint64(row.UserID), 10),
			Username:  names[row.UserID],
			SessionId: row.SessionID,
			Model:     row.Model,
			CreatedAt: row.CreatedAt.Format(time.DateTime),
			UpdatedAt: row.UpdatedAt.Format(time.DateTime),
		}
		if a, ok := aggMap[row.SessionID]; ok {
			item.MessageCount = int32(a.Cnt)
			if !a.LastAt.IsZero() {
				item.LastMessageAt = a.LastAt.Format(time.DateTime)
			}
		}
		out.Items = append(out.Items, item)
	}
	return out, nil
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
	if l.svcCtx.DB == nil {
		return nil, errorx.Internal("数据库未就绪")
	}
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := applyAiChatMessageFilters(l.svcCtx.DB.Model(&model.AiChatMessage{}), in)
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, errorx.Internal("查询消息失败")
	}
	var rows []model.AiChatMessage
	offset := int((page - 1) * pageSize)
	if err := q.Order("created_at DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, errorx.Internal("查询消息失败")
	}
	names := loadUsernames(l.svcCtx.DB, messageUserIDs(rows))
	out := &super.AdminListAiChatMessagesResp{Total: int32(total)}
	for _, row := range rows {
		out.Items = append(out.Items, aiChatMessageToProto(row, names[row.UserID]))
	}
	return out, nil
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
	if l.svcCtx.DB == nil {
		return nil, errorx.Internal("数据库未就绪")
	}
	limit := int(in.GetLimit())
	if limit <= 0 {
		limit = 5000
	}
	if limit > 20000 {
		limit = 20000
	}
	listReq := &super.AdminListAiChatMessagesReq{
		UserId:    in.GetUserId(),
		SessionId: in.GetSessionId(),
		Role:      in.GetRole(),
		Keyword:   in.GetKeyword(),
		From:      in.GetFrom(),
		To:        in.GetTo(),
		Page:      1,
		PageSize:  int32(limit + 1),
	}
	q := applyAiChatMessageFilters(l.svcCtx.DB.Model(&model.AiChatMessage{}), listReq)
	var rows []model.AiChatMessage
	if err := q.Order("created_at ASC").Limit(limit + 1).Find(&rows).Error; err != nil {
		return nil, errorx.Internal("导出失败")
	}
	truncated := len(rows) > limit
	if truncated {
		rows = rows[:limit]
	}
	names := loadUsernames(l.svcCtx.DB, messageUserIDs(rows))
	var b strings.Builder
	w := csv.NewWriter(&b)
	_ = w.Write([]string{"id", "user_id", "username", "session_id", "role", "model", "created_at", "content"})
	for _, row := range rows {
		_ = w.Write([]string{
			strconv.FormatUint(uint64(row.ID), 10),
			strconv.FormatUint(uint64(row.UserID), 10),
			names[row.UserID],
			row.SessionID,
			row.Role,
			row.Model,
			row.CreatedAt.Format(time.RFC3339),
			row.Content,
		})
	}
	w.Flush()
	return &super.AdminExportAiChatMessagesResp{
		Csv:       b.String(),
		RowCount:  int32(len(rows)),
		Truncated: truncated,
	}, nil
}

// —— 数据分析 ——

type AdminAnalyticsOverviewLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminAnalyticsOverviewLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminAnalyticsOverviewLogic {
	return &AdminAnalyticsOverviewLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminAnalyticsOverviewLogic) AdminAnalyticsOverview(_ *super.AdminGetMemoryStatsReq) (*super.AdminAnalyticsOverviewResp, error) {
	if l.svcCtx.DB == nil {
		return nil, errorx.Internal("数据库未就绪")
	}
	db := l.svcCtx.DB
	out := &super.AdminAnalyticsOverviewResp{}
	now := time.Now()
	since7d := now.AddDate(0, 0, -7)

	var userTotal int64
	_ = db.Model(&model.User{}).Count(&userTotal).Error
	out.UserTotal = int32(userTotal)

	var usersNew7d int64
	_ = db.Model(&model.User{}).Where("created_at >= ?", since7d).Count(&usersNew7d).Error
	out.UsersNew_7D = int32(usersNew7d)
	out.UsersByDay = countByDay(db, &model.User{}, "created_at", 14)

	var memTotal int64
	_ = db.Model(&model.UserMemory{}).Count(&memTotal).Error
	out.MemoryTotal = int32(memTotal)
	var memUsers int64
	_ = db.Model(&model.UserMemory{}).Distinct("user_id").Count(&memUsers).Error
	out.MemoryUsers = int32(memUsers)
	out.MemoriesByDay = countByDay(db, &model.UserMemory{}, "created_at", 14)
	out.MemoryByType = memoryTypeStats(db)

	if l.svcCtx.MoeAdmin != nil {
		stats, err := l.svcCtx.MoeAdmin.QueryToolStats(l.ctx, moebiz.ToolStatsFilter{
			From: &since7d,
			To:   &now,
		})
		if err == nil {
			out.MoeToolCalls_7D = int32(stats.TotalCalls)
			if stats.TotalCalls > 0 {
				out.MoeToolSuccessRate = float64(stats.SuccessCalls) / float64(stats.TotalCalls)
			}
			for _, row := range stats.ByDay {
				out.MoeToolsByDay = append(out.MoeToolsByDay, &super.AdminDayStat{
					Date:  row.Date,
					Count: int32(row.TotalCalls),
				})
			}
		}
	}

	var sessTotal int64
	_ = db.Model(&model.AiChatSession{}).Count(&sessTotal).Error
	out.ChatSessionsTotal = int32(sessTotal)
	var msg7d int64
	_ = db.Model(&model.AiChatMessage{}).Where("created_at >= ?", since7d).Count(&msg7d).Error
	out.ChatMessages_7D = int32(msg7d)
	out.ChatMessagesByDay = countByDay(db, &model.AiChatMessage{}, "created_at", 14)

	return out, nil
}

// —— 话题标签 ——

type AdminListTopicTagsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListTopicTagsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListTopicTagsLogic {
	return &AdminListTopicTagsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListTopicTagsLogic) AdminListTopicTags(in *super.AdminListTopicTagsReq) (*super.AdminListTopicTagsResp, error) {
	if l.svcCtx.DB == nil {
		return nil, errorx.Internal("数据库未就绪")
	}
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := l.svcCtx.DB.Model(&model.TopicTag{})
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("name LIKE ?", like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, errorx.Internal("查询话题标签失败")
	}
	var rows []model.TopicTag
	offset := int((page - 1) * pageSize)
	if err := q.Order("id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, errorx.Internal("查询话题标签失败")
	}
	out := &super.AdminListTopicTagsResp{Total: int32(total)}
	for _, row := range rows {
		out.Items = append(out.Items, topicTagToProto(row))
	}
	return out, nil
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
	if l.svcCtx.DB == nil {
		return nil, errorx.Internal("数据库未就绪")
	}
	name := strings.TrimSpace(in.GetName())
	if name == "" {
		return nil, errorx.InvalidArgument("标签名不能为空")
	}
	color := strings.TrimSpace(in.GetColor())
	if color == "" {
		color = "#7f7fd5"
	}
	row := model.TopicTag{Name: name, Color: color}
	if err := l.svcCtx.DB.Create(&row).Error; err != nil {
		return nil, errorx.InvalidArgument("创建失败，可能名称已存在")
	}
	return &super.AdminCreateTopicTagResp{Item: topicTagToProto(row)}, nil
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
	var row model.TopicTag
	if err := l.svcCtx.DB.First(&row, in.GetTagId()).Error; err != nil {
		return nil, errorx.NotFound("标签不存在")
	}
	updates := map[string]any{}
	if n := strings.TrimSpace(in.GetName()); n != "" {
		updates["name"] = n
	}
	if c := strings.TrimSpace(in.GetColor()); c != "" {
		updates["color"] = c
	}
	if len(updates) > 0 {
		if err := l.svcCtx.DB.Model(&row).Updates(updates).Error; err != nil {
			return nil, errorx.InvalidArgument("更新失败")
		}
		_ = l.svcCtx.DB.First(&row, row.ID).Error
	}
	return &super.AdminUpdateTopicTagResp{Item: topicTagToProto(row)}, nil
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
	if err := l.svcCtx.DB.Delete(&model.TopicTag{}, in.GetTagId()).Error; err != nil {
		return nil, errorx.Internal("删除失败")
	}
	return &super.AdminDeleteTopicTagResp{}, nil
}

// —— 标签字典 ——

type AdminListTagDictionaryLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListTagDictionaryLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListTagDictionaryLogic {
	return &AdminListTagDictionaryLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListTagDictionaryLogic) AdminListTagDictionary(in *super.AdminListTagDictionaryReq) (*super.AdminListTagDictionaryResp, error) {
	if l.svcCtx.DB == nil {
		return nil, errorx.Internal("数据库未就绪")
	}
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	q := l.svcCtx.DB.Model(&model.TagDictionaryEntry{})
	if cat := strings.TrimSpace(in.GetCategory()); cat != "" {
		q = q.Where("category = ?", cat)
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("tag LIKE ? OR label LIKE ?", like, like)
	}
	var total int64
	if err := q.Count(&total).Error; err != nil {
		return nil, errorx.Internal("查询标签字典失败")
	}
	var rows []model.TagDictionaryEntry
	offset := int((page - 1) * pageSize)
	if err := q.Order("sort_order ASC, id DESC").Offset(offset).Limit(int(pageSize)).Find(&rows).Error; err != nil {
		return nil, errorx.Internal("查询标签字典失败")
	}
	out := &super.AdminListTagDictionaryResp{Total: int32(total)}
	for _, row := range rows {
		out.Items = append(out.Items, tagDictToProto(row))
	}
	return out, nil
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
	if l.svcCtx.DB == nil {
		return nil, errorx.Internal("数据库未就绪")
	}
	cat := normalizeTagDictCategory(in.GetCategory())
	tag := strings.TrimSpace(in.GetTag())
	if tag == "" {
		return nil, errorx.InvalidArgument("标签不能为空")
	}
	row := model.TagDictionaryEntry{
		Category:  cat,
		Tag:       tag,
		Label:     strings.TrimSpace(in.GetLabel()),
		Note:      strings.TrimSpace(in.GetNote()),
		SortOrder: int(in.GetSortOrder()),
		Enabled:   in.GetEnabled(),
	}
	if err := l.svcCtx.DB.Create(&row).Error; err != nil {
		return nil, errorx.InvalidArgument("创建失败，可能重复")
	}
	return &super.AdminCreateTagDictionaryResp{Item: tagDictToProto(row)}, nil
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
	var row model.TagDictionaryEntry
	if err := l.svcCtx.DB.First(&row, in.GetEntryId()).Error; err != nil {
		return nil, errorx.NotFound("条目不存在")
	}
	updates := map[string]any{}
	if c := strings.TrimSpace(in.GetCategory()); c != "" {
		updates["category"] = normalizeTagDictCategory(c)
	}
	if t := strings.TrimSpace(in.GetTag()); t != "" {
		updates["tag"] = t
	}
	if in.GetLabel() != "" {
		updates["label"] = strings.TrimSpace(in.GetLabel())
	}
	if in.GetNote() != "" {
		updates["note"] = strings.TrimSpace(in.GetNote())
	}
	if in.GetSortOrder() != 0 {
		updates["sort_order"] = int(in.GetSortOrder())
	}
	if in.GetUpdateEnabled() {
		updates["enabled"] = in.GetEnabled()
	}
	if len(updates) > 0 {
		if err := l.svcCtx.DB.Model(&row).Updates(updates).Error; err != nil {
			return nil, errorx.InvalidArgument("更新失败")
		}
		_ = l.svcCtx.DB.First(&row, row.ID).Error
	}
	return &super.AdminUpdateTagDictionaryResp{Item: tagDictToProto(row)}, nil
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
	if err := l.svcCtx.DB.Delete(&model.TagDictionaryEntry{}, in.GetEntryId()).Error; err != nil {
		return nil, errorx.Internal("删除失败")
	}
	return &super.AdminDeleteTagDictionaryResp{}, nil
}

// —— helpers ——

func applyAiChatMessageFilters(db *gorm.DB, in *super.AdminListAiChatMessagesReq) *gorm.DB {
	q := db
	if uid := parseUintID(in.GetUserId()); uid > 0 {
		q = q.Where("user_id = ?", uid)
	}
	if sid := strings.TrimSpace(in.GetSessionId()); sid != "" {
		q = q.Where("session_id = ?", sid)
	}
	if role := strings.TrimSpace(in.GetRole()); role != "" {
		q = q.Where("role = ?", role)
	}
	if kw := strings.TrimSpace(in.GetKeyword()); kw != "" {
		like := "%" + kw + "%"
		q = q.Where("content LIKE ?", like)
	}
	if from, ok := parseAdminDate(in.GetFrom()); ok {
		q = q.Where("created_at >= ?", from)
	}
	if to, ok := parseAdminDateEnd(in.GetTo()); ok {
		q = q.Where("created_at < ?", to)
	}
	return q
}

func aiChatMessageToProto(row model.AiChatMessage, username string) *super.AdminAiChatMessageItem {
	return &super.AdminAiChatMessageItem{
		Id:          strconv.FormatUint(uint64(row.ID), 10),
		UserId:      strconv.FormatUint(uint64(row.UserID), 10),
		Username:    username,
		SessionId:   row.SessionID,
		SourceMsgId: row.SourceMsgID,
		Role:        row.Role,
		Content:     row.Content,
		Model:       row.Model,
		CreatedAt:   row.CreatedAt.Format(time.DateTime),
	}
}

func topicTagToProto(row model.TopicTag) *super.TopicTag {
	return &super.TopicTag{
		Id:        strconv.FormatUint(uint64(row.ID), 10),
		Name:      row.Name,
		Color:     row.Color,
		CreatedAt: row.CreatedAt.Format(time.DateTime),
	}
}

func tagDictToProto(row model.TagDictionaryEntry) *super.AdminTagDictionaryItem {
	return &super.AdminTagDictionaryItem{
		Id:        strconv.FormatUint(uint64(row.ID), 10),
		Category:  row.Category,
		Tag:       row.Tag,
		Label:     row.Label,
		Note:      row.Note,
		SortOrder: int32(row.SortOrder),
		Enabled:   row.Enabled,
		CreatedAt: row.CreatedAt.Format(time.DateTime),
		UpdatedAt: row.UpdatedAt.Format(time.DateTime),
	}
}

func normalizeTagDictCategory(raw string) string {
	switch strings.TrimSpace(raw) {
	case "bot_forbidden", "forbidden":
		return "bot_forbidden"
	case "bot_preferred", "preferred":
		return "bot_preferred"
	default:
		return "bot_forbidden"
	}
}

func parseUintID(s string) uint {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0
	}
	v, _ := strconv.ParseUint(s, 10, 64)
	return uint(v)
}

func parseAdminDate(s string) (time.Time, bool) {
	s = strings.TrimSpace(s)
	if s == "" {
		return time.Time{}, false
	}
	for _, layout := range []string{time.DateOnly, time.RFC3339, "2006-01-02 15:04:05"} {
		if t, err := time.ParseInLocation(layout, s, time.Local); err == nil {
			return t, true
		}
	}
	return time.Time{}, false
}

func parseAdminDateEnd(s string) (time.Time, bool) {
	t, ok := parseAdminDate(s)
	if !ok {
		return time.Time{}, false
	}
	if len(strings.TrimSpace(s)) == len("2006-01-02") {
		return t.Add(24 * time.Hour), true
	}
	return t, true
}

func sessionUserIDs(rows []model.AiChatSession) []uint {
	ids := make([]uint, 0, len(rows))
	seen := map[uint]struct{}{}
	for _, r := range rows {
		if _, ok := seen[r.UserID]; ok {
			continue
		}
		seen[r.UserID] = struct{}{}
		ids = append(ids, r.UserID)
	}
	return ids
}

func messageUserIDs(rows []model.AiChatMessage) []uint {
	ids := make([]uint, 0, len(rows))
	seen := map[uint]struct{}{}
	for _, r := range rows {
		if _, ok := seen[r.UserID]; ok {
			continue
		}
		seen[r.UserID] = struct{}{}
		ids = append(ids, r.UserID)
	}
	return ids
}

func loadUsernames(db *gorm.DB, userIDs []uint) map[uint]string {
	out := make(map[uint]string)
	if db == nil || len(userIDs) == 0 {
		return out
	}
	var users []model.User
	_ = db.Where("id IN ?", userIDs).Find(&users).Error
	for _, u := range users {
		out[u.ID] = u.Username
	}
	return out
}

func countByDay(db *gorm.DB, modelPtr any, column string, days int) []*super.AdminDayStat {
	if db == nil || days <= 0 {
		return nil
	}
	start := time.Now().AddDate(0, 0, -(days - 1))
	start = time.Date(start.Year(), start.Month(), start.Day(), 0, 0, 0, 0, start.Location())
	type row struct {
		Day   string
		Count int64
	}
	var rows []row
	expr := fmt.Sprintf("DATE(%s) as day, COUNT(*) as count", column)
	_ = db.Model(modelPtr).Select(expr).
		Where(column+" >= ?", start).
		Group("day").Order("day ASC").Scan(&rows).Error
	byDay := map[string]int64{}
	for _, r := range rows {
		byDay[r.Day] = r.Count
	}
	out := make([]*super.AdminDayStat, 0, days)
	for i := 0; i < days; i++ {
		d := start.AddDate(0, 0, i).Format(time.DateOnly)
		out = append(out, &super.AdminDayStat{Date: d, Count: int32(byDay[d])})
	}
	return out
}

func memoryTypeStats(db *gorm.DB) []*super.AdminMemoryTypeStat {
	if db == nil {
		return nil
	}
	type row struct {
		MemoryType string
		Count      int64
	}
	var rows []row
	_ = db.Model(&model.UserMemory{}).
		Select("memory_type, COUNT(*) as count").
		Group("memory_type").
		Order("count DESC").
		Scan(&rows).Error
	out := make([]*super.AdminMemoryTypeStat, len(rows))
	for i, r := range rows {
		mt := r.MemoryType
		if mt == "" {
			mt = "unknown"
		}
		out[i] = &super.AdminMemoryTypeStat{MemoryType: mt, Count: int32(r.Count)}
	}
	return out
}

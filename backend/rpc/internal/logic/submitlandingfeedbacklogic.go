package logic

import (
	"context"
	"strings"
	"time"
	"unicode/utf8"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/logutil"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type SubmitLandingFeedbackLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSubmitLandingFeedbackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SubmitLandingFeedbackLogic {
	return &SubmitLandingFeedbackLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *SubmitLandingFeedbackLogic) SubmitLandingFeedback(in *super.SubmitLandingFeedbackReq) (*super.SubmitLandingFeedbackResp, error) {
	email, err := utils.NormalizeFeishuEmail(in.GetEmail())
	if err != nil {
		return nil, errorx.InvalidArgument("请填写有效的联系邮箱")
	}

	content := strings.TrimSpace(in.GetContent())
	if utf8.RuneCountInString(content) < 5 {
		return nil, errorx.InvalidArgument("反馈内容至少 5 个字")
	}
	if utf8.RuneCountInString(content) > 2000 {
		return nil, errorx.InvalidArgument("反馈内容不能超过 2000 字")
	}

	category := normalizeLandingFeedbackCategory(in.GetCategory())
	source := strings.TrimSpace(in.GetSource())
	if source == "" {
		source = "official-site"
	}
	if len(source) > 64 {
		source = source[:64]
	}

	since := time.Now().Add(-1 * time.Hour)
	var recentCount int64
	if err := l.svcCtx.DB.Model(&model.LandingFeedback{}).
		Where("email = ? AND created_at >= ?", email, since).
		Count(&recentCount).Error; err != nil {
		l.Errorf("[landing] count recent feedback: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}
	if recentCount >= 5 {
		return nil, errorx.New(429, "提交过于频繁，请稍后再试")
	}

	row := model.LandingFeedback{
		Email:     email,
		Category:  category,
		Content:   content,
		Source:    source,
		ClientIP:  truncateRunes(strings.TrimSpace(in.GetClientIp()), 64),
		UserAgent: truncateRunes(strings.TrimSpace(in.GetUserAgent()), 255),
		CreatedAt: time.Now(),
	}
	if err := l.svcCtx.DB.Create(&row).Error; err != nil {
		l.Errorf("[landing] create feedback: %v", err)
		return nil, errorx.Internal("服务器内部错误")
	}

	if err := utils.SendFeishuLandingFeedbackNotification(l.ctx, utils.LandingFeedbackNotification{
		ID:        row.ID,
		Email:     row.Email,
		Category:  row.Category,
		Content:   row.Content,
		Source:    row.Source,
		ClientIP:  row.ClientIP,
		CreatedAt: row.CreatedAt,
	}); err != nil {
		l.Errorf("[landing] feishu notify failed id=%d email=%s: %v", row.ID, logutil.MaskEmail(email), err)
	} else {
		l.Infof("[landing] feedback saved id=%d email=%s", row.ID, logutil.MaskEmail(email))
	}

	return &super.SubmitLandingFeedbackResp{Id: uint64(row.ID)}, nil
}

func normalizeLandingFeedbackCategory(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "feature":
		return "feature"
	case "bug":
		return "bug"
	default:
		return "other"
	}
}

func truncateRunes(s string, max int) string {
	if max <= 0 || s == "" {
		return ""
	}
	if utf8.RuneCountInString(s) <= max {
		return s
	}
	runes := []rune(s)
	return string(runes[:max])
}

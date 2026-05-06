package logic

import (
	"context"
	"encoding/json"
	"errors"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"backend/model"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

var safePrivateImageToken = regexp.MustCompile(`^[a-zA-Z0-9._-]+$`)

type SendPrivateMessageLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewSendPrivateMessageLogic(ctx context.Context, svcCtx *svc.ServiceContext) *SendPrivateMessageLogic {
	return &SendPrivateMessageLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *SendPrivateMessageLogic) SendPrivateMessage(in *super.SendPrivateMessageReq) (*super.SendPrivateMessageResp, error) {
	senderID, err := strconv.ParseUint(strings.TrimSpace(in.SenderId), 10, 32)
	if err != nil || senderID == 0 {
		return nil, errors.New("invalid sender_id")
	}
	receiverID, err := strconv.ParseUint(strings.TrimSpace(in.ReceiverId), 10, 32)
	if err != nil || receiverID == 0 {
		return nil, errors.New("invalid receiver_id")
	}
	if senderID == receiverID {
		return nil, errors.New("cannot message self")
	}

	body := strings.TrimSpace(in.Body)
	if body == "" {
		return nil, errors.New("empty body")
	}
	maxRunes := utils.PrivateMessageBodyMaxRunes()
	if utf8.RuneCountInString(body) > maxRunes {
		return nil, errors.New("body too long")
	}

	paths, err := normalizePrivateImagePaths(in.ImagePaths)
	if err != nil {
		return nil, err
	}

	var sender model.User
	if err := l.svcCtx.DB.First(&sender, uint(senderID)).Error; err != nil {
		return nil, errors.New("sender not found")
	}
	var receiver model.User
	if err := l.svcCtx.DB.First(&receiver, uint(receiverID)).Error; err != nil {
		return nil, errors.New("receiver not found")
	}

	days := utils.PrivateMessageRetentionDaysForSender(&sender)
	row := model.PrivateMessage{
		SenderID:      uint(senderID),
		ReceiverID:    uint(receiverID),
		Body:          body,
		RetentionDays: retentionDaysToUint8(days),
		ExpiresAt:     time.Now().Add(time.Duration(days) * 24 * time.Hour),
	}
	if len(paths) > 0 {
		b, _ := json.Marshal(paths)
		row.ImagePaths = string(b)
	} else {
		row.ImagePaths = "[]"
	}

	if err := l.svcCtx.DB.Create(&row).Error; err != nil {
		l.Errorf("create private_message: %v", err)
		return nil, errors.New("save failed")
	}

	moeBy := loadMoeNoByUserID(l.svcCtx.DB, row.SenderID, row.ReceiverID)
	return &super.SendPrivateMessageResp{Message: privateMessageModelToProto(&row, moeBy)}, nil
}

func normalizePrivateImagePaths(in []string) ([]string, error) {
	maxN := utils.PrivateMessageImagePathsMax()
	if len(in) > maxN {
		return nil, errors.New("too many image_paths")
	}
	out := make([]string, 0, len(in))
	for _, p := range in {
		p = strings.TrimSpace(p)
		if p == "" {
			continue
		}
		if strings.Contains(p, "/") || strings.Contains(p, "\\") || strings.Contains(p, "..") {
			return nil, errors.New("invalid image path")
		}
		if !safePrivateImageToken.MatchString(p) {
			return nil, errors.New("invalid image path token")
		}
		out = append(out, p)
	}
	if len(out) > maxN {
		return nil, errors.New("too many image_paths")
	}
	return out, nil
}

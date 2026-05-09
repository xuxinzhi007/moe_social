package logic

import (
	"context"
	"strconv"
	"time"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetUserMemoriesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetUserMemoriesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetUserMemoriesLogic {
	return &GetUserMemoriesLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetUserMemoriesLogic) GetUserMemories(in *super.GetUserMemoriesReq) (*super.GetUserMemoriesResp, error) {
	start := time.Now()
	if in.UserId == "" {
		return nil, errorx.InvalidArgument("user_id不能为空")
	}

	userID, err := strconv.Atoi(in.UserId)
	if err != nil {
		return nil, errorx.InvalidArgument("无效的user_id")
	}

	limit := int(in.Limit)
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	offset := int(in.Offset)
	if offset < 0 {
		offset = 0
	}

	var total int64
	if err := l.svcCtx.DB.Model(&model.UserMemory{}).
		Where("user_id = ?", uint(userID)).
		Count(&total).Error; err != nil {
		l.Error("统计用户记忆总数失败: ", err)
		return nil, errorx.Internal("查询用户记忆列表失败")
	}

	var memories []model.UserMemory
	if err := l.svcCtx.DB.Where("user_id = ?", uint(userID)).
		Order("updated_at desc").
		Offset(offset).
		Limit(limit).
		Find(&memories).Error; err != nil {
		l.Error("查询用户记忆列表失败: ", err)
		return nil, errorx.Internal("查询用户记忆列表失败")
	}
	if cost := time.Since(start); cost > 150*time.Millisecond {
		l.Infof("slow get user memories query, user_id=%d limit=%d offset=%d total=%d cost_ms=%d", userID, limit, offset, total, cost.Milliseconds())
	}

	var rpcMemories []*super.UserMemory
	for _, m := range memories {
		rpcMemories = append(rpcMemories, &super.UserMemory{
			Id:          strconv.Itoa(int(m.ID)),
			UserId:      strconv.Itoa(int(m.UserID)),
			Key:         m.Key,
			Value:       m.Value,
			MemoryType:  m.MemoryType,
			Confidence:  m.Confidence,
			Source:      m.Source,
			SourceMsgId: m.SourceMsgID,
			SessionId:   m.SessionID,
			CreatedAt:   m.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt:   m.UpdatedAt.Format("2006-01-02 15:04:05"),
		})
	}

	return &super.GetUserMemoriesResp{
		Memories: rpcMemories,
		Total:    total,
		Limit:    int32(limit),
		Offset:   int32(offset),
		HasMore:  int64(offset+len(rpcMemories)) < total,
	}, nil
}

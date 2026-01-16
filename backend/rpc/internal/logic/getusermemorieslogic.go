package logic

import (
	"context"
	"strconv"

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
	if in.UserId == "" {
		return nil, errorx.InvalidArgument("user_id不能为空")
	}

	userID, err := strconv.Atoi(in.UserId)
	if err != nil {
		return nil, errorx.InvalidArgument("无效的user_id")
	}

	var memories []model.UserMemory
	if err := l.svcCtx.DB.Where("user_id = ?", uint(userID)).
		Order("updated_at desc").
		Find(&memories).Error; err != nil {
		l.Error("查询用户记忆列表失败: ", err)
		return nil, errorx.Internal("查询用户记忆列表失败")
	}

	var rpcMemories []*super.UserMemory
	for _, m := range memories {
		rpcMemories = append(rpcMemories, &super.UserMemory{
			Id:        strconv.Itoa(int(m.ID)),
			UserId:    strconv.Itoa(int(m.UserID)),
			Key:       m.Key,
			Value:     m.Value,
			CreatedAt: m.CreatedAt.Format("2006-01-02 15:04:05"),
			UpdatedAt: m.UpdatedAt.Format("2006-01-02 15:04:05"),
		})
	}

	return &super.GetUserMemoriesResp{
		Memories: rpcMemories,
	}, nil
}


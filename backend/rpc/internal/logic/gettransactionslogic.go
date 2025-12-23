package logic

import (
	"context"
	"strconv"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/rpc"

	"github.com/zeromicro/go-zero/core/logx"
	"gorm.io/gorm"
)

type GetTransactionsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetTransactionsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetTransactionsLogic {
	return &GetTransactionsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *GetTransactionsLogic) GetTransactions(in *rpc.GetTransactionsReq) (*rpc.GetTransactionsResp, error) {
	// 1. 转换用户ID
	userID, err := strconv.Atoi(in.UserId)
	if err != nil {
		return nil, errorx.New(400, "无效的用户ID")
	}

	// 2. 检查用户是否存在
	var user model.User
	if err := l.svcCtx.DB.First(&user, userID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			return nil, errorx.New(404, "用户不存在")
		}
		return nil, errorx.New(500, "查找用户失败")
	}

	// 3. 设置分页参数
	page := in.Page
	if page <= 0 {
		page = 1
	}

	pageSize := in.PageSize
	if pageSize <= 0 {
		pageSize = 10
	}

	offset := (page - 1) * pageSize

	// 4. 查询交易记录总数
	var total int64
	if err := l.svcCtx.DB.Model(&model.Transaction{}).Where("user_id = ?", userID).Count(&total).Error; err != nil {
		return nil, errorx.New(500, "查询交易记录总数失败")
	}

	// 5. 查询交易记录
	var transactions []model.Transaction
	if err := l.svcCtx.DB.Where("user_id = ?", userID).Order("created_at DESC").Offset(int(offset)).Limit(int(pageSize)).Find(&transactions).Error; err != nil {
		return nil, errorx.New(500, "查询交易记录失败")
	}

	// 6. 转换为RPC响应格式
	rpcTransactions := make([]*rpc.Transaction, len(transactions))
	for i, t := range transactions {
		rpcTransactions[i] = &rpc.Transaction{
			Id:          strconv.Itoa(int(t.ID)),
			UserId:      strconv.Itoa(int(t.UserID)),
			Amount:      float32(t.Amount),
			Type:        t.Type,
			Status:      t.Status,
			Description: t.Description,
			CreatedAt:   t.CreatedAt.Format("2006-01-02 15:04:05"),
		}
	}

	// 7. 构建响应
	return &rpc.GetTransactionsResp{
		Transactions: rpcTransactions,
		Total:        int32(total),
	}, nil
}

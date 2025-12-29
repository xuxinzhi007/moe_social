package logic

import (
	"context"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetVipRecordsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewGetVipRecordsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetVipRecordsLogic {
	return &GetVipRecordsLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

// 用户相关服务
func (l *GetVipRecordsLogic) GetVipRecords(in *super.GetVipRecordsReq) (*super.GetVipRecordsResp, error) {
	// 确保page和page_size有默认值
	page := in.Page
	if page <= 0 {
		page = 1
	}
	pageSize := in.PageSize
	if pageSize <= 0 {
		pageSize = 10
	}

	// 计算偏移量
	offset := (page - 1) * pageSize

	// 查询VIP记录列表
	var records []model.VipRecord
	var total int64

	// 获取总数
	l.svcCtx.DB.Model(&model.VipRecord{}).Where("user_id = ?", in.UserId).Count(&total)

	// 分页查询，预加载套餐信息
	result := l.svcCtx.DB.Preload("Plan").Where("user_id = ?", in.UserId).Offset(int(offset)).Limit(int(pageSize)).Find(&records)
	if result.Error != nil {
		l.Error("获取VIP记录失败: ", result.Error)
		return nil, errorx.Internal("获取VIP记录失败")
	}

	// 构建响应
	respRecords := make([]*super.VipRecord, len(records))
	for i, record := range records {
		status := "inactive"
		if record.IsActive {
			status = "active"
		}

		respRecords[i] = &super.VipRecord{
			Id:        string(rune(record.ID)),
			UserId:    in.UserId,
			PlanId:    string(rune(record.PlanID)),
			PlanName:  record.Plan.Name,
			StartAt:   record.StartAt.Format("2006-01-02 15:04:05"),
			EndAt:     record.EndAt.Format("2006-01-02 15:04:05"),
			Status:    status,
			CreatedAt: record.CreatedAt.Format("2006-01-02 15:04:05"),
		}
	}

	return &super.GetVipRecordsResp{
		Records: respRecords,
		Total:   int32(total),
	}, nil
}

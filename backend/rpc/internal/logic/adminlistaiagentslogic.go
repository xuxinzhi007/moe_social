package logic

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AdminListAiAgentsLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAdminListAiAgentsLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AdminListAiAgentsLogic {
	return &AdminListAiAgentsLogic{ctx: ctx, svcCtx: svcCtx, Logger: logx.WithContext(ctx)}
}

func (l *AdminListAiAgentsLogic) AdminListAiAgents(in *super.AdminListAiAgentsReq) (*super.AdminListAiAgentsResp, error) {
	page, pageSize := adminPageParams(in.GetPage(), in.GetPageSize())
	kw := strings.ToLower(strings.TrimSpace(in.GetKeyword()))

	var configs []model.AiUserConfig
	if err := l.svcCtx.DB.Find(&configs).Error; err != nil {
		l.Errorf("[admin] list ai configs: %v", err)
		return nil, errorx.Internal("查询 AI 角色失败")
	}

	type agentRow struct {
		id        string
		ownerID   uint
		ownerName string
		payload   string
	}
	all := make([]agentRow, 0)
	for _, cfg := range configs {
		ownerName := l.resolveUserDisplayName(cfg.UserID)
		agents := decodeAIJSONArray(cfg.AgentsJSON)
		for _, item := range agents {
			if !agentIsPublic(item) {
				continue
			}
			id := fmt.Sprint(item["id"])
			name := strings.ToLower(fmt.Sprint(item["name"]))
			if kw != "" && !strings.Contains(id, kw) && !strings.Contains(name, kw) && !strings.Contains(ownerName, kw) {
				continue
			}
			if _, ok := item["created_by_user_id"]; !ok {
				item["created_by_user_id"] = fmt.Sprint(cfg.UserID)
			}
			if ownerName != "" {
				item["author_name"] = ownerName
			}
			payload, err := json.Marshal(item)
			if err != nil {
				return nil, errorx.Internal("解析 AI 角色失败")
			}
			all = append(all, agentRow{
				id:        id,
				ownerID:   cfg.UserID,
				ownerName: ownerName,
				payload:   string(payload),
			})
		}
	}

	total := int32(len(all))
	start := int((page - 1) * pageSize)
	if start >= len(all) {
		return &super.AdminListAiAgentsResp{Items: []*super.AdminAiAgentItem{}, Total: total}, nil
	}
	end := start + int(pageSize)
	if end > len(all) {
		end = len(all)
	}
	slice := all[start:end]
	items := make([]*super.AdminAiAgentItem, len(slice))
	for i, row := range slice {
		items[i] = &super.AdminAiAgentItem{
			Id:          row.id,
			OwnerUserId: fmt.Sprint(row.ownerID),
			OwnerName:   row.ownerName,
			PayloadJson: row.payload,
		}
	}
	return &super.AdminListAiAgentsResp{Items: items, Total: total}, nil
}

func (l *AdminListAiAgentsLogic) resolveUserDisplayName(userID uint) string {
	var user model.User
	if err := l.svcCtx.DB.First(&user, userID).Error; err != nil {
		return ""
	}
	if user.Username != "" {
		return user.Username
	}
	return user.Email
}

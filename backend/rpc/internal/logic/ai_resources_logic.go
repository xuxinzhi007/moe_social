package logic

import (
	"context"
	"encoding/json"
	"fmt"

	"backend/model"
	"backend/rpc/internal/errorx"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

	"github.com/zeromicro/go-zero/core/logx"
)

type AiResourcesLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewAiResourcesLogic(ctx context.Context, svcCtx *svc.ServiceContext) *AiResourcesLogic {
	return &AiResourcesLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *AiResourcesLogic) list(field string, in *super.ListAiResourceReq) (*super.ListAiResourceResp, error) {
	userID, err := parseAIUserID(in.UserId)
	if err != nil {
		return nil, err
	}
	cfg, err := loadOrCreateAIConfig(l.svcCtx.DB, userID)
	if err != nil {
		return nil, errorx.Internal(fmt.Sprintf("读取AI配置失败: %v", err))
	}
	var raw string
	switch field {
	case "providers":
		raw = cfg.ProviderProfilesJSON
	case "agents":
		raw = cfg.AgentsJSON
	case "lorebooks":
		raw = cfg.LorebooksJSON
	default:
		return nil, errorx.Internal("未知资源类型")
	}
	items := decodeAIJSONArray(raw)
	resp := &super.ListAiResourceResp{Items: make([]*super.AiJsonResourceItem, 0, len(items))}
	for _, item := range items {
		resp.Items = append(resp.Items, &super.AiJsonResourceItem{
			Id:         fmt.Sprint(item["id"]),
			PayloadJson: mustJSON(item),
		})
	}
	return resp, nil
}

func (l *AiResourcesLogic) upsert(field string, in *super.UpsertAiResourceReq) (*super.UpsertAiResourceResp, error) {
	userID, err := parseAIUserID(in.UserId)
	if err != nil {
		return nil, err
	}
	cfg, err := loadOrCreateAIConfig(l.svcCtx.DB, userID)
	if err != nil {
		return nil, errorx.Internal(fmt.Sprintf("读取AI配置失败: %v", err))
	}
	item := map[string]interface{}{}
	if err := json.Unmarshal([]byte(in.PayloadJson), &item); err != nil {
		return nil, errorx.InvalidArgument("payload_json无效")
	}
	items := decodeAIJSONArray(selectField(cfg, field))
	id := fmt.Sprint(item["id"])
	replaced := false
	for i, current := range items {
		if fmt.Sprint(current["id"]) == id {
			items[i] = item
			replaced = true
			break
		}
	}
	if !replaced {
		items = append(items, item)
	}
	setField(cfg, field, encodeAIJSONArray(items))
	if err := l.svcCtx.DB.Save(cfg).Error; err != nil {
		return nil, errorx.Internal(fmt.Sprintf("保存AI配置失败: %v", err))
	}
	return &super.UpsertAiResourceResp{
		Item: &super.AiJsonResourceItem{
			Id:         id,
			PayloadJson: in.PayloadJson,
		},
	}, nil
}

func (l *AiResourcesLogic) delete(field string, in *super.DeleteAiResourceReq) (*super.DeleteAiResourceResp, error) {
	userID, err := parseAIUserID(in.UserId)
	if err != nil {
		return nil, err
	}
	cfg, err := loadOrCreateAIConfig(l.svcCtx.DB, userID)
	if err != nil {
		return nil, errorx.Internal(fmt.Sprintf("读取AI配置失败: %v", err))
	}
	items := decodeAIJSONArray(selectField(cfg, field))
	next := make([]map[string]interface{}, 0, len(items))
	for _, item := range items {
		if fmt.Sprint(item["id"]) != in.Id {
			next = append(next, item)
		}
	}
	setField(cfg, field, encodeAIJSONArray(next))
	if err := l.svcCtx.DB.Save(cfg).Error; err != nil {
		return nil, errorx.Internal(fmt.Sprintf("保存AI配置失败: %v", err))
	}
	return &super.DeleteAiResourceResp{Ok: true}, nil
}

func selectField(cfg *model.AiUserConfig, field string) string {
	switch field {
	case "providers":
		return cfg.ProviderProfilesJSON
	case "agents":
		return cfg.AgentsJSON
	case "lorebooks":
		return cfg.LorebooksJSON
	default:
		return "[]"
	}
}

func setField(cfg *model.AiUserConfig, field, value string) {
	switch field {
	case "providers":
		cfg.ProviderProfilesJSON = value
	case "agents":
		cfg.AgentsJSON = value
	case "lorebooks":
		cfg.LorebooksJSON = value
	}
}

func mustJSON(v interface{}) string {
	raw, _ := json.Marshal(v)
	return string(raw)
}

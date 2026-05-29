package httplegacy

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"backend/internal/apilegacy/common"
	llmbiz "backend/internal/biz/llm"
	"backend/internal/platform/svc"
	"backend/internal/legacy/types"
	aiv1 "backend/api/ai/v1"
	llmv1 "backend/api/llm/v1"
	aiapp "backend/internal/service/ai"
	llmapp "backend/internal/service/llm"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

const PilotNativeAiCompatRoutes = 14

func RegisterAiCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil {
		return
	}
	llmApp := svcCtx.LLMApp
	if llmApp == nil {
		return
	}
	// D2：AiResources CRUD 已迁入 RegisterAiResourcesHTTPServer
	r := srv.Route("/")
	r.GET("/api/ai/config", aiGetUserConfig(llmApp))
	r.PUT("/api/ai/config", aiUpsertUserConfig(llmApp))
	r.GET("/api/ai/memory/settings", aiGetAiMemorySettings(llmApp))
	r.PUT("/api/ai/memory/settings", aiPutAiMemorySettings(llmApp))
}

func aiListAgents(app *aiapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		items, base := aiListResource(ctx, app, userID, "agents")
		return ctx.JSON(http.StatusOK, types.AiAgentsResp{BaseResp: base, Data: items})
	}
}

func aiUpsertAgent(app *aiapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AiResourceUpsertReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		full, err := aiUpsertResource(ctx, app, userID, "agents", req.Data)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, &full.BaseResp)
	}
}

func aiDeleteAgent(app *aiapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AiResourceDeleteReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		if req.Id == "" {
			return errors.New("missing agent id")
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		full, err := aiDeleteResource(ctx, app, userID, "agents", req.Id)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, &full.BaseResp)
	}
}

func aiListPublicAgents(app *aiapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.ListPublicAiAgentsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		limit := int32(req.Limit)
		if limit <= 0 {
			limit = 50
		}
		resp, err := app.ListPublicAiAgents(ctx, aiv1.ListPublicAiAgentsReqFromMoe(&moe.ListPublicAiAgentsReq{Limit: limit}))
		if err != nil {
			return err
		}
		items := make([]map[string]interface{}, 0, len(resp.GetItems()))
		for _, item := range resp.GetItems() {
			items = append(items, aiDecodeObject(item.GetPayloadJson()))
		}
		return ctx.JSON(http.StatusOK, types.AiAgentsResp{
			BaseResp: common.HandleRPCError(nil, "操作成功"),
			Data:     items,
		})
	}
}

func aiListLorebooks(app *aiapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		items, base := aiListResource(ctx, app, userID, "lorebooks")
		return ctx.JSON(http.StatusOK, types.AiLorebooksResp{BaseResp: base, Data: items})
	}
}

func aiUpsertLorebook(app *aiapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AiLorebookUpsertReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		item := req.Data
		if req.Entries != nil {
			item["entries"] = req.Entries
		}
		full, err := aiUpsertResource(ctx, app, userID, "lorebooks", item)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, &full.BaseResp)
	}
}

func aiDeleteLorebook(app *aiapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AiResourceDeleteReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		if req.Id == "" {
			return errors.New("missing lorebook id")
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		full, err := aiDeleteResource(ctx, app, userID, "lorebooks", req.Id)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, &full.BaseResp)
	}
}

func aiListProviders(app *aiapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		items, base := aiListResource(ctx, app, userID, "providers")
		return ctx.JSON(http.StatusOK, types.AiProviderProfilesResp{BaseResp: base, Data: items})
	}
}

func aiUpsertProvider(app *aiapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AiResourceUpsertReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		full, err := aiUpsertResource(ctx, app, userID, "providers", req.Data)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, &full.BaseResp)
	}
}

func aiDeleteProvider(app *aiapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AiResourceDeleteReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		if req.Id == "" {
			return errors.New("missing provider id")
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		full, err := aiDeleteResource(ctx, app, userID, "providers", req.Id)
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, &full.BaseResp)
	}
}

func aiGetUserConfig(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		cfgReq := llmv1.GetAiUserConfigReqFromMoe(&moe.GetAiUserConfigReq{UserId: strconv.FormatUint(uint64(userID), 10)})
		resp, err := app.GetAiUserConfig(ctx, cfgReq)
		if err != nil {
			return ctx.JSON(http.StatusOK, types.AiUserConfigResp{BaseResp: common.HandleRPCError(err, "")})
		}
		return ctx.JSON(http.StatusOK, types.AiUserConfigResp{
			BaseResp: common.HandleRPCError(nil, "操作成功"),
			Data: types.AiUserConfigData{
				ProviderProfiles: []map[string]interface{}{},
				Agents:           []map[string]interface{}{},
				Lorebooks:        []map[string]interface{}{},
				UserPersona:      resp.GetUserPersona(),
				Preferences:      aiDecodeObject(resp.GetPreferencesJson()),
			},
		})
	}
}

func aiUpsertUserConfig(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AiUserConfigReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		var preferencesJSON string
		if req.Preferences != nil {
			raw, marshalErr := json.Marshal(req.Preferences)
			if marshalErr != nil {
				return ctx.JSON(http.StatusOK, types.AiUserConfigResp{
					BaseResp: common.HandleError(fmt.Errorf("marshal preferences: %w", marshalErr)),
				})
			}
			preferencesJSON = string(raw)
		}
		upsertCfg := llmv1.UpsertAiUserConfigReqFromMoe(&moe.UpsertAiUserConfigReq{
			UserId:          strconv.FormatUint(uint64(userID), 10),
			UserPersona:     req.UserPersona,
			HasUserPersona:  req.HasUserPersona,
			PreferencesJson: preferencesJSON,
		})
		resp, rpcErr := app.UpsertAiUserConfig(ctx, upsertCfg)
		if rpcErr != nil {
			return ctx.JSON(http.StatusOK, types.AiUserConfigResp{BaseResp: common.HandleRPCError(rpcErr, "")})
		}
		return ctx.JSON(http.StatusOK, types.AiUserConfigResp{
			BaseResp: common.HandleRPCError(nil, "操作成功"),
			Data: types.AiUserConfigData{
				ProviderProfiles: []map[string]interface{}{},
				Agents:           []map[string]interface{}{},
				Lorebooks:        []map[string]interface{}{},
				UserPersona:      resp.GetUserPersona(),
				Preferences:      aiDecodeObject(resp.GetPreferencesJson()),
			},
		})
	}
}

func aiGetAiMemorySettings(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.EmptyReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		uid := strconv.FormatUint(uint64(userID), 10)
		auto := aiUserMemoryAutoLearnEnabled(ctx, app, uid)
		return ctx.JSON(http.StatusOK, types.AiMemorySettingsResp{
			BaseResp: common.HandleError(nil),
			Data:     types.AiMemorySettingsData{AutoLearn: auto},
		})
	}
}

func aiPutAiMemorySettings(app *llmapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.AiMemorySettingsReq
		if err := bindRequest(ctx, &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		userID, err := common.UserIDUint(ctx)
		if err != nil {
			return err
		}
		uid := strconv.FormatUint(uint64(userID), 10)
		existing := map[string]interface{}{}
		cfgReq := llmv1.GetAiUserConfigReqFromMoe(&moe.GetAiUserConfigReq{UserId: uid})
		if cur, getErr := app.GetAiUserConfig(ctx, cfgReq); getErr == nil && cur != nil {
			existing = llmbiz.DecodePreferencesJSON(cur.GetPreferencesJson())
		}
		prefsJSON := llmbiz.MergeMemoryAutoLearnPref(existing, req.AutoLearn)
		upsertReq := llmv1.UpsertAiUserConfigReqFromMoe(&moe.UpsertAiUserConfigReq{
			UserId:          uid,
			PreferencesJson: prefsJSON,
		})
		if _, rpcErr := app.UpsertAiUserConfig(ctx, upsertReq); rpcErr != nil {
			return ctx.JSON(http.StatusOK, types.AiMemorySettingsResp{
				BaseResp: common.HandleRPCError(rpcErr, ""),
			})
		}
		return ctx.JSON(http.StatusOK, types.AiMemorySettingsResp{
			BaseResp: common.HandleError(nil),
			Data:     types.AiMemorySettingsData{AutoLearn: req.AutoLearn},
		})
	}
}

func aiListResource(ctx khttp.Context, app *aiapp.AppService, userID uint, kind string) ([]map[string]interface{}, types.BaseResp) {
	req := aiv1.ListAiResourceReqFromMoe(&moe.ListAiResourceReq{UserId: strconv.FormatUint(uint64(userID), 10)})
	var (
		resp *aiv1.ListAiResourceResp
		err  error
	)
	switch kind {
	case "providers":
		resp, err = app.ListAiProviders(ctx, req)
	case "agents":
		resp, err = app.ListAiAgents(ctx, req)
	case "lorebooks":
		resp, err = app.ListAiLorebooks(ctx, req)
	default:
		return []map[string]interface{}{}, common.HandleError(fmt.Errorf("unknown ai resource kind: %s", kind))
	}
	if err != nil {
		return []map[string]interface{}{}, common.HandleRPCError(err, "")
	}
	items := make([]map[string]interface{}, 0, len(resp.GetItems()))
	for _, item := range resp.GetItems() {
		items = append(items, aiDecodeObject(item.GetPayloadJson()))
	}
	return items, common.HandleRPCError(nil, "操作成功")
}

func aiUpsertResource(
	ctx khttp.Context,
	app *aiapp.AppService,
	userID uint,
	kind string,
	item map[string]interface{},
) (types.AiAgentsResp, error) {
	id := aiStringify(item["id"])
	if id == "" {
		return types.AiAgentsResp{BaseResp: common.HandleError(fmt.Errorf("missing resource id"))}, nil
	}
	raw, err := json.Marshal(item)
	if err != nil {
		return types.AiAgentsResp{BaseResp: common.HandleError(fmt.Errorf("marshal resource payload: %w", err))}, nil
	}
	req := aiv1.UpsertAiResourceReqFromMoe(&moe.UpsertAiResourceReq{
		UserId:      strconv.FormatUint(uint64(userID), 10),
		Id:          id,
		PayloadJson: string(raw),
	})
	var rpcErr error
	switch kind {
	case "providers":
		_, rpcErr = app.UpsertAiProvider(ctx, req)
	case "agents":
		_, rpcErr = app.UpsertAiAgent(ctx, req)
	case "lorebooks":
		_, rpcErr = app.UpsertAiLorebook(ctx, req)
	default:
		return types.AiAgentsResp{BaseResp: common.HandleError(fmt.Errorf("unknown ai resource kind: %s", kind))}, nil
	}
	if rpcErr != nil {
		return types.AiAgentsResp{BaseResp: common.HandleRPCError(rpcErr, "")}, nil
	}
	items, base := aiListResource(ctx, app, userID, kind)
	return types.AiAgentsResp{BaseResp: base, Data: items}, nil
}

func aiDeleteResource(
	ctx khttp.Context,
	app *aiapp.AppService,
	userID uint,
	kind, id string,
) (types.AiAgentsResp, error) {
	req := aiv1.DeleteAiResourceReqFromMoe(&moe.DeleteAiResourceReq{
		UserId: strconv.FormatUint(uint64(userID), 10),
		Id:     id,
	})
	var err error
	switch kind {
	case "providers":
		_, err = app.DeleteAiProvider(ctx, req)
	case "agents":
		_, err = app.DeleteAiAgent(ctx, req)
	case "lorebooks":
		_, err = app.DeleteAiLorebook(ctx, req)
	default:
		return types.AiAgentsResp{BaseResp: common.HandleError(fmt.Errorf("unknown ai resource kind: %s", kind))}, nil
	}
	if err != nil {
		return types.AiAgentsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}
	items, base := aiListResource(ctx, app, userID, kind)
	return types.AiAgentsResp{BaseResp: base, Data: items}, nil
}

func aiDecodeObject(raw string) map[string]interface{} {
	if raw == "" {
		return map[string]interface{}{}
	}
	var out map[string]interface{}
	if err := json.Unmarshal([]byte(raw), &out); err != nil {
		return map[string]interface{}{}
	}
	return out
}

func aiStringify(v interface{}) string {
	if v == nil {
		return ""
	}
	return strings.TrimSpace(fmt.Sprint(v))
}

func aiUserMemoryAutoLearnEnabled(ctx khttp.Context, app *llmapp.AppService, userID string) bool {
	if app == nil || userID == "" {
		return true
	}
	cfgReq := llmv1.GetAiUserConfigReqFromMoe(&moe.GetAiUserConfigReq{UserId: userID})
	resp, err := app.GetAiUserConfig(ctx, cfgReq)
	if err != nil || resp == nil {
		return true
	}
	prefs := llmbiz.DecodePreferencesJSON(resp.GetPreferencesJson())
	if v, ok := prefs["memory_auto_learn"]; ok {
		switch t := v.(type) {
		case bool:
			return t
		case string:
			return t != "false" && t != "0"
		case float64:
			return t != 0
		}
	}
	return true
}

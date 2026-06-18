package platformhttp

import (
	"context"

	platformv1 "backend/api/platform/v1"
	"backend/internal/apilegacy/common"
	moebiz "backend/internal/biz/moe"

	kerrors "github.com/go-kratos/kratos/v2/errors"
)

func (s *Server) MoeToolsSchema(ctx context.Context, _ *platformv1.MoeToolSchemaReq) (*platformv1.MoeToolSchemaResp, error) {
	if _, err := s.requireSvc(); err != nil {
		return nil, err
	}
	if s.moePlatform == nil {
		return nil, kerrors.InternalServer("MOE_UNAVAILABLE", "moe platform unavailable")
	}
	result := s.moePlatform.ToolsSchema()
	tools, err := moeToolsListValue(result.Tools)
	if err != nil {
		return nil, err
	}
	return &platformv1.MoeToolSchemaResp{
		Code: 0, Message: "ok", Success: true,
		Data: &platformv1.MoeToolSchemaData{Tools: tools, Tier: result.Tier},
	}, nil
}

func (s *Server) MoeExecuteTool(ctx context.Context, in *platformv1.MoeToolExecuteReq) (*platformv1.MoeToolExecuteResp, error) {
	if _, err := s.requireSvc(); err != nil {
		return nil, err
	}
	if s.moePlatform == nil {
		return nil, kerrors.InternalServer("MOE_UNAVAILABLE", "moe platform unavailable")
	}
	actorUID, err := moeBearerUserID(ctx)
	if err != nil {
		return nil, kerrors.BadRequest("UNAUTHORIZED", err.Error())
	}
	result, execErr := s.moePlatform.ExecuteTool(ctx, moebiz.ExecuteToolInput{
		Tool:           in.GetTool(),
		ArgumentsJSON:  in.GetArguments(),
		ActorUserID:    actorUID,
		AgentKey:       in.GetAgentKey(),
		Source:         "api",
		IdempotencyKey: in.GetIdempotencyKey(),
	})
	if execErr != nil {
		br := common.HandleRPCError(execErr, "")
		return &platformv1.MoeToolExecuteResp{
			Code: int32(br.Code), Message: br.Message, Success: br.Success,
		}, nil
	}
	br := common.HandleRPCError(nil, "ok")
	return &platformv1.MoeToolExecuteResp{
		Code: int32(br.Code), Message: br.Message, Success: br.Success,
		Data: &platformv1.MoeToolExecuteData{
			Ok: result.OK, Result: result.Result, Error: result.Error,
		},
	}, nil
}

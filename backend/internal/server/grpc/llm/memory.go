package llmgrpc

import (
	"context"

	llmv1 "backend/api/llm/v1"
	userbiz "backend/internal/biz/user"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

func (s *Server) UpsertUserMemory(ctx context.Context, in *llmv1.UpsertUserMemoryReq) (*llmv1.UpsertUserMemoryResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.UpsertUserMemory(ctx, in)
}

func (s *Server) GetUserMemories(ctx context.Context, in *llmv1.GetUserMemoriesReq) (*llmv1.GetUserMemoriesResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserMemories(ctx, in)
}

func (s *Server) DeleteUserMemory(ctx context.Context, in *llmv1.DeleteUserMemoryReq) (*llmv1.DeleteUserMemoryResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.DeleteUserMemory(ctx, in)
}

func (s *Server) SubmitUserMemoryFeedback(ctx context.Context, in *llmv1.SubmitUserMemoryFeedbackReq) (*llmv1.SubmitUserMemoryFeedbackResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.SubmitUserMemoryFeedback(ctx, in)
}

func (s *Server) GetUserMemoryProfiles(ctx context.Context, in *llmv1.GetUserMemoryProfilesReq) (*llmv1.GetUserMemoryProfilesResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	return app.GetUserMemoryProfiles(ctx, in)
}

func (s *Server) RebuildUserMemoryEmbeddings(ctx context.Context, in *llmv1.RebuildUserMemoryEmbeddingsReq) (*llmv1.RebuildUserMemoryEmbeddingsResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	in.UserId = userID
	return app.RebuildUserMemoryEmbeddings(ctx, in)
}

func (s *Server) GetUserMemoriesDisplay(ctx context.Context, in *llmv1.GetUserMemoriesDisplayReq) (*llmv1.GetUserMemoriesDisplayResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	memResp, err := app.GetUserMemories(ctx, &llmv1.GetUserMemoriesReq{
		UserId: userID, Limit: 200, Offset: 0,
	})
	if err != nil {
		return nil, err
	}
	profResp, err := app.GetUserMemoryProfiles(ctx, &llmv1.GetUserMemoryProfilesReq{
		UserId: userID, Limit: 12,
	})
	if err != nil {
		return nil, err
	}
	display := userbiz.BuildUserMemoryDisplay(memResp.GetMemories(), profResp.GetProfiles())
	return &llmv1.GetUserMemoriesDisplayResp{Data: userMemoryDisplayToProto(display)}, nil
}

func (s *Server) SearchUserMemories(ctx context.Context, in *llmv1.SearchUserMemoriesReq) (*llmv1.SearchUserMemoriesResp, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	limit := in.GetLimit()
	if limit <= 0 {
		limit = 8
	}
	memResp, err := app.GetUserMemories(ctx, &llmv1.GetUserMemoriesReq{
		UserId: in.GetUserId(), Limit: 200, Offset: 0,
	})
	if err != nil {
		return nil, err
	}
	result := userbiz.HybridSearchUserFacingMemories(ctx, userbiz.MemorySearchParams{
		Gateway:          s.memoryGW,
		InferenceBaseURL: s.inferenceBaseURL,
		UserID:           in.GetUserId(),
		Memories:         memResp.GetMemories(),
		Query:            in.GetQ(),
		Limit:            int(limit),
	})
	items := make([]*llmv1.UserMemoryDisplayItem, 0, len(result.Items))
	for _, it := range result.Items {
		items = append(items, &llmv1.UserMemoryDisplayItem{
			Id: it.ID, Key: it.Key, Title: it.Title, Content: it.Content,
			Category: it.Category, UpdatedAt: it.UpdatedAt,
		})
	}
	return &llmv1.SearchUserMemoriesResp{
		Data: &llmv1.SearchUserMemoriesData{
			Query: result.Query, Items: items, Total: int32(result.Total),
		},
	}, nil
}

func actorUserID(ctx context.Context) (string, error) {
	req, ok := khttp.RequestFromServerContext(ctx)
	if !ok || req == nil {
		return "", errUnauthorized
	}
	return bearerUserIDString(req)
}

func userMemoryDisplayToProto(d userbiz.UserMemoryDisplayData) *llmv1.UserMemoryDisplayData {
	profiles := make([]*llmv1.UserMemoryDisplayProfile, 0, len(d.Profiles))
	for _, p := range d.Profiles {
		profiles = append(profiles, &llmv1.UserMemoryDisplayProfile{
			Title: p.Title, Summary: p.Summary, ItemCount: int32(p.ItemCount),
		})
	}
	items := make([]*llmv1.UserMemoryDisplayItem, 0, len(d.Items))
	for _, it := range d.Items {
		items = append(items, &llmv1.UserMemoryDisplayItem{
			Id: it.ID, Key: it.Key, Title: it.Title, Content: it.Content,
			Category: it.Category, UpdatedAt: it.UpdatedAt,
		})
	}
	return &llmv1.UserMemoryDisplayData{
		Headline: d.Headline, Profiles: profiles, Items: items, Total: int32(d.Total),
	}
}

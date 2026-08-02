package companionhttp

import (
	"context"
	"errors"

	companionv1 "backend/api/companion/v1"
	companionapp "backend/internal/service/companion"
)

var errCompanionAppNil = errors.New("companion service unavailable")

type Server struct {
	companionv1.UnimplementedCompanionServer
	app *companionapp.AppService
}

func New(app *companionapp.AppService) *Server {
	return &Server{app: app}
}

func (s *Server) requireApp() (*companionapp.AppService, error) {
	if s.app == nil {
		return nil, errCompanionAppNil
	}
	return s.app, nil
}

func (s *Server) GetProfile(ctx context.Context, in *companionv1.GetProfileRequest) (*companionv1.GetProfileReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.GetProfile(ctx, userID, in)
}

func (s *Server) GetCommunityIdentity(ctx context.Context, in *companionv1.GetCommunityIdentityRequest) (*companionv1.GetCommunityIdentityReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.GetCommunityIdentity(ctx, userID, in)
}

func (s *Server) UpsertProfile(ctx context.Context, in *companionv1.UpsertProfileRequest) (*companionv1.UpsertProfileReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.UpsertProfile(ctx, userID, in)
}

func (s *Server) GetState(ctx context.Context, in *companionv1.GetStateRequest) (*companionv1.GetStateReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.GetState(ctx, userID, in)
}

func (s *Server) GetProactiveSettings(ctx context.Context, in *companionv1.GetProactiveSettingsRequest) (*companionv1.GetProactiveSettingsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.GetProactiveSettings(ctx, userID, in)
}

func (s *Server) UpdateProactiveSettings(ctx context.Context, in *companionv1.UpdateProactiveSettingsRequest) (*companionv1.UpdateProactiveSettingsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.UpdateProactiveSettings(ctx, userID, in)
}

func (s *Server) ListMemories(ctx context.Context, in *companionv1.ListMemoriesRequest) (*companionv1.ListMemoriesReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.ListMemories(ctx, userID, in)
}

func (s *Server) DeleteMemory(ctx context.Context, in *companionv1.DeleteMemoryRequest) (*companionv1.DeleteMemoryReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.DeleteMemory(ctx, userID, in)
}

func (s *Server) SetMemoryPinned(ctx context.Context, in *companionv1.SetMemoryPinnedRequest) (*companionv1.SetMemoryPinnedReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.SetMemoryPinned(ctx, userID, in)
}

func (s *Server) UpdateMemory(ctx context.Context, in *companionv1.UpdateMemoryRequest) (*companionv1.UpdateMemoryReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.UpdateMemory(ctx, userID, in)
}

func (s *Server) ListMemoryConflicts(ctx context.Context, in *companionv1.ListMemoryConflictsRequest) (*companionv1.ListMemoryConflictsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.ListMemoryConflicts(ctx, userID, in)
}

func (s *Server) ResolveMemoryConflict(ctx context.Context, in *companionv1.ResolveMemoryConflictRequest) (*companionv1.ResolveMemoryConflictReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.ResolveMemoryConflict(ctx, userID, in)
}

func (s *Server) ListChatHistory(ctx context.Context, in *companionv1.ListChatHistoryRequest) (*companionv1.ListChatHistoryReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.ListChatHistory(ctx, userID, in)
}

func (s *Server) ListRelationshipEvents(ctx context.Context, in *companionv1.ListRelationshipEventsRequest) (*companionv1.ListRelationshipEventsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.ListRelationshipEvents(ctx, userID, in)
}

func (s *Server) ListEvents(ctx context.Context, in *companionv1.ListEventsRequest) (*companionv1.ListEventsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.ListEvents(ctx, userID, in)
}

func (s *Server) GetTimeline(ctx context.Context, in *companionv1.ListEventsRequest) (*companionv1.ListEventsReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.GetTimeline(ctx, userID, in)
}

func (s *Server) MarkProactiveRead(ctx context.Context, in *companionv1.MarkProactiveReadRequest) (*companionv1.MarkProactiveReadReply, error) {
	app, err := s.requireApp()
	if err != nil {
		return nil, err
	}
	userID, err := actorUserID(ctx)
	if err != nil {
		return nil, err
	}
	return app.MarkProactiveRead(ctx, userID, in)
}

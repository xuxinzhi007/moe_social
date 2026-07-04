package gameapp

import (
	"context"
	"strings"
	"time"

	"gorm.io/gorm"

	gamebiz "backend/internal/biz/game"
	gamedata "backend/internal/data/game"
	"backend/pkg/llminference"
)

type Deps struct {
	Inference llminference.Config
	Model     string
	LlmMode   string
}

type AppService struct {
	store gamebiz.Store
	deps  Deps
}

func New(db *gorm.DB, deps Deps) *AppService {
	s := &AppService{store: gamedata.NewStore(db), deps: deps}
	if s.store != nil {
		gamebiz.StartWorldRunner(context.Background(), s.store, 45*time.Second)
	}
	return s
}

func (s *AppService) turnDeps() gamebiz.TurnDeps {
	if s == nil {
		return gamebiz.TurnDeps{}
	}
	model := strings.TrimSpace(s.deps.Model)
	mode := gamebiz.ResolveGameLlmMode(s.deps.LlmMode, model)
	return gamebiz.TurnDeps{Inference: s.deps.Inference, Model: model, LlmMode: mode}
}

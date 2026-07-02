// Package gameapp 文字游戏应用服务。
package gameapp

import (
	"gorm.io/gorm"

	gamebiz "backend/internal/biz/game"
	gamedata "backend/internal/data/game"
	"backend/pkg/llminference"
)

type Deps struct {
	Inference llminference.Config
	Model     string
}

type AppService struct {
	store gamebiz.Store
	deps  Deps
}

func New(db *gorm.DB, deps Deps) *AppService {
	return &AppService{store: gamedata.NewStore(db), deps: deps}
}

func (s *AppService) turnDeps() gamebiz.TurnDeps {
	if s == nil {
		return gamebiz.TurnDeps{}
	}
	return gamebiz.TurnDeps{Inference: s.deps.Inference, Model: s.deps.Model}
}

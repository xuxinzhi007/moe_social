package moewiring

import (
	"context"

	"backend/internal/platform/appdb"
	gameapp "backend/internal/service/game"
	"backend/pkg/conf"
	"backend/pkg/llminference"
)

func GameAPIInProcessEnabled() bool {
	return conf.DomainInProcess("game")
}

func NewAPIGameService() (*gameapp.AppService, error) {
	if !GameAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	inf, gameModel, gameMode := conf.GameInference()
	gameModel = llminference.ResolveModelName(context.Background(), inf, gameModel)
	return gameapp.New(db, gameapp.Deps{
		Inference: inf,
		Model:     gameModel,
		LlmMode:   gameMode,
		WorldTick: conf.WorldTickInterval(),
	}), nil
}

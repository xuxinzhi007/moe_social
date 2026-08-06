package moewiring

import (
	"context"

	"backend/internal/adapter/moeconfig"
	"backend/internal/platform/appdb"
	gameapp "backend/internal/service/game"
	"backend/pkg/llminference"
)

func GameAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.game_api_in_process")
}

func NewAPIGameService() (*gameapp.AppService, error) {
	if !GameAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	inf, gameModel, gameMode := moeconfig.GameInferenceFromViper()
	gameModel = llminference.ResolveModelName(context.Background(), inf, gameModel)
	return gameapp.New(db, gameapp.Deps{
		Inference: inf,
		Model:     gameModel,
		LlmMode:   gameMode,
	}), nil
}

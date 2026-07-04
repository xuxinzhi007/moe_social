package moewiring

import (
	"context"

	"backend/internal/adapter/moeconfig"
	gameapp "backend/internal/service/game"
	"backend/pkg/llminference"
	"backend/utils"
)

func GameAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.game_api_in_process")
}

func NewAPIGameService() (*gameapp.AppService, error) {
	if !GameAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	inf, gameModel, gameMode := moeconfig.GameInferenceFromViper()
	gameModel = llminference.ResolveModelName(context.Background(), inf, gameModel)
	return gameapp.New(db, gameapp.Deps{
		Inference: inf,
		Model:     gameModel,
		LlmMode:   gameMode,
	}), nil
}

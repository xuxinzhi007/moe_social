package moewiring

import (
	"context"

	gameapp "backend/internal/service/game"
	"backend/internal/adapter/moeconfig"
	"backend/pkg/llminference"
	"backend/utils"
)

func GameAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.game_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.game_api_in_process"}, false)
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
	inf, gameModel := moeconfig.GameInferenceFromViper()
	gameModel = llminference.ResolveModelName(context.Background(), inf, gameModel)
	return gameapp.New(db, gameapp.Deps{
		Inference: inf,
		Model:     gameModel,
	}), nil
}

package ai

import (
	"errors"
	"net/http"
	"strings"

	"backend/utils"
)

func parseUserID(r *http.Request) (uint, error) {
	authHeader := r.Header.Get("Authorization")
	if !strings.HasPrefix(authHeader, "Bearer ") {
		return 0, errors.New("missing or invalid authorization header")
	}
	tokenString := strings.TrimPrefix(authHeader, "Bearer ")
	return utils.GetUserIDFromToken(tokenString)
}

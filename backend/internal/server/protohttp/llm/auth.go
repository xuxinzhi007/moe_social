package llmhttp

import (
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend/utils"
)

var (
	errUnauthorized = errors.New("unauthorized")
)

func bearerUserIDString(r *http.Request) (string, error) {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(auth, "Bearer ") {
		auth = strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
	}
	if auth == "" {
		return "", errUnauthorized
	}
	cl, err := utils.ParseToken(auth)
	if err != nil {
		return "", err
	}
	return strconv.FormatUint(uint64(cl.UserID), 10), nil
}

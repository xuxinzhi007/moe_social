package postbiz

import (
	"context"
	"strings"

	mediabiz "backend/internal/biz/media"
	"backend/model"
	"backend/pkg/handdraw"
)

// EnsureHandDrawThumb 若已有缩略图则原样返回；否则从笔迹 JSON 服务端栅格化并入库。
func EnsureHandDrawThumb(
	ctx context.Context,
	cfg mediabiz.ImageConfig,
	user model.User,
	cardJSON string,
	currentThumb string,
) (string, error) {
	if strings.TrimSpace(currentThumb) != "" {
		return currentThumb, nil
	}
	cardJSON = strings.TrimSpace(cardJSON)
	if cardJSON == "" {
		return "", nil
	}
	png, err := handdraw.RasterPNG(cardJSON, 360)
	if err != nil {
		return "", err
	}
	folder := mediabiz.FolderNameForUser(user.ID, user.Username)
	info, err := mediabiz.SaveImageBytes(ctx, cfg, folder, "hand_draw_thumb.png", png)
	if err != nil {
		return "", err
	}
	return info.URL, nil
}

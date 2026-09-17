package runserver

import (
	"log"
	"strings"

	mediabiz "backend/internal/biz/media"
	"backend/internal/platform/apiconfig"
	"backend/internal/platform/moewiring"
	"backend/internal/platform/svc"
	mediaapp "backend/internal/service/media"
)

func wirePlatformServices(ctx *svc.ServiceContext, c apiconfig.ImageConf) {
	if ctx == nil {
		return
	}
	cfg := moewiring.ImageConfigFromAPI(c)
	app, err := mediaapp.New(cfg)
	if err != nil {
		log.Printf("[media] init store failed (driver=%s): %v — falling back to local", c.Driver, err)
		app, err = mediaapp.New(mediabiz.ImageConfig{
			Driver:        mediabiz.DriverLocal,
			LocalDir:      cfg.LocalDir,
			PublicBaseURL: cfg.PublicBaseURL,
		})
		if err != nil {
			log.Printf("[media] local fallback also failed: %v", err)
			return
		}
	}
	ctx.MediaApp = app
	log.Printf("[media] driver=%s local_dir=%s", strings.TrimSpace(c.Driver), c.LocalDir)
}

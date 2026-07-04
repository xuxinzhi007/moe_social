package runserver

import (
	"fmt"

	mediabiz "backend/internal/biz/media"
	"backend/internal/platform/svc"
	mediaapp "backend/internal/service/media"
)

func wirePlatformServices(ctx *svc.ServiceContext, c ImageConfig) {
	if ctx == nil {
		return
	}
	ctx.MediaApp = mediaapp.New(mediabiz.ImageConfig{
		LocalDir:      c.LocalDir,
		PublicBaseURL: c.PublicBaseUrl,
	})
}

type ImageConfig struct {
	LocalDir      string
	PublicBaseUrl string
}

func wireKratosNotes(rep *wireReporter) {
	if rep == nil {
		return
	}
	if kratosAdminInsightsEnabled() {
		rep.note(fmt.Sprintf("admin insights -> %s", kratosPilotBaseURL()))
	}
	if kratosAdminHTTPEnabled() {
		rep.note(fmt.Sprintf("moe admin kratos http -> %s", kratosPilotBaseURL()))
	}
	if kratosVipHTTPEnabled() {
		rep.note(fmt.Sprintf("vip kratos http -> %s", kratosPilotBaseURL()))
	}
}

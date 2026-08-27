package runserver

import (
	"fmt"
	"log"
	"strings"

	mediabiz "backend/internal/biz/media"
	"backend/internal/platform/svc"
	mediaapp "backend/internal/service/media"
)

func wirePlatformServices(ctx *svc.ServiceContext, c ImageConfig) {
	if ctx == nil {
		return
	}
	app, err := mediaapp.New(mediabiz.ImageConfig{
		Driver:        c.Driver,
		LocalDir:      c.LocalDir,
		PublicBaseURL: c.PublicBaseUrl,
		OSS: mediabiz.OSSConfig{
			Endpoint:        c.OSS.Endpoint,
			Bucket:          c.OSS.Bucket,
			AccessKeyID:     c.OSS.AccessKeyID,
			AccessKeySecret: c.OSS.AccessKeySecret,
			Prefix:          c.OSS.Prefix,
			PublicBaseURL:   c.OSS.PublicBaseUrl,
			Region:          c.OSS.Region,
			ProxyViaAPI:     c.OSS.ProxyViaAPI,
		},
	})
	if err != nil {
		log.Printf("[media] init store failed (driver=%s): %v — falling back to local", c.Driver, err)
		app, err = mediaapp.New(mediabiz.ImageConfig{
			Driver:        mediabiz.DriverLocal,
			LocalDir:      c.LocalDir,
			PublicBaseURL: c.PublicBaseUrl,
		})
		if err != nil {
			log.Printf("[media] local fallback also failed: %v", err)
			return
		}
	}
	ctx.MediaApp = app
	log.Printf("[media] driver=%s local_dir=%s", strings.TrimSpace(c.Driver), c.LocalDir)
}

// ImageConfig wiring 侧图片配置（含 OSS）。
type ImageConfig struct {
	Driver        string
	LocalDir      string
	PublicBaseUrl string
	OSS           ImageOSSConfig
}

// ImageOSSConfig 阿里云 OSS。
type ImageOSSConfig struct {
	Endpoint        string
	Bucket          string
	AccessKeyID     string
	AccessKeySecret string
	Prefix          string
	PublicBaseUrl   string
	Region          string
	ProxyViaAPI     bool
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

// 生产入口：单进程 Kratos HTTP :8888。
//
//	make moe-social
//	go run ./cmd/moe-social -f config/config.yaml
//
// 开发附加 deploy-agent 请用 cmd/moe-social-stack（make moe-social-dev）。
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"

	mediabiz "backend/internal/biz/media"
	"backend/internal/platform/apiconfig"
	"backend/internal/platform/moesocial"
	"backend/internal/platform/moewiring"
	"backend/internal/platform/wiring"
	"backend/internal/platform/yamlconf"
	"backend/pkg/conf"
	"backend/utils"

	"gopkg.in/yaml.v3"
)

var (
	configFile        = flag.String("f", "config/moe-service-app.yaml", "Unified config (moe-service-app.yaml + moe-service-data.yaml)")
	apiConfig         = flag.String("f-api", "", "Optional override: API struct fragment YAML")
	migrate           = flag.Bool("migrate", false, "run schema migrate before starting")
	migrateMediaQiniu = flag.Bool("migrate-media-qiniu", false, "upload image.local_dir to qiniu and exit")
	dryRun            = flag.Bool("dry-run", false, "with -migrate-media-qiniu, only list files")
)

func main() {
	flag.Parse()
	if *migrateMediaQiniu {
		if err := uploadLocalImages(*configFile, *apiConfig, *dryRun); err != nil {
			log.Fatal(err)
		}
		return
	}
	if err := moesocial.Run(moesocial.Options{
		UnifiedConfigFile: *configFile,
		APIConfigFile:     *apiConfig,
		Migrate:           utils.MigrateOptions{Enabled: *migrate},
	}); err != nil {
		log.Fatal(err)
	}
}

func uploadLocalImages(configFile, apiFile string, dryRun bool) error {
	paths := moesocial.ResolveStartupPaths(configFile, apiFile)
	fragment := apiconfig.DefaultConfig()
	if f := strings.TrimSpace(paths.APIFragment); f != "" {
		if _, err := os.Stat(f); err == nil {
			if err := yamlconf.Load(f, &fragment); err != nil {
				return fmt.Errorf("load api fragment %s: %w", f, err)
			}
		}
	}
	runserver.ApplyUnifiedConfigOverrides(&fragment)
	img := moewiring.ImageConfigFromAPI(fragment.Image)
	fillQiniuFromFiles(&img, paths.Unified, filepath.Join(filepath.Dir(paths.Unified), conf.DataConfigFileName), paths.APIFragment)
	log.Printf("config %s", conf.Path())
	log.Printf("qiniu bucket=%s cdn_domain=%s access_key=%s secret_key=%s",
		fieldState(img.Qiniu.Bucket), fieldState(img.Qiniu.CDNDomain), fieldState(img.Qiniu.AccessKey), fieldState(img.Qiniu.SecretKey))
	if img.Qiniu.AccessKey == "" || img.Qiniu.SecretKey == "" || img.Qiniu.Bucket == "" || img.Qiniu.CDNDomain == "" {
		return fmt.Errorf("qiniu config incomplete in %s", conf.Path())
	}
	_, _, err := mediabiz.MigrateLocalToQiniu(context.Background(), img, dryRun)
	return err
}

func fieldState(v string) string {
	if strings.TrimSpace(v) == "" {
		return "empty"
	}
	return "set"
}

// fillQiniuFromFiles 补上正式启动路径没接住的写法：config.yaml 里用 AccessKey / CDNDomain 这种大写键。
func fillQiniuFromFiles(img *mediabiz.ImageConfig, files ...string) {
	for _, path := range files {
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		var root looseConfig
		if err := yaml.Unmarshal(data, &root); err != nil {
			continue
		}
		applyLooseQiniu(img, root.Image.Qiniu)
		applyLooseQiniu(img, root.Image.QiniuPascal)
		applyLooseQiniu(img, root.ImagePascal.Qiniu)
		applyLooseQiniu(img, root.ImagePascal.QiniuPascal)
	}
}

type looseConfig struct {
	Image       looseImage `yaml:"image"`
	ImagePascal looseImage `yaml:"Image"`
}

type looseImage struct {
	Qiniu       looseQiniu `yaml:"qiniu"`
	QiniuPascal looseQiniu `yaml:"Qiniu"`
}

type looseQiniu struct {
	AccessKey1   string `yaml:"access_key"`
	AccessKey2   string `yaml:"AccessKey"`
	SecretKey1   string `yaml:"secret_key"`
	SecretKey2   string `yaml:"SecretKey"`
	Bucket1      string `yaml:"bucket"`
	Bucket2      string `yaml:"Bucket"`
	CDNDomain1   string `yaml:"cdn_domain"`
	CDNDomain2   string `yaml:"CDNDomain"`
	Region1      string `yaml:"region"`
	Region2      string `yaml:"Region"`
	Prefix1      string `yaml:"prefix"`
	Prefix2      string `yaml:"Prefix"`
	Private1     *bool  `yaml:"private"`
	Private2     *bool  `yaml:"Private"`
	ProxyViaAPI1 *bool  `yaml:"proxy_via_api"`
	ProxyViaAPI2 *bool  `yaml:"ProxyViaAPI"`
}

func applyLooseQiniu(img *mediabiz.ImageConfig, q looseQiniu) {
	if img.Qiniu.AccessKey == "" {
		img.Qiniu.AccessKey = firstText(q.AccessKey1, q.AccessKey2)
	}
	if img.Qiniu.SecretKey == "" {
		img.Qiniu.SecretKey = firstText(q.SecretKey1, q.SecretKey2)
	}
	if img.Qiniu.Bucket == "" {
		img.Qiniu.Bucket = firstText(q.Bucket1, q.Bucket2)
	}
	if img.Qiniu.CDNDomain == "" {
		img.Qiniu.CDNDomain = firstText(q.CDNDomain1, q.CDNDomain2)
	}
	if img.Qiniu.Region == "" {
		img.Qiniu.Region = firstText(q.Region1, q.Region2)
	}
	if img.Qiniu.Prefix == "" {
		img.Qiniu.Prefix = firstText(q.Prefix1, q.Prefix2)
	}
	if q.Private1 != nil {
		img.Qiniu.Private = *q.Private1
	} else if q.Private2 != nil {
		img.Qiniu.Private = *q.Private2
	}
	if q.ProxyViaAPI1 != nil {
		img.Qiniu.ProxyViaAPI = *q.ProxyViaAPI1
	} else if q.ProxyViaAPI2 != nil {
		img.Qiniu.ProxyViaAPI = *q.ProxyViaAPI2
	}
}

func firstText(values ...string) string {
	for _, v := range values {
		if s := strings.TrimSpace(v); s != "" {
			return s
		}
	}
	return ""
}

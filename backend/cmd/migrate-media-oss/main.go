// Command migrate-media-oss 将本地 image.local_dir 上传到阿里云 OSS（不删本地）。
//
// 用法（在 backend/ 下）：
//
//	go run ./cmd/migrate-media-oss -conf ./config
//
// 需已配置 image.oss.* 或环境变量 MOE_OSS_ACCESS_KEY_ID / MOE_OSS_ACCESS_KEY_SECRET。
// 上传完成后把 image.driver 改为 oss 并重启服务。
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strings"
	"time"

	mediabiz "backend/internal/biz/media"

	"github.com/spf13/viper"
)

func main() {
	confDir := flag.String("conf", "./config", "config directory containing config.yaml")
	dryRun := flag.Bool("dry-run", false, "only list files, do not upload")
	flag.Parse()

	v := viper.New()
	v.SetConfigName("config")
	v.SetConfigType("yaml")
	v.AddConfigPath(*confDir)
	if err := v.ReadInConfig(); err != nil {
		log.Fatalf("read config: %v", err)
	}

	localDir := strings.TrimSpace(v.GetString("image.local_dir"))
	if localDir == "" {
		localDir = "./data/images"
	}
	cfg := mediabiz.ImageConfig{
		Driver:        mediabiz.DriverOSS,
		LocalDir:      localDir,
		PublicBaseURL: v.GetString("image.public_base_url"),
		OSS: mediabiz.OSSConfig{
			Endpoint:        v.GetString("image.oss.endpoint"),
			Bucket:          v.GetString("image.oss.bucket"),
			AccessKeyID:     v.GetString("image.oss.access_key_id"),
			AccessKeySecret: v.GetString("image.oss.access_key_secret"),
			Prefix:          v.GetString("image.oss.prefix"),
			PublicBaseURL:   v.GetString("image.oss.public_base_url"),
			Region:          v.GetString("image.oss.region"),
			ProxyViaAPI:     v.GetBool("image.oss.proxy_via_api"),
		},
	}

	ossStore, err := mediabiz.NewBlobStore(cfg)
	if err != nil {
		log.Fatalf("oss store: %v", err)
	}
	// NewBlobStore(oss) returns hybrid; we need pure OSS put. Re-open as OSS-only via hybrid primary.
	// Simpler: use local list + put through hybrid (writes OSS).
	local := mediabiz.ImageConfig{Driver: mediabiz.DriverLocal, LocalDir: localDir}
	localStore, err := mediabiz.NewBlobStore(local)
	if err != nil {
		log.Fatalf("local store: %v", err)
	}

	ctx := context.Background()
	all, err := localStore.ListAll(ctx)
	if err != nil {
		log.Fatalf("list local: %v", err)
	}
	log.Printf("found %d local objects under %s", len(all), localDir)
	if *dryRun {
		for _, m := range all {
			fmt.Printf("%s/%s (%d bytes)\n", m.Folder, m.Filename, m.Size)
		}
		return
	}

	ok, fail := 0, 0
	for i, m := range all {
		obj, err := localStore.Open(ctx, m.Folder, m.Filename)
		if err != nil {
			log.Printf("[%d/%d] open %s/%s: %v", i+1, len(all), m.Folder, m.Filename, err)
			fail++
			continue
		}
		err = ossStore.Put(ctx, m.Folder, m.Filename, obj.Body, obj.ContentType)
		_ = obj.Body.Close()
		if err != nil {
			log.Printf("[%d/%d] put %s/%s: %v", i+1, len(all), m.Folder, m.Filename, err)
			fail++
			continue
		}
		ok++
		if (i+1)%50 == 0 || i+1 == len(all) {
			log.Printf("progress %d/%d ok=%d fail=%d", i+1, len(all), ok, fail)
		}
	}
	log.Printf("done ok=%d fail=%d at %s", ok, fail, time.Now().Format(time.RFC3339))
	log.Printf("next: set image.driver: oss in %s and restart moe-social", filepath.Join(*confDir, "config.yaml"))
	if fail > 0 {
		os.Exit(1)
	}
}

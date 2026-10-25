// Command migrate-media-qiniu 把本机 image.local_dir 里的旧图补传到七牛（不删本地）。
//
// 有 Go 的机器：
//
//	go run ./cmd/migrate-media-qiniu -conf ./config -dry-run
//	go run ./cmd/migrate-media-qiniu -conf ./config
//
// 云服务器没有 Go，用同一个 moe-social 二进制，见 cmd/moe-social 的 -migrate-media-qiniu。
package main

import (
	"context"
	"flag"
	"log"
	"path/filepath"

	mediabiz "backend/internal/biz/media"
	"backend/pkg/conf"
)

func main() {
	confDir := flag.String("conf", "./config", "config directory containing config.yaml")
	dryRun := flag.Bool("dry-run", false, "only list files, do not upload")
	flag.Parse()

	if _, err := conf.LoadFile(filepath.Join(*confDir, "config.yaml")); err != nil {
		log.Fatalf("read config: %v", err)
	}
	img := conf.Get().Image
	_, _, err := mediabiz.MigrateLocalToQiniu(context.Background(), mediabiz.ImageConfig{
		Driver:        mediabiz.DriverQiniu,
		LocalDir:      img.LocalDir,
		PublicBaseURL: conf.ImagePublicBaseURL(),
		Qiniu: mediabiz.QiniuConfig{
			AccessKey:   img.Qiniu.AccessKey,
			SecretKey:   img.Qiniu.SecretKey,
			Bucket:      img.Qiniu.Bucket,
			CDNDomain:   img.Qiniu.CDNDomain,
			Region:      img.Qiniu.Region,
			Prefix:      img.Qiniu.Prefix,
			Private:     img.Qiniu.Private,
			ProxyViaAPI: img.Qiniu.ProxyViaAPI,
		},
	}, *dryRun)
	if err != nil {
		log.Fatal(err)
	}
}

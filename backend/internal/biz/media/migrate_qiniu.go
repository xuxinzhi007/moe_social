package mediabiz

import (
	"context"
	"fmt"
	"log"
	"strings"
	"time"
)

// MigrateLocalToQiniu 把 LocalDir 里的旧图补传到七牛，不删除本地文件。
// dryRun 为 true 时只列出对象。七牛上已有的同名对象会被覆盖。
func MigrateLocalToQiniu(ctx context.Context, cfg ImageConfig, dryRun bool) (ok, fail int, err error) {
	localDir := strings.TrimSpace(cfg.LocalDir)
	if localDir == "" {
		localDir = "./data/images"
		cfg.LocalDir = localDir
	}
	qiniuCfg := cfg
	qiniuCfg.Driver = DriverQiniu
	qiniuStore, err := NewBlobStore(qiniuCfg)
	if err != nil {
		return 0, 0, fmt.Errorf("qiniu store: %w", err)
	}
	localStore, err := NewBlobStore(ImageConfig{Driver: DriverLocal, LocalDir: localDir})
	if err != nil {
		return 0, 0, fmt.Errorf("local store: %w", err)
	}
	all, err := localStore.ListAll(ctx)
	if err != nil {
		return 0, 0, fmt.Errorf("list local: %w", err)
	}
	log.Printf("found %d local objects under %s", len(all), localDir)
	if dryRun {
		for _, m := range all {
			log.Printf("%s/%s (%d bytes)", m.Folder, m.Filename, m.Size)
		}
		return len(all), 0, nil
	}
	for i, m := range all {
		if err := ctx.Err(); err != nil {
			return ok, fail, err
		}
		if putErr := putOne(ctx, localStore, qiniuStore, m); putErr != nil {
			log.Printf("[%d/%d] %s/%s: %v", i+1, len(all), m.Folder, m.Filename, putErr)
			fail++
			continue
		}
		ok++
		if (i+1)%50 == 0 || i+1 == len(all) {
			log.Printf("progress %d/%d ok=%d fail=%d", i+1, len(all), ok, fail)
		}
	}
	log.Printf("done ok=%d fail=%d at %s", ok, fail, time.Now().Format(time.RFC3339))
	if fail > 0 {
		return ok, fail, fmt.Errorf("qiniu migrate: %d of %d failed", fail, len(all))
	}
	return ok, fail, nil
}

func putOne(ctx context.Context, local, qiniu BlobStore, m BlobMeta) error {
	obj, err := local.Open(ctx, m.Folder, m.Filename)
	if err != nil {
		return err
	}
	defer func() { _ = obj.Body.Close() }()
	return qiniu.Put(ctx, m.Folder, m.Filename, obj.Body, obj.ContentType)
}

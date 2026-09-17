package moewiring

import (
	"strings"

	mediabiz "backend/internal/biz/media"
	"backend/internal/platform/apiconfig"
	"backend/internal/platform/appdb"
	commentapp "backend/internal/service/comment"
	postapp "backend/internal/service/post"
	"backend/pkg/conf"
)

// ImageConfigFromAPI 将已合并统一配置与片段的图片配置注入 post/media。
func ImageConfigFromAPI(img apiconfig.ImageConf) mediabiz.ImageConfig {
	return mediabiz.ImageConfig{
		Driver:        strings.TrimSpace(img.Driver),
		LocalDir:      strings.TrimSpace(img.LocalDir),
		PublicBaseURL: conf.TrimURL(img.PublicBaseUrl),
		OSS: mediabiz.OSSConfig{
			Endpoint:        strings.TrimSpace(img.OSS.Endpoint),
			Bucket:          strings.TrimSpace(img.OSS.Bucket),
			AccessKeyID:     strings.TrimSpace(img.OSS.AccessKeyID),
			AccessKeySecret: strings.TrimSpace(img.OSS.AccessKeySecret),
			Prefix:          strings.TrimSpace(img.OSS.Prefix),
			PublicBaseURL:   conf.TrimURL(img.OSS.PublicBaseUrl),
			Region:          strings.TrimSpace(img.OSS.Region),
			ProxyViaAPI:     img.OSS.ProxyViaAPI,
		},
	}
}

func PostAPIInProcessEnabled() bool {
	return conf.DomainInProcess("post")
}

func CommentAPIInProcessEnabled() bool {
	return conf.DomainInProcess("comment")
}

func NewAPIPostService(image mediabiz.ImageConfig) (*postapp.AppService, error) {
	if !PostAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return postapp.New(db, handDrawRequireModeration(), image), nil
}

// handDrawRequireModeration 读 config.yaml 的 runtime.hand_draw_require_moderation。
func handDrawRequireModeration() bool {
	return conf.Get().Runtime.HandDrawRequireModeration
}

func NewAPICommentService() (*commentapp.AppService, error) {
	if !CommentAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return commentapp.New(db), nil
}

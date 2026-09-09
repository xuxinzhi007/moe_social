package moewiring

import (
	"strings"

	mediabiz "backend/internal/biz/media"
	"backend/internal/platform/appdb"
	commentapp "backend/internal/service/comment"
	postapp "backend/internal/service/post"
	"backend/pkg/conf"
)

func imageConfigFromMoe() mediabiz.ImageConfig {
	img := conf.Get().Image
	return mediabiz.ImageConfig{
		Driver:        strings.TrimSpace(img.Driver),
		LocalDir:      strings.TrimSpace(img.LocalDir),
		PublicBaseURL: strings.TrimSpace(img.PublicBaseURL),
		OSS: mediabiz.OSSConfig{
			Endpoint:        strings.TrimSpace(img.OSS.Endpoint),
			Bucket:          strings.TrimSpace(img.OSS.Bucket),
			AccessKeyID:     strings.TrimSpace(img.OSS.AccessKeyID),
			AccessKeySecret: strings.TrimSpace(img.OSS.AccessKeySecret),
			Prefix:          strings.TrimSpace(img.OSS.Prefix),
			PublicBaseURL:   strings.TrimSpace(img.OSS.PublicBaseURL),
			Region:          strings.TrimSpace(img.OSS.Region),
			ProxyViaAPI:     img.OSS.ProxyViaAPI,
		},
	}
}

func PostAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.post_api_in_process")
}

func CommentAPIInProcessEnabled() bool {
	return domainInProcessEnabled("moe.comment_api_in_process")
}

func NewAPIPostService() (*postapp.AppService, error) {
	if !PostAPIInProcessEnabled() {
		return nil, nil
	}
	db, err := appdb.Open()
	if err != nil {
		return nil, err
	}
	return postapp.New(db, handDrawRequireModeration(), imageConfigFromMoe()), nil
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

package moewiring

import (
	"strings"

	mediabiz "backend/internal/biz/media"
	"backend/internal/platform/appdb"
	commentapp "backend/internal/service/comment"
	postapp "backend/internal/service/post"
)

func imageConfigFromMoe() mediabiz.ImageConfig {
	v := moeViper()
	if v == nil {
		return mediabiz.ImageConfig{}
	}
	return mediabiz.ImageConfig{
		Driver:        firstNonEmpty(v.GetString("image.driver"), v.GetString("Image.Driver")),
		LocalDir:      firstNonEmpty(v.GetString("image.local_dir"), v.GetString("Image.LocalDir")),
		PublicBaseURL: firstNonEmpty(v.GetString("image.public_base_url"), v.GetString("Image.PublicBaseUrl")),
		OSS: mediabiz.OSSConfig{
			Endpoint:        firstNonEmpty(v.GetString("image.oss.endpoint"), v.GetString("Image.OSS.Endpoint")),
			Bucket:          firstNonEmpty(v.GetString("image.oss.bucket"), v.GetString("Image.OSS.Bucket")),
			AccessKeyID:     firstNonEmpty(v.GetString("image.oss.access_key_id"), v.GetString("Image.OSS.AccessKeyID")),
			AccessKeySecret: firstNonEmpty(v.GetString("image.oss.access_key_secret"), v.GetString("Image.OSS.AccessKeySecret")),
			Prefix:          firstNonEmpty(v.GetString("image.oss.prefix"), v.GetString("Image.OSS.Prefix")),
			PublicBaseURL:   firstNonEmpty(v.GetString("image.oss.public_base_url"), v.GetString("Image.OSS.PublicBaseUrl")),
			Region:          firstNonEmpty(v.GetString("image.oss.region"), v.GetString("Image.OSS.Region")),
			ProxyViaAPI:     v.GetBool("image.oss.proxy_via_api"),
		},
	}
}

func firstNonEmpty(vals ...string) string {
	for _, v := range vals {
		if s := strings.TrimSpace(v); s != "" {
			return s
		}
	}
	return ""
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

func handDrawRequireModeration() bool {
	return boolOr(moeViper(), []string{"hand_draw_require_moderation", "HandDrawRequireModeration"}, false)
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

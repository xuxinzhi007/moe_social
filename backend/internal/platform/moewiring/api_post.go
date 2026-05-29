package moewiring

import (
	postapp "backend/internal/service/post"
	commentapp "backend/internal/service/comment"
	mediabiz "backend/internal/biz/media"
	"backend/utils"
)

func imageConfigFromMoe() mediabiz.ImageConfig {
	v := moeViper()
	if v == nil {
		return mediabiz.ImageConfig{}
	}
	return mediabiz.ImageConfig{
		LocalDir:      v.GetString("Image.LocalDir"),
		PublicBaseURL: v.GetString("Image.PublicBaseUrl"),
	}
}

func PostAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.post_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.post_api_in_process"}, false)
}

func CommentAPIInProcessEnabled() bool {
	if SingleProcessEnabled() || APIInProcessEnabled() {
		return boolOr(moeViper(), []string{"moe.comment_api_in_process"}, true)
	}
	return boolOr(moeViper(), []string{"moe.comment_api_in_process"}, false)
}

func NewAPIPostService() (*postapp.AppService, error) {
	if !PostAPIInProcessEnabled() {
		return nil, nil
	}
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
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
	if err := utils.EnsureDB(); err != nil {
		return nil, err
	}
	db := utils.GetDB()
	if db == nil {
		return nil, nil
	}
	return commentapp.New(db), nil
}

package adminapp

import (
	"context"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) AdminBootstrapTopicTags(ctx context.Context, in *adminv1.AdminBootstrapTopicTagsReq) (*adminv1.AdminBootstrapTopicTagsResp, error) {
	_ = in
	created, err := adminbiz.BootstrapTopicTags(ctx, s.store)
	if err != nil {
		return nil, err
	}
	return &adminv1.AdminBootstrapTopicTagsResp{Created: created}, nil
}

func (s *AppService) ListTopicTags(ctx context.Context, in *adminv1.AdminListTopicTagsReq) (*adminv1.AdminListTopicTagsResp, error) {
	out, err := adminbiz.AdminListTopicTags(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) CreateTopicTag(ctx context.Context, in *adminv1.AdminCreateTopicTagReq) (*adminv1.AdminCreateTopicTagResp, error) {
	out, err := adminbiz.AdminCreateTopicTag(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) UpdateTopicTag(ctx context.Context, in *adminv1.AdminUpdateTopicTagReq) (*adminv1.AdminUpdateTopicTagResp, error) {
	out, err := adminbiz.AdminUpdateTopicTag(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteTopicTag(ctx context.Context, in *adminv1.AdminDeleteTopicTagReq) (*adminv1.AdminDeleteTopicTagResp, error) {
	out, err := adminbiz.AdminDeleteTopicTag(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListTagDictionary(ctx context.Context, in *adminv1.AdminListTagDictionaryReq) (*adminv1.AdminListTagDictionaryResp, error) {
	out, err := adminbiz.AdminListTagDictionary(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) CreateTagDictionary(ctx context.Context, in *adminv1.AdminCreateTagDictionaryReq) (*adminv1.AdminCreateTagDictionaryResp, error) {
	out, err := adminbiz.AdminCreateTagDictionary(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) UpdateTagDictionary(ctx context.Context, in *adminv1.AdminUpdateTagDictionaryReq) (*adminv1.AdminUpdateTagDictionaryResp, error) {
	out, err := adminbiz.AdminUpdateTagDictionary(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteTagDictionary(ctx context.Context, in *adminv1.AdminDeleteTagDictionaryReq) (*adminv1.AdminDeleteTagDictionaryResp, error) {
	out, err := adminbiz.AdminDeleteTagDictionary(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

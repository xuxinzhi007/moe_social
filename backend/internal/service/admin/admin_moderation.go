package adminapp

import (
	"context"
	communitydata "backend/internal/data/community"
	adminv1 "backend/api/admin/v1"
	adminbiz "backend/internal/biz/admin"
)

func (s *AppService) ListFollows(ctx context.Context, in *adminv1.AdminListFollowsReq) (*adminv1.AdminListFollowsResp, error) {
	out, err := adminbiz.ListFollows(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteFollow(ctx context.Context, in *adminv1.AdminDeleteFollowReq) (*adminv1.AdminDeleteFollowResp, error) {
	out, err := adminbiz.DeleteFollow(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListPosts(ctx context.Context, in *adminv1.AdminListPostsReq) (*adminv1.AdminListPostsResp, error) {
	out, err := adminbiz.ListPosts(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeletePost(ctx context.Context, in *adminv1.AdminDeletePostReq) (*adminv1.AdminDeletePostResp, error) {
	out, err := adminbiz.DeletePost(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListComments(ctx context.Context, in *adminv1.AdminListCommentsReq) (*adminv1.AdminListCommentsResp, error) {
	out, err := adminbiz.ListComments(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteComment(ctx context.Context, in *adminv1.AdminDeleteCommentReq) (*adminv1.AdminDeleteCommentResp, error) {
	out, err := adminbiz.DeleteComment(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListGroups(ctx context.Context, in *adminv1.AdminListGroupsReq) (*adminv1.AdminListGroupsResp, error) {
	out, err := adminbiz.ListGroups(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) DeleteGroup(ctx context.Context, in *adminv1.AdminDeleteGroupReq) (*adminv1.AdminDeleteGroupResp, error) {
	out, err := adminbiz.DeleteGroup(ctx, communitydata.NewStore(s.store.Raw()), in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListFriendRequests(ctx context.Context, in *adminv1.AdminListFriendRequestsReq) (*adminv1.AdminListFriendRequestsResp, error) {
	out, err := adminbiz.ListFriendRequests(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

func (s *AppService) ListPostReports(ctx context.Context, in *adminv1.AdminListPostReportsReq) (*adminv1.AdminListPostReportsResp, error) {
	out, err := adminbiz.ListPostReports(ctx, s.store, in)
	if err != nil {
		return nil, err
	}
	return out, nil
}

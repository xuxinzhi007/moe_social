package moehttp

import (
	"net/http"
	"strconv"

	"backend/api/internal/svc"
	"backend/api/internal/types"
	communityapp "backend/internal/service/community"
	"backend/rpc/pb/moe"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
	"github.com/zeromicro/go-zero/rest/httpx"
)

// PilotNativeCommunityCompatRoutes 社群域 HTTP（internal/service/community）。
const PilotNativeCommunityCompatRoutes = 11

func RegisterCommunityCompat(srv *khttp.Server, svcCtx *svc.ServiceContext) {
	if srv == nil || svcCtx == nil || svcCtx.CommunityApp == nil {
		return
	}
	app := svcCtx.CommunityApp
	r := srv.Route("/")
	r.GET("/api/community/groups", getGroups(app))
	r.POST("/api/community/groups", createGroup(app))
	r.GET("/api/community/groups/:group_id", getGroup(app))
	r.PUT("/api/community/groups/:group_id", updateGroup(app))
	r.DELETE("/api/community/groups/:group_id", deleteGroup(app))
	r.POST("/api/community/groups/:group_id/join", joinGroup(app))
	r.POST("/api/community/groups/:group_id/leave", leaveGroup(app))
	r.GET("/api/community/groups/:group_id/members", getGroupMembers(app))
	r.POST("/api/community/groups/:group_id/posts", createGroupPost(app))
	r.GET("/api/community/groups/:group_id/posts", getGroupPosts(app))
	r.GET("/api/user/:user_id/community/groups", getUserGroups(app))
}

func getGroups(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGroupsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetGroupsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetGroups(ctx, &moe.GetGroupsReq{
			Page: int32(req.Page), PageSize: int32(req.PageSize),
			Keyword: req.Keyword, IsPublic: req.IsPublic, UserId: req.UserId,
		})
		if err != nil {
			return err
		}
		groups := make([]types.Group, 0, len(rpcResp.GetGroups()))
		for _, g := range rpcResp.GetGroups() {
			groups = append(groups, groupFromRPC(g))
		}
		return ctx.JSON(http.StatusOK, types.GetGroupsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     groups,
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func createGroup(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CreateGroupReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CreateGroupResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.CreateGroup(ctx, &moe.CreateGroupReq{
			Name: req.Name, Description: req.Description, Avatar: req.Avatar,
			Cover: req.Cover, IsPublic: req.IsPublic, UserId: req.UserId,
		})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.CreateGroupResp{
			BaseResp: types.BaseResp{Code: 0, Message: rpcResp.GetMessage(), Success: rpcResp.GetSuccess()},
			Data:     groupFromRPC(rpcResp.GetGroup()),
		})
	}
}

func getGroup(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGroupReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetGroupResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetGroup(ctx, &moe.GetGroupReq{GroupId: req.GroupId, UserId: req.UserId})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.GetGroupResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     groupFromRPC(rpcResp.GetGroup()),
		})
	}
}

func updateGroup(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.UpdateGroupReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.UpdateGroupResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.UpdateGroup(ctx, &moe.UpdateGroupReq{
			GroupId: req.GroupId, Name: req.Name, Description: req.Description,
			Avatar: req.Avatar, Cover: req.Cover, IsPublic: req.IsPublic,
		})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.UpdateGroupResp{
			BaseResp: types.BaseResp{Code: 0, Message: rpcResp.GetMessage(), Success: rpcResp.GetSuccess()},
			Data:     groupFromRPC(rpcResp.GetGroup()),
		})
	}
}

func deleteGroup(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.DeleteGroupReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.DeleteGroup(ctx, &moe.DeleteGroupReq{GroupId: req.GroupId, UserId: req.UserId})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.BaseResp{
			Code: 0, Message: rpcResp.GetMessage(), Success: rpcResp.GetSuccess(),
		})
	}
}

func joinGroup(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.JoinGroupReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.JoinGroup(ctx, &moe.JoinGroupReq{GroupId: req.GroupId, UserId: req.UserId})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.BaseResp{
			Code: 0, Message: rpcResp.GetMessage(), Success: rpcResp.GetSuccess(),
		})
	}
}

func leaveGroup(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.LeaveGroupReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.BaseResp{
				Code: -1, Message: err.Error(), Success: false,
			})
		}
		rpcResp, err := app.LeaveGroup(ctx, &moe.LeaveGroupReq{GroupId: req.GroupId, UserId: req.UserId})
		if err != nil {
			return err
		}
		return ctx.JSON(http.StatusOK, types.BaseResp{
			Code: 0, Message: rpcResp.GetMessage(), Success: rpcResp.GetSuccess(),
		})
	}
}

func getGroupMembers(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGroupMembersReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetGroupMembersResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetGroupMembers(ctx, &moe.GetGroupMembersReq{
			GroupId: req.GroupId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return err
		}
		members := make([]types.GroupMember, 0, len(rpcResp.GetMembers()))
		for _, m := range rpcResp.GetMembers() {
			if m == nil {
				continue
			}
			members = append(members, types.GroupMember{
				Id:         strconv.FormatUint(m.GetId(), 10),
				GroupId:    strconv.FormatUint(m.GetGroupId(), 10),
				UserId:     strconv.FormatUint(m.GetUserId(), 10),
				UserName:   m.GetUserName(),
				UserAvatar: m.GetUserAvatar(),
				Role:       m.GetRole(),
				JoinAt:     m.GetJoinAt(),
				CreatedAt:  m.GetCreatedAt(),
			})
		}
		return ctx.JSON(http.StatusOK, types.GetGroupMembersResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     members,
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func createGroupPost(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.CreateGroupPostReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.CreateGroupPostResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.CreateGroupPost(ctx, &moe.CreateGroupPostReq{
			GroupId: req.GroupId, PostId: req.PostId, UserId: req.UserId,
		})
		if err != nil {
			return err
		}
		if !rpcResp.GetSuccess() {
			return ctx.JSON(http.StatusOK, types.CreateGroupPostResp{
				BaseResp: types.BaseResp{Code: 1, Message: rpcResp.GetMessage(), Success: false},
			})
		}
		return ctx.JSON(http.StatusOK, types.CreateGroupPostResp{
			BaseResp: types.BaseResp{Code: 0, Message: rpcResp.GetMessage(), Success: true},
			Data:     groupPostFromRPC(rpcResp.GetGroupPost()),
		})
	}
}

func getGroupPosts(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetGroupPostsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetGroupPostsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetGroupPosts(ctx, &moe.GetGroupPostsReq{
			GroupId: req.GroupId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return err
		}
		items := make([]types.GroupPost, 0, len(rpcResp.GetPosts()))
		for _, gp := range rpcResp.GetPosts() {
			items = append(items, groupPostFromRPC(gp))
		}
		return ctx.JSON(http.StatusOK, types.GetGroupPostsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     items,
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

func getUserGroups(app *communityapp.AppService) func(khttp.Context) error {
	return func(ctx khttp.Context) error {
		var req types.GetUserGroupsReq
		if err := httpx.Parse(ctx.Request(), &req); err != nil {
			return ctx.JSON(http.StatusBadRequest, types.GetUserGroupsResp{
				BaseResp: types.BaseResp{Code: -1, Message: err.Error(), Success: false},
			})
		}
		rpcResp, err := app.GetUserGroups(ctx, &moe.GetUserGroupsReq{
			UserId: req.UserId, Page: int32(req.Page), PageSize: int32(req.PageSize),
		})
		if err != nil {
			return err
		}
		groups := make([]types.Group, 0, len(rpcResp.GetGroups()))
		for _, g := range rpcResp.GetGroups() {
			groups = append(groups, groupFromRPC(g))
		}
		return ctx.JSON(http.StatusOK, types.GetUserGroupsResp{
			BaseResp: types.BaseResp{Code: 0, Message: "ok", Success: true},
			Data:     groups,
			Total:    int(rpcResp.GetTotal()),
		})
	}
}

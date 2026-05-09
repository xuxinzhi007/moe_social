package user

import (
	"context"
	"errors"
	"net/http"
	"strconv"
	"strings"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"
	"backend/rpc/pb/super"
	"backend/utils"

	"github.com/zeromicro/go-zero/core/logx"
)

type FriendLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewFriendLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FriendLogic {
	return &FriendLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func bearerUserID(r *http.Request) (uint, error) {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(auth, "Bearer ") {
		auth = strings.TrimSpace(strings.TrimPrefix(auth, "Bearer "))
	}
	if auth == "" {
		return 0, errors.New("unauthorized")
	}
	cl, err := utils.ParseToken(auth)
	if err != nil {
		return 0, err
	}
	return cl.UserID, nil
}

func parsePathUint(s string) (uint, error) {
	v, err := strconv.ParseUint(strings.TrimSpace(s), 10, 64)
	if err != nil {
		return 0, err
	}
	return uint(v), nil
}

func rpcUserToTypes(u *super.User) types.User {
	if u == nil {
		return types.User{}
	}
	return types.User{
		Id:                     u.Id,
		Username:               u.Username,
		Email:                  u.Email,
		MoeNo:                  u.MoeNo,
		DisplayUserId:          u.GetDisplayUserId(),
		MessageRetentionChoice: int(u.GetMessageRetentionChoice()),
		Avatar:                 u.Avatar,
		Signature:              u.Signature,
		Gender:                 u.Gender,
		Birthday:               u.Birthday,
		CreatedAt:              u.CreatedAt,
		UpdatedAt:              u.UpdatedAt,
		IsVip:                  u.IsVip,
		VipExpiresAt:           u.VipExpiresAt,
		AutoRenew:              u.AutoRenew,
		Balance:                float64(u.Balance),
		GiftCharm:              int(u.GiftCharm),
		ReceivedGiftValue:      u.ReceivedGiftValue,
		Inventory:              u.Inventory,
		EquippedFrameId:        u.EquippedFrameId,
	}
}

func rpcFriendViewToTypes(v *super.FriendRequestView) types.FriendRequestView {
	if v == nil {
		return types.FriendRequestView{}
	}
	return types.FriendRequestView{
		Id:        v.Id,
		FromUser:  rpcUserToTypes(v.FromUser),
		ToUser:    rpcUserToTypes(v.ToUser),
		Status:    v.Status,
		CreatedAt: v.CreatedAt,
	}
}

func actorString(me uint) string {
	return strconv.FormatUint(uint64(me), 10)
}

func (l *FriendLogic) SendFriendRequest(r *http.Request, req *types.SendFriendRequestReq) (*types.SendFriendRequestResp, error) {
	me, err := bearerUserID(r)
	if err != nil {
		return &types.SendFriendRequestResp{BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false}}, nil
	}
	pathUID, err := parsePathUint(req.UserId)
	if err != nil || pathUID != me {
		return &types.SendFriendRequestResp{BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false}}, nil
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.SendFriendRequest(l.ctx, &super.SendFriendRequestReq{
		ActorUserId: actorString(me),
		ToUserId:    strings.TrimSpace(req.ToUserId),
		ToMoeNo:     strings.TrimSpace(req.ToMoeNo),
	})
	if err != nil {
		return &types.SendFriendRequestResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	msg := "好友申请已发送"
	return &types.SendFriendRequestResp{
		BaseResp: common.HandleRPCError(nil, msg),
		Data:     rpcFriendViewToTypes(rpcResp.Data),
	}, nil
}

func (l *FriendLogic) ListIncoming(r *http.Request, userIDPath string) (*types.ListFriendRequestsResp, error) {
	me, err := bearerUserID(r)
	if err != nil {
		return &types.ListFriendRequestsResp{BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false}}, nil
	}
	pathUID, err := parsePathUint(userIDPath)
	if err != nil || pathUID != me {
		return &types.ListFriendRequestsResp{BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false}}, nil
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.ListIncomingFriendRequests(l.ctx, &super.ListIncomingFriendRequestsReq{
		ActorUserId: actorString(me),
	})
	if err != nil {
		return &types.ListFriendRequestsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	out := make([]types.FriendRequestView, 0, len(rpcResp.Data))
	for _, v := range rpcResp.Data {
		out = append(out, rpcFriendViewToTypes(v))
	}
	return &types.ListFriendRequestsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     out,
	}, nil
}

func (l *FriendLogic) ListOutgoing(r *http.Request, userIDPath string) (*types.ListFriendRequestsResp, error) {
	me, err := bearerUserID(r)
	if err != nil {
		return &types.ListFriendRequestsResp{BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false}}, nil
	}
	pathUID, err := parsePathUint(userIDPath)
	if err != nil || pathUID != me {
		return &types.ListFriendRequestsResp{BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false}}, nil
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.ListOutgoingFriendRequests(l.ctx, &super.ListOutgoingFriendRequestsReq{
		ActorUserId: actorString(me),
	})
	if err != nil {
		return &types.ListFriendRequestsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	out := make([]types.FriendRequestView, 0, len(rpcResp.Data))
	for _, v := range rpcResp.Data {
		out = append(out, rpcFriendViewToTypes(v))
	}
	return &types.ListFriendRequestsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     out,
	}, nil
}

func (l *FriendLogic) AcceptFriendRequest(r *http.Request, req *types.FriendRequestActionReq) (*types.FriendRequestActionResp, error) {
	me, err := bearerUserID(r)
	if err != nil {
		return &types.FriendRequestActionResp{BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false}}, nil
	}
	pathUID, err := parsePathUint(req.UserId)
	if err != nil || pathUID != me {
		return &types.FriendRequestActionResp{BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false}}, nil
	}

	_, err = l.svcCtx.SuperRpcClient.AcceptFriendRequest(l.ctx, &super.AcceptFriendRequestReq{
		ActorUserId: actorString(me),
		RequestId:   req.RequestId,
	})
	if err != nil {
		return &types.FriendRequestActionResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	return &types.FriendRequestActionResp{
		BaseResp: common.HandleRPCError(nil, "已同意好友申请"),
		Data:     true,
	}, nil
}

func (l *FriendLogic) RejectFriendRequest(r *http.Request, req *types.FriendRequestActionReq) (*types.FriendRequestActionResp, error) {
	me, err := bearerUserID(r)
	if err != nil {
		return &types.FriendRequestActionResp{BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false}}, nil
	}
	pathUID, err := parsePathUint(req.UserId)
	if err != nil || pathUID != me {
		return &types.FriendRequestActionResp{BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false}}, nil
	}

	_, err = l.svcCtx.SuperRpcClient.RejectFriendRequest(l.ctx, &super.RejectFriendRequestReq{
		ActorUserId: actorString(me),
		RequestId:   req.RequestId,
	})
	if err != nil {
		return &types.FriendRequestActionResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	return &types.FriendRequestActionResp{
		BaseResp: common.HandleRPCError(nil, "已拒绝"),
		Data:     true,
	}, nil
}

func (l *FriendLogic) ListFriends(r *http.Request, userIDPath string) (*types.ListFriendsResp, error) {
	me, err := bearerUserID(r)
	if err != nil {
		return &types.ListFriendsResp{BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false}}, nil
	}
	pathUID, err := parsePathUint(userIDPath)
	if err != nil || pathUID != me {
		return &types.ListFriendsResp{BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false}}, nil
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.ListFriends(l.ctx, &super.ListFriendsReq{
		ActorUserId: actorString(me),
	})
	if err != nil {
		return &types.ListFriendsResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	out := make([]types.User, 0, len(rpcResp.Users))
	for _, u := range rpcResp.Users {
		out = append(out, rpcUserToTypes(u))
	}
	return &types.ListFriendsResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     out,
	}, nil
}

func (l *FriendLogic) FriendStatus(r *http.Request, userIDPath, otherIDPath string) (*types.FriendStatusResp, error) {
	me, err := bearerUserID(r)
	if err != nil {
		return &types.FriendStatusResp{BaseResp: types.BaseResp{Code: 401, Message: "请先登录", Success: false}}, nil
	}
	pathUID, err := parsePathUint(userIDPath)
	if err != nil || pathUID != me {
		return &types.FriendStatusResp{BaseResp: types.BaseResp{Code: 403, Message: "无权操作", Success: false}}, nil
	}

	rpcResp, err := l.svcCtx.SuperRpcClient.GetFriendRelation(l.ctx, &super.GetFriendRelationReq{
		ActorUserId: actorString(me),
		OtherUserId: strings.TrimSpace(otherIDPath),
	})
	if err != nil {
		return &types.FriendStatusResp{BaseResp: common.HandleRPCError(err, "")}, nil
	}

	return &types.FriendStatusResp{
		BaseResp: common.HandleRPCError(nil, "ok"),
		Data:     types.FriendRelationData{Relation: rpcResp.Relation},
	}, nil
}

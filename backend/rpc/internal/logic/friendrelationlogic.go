package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"

	"github.com/zeromicro/go-zero/core/logx"
)

type FriendRelationLogic struct {
	ctx    context.Context
	svcCtx *svc.ServiceContext
	logx.Logger
}

func NewFriendRelationLogic(ctx context.Context, svcCtx *svc.ServiceContext) *FriendRelationLogic {
	return &FriendRelationLogic{
		ctx:    ctx,
		svcCtx: svcCtx,
		Logger: logx.WithContext(ctx),
	}
}

func (l *FriendRelationLogic) app() *userapp.AppService {
	return userapp.New(l.svcCtx.DB)
}

func (l *FriendRelationLogic) SendFriendRequest(in *moe.SendFriendRequestReq) (*moe.SendFriendRequestResp, error) {
	resp, err := l.app().SendFriendRequest(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) ListIncomingFriendRequests(in *moe.ListIncomingFriendRequestsReq) (*moe.ListIncomingFriendRequestsResp, error) {
	resp, err := l.app().ListIncomingFriendRequests(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) ListOutgoingFriendRequests(in *moe.ListOutgoingFriendRequestsReq) (*moe.ListOutgoingFriendRequestsResp, error) {
	resp, err := l.app().ListOutgoingFriendRequests(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) AcceptFriendRequest(in *moe.AcceptFriendRequestReq) (*moe.AcceptFriendRequestResp, error) {
	resp, err := l.app().AcceptFriendRequest(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) RejectFriendRequest(in *moe.RejectFriendRequestReq) (*moe.RejectFriendRequestResp, error) {
	resp, err := l.app().RejectFriendRequest(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) ListFriends(in *moe.ListFriendsReq) (*moe.ListFriendsResp, error) {
	resp, err := l.app().ListFriends(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) GetFriendRelation(in *moe.GetFriendRelationReq) (*moe.GetFriendRelationResp, error) {
	resp, err := l.app().GetFriendRelation(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

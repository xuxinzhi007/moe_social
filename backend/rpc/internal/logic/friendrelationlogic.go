package logic

import (
	"context"

	userapp "backend/internal/service/user"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/super"

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

func (l *FriendRelationLogic) SendFriendRequest(in *super.SendFriendRequestReq) (*super.SendFriendRequestResp, error) {
	resp, err := l.app().SendFriendRequest(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) ListIncomingFriendRequests(in *super.ListIncomingFriendRequestsReq) (*super.ListIncomingFriendRequestsResp, error) {
	resp, err := l.app().ListIncomingFriendRequests(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) ListOutgoingFriendRequests(in *super.ListOutgoingFriendRequestsReq) (*super.ListOutgoingFriendRequestsResp, error) {
	resp, err := l.app().ListOutgoingFriendRequests(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) AcceptFriendRequest(in *super.AcceptFriendRequestReq) (*super.AcceptFriendRequestResp, error) {
	resp, err := l.app().AcceptFriendRequest(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) RejectFriendRequest(in *super.RejectFriendRequestReq) (*super.RejectFriendRequestResp, error) {
	resp, err := l.app().RejectFriendRequest(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) ListFriends(in *super.ListFriendsReq) (*super.ListFriendsResp, error) {
	resp, err := l.app().ListFriends(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

func (l *FriendRelationLogic) GetFriendRelation(in *super.GetFriendRelationReq) (*super.GetFriendRelationResp, error) {
	resp, err := l.app().GetFriendRelation(l.ctx, in)
	if err != nil {
		return nil, mapFriendBizErr(err)
	}
	return resp, nil
}

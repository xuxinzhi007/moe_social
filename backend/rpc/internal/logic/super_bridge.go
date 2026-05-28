package logic

import (
	"context"

	"backend/internal/adapter/rpcsuper"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"
)

type superBridge struct {
	svc *svc.ServiceContext
}

func newSuperBridge(svcCtx *svc.ServiceContext) rpcsuper.Bridge {
	return superBridge{svc: svcCtx}
}

func (b superBridge) GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq) (*moe.GetUserMemoriesResp, error) {
	return NewGetUserMemoriesLogic(ctx, b.svc).GetUserMemories(in)
}

func (b superBridge) UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq) (*moe.UpsertUserMemoryResp, error) {
	return NewUpsertUserMemoryLogic(ctx, b.svc).UpsertUserMemory(in)
}

func (b superBridge) DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error) {
	return NewDeleteUserMemoryLogic(ctx, b.svc).DeleteUserMemory(in)
}

func (b superBridge) CreatePost(ctx context.Context, in *moe.CreatePostReq) (*moe.CreatePostResp, error) {
	return NewCreatePostLogic(ctx, b.svc).CreatePost(in)
}

func (b superBridge) UpdatePost(ctx context.Context, in *moe.UpdatePostReq) (*moe.UpdatePostResp, error) {
	return NewUpdatePostLogic(ctx, b.svc).UpdatePost(in)
}

func (b superBridge) GetPost(ctx context.Context, in *moe.GetPostReq) (*moe.GetPostResp, error) {
	return NewGetPostLogic(ctx, b.svc).GetPost(in)
}

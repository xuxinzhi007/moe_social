package bootstrap

import (
	"context"

	"backend/internal/adapter/rpcsuper"
	"backend/internal/platform/moewiring"
	"backend/pkg/moe/port"
	"backend/rpc/internal/svc"
	"backend/rpc/pb/moe"
)

// appBridge implements rpcsuper.Bridge via moewiring.NewAppAdapter (P5: logic-free SuperPort).
type appBridge struct {
	port port.SuperPort
}

func newAppBridge(svcCtx *svc.ServiceContext) rpcsuper.Bridge {
	if svcCtx == nil {
		return nil
	}
	return appBridge{port: moewiring.NewAppAdapter(svcCtx.PostApp, svcCtx.LLMApp)}
}

func (b appBridge) GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq) (*moe.GetUserMemoriesResp, error) {
	return b.port.GetUserMemories(ctx, in)
}

func (b appBridge) UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq) (*moe.UpsertUserMemoryResp, error) {
	return b.port.UpsertUserMemory(ctx, in)
}

func (b appBridge) DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error) {
	return b.port.DeleteUserMemory(ctx, in)
}

func (b appBridge) CreatePost(ctx context.Context, in *moe.CreatePostReq) (*moe.CreatePostResp, error) {
	return b.port.CreatePost(ctx, in)
}

func (b appBridge) UpdatePost(ctx context.Context, in *moe.UpdatePostReq) (*moe.UpdatePostResp, error) {
	return b.port.UpdatePost(ctx, in)
}

func (b appBridge) GetPost(ctx context.Context, in *moe.GetPostReq) (*moe.GetPostResp, error) {
	return b.port.GetPost(ctx, in)
}

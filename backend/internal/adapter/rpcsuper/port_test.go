package rpcsuper

import (
	"context"
	"testing"

	"backend/rpc/pb/moe"
)

type stubBridge struct{}

func (stubBridge) GetUserMemories(context.Context, *moe.GetUserMemoriesReq) (*moe.GetUserMemoriesResp, error) {
	return &moe.GetUserMemoriesResp{}, nil
}
func (stubBridge) UpsertUserMemory(context.Context, *moe.UpsertUserMemoryReq) (*moe.UpsertUserMemoryResp, error) {
	return &moe.UpsertUserMemoryResp{}, nil
}
func (stubBridge) DeleteUserMemory(context.Context, *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error) {
	return &moe.DeleteUserMemoryResp{}, nil
}
func (stubBridge) CreatePost(context.Context, *moe.CreatePostReq) (*moe.CreatePostResp, error) {
	return &moe.CreatePostResp{}, nil
}
func (stubBridge) UpdatePost(context.Context, *moe.UpdatePostReq) (*moe.UpdatePostResp, error) {
	return &moe.UpdatePostResp{}, nil
}
func (stubBridge) GetPost(context.Context, *moe.GetPostReq) (*moe.GetPostResp, error) {
	return &moe.GetPostResp{}, nil
}

func TestNewMoeToolPort_NilBridge(t *testing.T) {
	if NewMoeToolPort(context.Background(), nil) != nil {
		t.Fatal("expected nil port for nil bridge")
	}
}

func TestNewMoeToolPort_Delegates(t *testing.T) {
	p := NewMoeToolPort(context.Background(), stubBridge{})
	if p == nil {
		t.Fatal("expected port")
	}
	if _, err := p.GetPost(context.Background(), &moe.GetPostReq{}); err != nil {
		t.Fatalf("GetPost: %v", err)
	}
}

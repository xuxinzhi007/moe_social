package rpcsuper

import (
	"context"
	"testing"

	"backend/rpc/pb/super"
)

type stubBridge struct{}

func (stubBridge) GetUserMemories(context.Context, *super.GetUserMemoriesReq) (*super.GetUserMemoriesResp, error) {
	return &super.GetUserMemoriesResp{}, nil
}
func (stubBridge) UpsertUserMemory(context.Context, *super.UpsertUserMemoryReq) (*super.UpsertUserMemoryResp, error) {
	return &super.UpsertUserMemoryResp{}, nil
}
func (stubBridge) DeleteUserMemory(context.Context, *super.DeleteUserMemoryReq) (*super.DeleteUserMemoryResp, error) {
	return &super.DeleteUserMemoryResp{}, nil
}
func (stubBridge) CreatePost(context.Context, *super.CreatePostReq) (*super.CreatePostResp, error) {
	return &super.CreatePostResp{}, nil
}
func (stubBridge) UpdatePost(context.Context, *super.UpdatePostReq) (*super.UpdatePostResp, error) {
	return &super.UpdatePostResp{}, nil
}
func (stubBridge) GetPost(context.Context, *super.GetPostReq) (*super.GetPostResp, error) {
	return &super.GetPostResp{}, nil
}

func TestNewSuperPort_NilBridge(t *testing.T) {
	if NewSuperPort(context.Background(), nil) != nil {
		t.Fatal("expected nil port for nil bridge")
	}
}

func TestNewSuperPort_Delegates(t *testing.T) {
	p := NewSuperPort(context.Background(), stubBridge{})
	if p == nil {
		t.Fatal("expected port")
	}
	if _, err := p.GetPost(context.Background(), &super.GetPostReq{}); err != nil {
		t.Fatalf("GetPost: %v", err)
	}
}

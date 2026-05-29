package rpcsuper

import (
	"context"
	"testing"

	llmv1 "backend/api/llm/v1"
	postv1 "backend/api/post/v1"
)

type stubBridge struct{}

func (stubBridge) GetUserMemories(context.Context, *llmv1.GetUserMemoriesReq) (*llmv1.GetUserMemoriesResp, error) {
	return &llmv1.GetUserMemoriesResp{}, nil
}
func (stubBridge) UpsertUserMemory(context.Context, *llmv1.UpsertUserMemoryReq) (*llmv1.UpsertUserMemoryResp, error) {
	return &llmv1.UpsertUserMemoryResp{}, nil
}
func (stubBridge) DeleteUserMemory(context.Context, *llmv1.DeleteUserMemoryReq) (*llmv1.DeleteUserMemoryResp, error) {
	return &llmv1.DeleteUserMemoryResp{}, nil
}
func (stubBridge) CreatePost(context.Context, *postv1.CreatePostRequest) (*postv1.CreatePostReply, error) {
	return &postv1.CreatePostReply{}, nil
}
func (stubBridge) UpdatePost(context.Context, *postv1.UpdatePostRequest) (*postv1.UpdatePostReply, error) {
	return &postv1.UpdatePostReply{}, nil
}
func (stubBridge) GetPost(context.Context, *postv1.GetPostRequest) (*postv1.GetPostReply, error) {
	return &postv1.GetPostReply{}, nil
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
	if _, err := p.GetPost(context.Background(), &postv1.GetPostRequest{}); err != nil {
		t.Fatalf("GetPost: %v", err)
	}
}

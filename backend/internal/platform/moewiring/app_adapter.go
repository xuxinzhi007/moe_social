package moewiring

import (
	"context"
	"errors"

	llmv1 "backend/api/llm/v1"
	postv1 "backend/api/post/v1"
	llmapp "backend/internal/service/llm"
	postapp "backend/internal/service/post"
	"backend/pkg/moe/port"
	"backend/rpc/pb/moe"
)

var errAppPortUnavailable = errors.New("super port: in-process app unavailable")

// appAdapter 进程内 MoeToolPort（P5：Super gRPC 退役后 Moe 试跑/工具链直连 App）。
type appAdapter struct {
	post *postapp.AppService
	llm  *llmapp.AppService
}

// NewAppAdapter 构造进程内 MoeToolPort；post/llm 可为 nil（对应方法返回不可用错误）。
func NewAppAdapter(post *postapp.AppService, llm *llmapp.AppService) port.MoeToolPort {
	return appAdapter{post: post, llm: llm}
}

func (a appAdapter) GetUserMemories(ctx context.Context, in *moe.GetUserMemoriesReq) (*moe.GetUserMemoriesResp, error) {
	if a.llm == nil {
		return nil, errAppPortUnavailable
	}
	out, err := a.llm.GetUserMemories(ctx, llmv1.GetUserMemoriesReqFromMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.GetUserMemoriesRespToMoe(out), nil
}

func (a appAdapter) UpsertUserMemory(ctx context.Context, in *moe.UpsertUserMemoryReq) (*moe.UpsertUserMemoryResp, error) {
	if a.llm == nil {
		return nil, errAppPortUnavailable
	}
	out, err := a.llm.UpsertUserMemory(ctx, llmv1.UpsertUserMemoryReqFromMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.UpsertUserMemoryRespToMoe(out), nil
}

func (a appAdapter) DeleteUserMemory(ctx context.Context, in *moe.DeleteUserMemoryReq) (*moe.DeleteUserMemoryResp, error) {
	if a.llm == nil {
		return nil, errAppPortUnavailable
	}
	out, err := a.llm.DeleteUserMemory(ctx, llmv1.DeleteUserMemoryReqFromMoe(in))
	if err != nil {
		return nil, err
	}
	return llmv1.DeleteUserMemoryRespToMoe(out), nil
}

func (a appAdapter) CreatePost(ctx context.Context, in *moe.CreatePostReq) (*moe.CreatePostResp, error) {
	if a.post == nil {
		return nil, errAppPortUnavailable
	}
	out, err := a.post.CreatePost(ctx, postv1.CreatePostRequestFromMoe(in))
	if err != nil {
		return nil, err
	}
	return postv1.CreatePostReplyToMoe(out), nil
}

func (a appAdapter) UpdatePost(ctx context.Context, in *moe.UpdatePostReq) (*moe.UpdatePostResp, error) {
	if a.post == nil {
		return nil, errAppPortUnavailable
	}
	out, err := a.post.UpdatePost(ctx, postv1.UpdatePostRequestFromMoe(in))
	if err != nil {
		return nil, err
	}
	return postv1.UpdatePostReplyToMoe(out), nil
}

func (a appAdapter) GetPost(ctx context.Context, in *moe.GetPostReq) (*moe.GetPostResp, error) {
	if a.post == nil {
		return nil, errAppPortUnavailable
	}
	out, err := a.post.GetPost(ctx, postv1.GetPostRequestFromMoe(in))
	if err != nil {
		return nil, err
	}
	return postv1.GetPostReplyToMoe(out), nil
}

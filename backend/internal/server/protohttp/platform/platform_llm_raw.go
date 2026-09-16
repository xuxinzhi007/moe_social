package platformhttp

import (
	"net/http"

	llmbiz "backend/internal/biz/llm"

	khttp "github.com/go-kratos/kratos/v2/transport/http"
)

// RegisterLLMRawHTTP 把三个 Ollama 透传端点挂成 Kratos 原生路由，不走 proto RPC。
//
// proto RPC 这条路在这里有四处硬伤，任何一处都足以让端点不可用：
//  1. LlmRawProxyReq/Resp 是空消息，承载不了透传的 body 与响应；
//  2. 生成的 handler 会 ctx.Bind(&in)，把 POST body 读干，转发给 Ollama 的 body 为空；
//  3. 透传写完后只能 return nil, nil，而生成代码里的 out.(*LlmRawProxyResp) 对 nil 接口断言必 panic；
//  4. 旧实现靠反射取 Kratos transport 的 response 字段，那是未导出字段，
//     reflect.Value.Interface() 无条件 panic —— 这是 Go 的硬规则，不是偶发。
//
// 原生路由没有 reply 类型断言（router 只在 handler 返回 err 时才调用 ErrorEncoder），
// ctx.Response() 直接拿到 ResponseWriter，不 Bind 因此 body 完好，return nil 安全。
func RegisterLLMRawHTTP(srv *khttp.Server, deps Deps) {
	if srv == nil {
		return
	}
	r := srv.Route("/")
	r.POST("/api/llm/chat/raw", llmRawHandler(deps, forwardChatRaw))
	r.GET("/api/llm/models/raw", llmRawHandler(deps, forwardModelsRaw))
	r.POST("/api/llm/show/raw", llmRawHandler(deps, forwardShowRaw))
}

type llmRawForwarder func(w http.ResponseWriter, r *http.Request, deps Deps) error

func forwardChatRaw(w http.ResponseWriter, r *http.Request, deps Deps) error {
	if deps.LLMApp != nil {
		return deps.LLMApp.ForwardChatRaw(w, r)
	}
	return llmbiz.ForwardChatRaw(w, r, deps.InferenceConfig)
}

func forwardModelsRaw(w http.ResponseWriter, r *http.Request, deps Deps) error {
	if deps.LLMApp != nil {
		return deps.LLMApp.ForwardModelsRaw(w, r)
	}
	return llmbiz.ForwardModelsRaw(w, r, deps.InferenceConfig)
}

func forwardShowRaw(w http.ResponseWriter, r *http.Request, deps Deps) error {
	if deps.LLMApp != nil {
		return deps.LLMApp.ForwardShowRaw(w, r)
	}
	return llmbiz.ForwardShowRaw(w, r, deps.InferenceConfig)
}

func llmRawHandler(deps Deps, forward llmRawForwarder) func(ctx khttp.Context) error {
	return func(ctx khttp.Context) error {
		return forward(ctx.Response(), ctx.Request(), deps)
	}
}

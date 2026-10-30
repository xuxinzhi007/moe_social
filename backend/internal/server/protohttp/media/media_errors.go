package mediahttp

import (
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

var (
	errMediaAppNil       = status.Error(codes.FailedPrecondition, "MediaApp 未初始化")
	errUnauthorized      = status.Error(codes.Unauthenticated, "unauthorized")
	errForbidden         = status.Error(codes.PermissionDenied, "forbidden")
	errNotFound          = status.Error(codes.NotFound, "图片不存在")
	errBadCategory       = status.Error(codes.InvalidArgument, "分类只能是 avatar、album、post、chat、gen")
	errEmptyPrompt       = status.Error(codes.InvalidArgument, "提示词不能为空")
	errPromptTooLong     = status.Error(codes.InvalidArgument, "提示词过长")
	errBadDrawSize       = status.Error(codes.InvalidArgument, "宽高必须是 512 到 768 之间的 64 倍数")
	errBadDrawSteps      = status.Error(codes.InvalidArgument, "步数必须在 1 到 40")
	errBadDrawCFG        = status.Error(codes.InvalidArgument, "CFG 必须在 1 到 7")
	errComfyDown         = status.Error(codes.Unavailable, "本机 ComfyUI 没有响应，请先打开 ComfyUI 再试")
	errUnknownCheckpoint = status.Error(codes.InvalidArgument, "底模不存在，请从 ComfyUI 已安装的模型里选择")
)

package emoji

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetEmojiPackLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetEmojiPackLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetEmojiPackLogic {
	return &GetEmojiPackLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetEmojiPackLogic) GetEmojiPack(req *types.GetEmojiPackReq) (resp *types.GetEmojiPackResp, err error) {
	// 模拟获取单个表情包包详情
	// 实际项目中应该调用RPC服务或数据库查询

	emojiPack := types.EmojiPack{
		Id:          req.PackId,
		Name:        "可爱猫咪",
		Description: "可爱的猫咪表情包",
		AuthorName:  "系统管理员",
		Category:    "animals",
		Price:       0,
		IsFree:      true,
		CoverImage:  "https://picsum.photos/300/200?random=1",
		Emojis: []types.Emoji{
			{
				Id:         "1-1",
				ImageUrl:   "https://picsum.photos/100/100?random=2",
				Tags:       []string{"cat", "cute"},
				IsAnimated: false,
			},
			{
				Id:         "1-2",
				ImageUrl:   "https://picsum.photos/100/100?random=3",
				Tags:       []string{"cat", "happy"},
				IsAnimated: false,
			},
		},
		DownloadCount: 1000,
	}

	return &types.GetEmojiPackResp{
		BaseResp: common.HandleError(nil),
		Data:     emojiPack,
	}, nil
}

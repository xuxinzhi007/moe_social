package emoji

import (
	"context"

	"backend/api/internal/common"
	"backend/api/internal/svc"
	"backend/api/internal/types"

	"github.com/zeromicro/go-zero/core/logx"
)

type GetEmojiPacksLogic struct {
	logx.Logger
	ctx    context.Context
	svcCtx *svc.ServiceContext
}

func NewGetEmojiPacksLogic(ctx context.Context, svcCtx *svc.ServiceContext) *GetEmojiPacksLogic {
	return &GetEmojiPacksLogic{
		Logger: logx.WithContext(ctx),
		ctx:    ctx,
		svcCtx: svcCtx,
	}
}

func (l *GetEmojiPacksLogic) GetEmojiPacks(req *types.GetEmojiPacksReq) (resp *types.GetEmojiPacksResp, err error) {
	// 模拟获取表情包包列表
	// 实际项目中应该调用RPC服务或数据库查询

	// 如果没有表情包包，返回空数组
	emojiPacks := []types.EmojiPack{}

	// 模拟返回一些表情包包数据
	emojiPacks = append(emojiPacks, types.EmojiPack{
		Id:          "1",
		Name:        "可爱猫咪",
		Description: "可爱的猫咪表情包",
		AuthorName:  "系统管理员",
		Category:    "animals",
		Price:       0,
		IsFree:      true,
		CoverImage:  "https://via.placeholder.com/300x200/7F7FD5/FFFFFF?text=Emoji+Pack",
		Emojis: []types.Emoji{
			{
				Id:         "1-1",
				ImageUrl:   "https://via.placeholder.com/100/FFB6C1/FFFFFF?text=😺",
				Tags:       []string{"cat", "cute"},
				IsAnimated: false,
			},
			{
				Id:         "1-2",
				ImageUrl:   "https://via.placeholder.com/100/87CEFA/FFFFFF?text=😸",
				Tags:       []string{"cat", "happy"},
				IsAnimated: false,
			},
		},
		DownloadCount: 1000,
	})

	return &types.GetEmojiPacksResp{
		BaseResp: common.HandleError(nil),
		Data:     emojiPacks,
		Total:    len(emojiPacks),
	}, nil
}

package common

import (
	"strconv"

	"backend/api/internal/types"
	"backend/rpc/pb/moe"
)

func RpcPostToTypes(p *moe.Post) types.Post {
	if p == nil {
		return types.Post{}
	}
	tags := make([]types.TopicTag, 0, len(p.GetTopicTags()))
	for _, tag := range p.GetTopicTags() {
		tags = append(tags, types.TopicTag{
			Id:        tag.GetId(),
			Name:      tag.GetName(),
			Color:     tag.GetColor(),
			CreatedAt: tag.GetCreatedAt(),
		})
	}
	return types.Post{
		Id:               p.GetId(),
		UserId:           p.GetUserId(),
		UserName:         p.GetUserName(),
		UserAvatar:       p.GetUserAvatar(),
		Content:          p.GetContent(),
		Images:           p.GetImages(),
		TopicTags:        tags,
		Likes:            int(p.GetLikes()),
		Comments:         int(p.GetComments()),
		IsLiked:          p.GetIsLiked(),
		CreatedAt:        p.GetCreatedAt(),
		HandDrawCard:     p.GetHandDrawCard(),
		HandDrawThumbUrl: p.GetHandDrawThumbUrl(),
		ModerationStatus:  p.GetModerationStatus(),
		AuthorIsBot:       p.GetAuthorIsBot(),
		AuthorBotAgentKey: p.GetAuthorBotAgentKey(),
	}
}

func RpcCommentToTypes(c *moe.Comment) types.Comment {
	if c == nil {
		return types.Comment{}
	}
	return types.Comment{
		Id:              c.GetId(),
		PostId:          c.GetPostId(),
		UserId:          c.GetUserId(),
		UserName:        c.GetUserName(),
		UserAvatar:      c.GetUserAvatar(),
		Content:         c.GetContent(),
		Likes:           int(c.GetLikes()),
		IsLiked:         c.GetIsLiked(),
		CreatedAt:       c.GetCreatedAt(),
		ParentId:        c.GetParentId(),
		ReplyToUserName: c.GetReplyToUserName(),
	}
}

func RpcGroupToTypes(g *moe.Group) types.Group {
	if g == nil {
		return types.Group{}
	}
	return types.Group{
		Id:          strconv.FormatUint(g.GetId(), 10),
		Name:        g.GetName(),
		Description: g.GetDescription(),
		Avatar:      g.GetAvatar(),
		Cover:       g.GetCover(),
		CreatorId:   strconv.FormatUint(g.GetCreatorId(), 10),
		CreatorName: g.GetCreatorName(),
		MemberCount: int(g.GetMemberCount()),
		IsPublic:    g.GetIsPublic(),
		Status:      g.GetStatus(),
		CreatedAt:   g.GetCreatedAt(),
		IsJoined:    g.GetIsJoined(),
		UserRole:    g.GetUserRole(),
	}
}

func RpcVipOrderToTypes(o *moe.VipOrder) types.VipOrder {
	if o == nil {
		return types.VipOrder{}
	}
	return types.VipOrder{
		Id:        o.GetId(),
		UserId:    o.GetUserId(),
		PlanId:    o.GetPlanId(),
		PlanName:  o.GetPlanName(),
		Amount:    float64(o.GetAmount()),
		Status:    o.GetStatus(),
		CreatedAt: o.GetCreatedAt(),
		PaidAt:    o.GetPaidAt(),
		OrderNo:   o.GetOrderNo(),
	}
}

func RpcGiftPurchaseOrderToTypes(o *moe.GiftPurchaseOrder) types.GiftPurchaseOrder {
	if o == nil {
		return types.GiftPurchaseOrder{}
	}
	return types.GiftPurchaseOrder{
		Id:          o.GetId(),
		UserId:      o.GetUserId(),
		OrderNo:     o.GetOrderNo(),
		GiftId:      o.GetGiftId(),
		GiftName:    o.GetGiftName(),
		Quantity:    int(o.GetQuantity()),
		UnitPrice:   o.GetUnitPrice(),
		TotalAmount: o.GetTotalAmount(),
		PayMethod:   o.GetPayMethod(),
		Status:      o.GetStatus(),
		CreatedAt:   o.GetCreatedAt(),
	}
}

package giftgrpc

import (
	giftv1 "backend/api/gift/v1"
	moerpc "backend/rpc/pb/moe"
)

func giftToProto(in *moerpc.Gift) *giftv1.Gift {
	if in == nil {
		return nil
	}
	return &giftv1.Gift{
		Id: in.GetId(), Name: in.GetName(), Price: in.GetPrice(), Icon: in.GetIcon(),
		Description: in.GetDescription(), CreatedAt: in.GetCreatedAt(), UpdatedAt: in.GetUpdatedAt(),
		OwnedQuantity: in.GetOwnedQuantity(), Category: in.GetCategory(), SortOrder: in.GetSortOrder(),
	}
}

func giftsToProto(rows []*moerpc.Gift) []*giftv1.Gift {
	out := make([]*giftv1.Gift, 0, len(rows))
	for _, row := range rows {
		out = append(out, giftToProto(row))
	}
	return out
}

func giftRecordToProto(in *moerpc.GiftRecord) *giftv1.GiftRecord {
	if in == nil {
		return nil
	}
	return &giftv1.GiftRecord{
		Id: in.GetId(), FromUserId: in.GetFromUserId(), FromUserName: in.GetFromUserName(),
		ToUserId: in.GetToUserId(), ToUserName: in.GetToUserName(), GiftId: in.GetGiftId(),
		Gift: giftToProto(in.GetGift()), Quantity: in.GetQuantity(), CreatedAt: in.GetCreatedAt(),
	}
}

func giftRecordsToProto(rows []*moerpc.GiftRecord) []*giftv1.GiftRecord {
	out := make([]*giftv1.GiftRecord, 0, len(rows))
	for _, row := range rows {
		out = append(out, giftRecordToProto(row))
	}
	return out
}

func achievementUnlocksToProto(rows []*moerpc.AchievementUnlock) []*giftv1.AchievementUnlock {
	out := make([]*giftv1.AchievementUnlock, 0, len(rows))
	for _, row := range rows {
		if row == nil {
			continue
		}
		out = append(out, &giftv1.AchievementUnlock{
			BadgeId: row.GetBadgeId(), Name: row.GetName(), ExpGranted: row.GetExpGranted(),
			LevelUp: row.GetLevelUp(), NewLevel: row.GetNewLevel(),
		})
	}
	return out
}

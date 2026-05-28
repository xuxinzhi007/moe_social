package giftv1

import "backend/rpc/pb/moe"

func GiftFromMoe(g *moe.Gift) *Gift {
	if g == nil {
		return nil
	}
	return &Gift{
		Id:            g.GetId(),
		Name:          g.GetName(),
		Price:         g.GetPrice(),
		Icon:          g.GetIcon(),
		Description:   g.GetDescription(),
		CreatedAt:     g.GetCreatedAt(),
		UpdatedAt:     g.GetUpdatedAt(),
		OwnedQuantity: g.GetOwnedQuantity(),
		Category:      g.GetCategory(),
		SortOrder:     g.GetSortOrder(),
	}
}

func GiftToMoe(g *Gift) *moe.Gift {
	if g == nil {
		return nil
	}
	return &moe.Gift{
		Id:            g.GetId(),
		Name:          g.GetName(),
		Price:         g.GetPrice(),
		Icon:          g.GetIcon(),
		Description:   g.GetDescription(),
		CreatedAt:     g.GetCreatedAt(),
		UpdatedAt:     g.GetUpdatedAt(),
		OwnedQuantity: g.GetOwnedQuantity(),
		Category:      g.GetCategory(),
		SortOrder:     g.GetSortOrder(),
	}
}

func GiftsFromMoe(items []*moe.Gift) []*Gift {
	if len(items) == 0 {
		return nil
	}
	out := make([]*Gift, 0, len(items))
	for _, g := range items {
		if g == nil {
			continue
		}
		out = append(out, GiftFromMoe(g))
	}
	return out
}

func GiftRecordFromMoe(r *moe.GiftRecord) *GiftRecord {
	if r == nil {
		return nil
	}
	return &GiftRecord{
		Id:           r.GetId(),
		FromUserId:   r.GetFromUserId(),
		FromUserName: r.GetFromUserName(),
		ToUserId:     r.GetToUserId(),
		ToUserName:   r.GetToUserName(),
		GiftId:       r.GetGiftId(),
		Gift:         GiftFromMoe(r.GetGift()),
		Quantity:     r.GetQuantity(),
		CreatedAt:    r.GetCreatedAt(),
	}
}

func GiftRecordToMoe(r *GiftRecord) *moe.GiftRecord {
	if r == nil {
		return nil
	}
	return &moe.GiftRecord{
		Id:           r.GetId(),
		FromUserId:   r.GetFromUserId(),
		FromUserName: r.GetFromUserName(),
		ToUserId:     r.GetToUserId(),
		ToUserName:   r.GetToUserName(),
		GiftId:       r.GetGiftId(),
		Gift:         GiftToMoe(r.GetGift()),
		Quantity:     r.GetQuantity(),
		CreatedAt:    r.GetCreatedAt(),
	}
}

func GiftRecordsFromMoe(items []*moe.GiftRecord) []*GiftRecord {
	if len(items) == 0 {
		return nil
	}
	out := make([]*GiftRecord, 0, len(items))
	for _, r := range items {
		if r == nil {
			continue
		}
		out = append(out, GiftRecordFromMoe(r))
	}
	return out
}

func AchievementUnlockFromMoe(u *moe.AchievementUnlock) *AchievementUnlock {
	if u == nil {
		return nil
	}
	return &AchievementUnlock{
		BadgeId:    u.GetBadgeId(),
		Name:       u.GetName(),
		ExpGranted: u.GetExpGranted(),
		LevelUp:    u.GetLevelUp(),
		NewLevel:   u.GetNewLevel(),
	}
}

func AchievementUnlocksFromMoe(items []*moe.AchievementUnlock) []*AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	out := make([]*AchievementUnlock, 0, len(items))
	for _, u := range items {
		if u == nil {
			continue
		}
		out = append(out, AchievementUnlockFromMoe(u))
	}
	return out
}

func AchievementUnlocksToMoe(items []*AchievementUnlock) []*moe.AchievementUnlock {
	if len(items) == 0 {
		return nil
	}
	out := make([]*moe.AchievementUnlock, 0, len(items))
	for _, u := range items {
		if u == nil {
			continue
		}
		out = append(out, &moe.AchievementUnlock{
			BadgeId:    u.GetBadgeId(),
			Name:       u.GetName(),
			ExpGranted: u.GetExpGranted(),
			LevelUp:    u.GetLevelUp(),
			NewLevel:   u.GetNewLevel(),
		})
	}
	return out
}

func GiftPurchaseOrderFromMoe(o *moe.GiftPurchaseOrder) *GiftPurchaseOrder {
	if o == nil {
		return nil
	}
	return &GiftPurchaseOrder{
		Id:          o.GetId(),
		UserId:      o.GetUserId(),
		OrderNo:     o.GetOrderNo(),
		GiftId:      o.GetGiftId(),
		GiftName:    o.GetGiftName(),
		Quantity:    o.GetQuantity(),
		UnitPrice:   o.GetUnitPrice(),
		TotalAmount: o.GetTotalAmount(),
		PayMethod:   o.GetPayMethod(),
		Status:      o.GetStatus(),
		CreatedAt:   o.GetCreatedAt(),
	}
}

func GiftPurchaseOrdersFromMoe(items []*moe.GiftPurchaseOrder) []*GiftPurchaseOrder {
	if len(items) == 0 {
		return nil
	}
	out := make([]*GiftPurchaseOrder, 0, len(items))
	for _, o := range items {
		if o == nil {
			continue
		}
		out = append(out, GiftPurchaseOrderFromMoe(o))
	}
	return out
}

func GetGiftsRequestFromMoe(in *moe.GetGiftsReq) *GetGiftsRequest {
	if in == nil {
		return &GetGiftsRequest{}
	}
	return &GetGiftsRequest{
		Page:         in.GetPage(),
		PageSize:     in.GetPageSize(),
		ViewerUserId: in.GetViewerUserId(),
	}
}

func GetGiftsReplyToMoe(out *GetGiftsReply) *moe.GetGiftsResp {
	if out == nil {
		return &moe.GetGiftsResp{}
	}
	gifts := make([]*moe.Gift, 0, len(out.GetGifts()))
	for _, g := range out.GetGifts() {
		gifts = append(gifts, GiftToMoe(g))
	}
	return &moe.GetGiftsResp{Gifts: gifts, Total: out.GetTotal()}
}

func GetGiftRequestFromMoe(in *moe.GetGiftReq) *GetGiftRequest {
	if in == nil {
		return &GetGiftRequest{}
	}
	return &GetGiftRequest{GiftId: in.GetGiftId()}
}

func GetGiftReplyFromMoe(in *moe.GetGiftResp) *GetGiftReply {
	if in == nil {
		return &GetGiftReply{}
	}
	return &GetGiftReply{
		Success: in.GetSuccess(),
		Message: in.GetMessage(),
		Gift:    GiftFromMoe(in.GetGift()),
	}
}

func GetGiftReplyToMoe(out *GetGiftReply) *moe.GetGiftResp {
	if out == nil {
		return &moe.GetGiftResp{}
	}
	return &moe.GetGiftResp{
		Success: out.GetSuccess(),
		Message: out.GetMessage(),
		Gift:    GiftToMoe(out.GetGift()),
	}
}

func SendGiftRequestFromMoe(in *moe.SendGiftReq) *SendGiftRequest {
	if in == nil {
		return &SendGiftRequest{}
	}
	return &SendGiftRequest{
		FromUserId: in.GetFromUserId(),
		ToUserId:   in.GetToUserId(),
		GiftId:     in.GetGiftId(),
		Quantity:   in.GetQuantity(),
	}
}

func SendGiftReplyFromMoe(in *moe.SendGiftResp) *SendGiftReply {
	if in == nil {
		return &SendGiftReply{}
	}
	return &SendGiftReply{
		Success:         in.GetSuccess(),
		Message:         in.GetMessage(),
		Record:          GiftRecordFromMoe(in.GetRecord()),
		NewAchievements: AchievementUnlocksFromMoe(in.GetNewAchievements()),
	}
}

func SendGiftReplyToMoe(out *SendGiftReply) *moe.SendGiftResp {
	if out == nil {
		return &moe.SendGiftResp{}
	}
	return &moe.SendGiftResp{
		Success:         out.GetSuccess(),
		Message:         out.GetMessage(),
		Record:          GiftRecordToMoe(out.GetRecord()),
		NewAchievements: AchievementUnlocksToMoe(out.GetNewAchievements()),
	}
}

func GetGiftRecordsRequestFromMoe(in *moe.GetGiftRecordsReq) *GetGiftRecordsRequest {
	if in == nil {
		return &GetGiftRecordsRequest{}
	}
	return &GetGiftRecordsRequest{
		UserId:   in.GetUserId(),
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	}
}

func GetGiftRecordsReplyToMoe(out *GetGiftRecordsReply) *moe.GetGiftRecordsResp {
	if out == nil {
		return &moe.GetGiftRecordsResp{}
	}
	records := make([]*moe.GiftRecord, 0, len(out.GetRecords()))
	for _, r := range out.GetRecords() {
		records = append(records, GiftRecordToMoe(r))
	}
	return &moe.GetGiftRecordsResp{Records: records, Total: out.GetTotal()}
}

func PurchaseGiftRequestFromMoe(in *moe.PurchaseGiftReq) *PurchaseGiftRequest {
	if in == nil {
		return &PurchaseGiftRequest{}
	}
	return &PurchaseGiftRequest{
		UserId:   in.GetUserId(),
		GiftId:   in.GetGiftId(),
		Quantity: in.GetQuantity(),
	}
}

func PurchaseGiftReplyFromMoe(in *moe.PurchaseGiftResp) *PurchaseGiftReply {
	if in == nil {
		return &PurchaseGiftReply{}
	}
	return &PurchaseGiftReply{
		Success:       in.GetSuccess(),
		Message:       in.GetMessage(),
		NewBalance:    in.GetNewBalance(),
		OwnedQuantity: in.GetOwnedQuantity(),
		OrderNo:       in.GetOrderNo(),
	}
}

func PurchaseGiftReplyToMoe(out *PurchaseGiftReply) *moe.PurchaseGiftResp {
	if out == nil {
		return &moe.PurchaseGiftResp{}
	}
	return &moe.PurchaseGiftResp{
		Success:       out.GetSuccess(),
		Message:       out.GetMessage(),
		NewBalance:    out.GetNewBalance(),
		OwnedQuantity: out.GetOwnedQuantity(),
		OrderNo:       out.GetOrderNo(),
	}
}

func GetGiftPurchaseOrdersRequestFromMoe(in *moe.GetGiftPurchaseOrdersReq) *GetGiftPurchaseOrdersRequest {
	if in == nil {
		return &GetGiftPurchaseOrdersRequest{}
	}
	return &GetGiftPurchaseOrdersRequest{
		UserId:   in.GetUserId(),
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
	}
}

func GetGiftPurchaseOrdersReplyToMoe(out *GetGiftPurchaseOrdersReply) *moe.GetGiftPurchaseOrdersResp {
	if out == nil {
		return &moe.GetGiftPurchaseOrdersResp{}
	}
	orders := make([]*moe.GiftPurchaseOrder, 0, len(out.GetOrders()))
	for _, o := range out.GetOrders() {
		if o == nil {
			continue
		}
		orders = append(orders, &moe.GiftPurchaseOrder{
			Id: o.GetId(), UserId: o.GetUserId(), OrderNo: o.GetOrderNo(),
			GiftId: o.GetGiftId(), GiftName: o.GetGiftName(), Quantity: o.GetQuantity(),
			UnitPrice: o.GetUnitPrice(), TotalAmount: o.GetTotalAmount(),
			PayMethod: o.GetPayMethod(), Status: o.GetStatus(), CreatedAt: o.GetCreatedAt(),
		})
	}
	return &moe.GetGiftPurchaseOrdersResp{Orders: orders, Total: out.GetTotal()}
}

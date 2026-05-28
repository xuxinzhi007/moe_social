package vipgrpc

import (
	vipv1 "backend/api/vip/v1"
	moerpc "backend/rpc/pb/moe"
)

func vipRecordsToProto(items []*moerpc.VipRecord) []*vipv1.VipRecord {
	if len(items) == 0 {
		return nil
	}
	out := make([]*vipv1.VipRecord, 0, len(items))
	for _, r := range items {
		out = append(out, vipRecordToProto(r))
	}
	return out
}

func vipRecordToProto(r *moerpc.VipRecord) *vipv1.VipRecord {
	if r == nil {
		return nil
	}
	return &vipv1.VipRecord{
		Id: r.GetId(), UserId: r.GetUserId(), PlanId: r.GetPlanId(),
		PlanName: r.GetPlanName(), StartAt: r.GetStartAt(), EndAt: r.GetEndAt(),
		Status: r.GetStatus(), CreatedAt: r.GetCreatedAt(),
	}
}

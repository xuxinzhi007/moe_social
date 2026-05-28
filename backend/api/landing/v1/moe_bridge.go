package landingv1

import "backend/rpc/pb/moe"

func SubmitRequestFromMoe(in *moe.SubmitLandingFeedbackReq) *SubmitLandingFeedbackRequest {
	if in == nil {
		return &SubmitLandingFeedbackRequest{}
	}
	return &SubmitLandingFeedbackRequest{
		Email:     in.GetEmail(),
		Category:  in.GetCategory(),
		Content:   in.GetContent(),
		Source:    in.GetSource(),
		ClientIp:  in.GetClientIp(),
		UserAgent: in.GetUserAgent(),
	}
}

func SubmitReplyToMoe(out *SubmitLandingFeedbackReply) *moe.SubmitLandingFeedbackResp {
	if out == nil {
		return &moe.SubmitLandingFeedbackResp{}
	}
	return &moe.SubmitLandingFeedbackResp{Id: out.GetId()}
}

func ListRequestFromMoe(in *moe.ListLandingFeedbackReq) *ListLandingFeedbackRequest {
	if in == nil {
		return &ListLandingFeedbackRequest{}
	}
	return &ListLandingFeedbackRequest{
		Page:     in.GetPage(),
		PageSize: in.GetPageSize(),
		Category: in.GetCategory(),
	}
}

func ListReplyToMoe(out *ListLandingFeedbackReply) *moe.ListLandingFeedbackResp {
	if out == nil {
		return &moe.ListLandingFeedbackResp{}
	}
	items := make([]*moe.LandingFeedbackItem, 0, len(out.GetItems()))
	for _, it := range out.GetItems() {
		if it == nil {
			continue
		}
		items = append(items, &moe.LandingFeedbackItem{
			Id:         it.GetId(),
			Email:      it.GetEmail(),
			Category:   it.GetCategory(),
			Content:    it.GetContent(),
			Source:     it.GetSource(),
			ClientIp:   it.GetClientIp(),
			UserAgent:  it.GetUserAgent(),
			CreatedAt:  it.GetCreatedAt(),
		})
	}
	return &moe.ListLandingFeedbackResp{Items: items, Total: out.GetTotal()}
}

func FeedbackItemsFromMoe(items []*moe.LandingFeedbackItem) []*LandingFeedbackItem {
	if len(items) == 0 {
		return nil
	}
	out := make([]*LandingFeedbackItem, 0, len(items))
	for _, it := range items {
		if it == nil {
			continue
		}
		out = append(out, &LandingFeedbackItem{
			Id:         it.GetId(),
			Email:      it.GetEmail(),
			Category:   it.GetCategory(),
			Content:    it.GetContent(),
			Source:     it.GetSource(),
			ClientIp:   it.GetClientIp(),
			UserAgent:  it.GetUserAgent(),
			CreatedAt:  it.GetCreatedAt(),
		})
	}
	return out
}

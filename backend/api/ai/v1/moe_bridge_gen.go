package aiv1

import (
	"backend/rpc/pb/moe"

	"google.golang.org/protobuf/proto"
)

func cloneTo[S, D proto.Message](src S, newDst func() D) D {
	var zero D
	if any(src) == nil {
		return zero
	}
	dst := newDst()
	b, err := proto.Marshal(src)
	if err != nil {
		return zero
	}
	if err := proto.Unmarshal(b, dst); err != nil {
		return zero
	}
	return dst
}

func AiJsonResourceItemFromMoe(in *moe.AiJsonResourceItem) *AiJsonResourceItem {
	return cloneTo(in, func() *AiJsonResourceItem { return &AiJsonResourceItem{} })
}

func AiJsonResourceItemToMoe(in *AiJsonResourceItem) *moe.AiJsonResourceItem {
	return cloneTo(in, func() *moe.AiJsonResourceItem { return &moe.AiJsonResourceItem{} })
}

func DeleteAiResourceReqFromMoe(in *moe.DeleteAiResourceReq) *DeleteAiResourceReq {
	return cloneTo(in, func() *DeleteAiResourceReq { return &DeleteAiResourceReq{} })
}

func DeleteAiResourceReqToMoe(in *DeleteAiResourceReq) *moe.DeleteAiResourceReq {
	return cloneTo(in, func() *moe.DeleteAiResourceReq { return &moe.DeleteAiResourceReq{} })
}

func DeleteAiResourceRespFromMoe(in *moe.DeleteAiResourceResp) *DeleteAiResourceResp {
	return cloneTo(in, func() *DeleteAiResourceResp { return &DeleteAiResourceResp{} })
}

func DeleteAiResourceRespToMoe(in *DeleteAiResourceResp) *moe.DeleteAiResourceResp {
	return cloneTo(in, func() *moe.DeleteAiResourceResp { return &moe.DeleteAiResourceResp{} })
}

func ListAiResourceReqFromMoe(in *moe.ListAiResourceReq) *ListAiResourceReq {
	return cloneTo(in, func() *ListAiResourceReq { return &ListAiResourceReq{} })
}

func ListAiResourceReqToMoe(in *ListAiResourceReq) *moe.ListAiResourceReq {
	return cloneTo(in, func() *moe.ListAiResourceReq { return &moe.ListAiResourceReq{} })
}

func ListAiResourceRespFromMoe(in *moe.ListAiResourceResp) *ListAiResourceResp {
	return cloneTo(in, func() *ListAiResourceResp { return &ListAiResourceResp{} })
}

func ListAiResourceRespToMoe(in *ListAiResourceResp) *moe.ListAiResourceResp {
	return cloneTo(in, func() *moe.ListAiResourceResp { return &moe.ListAiResourceResp{} })
}

func ListPublicAiAgentsReqFromMoe(in *moe.ListPublicAiAgentsReq) *ListPublicAiAgentsReq {
	return cloneTo(in, func() *ListPublicAiAgentsReq { return &ListPublicAiAgentsReq{} })
}

func ListPublicAiAgentsReqToMoe(in *ListPublicAiAgentsReq) *moe.ListPublicAiAgentsReq {
	return cloneTo(in, func() *moe.ListPublicAiAgentsReq { return &moe.ListPublicAiAgentsReq{} })
}

func UpsertAiResourceReqFromMoe(in *moe.UpsertAiResourceReq) *UpsertAiResourceReq {
	return cloneTo(in, func() *UpsertAiResourceReq { return &UpsertAiResourceReq{} })
}

func UpsertAiResourceReqToMoe(in *UpsertAiResourceReq) *moe.UpsertAiResourceReq {
	return cloneTo(in, func() *moe.UpsertAiResourceReq { return &moe.UpsertAiResourceReq{} })
}

func UpsertAiResourceRespFromMoe(in *moe.UpsertAiResourceResp) *UpsertAiResourceResp {
	return cloneTo(in, func() *UpsertAiResourceResp { return &UpsertAiResourceResp{} })
}

func UpsertAiResourceRespToMoe(in *UpsertAiResourceResp) *moe.UpsertAiResourceResp {
	return cloneTo(in, func() *moe.UpsertAiResourceResp { return &moe.UpsertAiResourceResp{} })
}

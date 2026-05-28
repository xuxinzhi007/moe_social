package llmv1

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

func DeleteUserMemoryReqFromMoe(in *moe.DeleteUserMemoryReq) *DeleteUserMemoryReq {
	return cloneTo(in, func() *DeleteUserMemoryReq { return &DeleteUserMemoryReq{} })
}

func DeleteUserMemoryReqToMoe(in *DeleteUserMemoryReq) *moe.DeleteUserMemoryReq {
	return cloneTo(in, func() *moe.DeleteUserMemoryReq { return &moe.DeleteUserMemoryReq{} })
}

func DeleteUserMemoryRespFromMoe(in *moe.DeleteUserMemoryResp) *DeleteUserMemoryResp {
	return cloneTo(in, func() *DeleteUserMemoryResp { return &DeleteUserMemoryResp{} })
}

func DeleteUserMemoryRespToMoe(in *DeleteUserMemoryResp) *moe.DeleteUserMemoryResp {
	return cloneTo(in, func() *moe.DeleteUserMemoryResp { return &moe.DeleteUserMemoryResp{} })
}

func GetAiUserConfigReqFromMoe(in *moe.GetAiUserConfigReq) *GetAiUserConfigReq {
	return cloneTo(in, func() *GetAiUserConfigReq { return &GetAiUserConfigReq{} })
}

func GetAiUserConfigReqToMoe(in *GetAiUserConfigReq) *moe.GetAiUserConfigReq {
	return cloneTo(in, func() *moe.GetAiUserConfigReq { return &moe.GetAiUserConfigReq{} })
}

func GetAiUserConfigRespFromMoe(in *moe.GetAiUserConfigResp) *GetAiUserConfigResp {
	return cloneTo(in, func() *GetAiUserConfigResp { return &GetAiUserConfigResp{} })
}

func GetAiUserConfigRespToMoe(in *GetAiUserConfigResp) *moe.GetAiUserConfigResp {
	return cloneTo(in, func() *moe.GetAiUserConfigResp { return &moe.GetAiUserConfigResp{} })
}

func GetUserMemoriesReqFromMoe(in *moe.GetUserMemoriesReq) *GetUserMemoriesReq {
	return cloneTo(in, func() *GetUserMemoriesReq { return &GetUserMemoriesReq{} })
}

func GetUserMemoriesReqToMoe(in *GetUserMemoriesReq) *moe.GetUserMemoriesReq {
	return cloneTo(in, func() *moe.GetUserMemoriesReq { return &moe.GetUserMemoriesReq{} })
}

func GetUserMemoriesRespFromMoe(in *moe.GetUserMemoriesResp) *GetUserMemoriesResp {
	return cloneTo(in, func() *GetUserMemoriesResp { return &GetUserMemoriesResp{} })
}

func GetUserMemoriesRespToMoe(in *GetUserMemoriesResp) *moe.GetUserMemoriesResp {
	return cloneTo(in, func() *moe.GetUserMemoriesResp { return &moe.GetUserMemoriesResp{} })
}

func GetUserMemoryProfilesReqFromMoe(in *moe.GetUserMemoryProfilesReq) *GetUserMemoryProfilesReq {
	return cloneTo(in, func() *GetUserMemoryProfilesReq { return &GetUserMemoryProfilesReq{} })
}

func GetUserMemoryProfilesReqToMoe(in *GetUserMemoryProfilesReq) *moe.GetUserMemoryProfilesReq {
	return cloneTo(in, func() *moe.GetUserMemoryProfilesReq { return &moe.GetUserMemoryProfilesReq{} })
}

func GetUserMemoryProfilesRespFromMoe(in *moe.GetUserMemoryProfilesResp) *GetUserMemoryProfilesResp {
	return cloneTo(in, func() *GetUserMemoryProfilesResp { return &GetUserMemoryProfilesResp{} })
}

func GetUserMemoryProfilesRespToMoe(in *GetUserMemoryProfilesResp) *moe.GetUserMemoryProfilesResp {
	return cloneTo(in, func() *moe.GetUserMemoryProfilesResp { return &moe.GetUserMemoryProfilesResp{} })
}

func ListUserMemoryEmbeddingsReqFromMoe(in *moe.ListUserMemoryEmbeddingsReq) *ListUserMemoryEmbeddingsReq {
	return cloneTo(in, func() *ListUserMemoryEmbeddingsReq { return &ListUserMemoryEmbeddingsReq{} })
}

func ListUserMemoryEmbeddingsReqToMoe(in *ListUserMemoryEmbeddingsReq) *moe.ListUserMemoryEmbeddingsReq {
	return cloneTo(in, func() *moe.ListUserMemoryEmbeddingsReq { return &moe.ListUserMemoryEmbeddingsReq{} })
}

func ListUserMemoryEmbeddingsRespFromMoe(in *moe.ListUserMemoryEmbeddingsResp) *ListUserMemoryEmbeddingsResp {
	return cloneTo(in, func() *ListUserMemoryEmbeddingsResp { return &ListUserMemoryEmbeddingsResp{} })
}

func ListUserMemoryEmbeddingsRespToMoe(in *ListUserMemoryEmbeddingsResp) *moe.ListUserMemoryEmbeddingsResp {
	return cloneTo(in, func() *moe.ListUserMemoryEmbeddingsResp { return &moe.ListUserMemoryEmbeddingsResp{} })
}

func ListUserMemoryRelationsReqFromMoe(in *moe.ListUserMemoryRelationsReq) *ListUserMemoryRelationsReq {
	return cloneTo(in, func() *ListUserMemoryRelationsReq { return &ListUserMemoryRelationsReq{} })
}

func ListUserMemoryRelationsReqToMoe(in *ListUserMemoryRelationsReq) *moe.ListUserMemoryRelationsReq {
	return cloneTo(in, func() *moe.ListUserMemoryRelationsReq { return &moe.ListUserMemoryRelationsReq{} })
}

func ListUserMemoryRelationsRespFromMoe(in *moe.ListUserMemoryRelationsResp) *ListUserMemoryRelationsResp {
	return cloneTo(in, func() *ListUserMemoryRelationsResp { return &ListUserMemoryRelationsResp{} })
}

func ListUserMemoryRelationsRespToMoe(in *ListUserMemoryRelationsResp) *moe.ListUserMemoryRelationsResp {
	return cloneTo(in, func() *moe.ListUserMemoryRelationsResp { return &moe.ListUserMemoryRelationsResp{} })
}

func RebuildUserMemoryEmbeddingsReqFromMoe(in *moe.RebuildUserMemoryEmbeddingsReq) *RebuildUserMemoryEmbeddingsReq {
	return cloneTo(in, func() *RebuildUserMemoryEmbeddingsReq { return &RebuildUserMemoryEmbeddingsReq{} })
}

func RebuildUserMemoryEmbeddingsReqToMoe(in *RebuildUserMemoryEmbeddingsReq) *moe.RebuildUserMemoryEmbeddingsReq {
	return cloneTo(in, func() *moe.RebuildUserMemoryEmbeddingsReq { return &moe.RebuildUserMemoryEmbeddingsReq{} })
}

func RebuildUserMemoryEmbeddingsRespFromMoe(in *moe.RebuildUserMemoryEmbeddingsResp) *RebuildUserMemoryEmbeddingsResp {
	return cloneTo(in, func() *RebuildUserMemoryEmbeddingsResp { return &RebuildUserMemoryEmbeddingsResp{} })
}

func RebuildUserMemoryEmbeddingsRespToMoe(in *RebuildUserMemoryEmbeddingsResp) *moe.RebuildUserMemoryEmbeddingsResp {
	return cloneTo(in, func() *moe.RebuildUserMemoryEmbeddingsResp { return &moe.RebuildUserMemoryEmbeddingsResp{} })
}

func RecordLlmChatTurnReqFromMoe(in *moe.RecordLlmChatTurnReq) *RecordLlmChatTurnReq {
	return cloneTo(in, func() *RecordLlmChatTurnReq { return &RecordLlmChatTurnReq{} })
}

func RecordLlmChatTurnReqToMoe(in *RecordLlmChatTurnReq) *moe.RecordLlmChatTurnReq {
	return cloneTo(in, func() *moe.RecordLlmChatTurnReq { return &moe.RecordLlmChatTurnReq{} })
}

func RecordLlmChatTurnRespFromMoe(in *moe.RecordLlmChatTurnResp) *RecordLlmChatTurnResp {
	return cloneTo(in, func() *RecordLlmChatTurnResp { return &RecordLlmChatTurnResp{} })
}

func RecordLlmChatTurnRespToMoe(in *RecordLlmChatTurnResp) *moe.RecordLlmChatTurnResp {
	return cloneTo(in, func() *moe.RecordLlmChatTurnResp { return &moe.RecordLlmChatTurnResp{} })
}

func SubmitUserMemoryFeedbackReqFromMoe(in *moe.SubmitUserMemoryFeedbackReq) *SubmitUserMemoryFeedbackReq {
	return cloneTo(in, func() *SubmitUserMemoryFeedbackReq { return &SubmitUserMemoryFeedbackReq{} })
}

func SubmitUserMemoryFeedbackReqToMoe(in *SubmitUserMemoryFeedbackReq) *moe.SubmitUserMemoryFeedbackReq {
	return cloneTo(in, func() *moe.SubmitUserMemoryFeedbackReq { return &moe.SubmitUserMemoryFeedbackReq{} })
}

func SubmitUserMemoryFeedbackRespFromMoe(in *moe.SubmitUserMemoryFeedbackResp) *SubmitUserMemoryFeedbackResp {
	return cloneTo(in, func() *SubmitUserMemoryFeedbackResp { return &SubmitUserMemoryFeedbackResp{} })
}

func SubmitUserMemoryFeedbackRespToMoe(in *SubmitUserMemoryFeedbackResp) *moe.SubmitUserMemoryFeedbackResp {
	return cloneTo(in, func() *moe.SubmitUserMemoryFeedbackResp { return &moe.SubmitUserMemoryFeedbackResp{} })
}

func UpsertAiUserConfigReqFromMoe(in *moe.UpsertAiUserConfigReq) *UpsertAiUserConfigReq {
	return cloneTo(in, func() *UpsertAiUserConfigReq { return &UpsertAiUserConfigReq{} })
}

func UpsertAiUserConfigReqToMoe(in *UpsertAiUserConfigReq) *moe.UpsertAiUserConfigReq {
	return cloneTo(in, func() *moe.UpsertAiUserConfigReq { return &moe.UpsertAiUserConfigReq{} })
}

func UpsertAiUserConfigRespFromMoe(in *moe.UpsertAiUserConfigResp) *UpsertAiUserConfigResp {
	return cloneTo(in, func() *UpsertAiUserConfigResp { return &UpsertAiUserConfigResp{} })
}

func UpsertAiUserConfigRespToMoe(in *UpsertAiUserConfigResp) *moe.UpsertAiUserConfigResp {
	return cloneTo(in, func() *moe.UpsertAiUserConfigResp { return &moe.UpsertAiUserConfigResp{} })
}

func UpsertUserMemoryEmbeddingReqFromMoe(in *moe.UpsertUserMemoryEmbeddingReq) *UpsertUserMemoryEmbeddingReq {
	return cloneTo(in, func() *UpsertUserMemoryEmbeddingReq { return &UpsertUserMemoryEmbeddingReq{} })
}

func UpsertUserMemoryEmbeddingReqToMoe(in *UpsertUserMemoryEmbeddingReq) *moe.UpsertUserMemoryEmbeddingReq {
	return cloneTo(in, func() *moe.UpsertUserMemoryEmbeddingReq { return &moe.UpsertUserMemoryEmbeddingReq{} })
}

func UpsertUserMemoryEmbeddingRespFromMoe(in *moe.UpsertUserMemoryEmbeddingResp) *UpsertUserMemoryEmbeddingResp {
	return cloneTo(in, func() *UpsertUserMemoryEmbeddingResp { return &UpsertUserMemoryEmbeddingResp{} })
}

func UpsertUserMemoryEmbeddingRespToMoe(in *UpsertUserMemoryEmbeddingResp) *moe.UpsertUserMemoryEmbeddingResp {
	return cloneTo(in, func() *moe.UpsertUserMemoryEmbeddingResp { return &moe.UpsertUserMemoryEmbeddingResp{} })
}

func UpsertUserMemoryReqFromMoe(in *moe.UpsertUserMemoryReq) *UpsertUserMemoryReq {
	return cloneTo(in, func() *UpsertUserMemoryReq { return &UpsertUserMemoryReq{} })
}

func UpsertUserMemoryReqToMoe(in *UpsertUserMemoryReq) *moe.UpsertUserMemoryReq {
	return cloneTo(in, func() *moe.UpsertUserMemoryReq { return &moe.UpsertUserMemoryReq{} })
}

func UpsertUserMemoryRespFromMoe(in *moe.UpsertUserMemoryResp) *UpsertUserMemoryResp {
	return cloneTo(in, func() *UpsertUserMemoryResp { return &UpsertUserMemoryResp{} })
}

func UpsertUserMemoryRespToMoe(in *UpsertUserMemoryResp) *moe.UpsertUserMemoryResp {
	return cloneTo(in, func() *moe.UpsertUserMemoryResp { return &moe.UpsertUserMemoryResp{} })
}

func UserMemoryFromMoe(in *moe.UserMemory) *UserMemory {
	return cloneTo(in, func() *UserMemory { return &UserMemory{} })
}

func UserMemoryToMoe(in *UserMemory) *moe.UserMemory {
	return cloneTo(in, func() *moe.UserMemory { return &moe.UserMemory{} })
}

func UserMemoryEmbeddingItemFromMoe(in *moe.UserMemoryEmbeddingItem) *UserMemoryEmbeddingItem {
	return cloneTo(in, func() *UserMemoryEmbeddingItem { return &UserMemoryEmbeddingItem{} })
}

func UserMemoryEmbeddingItemToMoe(in *UserMemoryEmbeddingItem) *moe.UserMemoryEmbeddingItem {
	return cloneTo(in, func() *moe.UserMemoryEmbeddingItem { return &moe.UserMemoryEmbeddingItem{} })
}

func UserMemoryProfileFromMoe(in *moe.UserMemoryProfile) *UserMemoryProfile {
	return cloneTo(in, func() *UserMemoryProfile { return &UserMemoryProfile{} })
}

func UserMemoryProfileToMoe(in *UserMemoryProfile) *moe.UserMemoryProfile {
	return cloneTo(in, func() *moe.UserMemoryProfile { return &moe.UserMemoryProfile{} })
}

func UserMemoryRelationItemFromMoe(in *moe.UserMemoryRelationItem) *UserMemoryRelationItem {
	return cloneTo(in, func() *UserMemoryRelationItem { return &UserMemoryRelationItem{} })
}

func UserMemoryRelationItemToMoe(in *UserMemoryRelationItem) *moe.UserMemoryRelationItem {
	return cloneTo(in, func() *moe.UserMemoryRelationItem { return &moe.UserMemoryRelationItem{} })
}

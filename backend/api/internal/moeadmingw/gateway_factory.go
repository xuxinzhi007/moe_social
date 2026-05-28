package moeadmingw

import (
	moepb "backend/api/moe/v1"
	moeadmin "backend/internal/service/moe"
	"backend/internal/platform/moewiring"
)

// NewConfigured 按 config.yaml moe.* 构造网关（含可选 kratos_http 灰度）。
func NewConfigured(local *moeadmin.AdminService, moeGRPC moepb.MoeAdminClient) *Gateway {
	var kratos *KratosHTTPClient
	if moewiring.KratosAdminHTTPEnabled() {
		kratos = NewKratosHTTPClient(moewiring.KratosAdminBaseURL())
	}
	return New(local, moeGRPC, kratos)
}

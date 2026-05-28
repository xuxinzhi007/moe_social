package vipadmingw

import (
	vipadmin "backend/internal/service/vip"
	"backend/internal/platform/moewiring"
	"backend/rpc/pb/moe"
)

// NewConfigured 按 config.yaml moe.* 构造网关（含可选 kratos_http 灰度，PK-2）。
func NewConfigured(local *vipadmin.AdminService, legacy moe.SuperClient) *Gateway {
	var kratos *KratosHTTPClient
	if moewiring.KratosVipHTTPEnabled() {
		kratos = NewKratosHTTPClient(moewiring.KratosPilotBaseURL())
	}
	return New(local, legacy, kratos)
}

package types

type FeishuPublicConfigResp struct {
	BaseResp
	Data FeishuPublicConfigData `json:"data,omitempty"`
}

type FeishuPublicConfigData struct {
	Enabled             bool   `json:"enabled"`
	EnterpriseInviteURL string `json:"enterprise_invite_url,omitempty"`
	Notice              string `json:"notice,omitempty"`
}

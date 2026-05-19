package types

type FeishuAuthorizeURLResp struct {
	BaseResp
	Data FeishuAuthorizeURLData `json:"data,omitempty"`
}

type FeishuAuthorizeURLData struct {
	AuthorizeURL string `json:"authorize_url"`
}

type FeishuLoginReq struct {
	Code string `json:"code"`
}

type FeishuLoginResp struct {
	BaseResp
	Data FeishuLoginData `json:"data,omitempty"`
}

type FeishuLoginData struct {
	User      User   `json:"user"`
	Token     string `json:"token"`
	IsNewUser bool   `json:"is_new_user"`
}

package types

type BindFeishuReq struct {
	FeishuEmail string `json:"feishu_email"`
}

type BindFeishuResp struct {
	BaseResp
	Data User `json:"data,omitempty"`
}

type UnbindFeishuResp struct {
	BaseResp
	Data User `json:"data,omitempty"`
}

type SendFeishuTestCardResp struct {
	BaseResp
}

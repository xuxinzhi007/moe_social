package types

type AiProviderProfilesResp struct {
	BaseResp
	Data []map[string]interface{} `json:"data"`
}

type AiAgentsResp struct {
	BaseResp
	Data []map[string]interface{} `json:"data"`
}

type AiLorebooksResp struct {
	BaseResp
	Data []map[string]interface{} `json:"data"`
}

type AiResourceUpsertReq struct {
	Data map[string]interface{} `json:"data"`
}

type AiLorebookUpsertReq struct {
	Data    map[string]interface{}   `json:"data"`
	Entries []map[string]interface{} `json:"entries,optional"`
}

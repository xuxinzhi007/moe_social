package types

type AiUserConfigReq struct {
	ProviderProfiles []map[string]interface{} `json:"provider_profiles,optional"`
	Agents           []map[string]interface{} `json:"agents,optional"`
	Lorebooks        []map[string]interface{} `json:"lorebooks,optional"`
	UserPersona      string                   `json:"user_persona,optional"`
	HasUserPersona   bool                     `json:"has_user_persona,optional"`
	Preferences      map[string]interface{}   `json:"preferences,optional"`
}

type AiUserConfigData struct {
	ProviderProfiles []map[string]interface{} `json:"provider_profiles"`
	Agents           []map[string]interface{} `json:"agents"`
	Lorebooks        []map[string]interface{} `json:"lorebooks"`
	UserPersona      string                   `json:"user_persona"`
	Preferences      map[string]interface{}   `json:"preferences"`
}

type AiUserConfigResp struct {
	BaseResp
	Data AiUserConfigData `json:"data"`
}

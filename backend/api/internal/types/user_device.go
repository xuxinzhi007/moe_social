package types

type SyncUserDeviceReq struct {
	UserId      string `path:"user_id"`
	DeviceId    string `json:"device_id"`
	Platform    string `json:"platform,optional"`
	OSVersion   string `json:"os_version,optional"`
	AppVersion  string `json:"app_version,optional"`
	DeviceName  string `json:"device_name,optional"`
	LastSeen    string `json:"last_seen,optional"`
	PayloadJSON string `json:"payload_json,optional"`
}

type UserDeviceRecord struct {
	Id          string `json:"id"`
	UserId      string `json:"user_id"`
	DeviceId    string `json:"device_id"`
	Platform    string `json:"platform"`
	OSVersion   string `json:"os_version"`
	AppVersion  string `json:"app_version"`
	DeviceName  string `json:"device_name"`
	PayloadJSON string `json:"payload_json"`
	LastSeen    string `json:"last_seen"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at"`
}

type SyncUserDeviceResp struct {
	BaseResp
	Data UserDeviceRecord `json:"data"`
}

type ListUserDevicesReq struct {
	UserId string `path:"user_id"`
	Limit  int    `form:"limit,default=50"`
	Offset int    `form:"offset,default=0"`
}

type ListUserDevicesResp struct {
	BaseResp
	Data    []UserDeviceRecord `json:"data"`
	Total   int64              `json:"total"`
	Limit   int                `json:"limit"`
	Offset  int                `json:"offset"`
	HasMore bool               `json:"has_more"`
}

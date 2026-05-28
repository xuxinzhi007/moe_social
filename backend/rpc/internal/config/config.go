package config

// Config RPC 片段（rpc/etc/moe.yaml）；P5-D 不再嵌入 go-zero RpcServerConf。
type Config struct {
	Name    string `json:"Name" yaml:"Name"`
	ListenOn string `json:"ListenOn" yaml:"ListenOn"`
	Mode    string `json:"Mode" yaml:"Mode"` // dev | test | pro
	Timeout int64  `json:"Timeout" yaml:"Timeout"`
	// HandDrawRequireModeration 为 true 时，含手绘的帖子创建后为 pending，需在库或管理端改为 ok
	HandDrawRequireModeration bool `json:",optional" yaml:"HandDrawRequireModeration"`
}

func (c Config) DevOrTest() bool {
	m := c.Mode
	return m == "dev" || m == "test" || m == ""
}

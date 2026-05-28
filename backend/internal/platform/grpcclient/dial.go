// Package grpcclient 分体部署 API→RPC 连接（P5-D 替代 zrpc）。
package grpcclient

import (
	"fmt"
	"strings"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
)

// Conf 与 api/etc 中 SuperRpc 片段字段对齐。
type Conf struct {
	Endpoints []string `json:"Endpoints" yaml:"Endpoints"`
	Timeout   int64    `json:"Timeout" yaml:"Timeout"` // 毫秒
	NonBlock  bool     `json:"NonBlock" yaml:"NonBlock"`
}

// Dial 建立 insecure gRPC 连接（本机/内网 RPC）。
func Dial(c Conf) (*grpc.ClientConn, error) {
	ep := ""
	for _, e := range c.Endpoints {
		if s := strings.TrimSpace(e); s != "" {
			ep = s
			break
		}
	}
	if ep == "" {
		return nil, fmt.Errorf("grpcclient: no endpoints")
	}
	if !strings.Contains(ep, "://") {
		ep = "passthrough:///" + ep
	}
	opts := []grpc.DialOption{
		grpc.WithTransportCredentials(insecure.NewCredentials()),
	}
	if c.Timeout > 0 {
		opts = append(opts, grpc.WithIdleTimeout(time.Duration(c.Timeout)*time.Millisecond))
	}
	return grpc.NewClient(ep, opts...)
}

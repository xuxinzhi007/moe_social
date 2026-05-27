package moeconf

import (
	"testing"

	moeconfv1 "backend/internal/conf/moe/v1"
)

func TestMapViperToBootstrap_defaults(t *testing.T) {
	b := mapViperToBootstrap(nil)
	if b == nil || b.GetMoe() == nil {
		t.Fatal("expected bootstrap")
	}
}

func TestBootstrapProtoShape(t *testing.T) {
	b := &moeconfv1.Bootstrap{
		Server: &moeconfv1.PilotServer{GrpcAddr: ":19031", HttpAddr: ":19032"},
		Moe:    &moeconfv1.PilotMoe{KratosAdminHttpEnabled: true},
	}
	if b.GetServer().GetGrpcAddr() != ":19031" {
		t.Fatalf("grpc=%s", b.GetServer().GetGrpcAddr())
	}
	if !b.GetMoe().GetKratosAdminHttpEnabled() {
		t.Fatal("expected kratos enabled")
	}
}

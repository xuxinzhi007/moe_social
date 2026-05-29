// Package grpcsmoke documents and tests P4 domain gRPC smoke (notify / chat / vip).
package grpcsmoke

import (
	"context"
	"os"
	"testing"
	"time"

	chatv1 "backend/api/chat/v1"
	notifyv1 "backend/api/notify/v1"
	vipv1 "backend/api/vip/v1"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/status"
)

func grpcHost() string {
	if h := os.Getenv("GRPC_HOST"); h != "" {
		return h
	}
	return "127.0.0.1:8080"
}

func smokeUserID() string {
	if id := os.Getenv("SMOKE_USER_ID"); id != "" {
		return id
	}
	return "1"
}

func dial(t *testing.T) *grpc.ClientConn {
	t.Helper()
	if os.Getenv("GRPC_SMOKE") != "1" {
		t.Skip("set GRPC_SMOKE=1 with a running RPC server (make moe-social)")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	conn, err := grpc.DialContext(ctx, grpcHost(),
		grpc.WithTransportCredentials(insecure.NewCredentials()),
		grpc.WithBlock(),
	)
	if err != nil {
		t.Fatalf("dial %s: %v", grpcHost(), err)
	}
	t.Cleanup(func() { _ = conn.Close() })
	return conn
}

func TestNotifyGetNotifications(t *testing.T) {
	conn := dial(t)
	client := notifyv1.NewNotifyServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err := client.GetNotifications(ctx, &notifyv1.GetNotificationsRequest{
		UserId:   smokeUserID(),
		Page:     1,
		PageSize: 5,
	})
	if err != nil {
		t.Fatalf("GetNotifications: %v", err)
	}
}

func TestNotifyGetUnreadCount(t *testing.T) {
	conn := dial(t)
	client := notifyv1.NewNotifyServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	resp, err := client.GetUnreadCount(ctx, &notifyv1.GetUnreadCountRequest{UserId: smokeUserID()})
	if err != nil {
		t.Fatalf("GetUnreadCount: %v", err)
	}
	if resp.GetCount() < 0 {
		t.Fatalf("unexpected count: %d", resp.GetCount())
	}
}

func TestChatListPrivateConversations(t *testing.T) {
	conn := dial(t)
	client := chatv1.NewPrivateMessageServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err := client.ListPrivateConversations(ctx, &chatv1.ListPrivateConversationsRequest{
		ViewerId: smokeUserID(),
		Limit:    10,
		Offset:   0,
	})
	if err != nil {
		t.Fatalf("ListPrivateConversations: %v", err)
	}
}

func TestVipGetVipRecords(t *testing.T) {
	conn := dial(t)
	client := vipv1.NewVipServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err := client.GetVipRecords(ctx, &vipv1.GetVipRecordsReq{
		UserId:   smokeUserID(),
		Page:     1,
		PageSize: 5,
	})
	if err != nil {
		t.Fatalf("GetVipRecords: %v", err)
	}
}

func TestVipGetUserActiveVipRecord(t *testing.T) {
	conn := dial(t)
	client := vipv1.NewVipServiceClient(conn)
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	_, err := client.GetUserActiveVipRecord(ctx, &vipv1.GetUserActiveVipRecordReq{UserId: smokeUserID()})
	if err != nil && !isNoActiveVip(err) {
		t.Fatalf("GetUserActiveVipRecord: %v", err)
	}
}

func isNoActiveVip(err error) bool {
	st, ok := status.FromError(err)
	if !ok {
		return false
	}
	return st.Code() == codes.Unknown && st.Message() == "no active vip record"
}

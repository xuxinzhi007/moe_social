package transport

import (
	chatbiz "backend/internal/biz/chat"
	moeadmin "backend/internal/service/moe"
)

type Deps struct {
	MoeAdmin *moeadmin.AdminService
	ChatWS   chatbiz.ChatWSDeps
}

func (d Deps) Valid() bool {
	return d.MoeAdmin != nil || d.ChatWS.PM != nil || d.ChatWS.Delivery.UserReader != nil || d.ChatWS.Delivery.NotifyStore != nil || d.ChatWS.Delivery.NotifyRPC != nil
}

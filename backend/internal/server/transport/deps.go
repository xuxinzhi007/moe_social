package transport

import (
	chatbiz "backend/internal/biz/chat"
	lifeapp "backend/internal/service/life"
	moeadmin "backend/internal/service/moe"
)

type Deps struct {
	MoeAdmin *moeadmin.AdminService
	ChatWS   chatbiz.ChatWSDeps
	LifeApp  *lifeapp.AppService
}

func (d Deps) Valid() bool {
	return d.MoeAdmin != nil || d.ChatWS.PM != nil || d.ChatWS.Delivery.UserReader != nil || d.ChatWS.Delivery.NotifyStore != nil || d.ChatWS.Delivery.NotifyRPC != nil
}

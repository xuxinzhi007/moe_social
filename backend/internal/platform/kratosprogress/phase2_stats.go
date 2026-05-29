package kratosprogress

import "backend/internal/platform/moeimportcount"

// BizMoeImportFileCount counts .go files under internal/biz importing rpc/pb/moe.
func BizMoeImportFileCount() int {
	return moeimportcount.BizMoeImportFileCount()
}

// ApilegacyMoeImportFileCount counts .go files under internal/apilegacy importing rpc/pb/moe.
func ApilegacyMoeImportFileCount() int {
	return moeimportcount.ApilegacyMoeImportFileCount()
}

// Phase2BridgeRetiredPercent is 100 when both biz and apilegacy moe import counts are 0.
func Phase2BridgeRetiredPercent() int {
	return moeimportcount.Phase2BridgeRetiredPercent()
}

// RpcMoePbRetiredPercent is 100 when runtime code no longer imports rpc/pb/moe.
func RpcMoePbRetiredPercent() int {
	return moeimportcount.RpcMoePbRetiredPercent()
}

// RuntimeMoePbImportFileCount returns runtime rpc/pb/moe import file count.
func RuntimeMoePbImportFileCount() int {
	return moeimportcount.RuntimeMoePbImportFileCount()
}

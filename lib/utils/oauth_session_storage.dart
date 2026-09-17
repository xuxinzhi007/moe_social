// OAuth 待处理事务的 Web 落地存储（sessionStorage）。
//
// 用 sessionStorage 而不是 localStorage：授权要跳到供应商站点再跳回来，
// 事务必须活过这次导航；但它又只该属于「发起授权的那个标签页」。
// localStorage 会跨标签页共享，另一个标签页里上一次没走完的授权
// 就可能被这次回调认领 —— 那正是 state 绑定要防的事。
export 'oauth_session_storage_stub.dart'
    if (dart.library.html) 'oauth_session_storage_web.dart';

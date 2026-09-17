// Package prototest 校验 proto service 的每个 RPC 都被 HTTP 适配层真正覆盖了。
// 只供 _test.go 使用。
package prototest

import (
	"context"
	"errors"
	"reflect"
	"sort"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// AssertRPCsAdapted 逐个反射调用 srv 上与 stub 同名的 RPC 方法，确认没有一个落回
// 嵌入的 Unimplemented* 桩。
//
// 为什么需要这个检查：漏写适配方法在编译期完全不报错。嵌入桩会顶上，
// 路由照常注册、请求照常匹配、鉴权照常通过，线上只是永远回 501 —— 静态读代码
// 和 grep 都很难发现，只有真的打一次请求才暴露。
//
// 判据是「用一个依赖为 nil 的 srv 调用后拿到什么错」：
//   - 落回桩 → codes.Unimplemented
//   - 被覆盖 → 适配层自己的前置校验错误（依赖未初始化、未登录等）
//
// wantErr 非 nil 时额外断言错误就是它，用来确认调用确实走到了适配层的第一道校验，
// 而不是碰巧被别的东西挡住。传 nil 则只断言「不是 Unimplemented」。
//
// pendingDeletion 里的方法名允许仍是 Unimplemented —— 用于已判定为死接口、
// 等着从 proto 里删掉的那些。
//
// 但登记项**不会自动失效**：真把 RPC 从 proto 删掉之后必须回来把名字一起删掉，
// 否则测试会在末尾报「登记项已失效」。早先这里是静默忽略未命中的登记项的，
// 于是一份陈旧白名单可以无限期地堆下去，每多一条就多一个「将来某个 RPC 悄悄退回
// 501 也没人发现」的口子 —— 白名单越长门禁越松，而且没有任何信号提示该收尾了。
func AssertRPCsAdapted(t *testing.T, srv, stub any, wantErr error, pendingDeletion ...string) {
	t.Helper()

	pending := make(map[string]bool, len(pendingDeletion))
	for _, name := range pendingDeletion {
		pending[name] = true
	}

	srvValue := reflect.ValueOf(srv)
	srvType := srvValue.Type()
	stubType := reflect.TypeOf(stub)
	if stubType.Kind() == reflect.Pointer {
		stubType = stubType.Elem()
	}

	checked, skipped := 0, 0
	for i := 0; i < stubType.NumMethod(); i++ {
		name := stubType.Method(i).Name

		method, ok := srvType.MethodByName(name)
		if !ok {
			t.Errorf("%s: %s 上找不到该方法", name, srvType)
			continue
		}
		// 形状必须是 (recv, ctx, req) → (reply, error)，否则反射调用不适用。
		if method.Type.NumIn() != 3 || method.Type.NumOut() != 2 {
			t.Fatalf("%s: 方法形状不是 (ctx, req) → (reply, error)，无法反射调用", name)
		}
		reqType := method.Type.In(2)
		if reqType.Kind() != reflect.Pointer || reqType.Elem().Kind() != reflect.Struct {
			t.Fatalf("%s: 请求类型 %s 不是结构体指针", name, reqType)
		}

		out, panicked := callRPC(method.Func, srvValue, reqType)
		if panicked != nil {
			// 桩本身永远不会 panic，所以能 panic 就说明方法确实被覆盖了。
			// 依赖为 nil 只是本轮扫描的构造方式（http_proto.go 的注册都有非 nil 守卫），
			// 生产不会走到，所以记日志而不是判失败。
			checked++
			t.Logf("%s: 依赖为 nil 时 panic，确认已覆盖（nil 依赖仅为扫描构造，生产不传）", name)
			continue
		}

		var err error
		if v := out.Interface(); v != nil {
			err = v.(error)
		}

		if status.Code(err) == codes.Unimplemented {
			if pending[name] {
				pending[name] = false
				skipped++
				t.Logf("%s: 仍是 Unimplemented，已登记为待删死接口", name)
				continue
			}
			t.Errorf("%s: 没有适配方法，线上会永远回 501 Unimplemented（err=%v）", name, err)
			continue
		}

		checked++
		if wantErr != nil && !errors.Is(err, wantErr) {
			t.Errorf("%s: 期望在适配层前置校验处返回 %v，实际 %v", name, wantErr, err)
		}
	}

	if checked == 0 {
		t.Fatalf("一个 RPC 都没核对到（stub=%s），这个测试是空转的", stubType)
	}

	var stale []string
	for name, unconsumed := range pending {
		if unconsumed {
			stale = append(stale, name)
		}
	}
	if len(stale) > 0 {
		sort.Strings(stale)
		t.Errorf("待删登记项已失效（stub=%s，这些方法已不在 proto 里）：%v —— 请把它们从登记表中删掉，"+
			"留着的白名单只会让门禁越来越松", stubType, stale)
	}

	t.Logf("已核对 %d 个 RPC 适配方法，跳过 %d 个待删死接口", checked, skipped)
}

// callRPC 用零值请求反射调用一个 RPC 方法，并兜住 panic，
// 免得某个「依赖为 nil 就解引用」的适配方法把整轮扫描打断。
// 返回方法的 error 返回值与 recover 到的 panic（正常返回时为 nil）。
func callRPC(fn, srv reflect.Value, reqType reflect.Type) (errValue reflect.Value, panicked any) {
	defer func() {
		if r := recover(); r != nil {
			panicked = r
		}
	}()
	out := fn.Call([]reflect.Value{
		srv,
		reflect.ValueOf(context.Background()),
		reflect.New(reqType.Elem()),
	})
	return out[1], nil
}

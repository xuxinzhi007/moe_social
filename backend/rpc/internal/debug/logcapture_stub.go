//go:build !hybrid

package debug

// InstallLogCapture 纯 Kratos 构建不挂接 go-zero logx（见 logcapture.go hybrid）。
func InstallLogCapture() {}

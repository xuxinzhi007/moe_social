package utils

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"

	"github.com/spf13/viper"
)

// TryEnsureFeishuDirectoryUser 尝试将用户加入飞书通讯录（需管理员权限与 department_id）。
// 若用户已在企业内或权限不足，仅记录错误，不阻断登录。
func TryEnsureFeishuDirectoryUser(ctx context.Context, name, email string) error {
	if !viper.GetBool("feishu.auto_add_to_directory") {
		return nil
	}
	email = strings.TrimSpace(email)
	if email == "" {
		return nil
	}
	deptID := strings.TrimSpace(viper.GetString("feishu.default_department_id"))
	if deptID == "" {
		return fmt.Errorf("feishu.default_department_id is empty")
	}
	appID := strings.TrimSpace(viper.GetString("feishu.app_id"))
	appSecret := strings.TrimSpace(viper.GetString("feishu.app_secret"))
	token, err := getFeishuTenantAccessToken(ctx, appID, appSecret)
	if err != nil {
		return err
	}
	displayName := strings.TrimSpace(name)
	if displayName == "" {
		displayName = strings.Split(email, "@")[0]
	}
	body := map[string]interface{}{
		"user": map[string]interface{}{
			"name":           displayName,
			"email":          email,
			"department_ids": []string{deptID},
			"employee_type":  1,
		},
	}
	raw, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, feishuAPIBase+"/contact/v3/users", bytes.NewReader(raw))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)

	resp, err := NewHTTPClient(10).Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	var parsed struct {
		Code int    `json:"code"`
		Msg  string `json:"msg"`
	}
	_ = json.Unmarshal(respBody, &parsed)
	if parsed.Code == 0 {
		return nil
	}
	// 已在通讯录等场景视为可忽略
	msg := strings.ToLower(parsed.Msg)
	if strings.Contains(msg, "exist") || strings.Contains(msg, "已存在") || parsed.Code == 41050 {
		return nil
	}
	return fmt.Errorf("feishu contact create code=%d msg=%s", parsed.Code, parsed.Msg)
}

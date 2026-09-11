package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"backend/pkg/conf"

	"gopkg.in/yaml.v3"
)

// RuntimeConfigView 供 Moe Admin 展示/编辑的非敏感运行时配置。
type RuntimeConfigView struct {
	PublicApiBaseUrl   string `json:"public_api_base_url"`
	ApiPublicBaseUrl   string `json:"api_public_base_url"`
	ImagePublicBaseUrl string `json:"image_public_base_url"`
	ImageLocalDir      string `json:"image_local_dir"`
	ImageMaxBytes      int64  `json:"image_max_bytes"`
	ConfigFile         string `json:"config_file"`
}

// RuntimeConfigPatch 按字段增量更新 config.yaml。
type RuntimeConfigPatch struct {
	PublicApiBaseUrl   *string
	ApiPublicBaseUrl   *string
	ImagePublicBaseUrl *string
	ImageLocalDir      *string
	ImageMaxBytes      *int64
}

// resolveUnifiedConfigPath 返回要写回的配置文件路径。
//
// 必须以 conf.Path() 为准。进程可能用 -f 指定了任意路径，而写回若自己按 cwd 去猜
// ./config/config.yaml，就会写到**另一个**文件，随后 conf.LoadFile 又把整个进程的配置源
// 劫持过去。那样读路径（ReadRuntimeConfig 走 conf.Reload → current.path）尊重 -f、
// 写路径不尊重，两条路径对「哪个文件是权威」的答案不一致 —— 而 -f 是进程级唯一权威。
// 三候选只在 conf 尚未成功加载时兜底（例如配置文件本身损坏）。
func resolveUnifiedConfigPath() (string, error) {
	if p := conf.Path(); p != "" {
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	candidates := []string{
		"./config/config.yaml",
		"../config/config.yaml",
		"../../config/config.yaml",
	}
	for _, p := range candidates {
		if _, err := os.Stat(p); err == nil {
			abs, err := filepath.Abs(p)
			if err != nil {
				return p, nil
			}
			return abs, nil
		}
	}
	return "", fmt.Errorf("未找到 backend/config/config.yaml")
}

// yamlEdit 是一处定点改值：key 是 config.yaml 里的蛇形点路径，value 是 string 或 int64。
type yamlEdit struct {
	key   string
	value any
}

// patchYAMLFile 在原始字节上做行内替换，除被改的那几行外文件逐字节不变。
//
// 两种「重新序列化整个文件」的写法都不可接受，均已在真实 backend/config/config.yaml 上实测：
//   - viper.Set + WriteConfig：10073→4416 字节、265→154 行、**79 行注释→0 行注释**，
//     并把 memory.search 的 3 个 float 静默降级成 int；
//   - yaml.Marshal(&node)：注释保住了，但缩进从 2 空格变 4 空格、空行全删、行内注释前的
//     两个空格压成一个 —— 418 行 diff。
//
// 管理台点一次「保存」就会把上面任意一种破坏落进一个被 git 跟踪的文件，抹掉本地地址备选
// （:133）、CDN 回退语义（:164）这类只存在于注释里的运维知识。所以这里只用 yaml.Node 取
// 目标节点的行列号，其余全靠原文；落盘前再把候选内容整体重解析并逐键校验，
// 任何一步不成立就返错不写 —— 宁可失败也不写坏文件。
func patchYAMLFile(path string, edits []yamlEdit) error {
	if len(edits) == 0 {
		return nil
	}
	raw, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("读取配置失败: %w", err)
	}
	root, err := parseYAMLDoc(raw, path)
	if err != nil {
		return err
	}
	before := leafValues(root)

	lines := strings.Split(string(raw), "\n")
	expect := make(map[string]string, len(edits))
	for _, e := range edits {
		text, err := renderScalar(e.value)
		if err != nil {
			return fmt.Errorf("配置键 %s: %w", e.key, err)
		}
		if err := editValueLine(lines, root, e.key, text); err != nil {
			return err
		}
		expect[e.key] = decodedForm(e.value)
	}

	candidate := strings.Join(lines, "\n")
	after, err := parseYAMLDoc([]byte(candidate), path)
	if err != nil {
		return fmt.Errorf("改值后文档不再合法（已放弃写入）: %w", err)
	}
	afterVals := leafValues(after)
	if len(afterVals) != len(before) {
		return fmt.Errorf("改值后叶子键数 %d → %d（已放弃写入）", len(before), len(afterVals))
	}
	for k, want := range expect {
		if got := afterVals[k]; got != want {
			return fmt.Errorf("配置键 %s 未生效：读到 %q, want %q（已放弃写入）", k, got, want)
		}
	}
	for k, want := range before {
		if _, edited := expect[k]; edited {
			continue
		}
		if got := afterVals[k]; got != want {
			return fmt.Errorf("非目标键 %s 被意外改动：%q → %q（已放弃写入）", k, want, got)
		}
	}
	if got, want := len(strings.Split(candidate, "\n")), len(lines); got != want {
		return fmt.Errorf("行数 %d → %d（已放弃写入）", want, got)
	}

	// 沿用原文件权限：config.yaml 含数据库口令与第三方密钥，不能顺手放宽。
	perm := os.FileMode(0o600)
	if fi, err := os.Stat(path); err == nil {
		perm = fi.Mode().Perm()
	}
	if err := os.WriteFile(path, []byte(candidate), perm); err != nil {
		return fmt.Errorf("写入配置失败: %w", err)
	}
	return nil
}

func parseYAMLDoc(raw []byte, path string) (*yaml.Node, error) {
	var doc yaml.Node
	if err := yaml.Unmarshal(raw, &doc); err != nil {
		return nil, fmt.Errorf("解析 %s 失败: %w", path, err)
	}
	if doc.Kind != yaml.DocumentNode || len(doc.Content) == 0 || doc.Content[0].Kind != yaml.MappingNode {
		return nil, fmt.Errorf("%s 不是有效的 YAML 映射文档", path)
	}
	return doc.Content[0], nil
}

// editValueLine 只重写 key 所在的那一行，保留行首缩进、键名、冒号后的空格，
// 以及值后面的行内注释与其原始间距。
func editValueLine(lines []string, root *yaml.Node, key, text string) error {
	node, err := locateYAMLNode(root, key, strings.Split(key, "."))
	if err != nil {
		return err
	}
	if node.Kind != yaml.ScalarNode {
		return fmt.Errorf("配置键 %s 不是标量，无法定点改值", key)
	}
	switch node.Style {
	case yaml.LiteralStyle, yaml.FoldedStyle, yaml.FlowStyle:
		return fmt.Errorf("配置键 %s 是块/流式标量，无法定点改值", key)
	}
	idx, col := node.Line-1, node.Column-1
	if idx < 0 || idx >= len(lines) {
		return fmt.Errorf("配置键 %s 的行号 %d 超出文件范围", key, node.Line)
	}
	line := lines[idx]
	if col < 0 || col > len(line) {
		return fmt.Errorf("配置键 %s 的列号 %d 超出该行范围", key, node.Column)
	}
	prefix, rest := line[:col], line[col:]

	// 值后面的部分（行内注释及其原始间距、CRLF 文件里的 \r）原样接回。
	suffix := ""
	if node.LineComment != "" {
		ci := strings.LastIndex(rest, node.LineComment)
		if ci < 0 {
			return fmt.Errorf("配置键 %s 的行内注释在该行里定位不到", key)
		}
		head := rest[:ci]
		trimmed := strings.TrimRight(head, " \t")
		suffix = head[len(trimmed):] + rest[ci:]
	} else if i := strings.IndexByte(rest, '\r'); i >= 0 {
		suffix = rest[i:]
	}

	lines[idx] = prefix + text + suffix
	return nil
}

// locateYAMLNode 沿点路径下钻，返回值节点。键不存在即报错：
// 按行追加需要猜父块的缩进与结束位置，风险高于「让运维手工加一行」。
// full 始终是调用方给的完整点路径 —— 递归里的剩余路径拼出来的错误信息会丢掉段名，
// 运维看到「不存在键 max_bytes」根本不知道是哪一段。
func locateYAMLNode(node *yaml.Node, full string, path []string) (*yaml.Node, error) {
	if node.Kind != yaml.MappingNode {
		return nil, fmt.Errorf("配置键 %s 的父节点不是映射", full)
	}
	for i := 0; i+1 < len(node.Content); i += 2 {
		if node.Content[i].Value != path[0] {
			continue
		}
		v := node.Content[i+1]
		if len(path) == 1 {
			return v, nil
		}
		return locateYAMLNode(v, full, path[1:])
	}
	return nil, fmt.Errorf("配置文件里不存在键 %s；请先手工加上这一行再用管理台改它", full)
}

// renderScalar 生成替换文本。字符串一律双引号：转义规则确定，不会因值里含 ": " 或 "#"
// 而改变文档结构。只有被改的那几行会因此带上引号，语义与 plain 完全一致。
func renderScalar(value any) (string, error) {
	switch val := value.(type) {
	case string:
		var b strings.Builder
		b.WriteByte('"')
		for _, r := range val {
			switch r {
			case '"':
				b.WriteString(`\"`)
			case '\\':
				b.WriteString(`\\`)
			case '\n':
				b.WriteString(`\n`)
			case '\t':
				b.WriteString(`\t`)
			default:
				if r < 0x20 {
					return "", fmt.Errorf("值含控制字符 %q，拒绝写入", r)
				}
				b.WriteRune(r)
			}
		}
		b.WriteByte('"')
		return b.String(), nil
	case int64:
		return strconv.FormatInt(val, 10), nil
	default:
		return "", fmt.Errorf("不支持的类型 %T", value)
	}
}

// decodedForm 是值被 YAML 解析回来后的比较形态，与 leafValues 的输出对齐。
func decodedForm(value any) string {
	switch val := value.(type) {
	case string:
		return val
	case int64:
		return strconv.FormatInt(val, 10)
	default:
		return fmt.Sprintf("%v", value)
	}
}

// leafValues 把文档展开成「点路径/列表下标 → 标量文本」，供写前写后逐键比对。
func leafValues(node *yaml.Node) map[string]string {
	out := map[string]string{}
	var walk func(prefix string, n *yaml.Node)
	walk = func(prefix string, n *yaml.Node) {
		switch n.Kind {
		case yaml.MappingNode:
			for i := 0; i+1 < len(n.Content); i += 2 {
				key := n.Content[i].Value
				if prefix != "" {
					key = prefix + "." + key
				}
				walk(key, n.Content[i+1])
			}
		case yaml.SequenceNode:
			for i, item := range n.Content {
				walk(fmt.Sprintf("%s[%d]", prefix, i), item)
			}
		case yaml.DocumentNode:
			for _, c := range n.Content {
				walk(prefix, c)
			}
		default:
			out[prefix] = n.Value
		}
	}
	walk("", node)
	return out
}

func trimURL(u string) string {
	u = strings.TrimSpace(u)
	for strings.HasSuffix(u, "/") {
		u = strings.TrimSuffix(u, "/")
	}
	return u
}

// ReadRuntimeConfig 读取统一 config.yaml 中的 App/图片相关配置。
// 用 Reload 而不是 Get：这个视图要反映磁盘上的当前值，包括运维手改文件的情况
// （迁移前每次都新开一个 viper 读盘，语义等价；管理台是低频端点，读盘开销可接受）。
func ReadRuntimeConfig() (RuntimeConfigView, error) {
	cfg, err := conf.Reload()
	if err != nil {
		return RuntimeConfigView{}, err
	}
	return RuntimeConfigView{
		PublicApiBaseUrl:   trimURL(cfg.AppClient.PublicAPIBaseURL),
		ApiPublicBaseUrl:   trimURL(cfg.API.PublicBaseURL),
		ImagePublicBaseUrl: trimURL(cfg.Image.PublicBaseURL),
		ImageLocalDir:      strings.TrimSpace(cfg.Image.LocalDir),
		ImageMaxBytes:      cfg.Image.MaxBytes,
		ConfigFile:         conf.Path(),
	}, nil
}

// ApplyRuntimeConfigPatch 写入 config.yaml 并返回最新视图。
func ApplyRuntimeConfigPatch(patch RuntimeConfigPatch) (RuntimeConfigView, error) {
	path, err := resolveUnifiedConfigPath()
	if err != nil {
		return RuntimeConfigView{}, err
	}
	// 键名必须是 config.yaml 实际使用的蛇形键；写成 Image.PublicBaseUrl 会被小写化为
	// 无下划线的 publicbaseurl 死键，运行时优先读 public_base_url，改动静默丢失。
	var edits []yamlEdit
	if patch.PublicApiBaseUrl != nil {
		edits = append(edits, yamlEdit{"app_client.public_api_base_url", trimURL(*patch.PublicApiBaseUrl)})
	}
	if patch.ApiPublicBaseUrl != nil {
		edits = append(edits, yamlEdit{"api.public_base_url", trimURL(*patch.ApiPublicBaseUrl)})
	}
	if patch.ImagePublicBaseUrl != nil {
		edits = append(edits, yamlEdit{"image.public_base_url", trimURL(*patch.ImagePublicBaseUrl)})
	}
	if patch.ImageLocalDir != nil {
		edits = append(edits, yamlEdit{"image.local_dir", strings.TrimSpace(*patch.ImageLocalDir)})
	}
	if patch.ImageMaxBytes != nil {
		edits = append(edits, yamlEdit{"image.max_bytes", *patch.ImageMaxBytes})
	}
	// 一处没改就不落盘：旧实现即便空 patch 也会 WriteConfig，白抹一遍全文注释。
	if len(edits) > 0 {
		if err := patchYAMLFile(path, edits); err != nil {
			return RuntimeConfigView{}, err
		}
		// pkg/conf 没有 setter，写完必须让进程内的缓存指向刚写的文件，
		// 否则其余读者到重启前都看不到本次改动 —— load.go 的 Reload 注释就是这条要求。
		if _, err := conf.LoadFile(path); err != nil {
			return RuntimeConfigView{}, fmt.Errorf("重载配置失败: %w", err)
		}
	}
	view, err := ReadRuntimeConfig()
	if err != nil {
		return RuntimeConfigView{}, err
	}
	view.ConfigFile = path
	return view, nil
}

package mediabiz

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strings"
	"time"
)

// qiniuS3Endpoint 返回七牛 Kodo 各区域的官方 AWS S3 兼容源站域名（永久有效，无需备案自定义域名）。
// 参考：https://developer-doc.qiniu.com/products/kodo/development-guidelines/aws-s3-compatible/0-s3-access-domainname
func qiniuS3RegionAndHost(region string) (s3Region, s3Host string) {
	switch strings.ToLower(strings.TrimSpace(region)) {
	case "z0", "huadong", "cn-east-1":
		return "cn-east-1", "s3.cn-east-1.qiniucs.com"
	case "cn-east-2":
		return "cn-east-2", "s3.cn-east-2.qiniucs.com"
	case "z1", "huabei", "cn-north-1":
		return "cn-north-1", "s3.cn-north-1.qiniucs.com"
	case "na0", "beimei", "us-north-1":
		return "us-north-1", "s3.us-north-1.qiniucs.com"
	case "as0", "xinjiapo", "ap-southeast-1":
		return "ap-southeast-1", "s3.ap-southeast-1.qiniucs.com"
	case "", "z2", "huanan", "cn-south-1":
		fallthrough
	default:
		return "cn-south-1", "s3.cn-south-1.qiniucs.com"
	}
}

// signQiniuS3GetRequest 为七牛 S3 兼容接口构造带 AWS Signature V4 的 GET 请求。
// 当七牛 30 天测试域名（*.clouddn.com）被回收且未绑定自定义备案域名时，
// 服务端可通过该官方 S3 源站域名直接流式读取桶内对象。
func signQiniuS3GetRequest(
	req *http.Request,
	accessKey, secretKey, region string,
	now time.Time,
) {
	s3Region, _ := qiniuS3RegionAndHost(region)
	utc := now.UTC()
	amzDate := utc.Format("20060102T150405Z")
	dateStamp := utc.Format("20060102")
	payloadHash := "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" // SHA256("")

	req.Header.Set("Host", req.URL.Host)
	req.Header.Set("x-amz-date", amzDate)
	req.Header.Set("x-amz-content-sha256", payloadHash)

	canonicalURI := canonicalS3Path(req.URL.Path)
	canonicalQuery := canonicalS3Query(req.URL.Query())
	canonicalHeaders := fmt.Sprintf(
		"host:%s\nx-amz-content-sha256:%s\nx-amz-date:%s\n",
		req.URL.Host,
		payloadHash,
		amzDate,
	)
	signedHeaders := "host;x-amz-content-sha256;x-amz-date"

	canonicalRequest := strings.Join([]string{
		req.Method,
		canonicalURI,
		canonicalQuery,
		canonicalHeaders,
		signedHeaders,
		payloadHash,
	}, "\n")

	credentialScope := fmt.Sprintf("%s/%s/s3/aws4_request", dateStamp, s3Region)
	stringToSign := strings.Join([]string{
		"AWS4-HMAC-SHA256",
		amzDate,
		credentialScope,
		sha256Hex([]byte(canonicalRequest)),
	}, "\n")

	kDate := hmacSHA256([]byte("AWS4"+secretKey), dateStamp)
	kRegion := hmacSHA256(kDate, s3Region)
	kService := hmacSHA256(kRegion, "s3")
	kSigning := hmacSHA256(kService, "aws4_request")
	signature := hex.EncodeToString(hmacSHA256(kSigning, stringToSign))

	authHeader := fmt.Sprintf(
		"AWS4-HMAC-SHA256 Credential=%s/%s, SignedHeaders=%s, Signature=%s",
		accessKey,
		credentialScope,
		signedHeaders,
		signature,
	)
	req.Header.Set("Authorization", authHeader)
}

func canonicalS3Path(rawPath string) string {
	if rawPath == "" {
		return "/"
	}
	parts := strings.Split(rawPath, "/")
	encoded := make([]string, len(parts))
	for i, p := range parts {
		encoded[i] = awsURIEncode(p)
	}
	res := strings.Join(encoded, "/")
	if !strings.HasPrefix(res, "/") {
		res = "/" + res
	}
	return res
}

func canonicalS3Query(q url.Values) string {
	if len(q) == 0 {
		return ""
	}
	keys := make([]string, 0, len(q))
	for k := range q {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	var pairs []string
	for _, k := range keys {
		vals := q[k]
		sort.Strings(vals)
		for _, v := range vals {
			pairs = append(pairs, awsURIEncode(k)+"="+awsURIEncode(v))
		}
	}
	return strings.Join(pairs, "&")
}

func awsURIEncode(s string) string {
	var buf strings.Builder
	for i := 0; i < len(s); i++ {
		b := s[i]
		if (b >= 'A' && b <= 'Z') ||
			(b >= 'a' && b <= 'z') ||
			(b >= '0' && b <= '9') ||
			b == '-' || b == '_' || b == '.' || b == '~' {
			buf.WriteByte(b)
		} else {
			fmt.Fprintf(&buf, "%%%02X", b)
		}
	}
	return buf.String()
}

func hmacSHA256(key []byte, data string) []byte {
	h := hmac.New(sha256.New, key)
	h.Write([]byte(data))
	return h.Sum(nil)
}

func sha256Hex(data []byte) string {
	sum := sha256.Sum256(data)
	return hex.EncodeToString(sum[:])
}

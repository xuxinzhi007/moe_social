package mediabiz

import (
	"net/http"
	"strings"
	"testing"
	"time"
)

func TestNewBlobStoreQiniuIncomplete(t *testing.T) {
	_, err := NewBlobStore(ImageConfig{Driver: DriverQiniu, Qiniu: QiniuConfig{Bucket: "moe-image"}})
	if err == nil {
		t.Fatal("missing qiniu credentials should fail")
	}
}

func TestQiniuPrivateDownloadSignsAndProxies(t *testing.T) {
	store, err := newQiniuBlobStore(ImageConfig{Qiniu: QiniuConfig{
		AccessKey:   "test-access-key",
		SecretKey:   "test-secret-key",
		Bucket:      "moe-image",
		CDNDomain:   "tm6hu0nnn.hn-bkt.clouddn.com",
		Region:      "z2",
		Prefix:      "media",
		Private:     true,
		ProxyViaAPI: false,
	}})
	if err != nil {
		t.Fatal(err)
	}
	if !store.proxyViaAPI {
		t.Fatal("private bucket must be served by the API")
	}
	if store.cdnDomain != "http://tm6hu0nnn.hn-bkt.clouddn.com" {
		t.Fatalf("cdn domain = %q", store.cdnDomain)
	}
	got := store.downloadURL("media/1_user/photo.png")
	if !strings.Contains(got, "http://tm6hu0nnn.hn-bkt.clouddn.com/") || !strings.Contains(got, "token=") {
		t.Fatalf("signed url = %q", got)
	}
}

func TestQiniuPublicDownloadHasNoToken(t *testing.T) {
	store, err := newQiniuBlobStore(ImageConfig{Qiniu: QiniuConfig{
		AccessKey: "test-access-key",
		SecretKey: "test-secret-key",
		Bucket:    "moe-image",
		CDNDomain: "https://cdn.example.com/",
		Private:   false,
	}})
	if err != nil {
		t.Fatal(err)
	}
	if store.proxyViaAPI {
		t.Fatal("public bucket should redirect")
	}
	got := store.downloadURL("media/1_user/photo.png")
	if strings.Contains(got, "token=") || !strings.HasPrefix(got, "https://cdn.example.com/") {
		t.Fatalf("public url = %q", got)
	}
}

func TestQiniuDirMarkers(t *testing.T) {
	got := qiniuDirMarkers("media/1_xxz/post/a.png")
	want := []string{"media/", "media/1_xxz/", "media/1_xxz/post/"}
	if len(got) != len(want) {
		t.Fatalf("markers = %#v", got)
	}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("markers = %#v", got)
		}
	}
}

func TestQiniuZoneRejectsUnknown(t *testing.T) {
	_, err := qiniuZone("mars")
	if err == nil {
		t.Fatal("unknown region should fail")
	}
}

func TestQiniuS3SignatureWhenTestDomainReclaimed(t *testing.T) {
	s3Region, s3Host := qiniuS3RegionAndHost("z2")
	if s3Region != "cn-south-1" || s3Host != "s3.cn-south-1.qiniucs.com" {
		t.Fatalf("unexpected z2 s3 endpoint: %s %s", s3Region, s3Host)
	}
	req, err := http.NewRequest(
		http.MethodGet,
		"https://"+s3Host+"/moe-image/media/1_xxz/gen/1_gen.png",
		nil,
	)
	if err != nil {
		t.Fatal(err)
	}
	signQiniuS3GetRequest(
		req,
		"test-ak",
		"test-sk",
		"z2",
		time.Date(2026, 10, 31, 0, 0, 0, 0, time.UTC),
	)
	auth := req.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "AWS4-HMAC-SHA256 Credential=test-ak/20261031/cn-south-1/s3/aws4_request") {
		t.Fatalf("unexpected Authorization header: %q", auth)
	}
}


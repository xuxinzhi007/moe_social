package mediabiz

import (
	"strings"
	"testing"
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

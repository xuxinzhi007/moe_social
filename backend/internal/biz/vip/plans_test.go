package vipbiz

import (
	"testing"
)

func TestListPlansFilter_defaults(t *testing.T) {
	f := ListPlansFilter{}
	if f.Page != 0 || f.PageSize != 0 {
		t.Fatalf("zero value filter ok")
	}
}

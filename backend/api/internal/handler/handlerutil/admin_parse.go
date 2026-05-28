//go:build hybrid

package handlerutil

import (
	"strconv"
	"strings"
)

// ParseAdminPathID parses a path/query ID string as uint64.
func ParseAdminPathID(raw string) (uint64, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return 0, strconv.ErrSyntax
	}
	return strconv.ParseUint(raw, 10, 64)
}

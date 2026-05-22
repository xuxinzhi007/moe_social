package runner

import (
	"io"
	"runtime"

	"golang.org/x/text/encoding/simplifiedchinese"
	"golang.org/x/text/transform"
)

// commandOutputReader decodes child process stdout/stderr on Windows (often GBK).
func commandOutputReader(r io.Reader) io.Reader {
	if runtime.GOOS != "windows" || useGitBashOnWindows() {
		return r
	}
	return transform.NewReader(r, simplifiedchinese.GBK.NewDecoder())
}

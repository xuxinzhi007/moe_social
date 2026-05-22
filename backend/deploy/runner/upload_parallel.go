package runner

import (
	"context"
	"fmt"
	"path/filepath"
	"sync"

	"github.com/pkg/sftp"
)

// uploadBinariesParallel uploads api+rpc over separate SSH/SFTP sessions (client is not goroutine-safe).
func uploadBinariesParallel(ctx context.Context, sshCfg SSHConfig, localBE, remoteBE string, sink LogSink) error {
	var wg sync.WaitGroup
	errCh := make(chan error, len(backendBinaryArtifacts))
	for i, art := range backendBinaryArtifacts {
		wg.Add(1)
		go func(idx int, art binaryArtifact) {
			defer wg.Done()
			localPath := filepath.Join(localBE, art.localRel)
			remotePath := remoteJoin(remoteBE, art.remoteRel)
			if sink != nil {
				sink(fmt.Sprintf("  [并行 %d/%d] 开始 %s\n", idx+1, len(backendBinaryArtifacts), art.remoteRel))
			}
			client, err := dialSSH(ctx, sshCfg)
			if err != nil {
				errCh <- fmt.Errorf("%s: SSH: %w", art.remoteRel, err)
				return
			}
			defer client.Close()
			sftpClient, err := sftp.NewClient(client)
			if err != nil {
				errCh <- fmt.Errorf("%s: SFTP: %w", art.remoteRel, err)
				return
			}
			defer sftpClient.Close()
			if err := uploadOneFile(ctx, sftpClient, localPath, remotePath, sink); err != nil {
				errCh <- err
				return
			}
			if sink != nil {
				sink(fmt.Sprintf("  [并行 %d/%d] 完成 %s\n", idx+1, len(backendBinaryArtifacts), art.remoteRel))
			}
		}(i, art)
	}
	wg.Wait()
	close(errCh)
	for err := range errCh {
		if err != nil {
			return err
		}
	}
	return nil
}

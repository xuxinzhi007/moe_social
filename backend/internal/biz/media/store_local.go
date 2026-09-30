package mediabiz

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"backend/utils"
)

type localBlobStore struct {
	root string
}

func newLocalBlobStore(cfg ImageConfig) *localBlobStore {
	return &localBlobStore{root: utils.ResolveImageLocalDir(cfg.LocalDir)}
}

func (s *localBlobStore) abs(folder, filename string) (string, error) {
	relFolder := cleanFolder(folder)
	name := filepath.Base(strings.TrimSpace(filename))
	if relFolder == "" || name == "" || name == "." || name == ".." {
		return "", fmt.Errorf("invalid media path")
	}
	target := filepath.Join(s.root, filepath.FromSlash(relFolder), name)
	rootAbs, err := filepath.Abs(s.root)
	if err != nil {
		return "", err
	}
	targetAbs, err := filepath.Abs(target)
	if err != nil {
		return "", err
	}
	sep := string(os.PathSeparator)
	if targetAbs != rootAbs && !strings.HasPrefix(targetAbs, rootAbs+sep) {
		return "", fmt.Errorf("invalid media path")
	}
	return target, nil
}

func (s *localBlobStore) Put(_ context.Context, folder, filename string, r io.Reader, _ string) error {
	target, err := s.abs(folder, filename)
	if err != nil {
		return err
	}
	dir := filepath.Dir(target)
	if err := os.MkdirAll(dir, os.ModePerm); err != nil {
		return fmt.Errorf("mkdir media dir: %w", err)
	}
	out, err := os.Create(target)
	if err != nil {
		return fmt.Errorf("create media file: %w", err)
	}
	defer out.Close()
	if _, err := io.Copy(out, r); err != nil {
		return fmt.Errorf("write media file: %w", err)
	}
	return nil
}

func (s *localBlobStore) Delete(_ context.Context, folder, filename string) error {
	path, err := s.abs(folder, filename)
	if err != nil {
		return err
	}
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return nil
	}
	if err := os.Remove(path); err != nil {
		return fmt.Errorf("remove media file: %w", err)
	}
	return nil
}

func (s *localBlobStore) Open(_ context.Context, folder, filename string) (BlobObject, error) {
	path, err := s.abs(folder, filename)
	if err != nil {
		return BlobObject{}, err
	}
	info, err := os.Stat(path)
	if err != nil {
		return BlobObject{}, err
	}
	f, err := os.Open(path)
	if err != nil {
		return BlobObject{}, err
	}
	return BlobObject{
		Body:        f,
		Size:        info.Size(),
		ModTime:     info.ModTime(),
		ContentType: contentTypeForName(filename),
		LocalPath:   path,
	}, nil
}

func (s *localBlobStore) ListFolder(_ context.Context, folder string) ([]BlobMeta, error) {
	relFolder := cleanFolder(folder)
	if relFolder == "" {
		return nil, fmt.Errorf("invalid media folder")
	}
	dir := filepath.Join(s.root, filepath.FromSlash(relFolder))
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	out := make([]BlobMeta, 0, len(entries))
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		name := e.Name()
		out = append(out, BlobMeta{
			Folder:    relFolder,
			Filename:  name,
			Size:      info.Size(),
			ModTime:   info.ModTime(),
			ObjectKey: relFolder + "/" + name,
		})
	}
	return out, nil
}

func (s *localBlobStore) ListAll(_ context.Context) ([]BlobMeta, error) {
	var out []BlobMeta
	err := filepath.WalkDir(s.root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			if os.IsNotExist(err) {
				return nil
			}
			return err
		}
		if d.IsDir() {
			return nil
		}
		rel, err := filepath.Rel(s.root, path)
		if err != nil {
			return nil
		}
		rel = filepath.ToSlash(rel)
		folder, filename, ok := metaFromRel(rel)
		if !ok {
			return nil
		}
		info, err := d.Info()
		if err != nil {
			return nil
		}
		out = append(out, BlobMeta{
			Folder:    folder,
			Filename:  filename,
			Size:      info.Size(),
			ModTime:   info.ModTime(),
			ObjectKey: rel,
		})
		return nil
	})
	if err != nil && !os.IsNotExist(err) {
		return nil, err
	}
	return out, nil
}

// hybridBlobStore：OSS 为主，本地为迁移期读回退。
type hybridBlobStore struct {
	primary  BlobStore
	fallback BlobStore
}

func (s *hybridBlobStore) Put(ctx context.Context, folder, filename string, r io.Reader, contentType string) error {
	return s.primary.Put(ctx, folder, filename, r, contentType)
}

func (s *hybridBlobStore) Delete(ctx context.Context, folder, filename string) error {
	errPrimary := s.primary.Delete(ctx, folder, filename)
	_ = s.fallback.Delete(ctx, folder, filename)
	return errPrimary
}

func (s *hybridBlobStore) Open(ctx context.Context, folder, filename string) (BlobObject, error) {
	obj, err := s.primary.Open(ctx, folder, filename)
	if err == nil {
		return obj, nil
	}
	return s.fallback.Open(ctx, folder, filename)
}

func (s *hybridBlobStore) ListFolder(ctx context.Context, folder string) ([]BlobMeta, error) {
	primary, err := s.primary.ListFolder(ctx, folder)
	if err != nil {
		return nil, err
	}
	fallback, err := s.fallback.ListFolder(ctx, folder)
	if err != nil {
		return primary, nil
	}
	return mergeBlobMeta(primary, fallback), nil
}

func (s *hybridBlobStore) ListAll(ctx context.Context) ([]BlobMeta, error) {
	primary, err := s.primary.ListAll(ctx)
	if err != nil {
		return nil, err
	}
	fallback, err := s.fallback.ListAll(ctx)
	if err != nil {
		return primary, nil
	}
	return mergeBlobMeta(primary, fallback), nil
}

func mergeBlobMeta(primary, fallback []BlobMeta) []BlobMeta {
	seen := make(map[string]struct{}, len(primary))
	out := make([]BlobMeta, 0, len(primary)+len(fallback))
	for _, m := range primary {
		k := m.Folder + "/" + m.Filename
		seen[k] = struct{}{}
		out = append(out, m)
	}
	for _, m := range fallback {
		k := m.Folder + "/" + m.Filename
		if _, ok := seen[k]; ok {
			continue
		}
		out = append(out, m)
	}
	return out
}

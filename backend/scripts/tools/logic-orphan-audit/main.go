// logic-orphan-audit 列出 api/internal/logic 中 New*Logic 未被 handler 引用的文件。
package main

import (
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strings"
)

func main() {
	root := filepath.Join("api", "internal")
	logicRoot := filepath.Join(root, "logic")
	handlerRoot := filepath.Join(root, "handler")

	handlerSrc, err := readTree(handlerRoot)
	if err != nil {
		fmt.Fprintf(os.Stderr, "read handlers: %v\n", err)
		os.Exit(1)
	}

	var orphans []string
	err = filepath.Walk(logicRoot, func(path string, info os.FileInfo, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if info.IsDir() || !strings.HasSuffix(path, "logic.go") {
			return nil
		}
		ctors := logicConstructors(path)
		if len(ctors) == 0 {
			return nil
		}
		for _, ctor := range ctors {
			if strings.Contains(handlerSrc, ctor+"(") {
				continue
			}
			if referencedOutsideFile(logicRoot, path, ctor) {
				continue
			}
			orphans = append(orphans, fmt.Sprintf("%s (%s)", rel(path), ctor))
		}
		return nil
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "walk logic: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("logic orphan audit (no handler ref, no cross-logic ref)\n")
	fmt.Printf("logic files scanned under %s\n\n", logicRoot)
	if len(orphans) == 0 {
		fmt.Println("none")
		return
	}
	for _, o := range orphans {
		fmt.Println(o)
	}
}

func rel(path string) string {
	return filepath.ToSlash(path)
}

func readTree(dir string) (string, error) {
	var b strings.Builder
	err := filepath.Walk(dir, func(path string, info os.FileInfo, walkErr error) error {
		if walkErr != nil || info.IsDir() || !strings.HasSuffix(path, ".go") {
			return walkErr
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		b.Write(data)
		b.WriteByte('\n')
		return nil
	})
	return b.String(), err
}

func logicConstructors(path string) []string {
	fset := token.NewFileSet()
	f, err := parser.ParseFile(fset, path, nil, 0)
	if err != nil {
		return nil
	}
	var out []string
	for _, decl := range f.Decls {
		fn, ok := decl.(*ast.FuncDecl)
		if !ok || fn.Name == nil || !strings.HasPrefix(fn.Name.Name, "New") {
			continue
		}
		if !strings.HasSuffix(fn.Name.Name, "Logic") {
			continue
		}
		out = append(out, fn.Name.Name)
	}
	return out
}

func referencedOutsideFile(logicRoot, selfPath, ctor string) bool {
	found := false
	_ = filepath.Walk(logicRoot, func(path string, info os.FileInfo, walkErr error) error {
		if walkErr != nil || found {
			return walkErr
		}
		if info.IsDir() || !strings.HasSuffix(path, ".go") || path == selfPath {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		if strings.Contains(string(data), ctor+"(") {
			found = true
		}
		return nil
	})
	return found
}

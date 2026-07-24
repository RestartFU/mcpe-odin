package main

import (
	"bufio"
	"flag"
	"fmt"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const prefix = "github.com/sandertv/go-raknet."

func receiverName(expr ast.Expr) string {
	switch value := expr.(type) {
	case *ast.Ident:
		return value.Name
	case *ast.StarExpr:
		return receiverName(value.X)
	default:
		return ""
	}
}

func addTypeDeclarations(found map[string]bool, spec *ast.TypeSpec) {
	if !ast.IsExported(spec.Name.Name) {
		return
	}
	found[prefix+spec.Name.Name] = true
	var fields *ast.FieldList
	switch value := spec.Type.(type) {
	case *ast.StructType:
		fields = value.Fields
	case *ast.InterfaceType:
		fields = value.Methods
	}
	if fields == nil {
		return
	}
	for _, field := range fields.List {
		for _, name := range field.Names {
			if ast.IsExported(name.Name) {
				found[prefix+spec.Name.Name+"."+name.Name] = true
			}
		}
	}
}

func inventory(source string) (map[string]bool, error) {
	found := map[string]bool{}
	files, err := filepath.Glob(filepath.Join(source, "*.go"))
	if err != nil {
		return nil, err
	}
	fset := token.NewFileSet()
	for _, path := range files {
		if strings.HasSuffix(path, "_test.go") {
			continue
		}
		file, parseErr := parser.ParseFile(fset, path, nil, 0)
		if parseErr != nil {
			return nil, parseErr
		}
		for _, declaration := range file.Decls {
			switch value := declaration.(type) {
			case *ast.GenDecl:
				for _, rawSpec := range value.Specs {
					switch spec := rawSpec.(type) {
					case *ast.TypeSpec:
						addTypeDeclarations(found, spec)
					case *ast.ValueSpec:
						for _, name := range spec.Names {
							if ast.IsExported(name.Name) {
								found[prefix+name.Name] = true
							}
						}
					}
				}
			case *ast.FuncDecl:
				if !ast.IsExported(value.Name.Name) {
					continue
				}
				if value.Recv == nil {
					found[prefix+value.Name.Name] = true
					continue
				}
				receiver := receiverName(value.Recv.List[0].Type)
				if ast.IsExported(receiver) {
					found[prefix+receiver+"."+value.Name.Name] = true
				}
			}
		}
	}
	return found, nil
}

func ledger(path string) (map[string]int, error) {
	file, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer file.Close()
	found := map[string]int{}
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if !strings.HasPrefix(line, `upstream = "`) {
			continue
		}
		name := strings.TrimSuffix(strings.TrimPrefix(line, `upstream = "`), `"`)
		if strings.HasPrefix(name, prefix) {
			found[name]++
		}
	}
	return found, scanner.Err()
}

func main() {
	source := flag.String("source", "", "pinned go-raknet checkout")
	apiMap := flag.String("api-map", "api-map.toml", "conformance ledger")
	flag.Parse()
	if *source == "" {
		fmt.Fprintln(os.Stderr, "-source is required")
		os.Exit(2)
	}
	expected, err := inventory(*source)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	actual, err := ledger(*apiMap)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	missing := []string{}
	duplicates := []string{}
	stale := []string{}
	for name := range expected {
		if actual[name] == 0 {
			missing = append(missing, name)
		}
	}
	for name, count := range actual {
		if count > 1 {
			duplicates = append(duplicates, name)
		}
		if !expected[name] {
			stale = append(stale, name)
		}
	}
	sort.Strings(missing)
	sort.Strings(duplicates)
	sort.Strings(stale)
	for _, name := range missing {
		fmt.Printf("missing: %s\n", name)
	}
	for _, name := range duplicates {
		fmt.Printf("duplicate: %s\n", name)
	}
	for _, name := range stale {
		fmt.Printf("stale: %s\n", name)
	}
	if len(missing) != 0 || len(duplicates) != 0 || len(stale) != 0 {
		os.Exit(1)
	}
	fmt.Printf("go-raknet API ledger covers %d exported declarations\n", len(expected))
}

import os, re, subprocess
from pathlib import Path

root = Path(__file__).resolve().parent
logic_root = root / 'api/internal/logic'
search_roots = [
    root / 'api/internal/handler',
    root / 'api/moehttp',
    root / 'api/runserver',
    root / 'internal',
    logic_root,
]
manifest = set()
for line in (root / 'scripts/goctl-orphan-stubs.txt').read_text(encoding='utf-8').splitlines():
    line = line.split('#', 1)[0].strip()
    if line:
        manifest.add(line.replace('\\', '/'))

files = sorted({p.resolve() for p in logic_root.rglob('*logic.go')})
results = []
for f in files:
    text = f.read_text(encoding='utf-8', errors='replace')
    m = re.search(r'^type (\w+Logic) struct', text, re.M)
    if not m:
        continue
    logic_type = m.group(1)
    ctor = f'New{logic_type}'
    has_todo = bool(re.search(r'todo:\s*add your logic', text, re.I))
    rel = str(f.relative_to(root)).replace('\\', '/')
    in_manifest = rel in manifest
    handler_refs, logic_refs, other_refs = [], [], []
    for sr in search_roots:
        if not sr.exists():
            continue
        try:
            out = subprocess.check_output(['rg', '-l', f'{ctor}\\(', str(sr)], text=True, stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            continue
        for hit in out.splitlines():
            hp = Path(hit).resolve()
            if hp == f.resolve():
                continue
            hr = str(hp.relative_to(root)).replace('\\', '/')
            if '/handler/' in hr:
                handler_refs.append(hr)
            elif '/logic/' in hr:
                logic_refs.append(hr)
            else:
                other_refs.append(hr)
    handler_refs = sorted(set(handler_refs))
    logic_refs = sorted(set(logic_refs))
    other_refs = sorted(set(other_refs))
    ext = len(handler_refs) + len(logic_refs) + len(other_refs)
    results.append(dict(file=rel, logic_type=logic_type, ctor=ctor, has_todo=has_todo, in_manifest=in_manifest,
                        handler=handler_refs, logic=logic_refs, other=other_refs, ext=ext))

print('=== SUMMARY ===')
print('Total logic files:', len(results))
print('Todo shells:', sum(1 for r in results if r['has_todo']))
print('No external refs:', sum(1 for r in results if r['ext']==0))
print('Manifest entries present:', sum(1 for r in results if r['in_manifest']))

print('\n=== CAT1_SAFE (no ext refs OR in manifest) ===')
for r in sorted(results, key=lambda x: x['file']):
    if r['ext']==0 or r['in_manifest']:
        reason = 'manifest' if r['in_manifest'] else 'no-ext-refs'
        if r['has_todo']: reason += '+todo'
        print(f"{r['file']} | {r['logic_type']} | {r['ctor']} | {reason}")

print('\n=== CAT2_LOGIC_ONLY (logic refs, no handler) ===')
for r in sorted(results, key=lambda x: x['file']):
    if r['logic'] and not r['handler']:
        print(f"{r['file']} | {r['logic_type']} | {r['ctor']} | refs: {', '.join(r['logic'])}")

print('\n=== NO_EXT_REFS_NOT_MANIFEST ===')
for r in sorted(results, key=lambda x: x['file']):
    if r['ext']==0 and not r['in_manifest']:
        todo = ' | TODO' if r['has_todo'] else ''
        print(f"{r['file']} | {r['logic_type']} | {r['ctor']}{todo}")

print('\n=== OTHER_REFS (non-handler non-logic) ===')
for r in sorted(results, key=lambda x: x['file']):
    if r['other']:
        print(f"{r['file']} | {r['logic_type']} | {r['ctor']} | other: {', '.join(r['other'])}")

handler_count = sum(1 for r in results if r['handler'])
print('\n=== CAT3_HANDLER count ===', handler_count)

from pathlib import Path

p = Path(__file__).resolve().parent.parent / "src" / "pages" / "PlatformPage.tsx"
text = p.read_text(encoding="utf-8")

start = text.index('<motion className="platform-asset-rings">')
end = text.index("            </section>", start)

new_inner = (
    '              <div className="platform-asset-rings">\n'
    '                <div className="platform-asset-ring">\n'
    "                  <strong>{catalog.summary.total_tables}</strong>\n"
    "                  <span>数据表</span>\n"
    "                </div>\n"
    '                <div className="platform-asset-ring is-ok">\n'
    "                  <strong>{catalog.summary.managed_full}</strong>\n"
    "                  <span>完整治理</span>\n"
    "                </div>\n"
    '                <div className="platform-asset-ring is-warn">\n'
    "                  <strong>{catalog.summary.unmanaged}</strong>\n"
    "                  <span>待加强</span>\n"
    "                </div>\n"
    "              </div>\n"
    '              <button type="button" className="btn btn-primary btn-sm" onClick={() => setTab(\'data\')}>\n'
    "                进入数据星系 →\n"
    "              </button>\n"
)
text = text[:start] + new_inner + text[end:]

data_old_start = text.index("      {tab === 'data' && catalog ? (")
data_old_end = text.index("      {tab === 'memory' ?", data_old_start)
data_new = """      {tab === 'data' && catalog ? (
        <section className="panel platform-panel platform-data-stage">
          <DataDomainMap
            matrix={domainMatrix}
            items={catalog.items}
            selectedDomain={dataDomain}
            onSelectDomain={setDataDomain}
          />
          <div className="platform-data-foot">
            <Link className="btn btn-ghost btn-sm" to="/system/data">完整数据目录（树形 + 快捷操作）</Link>
            {dataDomain ? (
              <div className="platform-data-actions">
                {catalog.items
                  .filter((r) => r.domain === dataDomain && r.admin_route)
                  .slice(0, 6)
                  .map((row) => (
                    <Link key={row.key} className="btn btn-mint btn-sm" to={row.admin_route!}>
                      {row.label}
                    </Link>
                  ))}
              </div>
            ) : null}
          </div>
        </section>
      ) : null}

"""
text = text[:data_old_start] + data_new + text[data_old_end:]

for a, b in [
    ('<section className="panel platform-config-form">', '<section className="panel platform-panel platform-config-form">'),
    ('<section className="panel platform-preview">', '<section className="panel platform-panel platform-preview">'),
    ("      {tab === 'media' ? (\n        <section className=\"panel\">", "      {tab === 'media' ? (\n        <section className=\"panel platform-panel\">"),
    ("      {tab === 'memory' ? (\n        <section className=\"panel\">", "      {tab === 'memory' ? (\n        <section className=\"panel platform-panel\">"),
]:
    text = text.replace(a, b)

if "schemaCoverageTag(" not in text:
    text = text.replace("import { schemaCoverageTag } from '../lib/adminLabels'\n", "")
if "schemaQuickActions(" not in text:
    text = text.replace("import { schemaQuickActions } from '../lib/schemaActions'\n", "")

p.write_text(text, encoding="utf-8")
print("patched PlatformPage")

# Shared by scripts/verify/* — locate backend module root (go.mod + Makefile).
moe_backend_cd() {
	local d
	d="$(cd "${1:-$(dirname "${BASH_SOURCE[1]}")}" && pwd)"
	while [ "$d" != "/" ]; do
		if [ -f "$d/go.mod" ] && [ -f "$d/Makefile" ]; then
			cd "$d" || return 1
			return 0
		fi
		d="$(dirname "$d")"
	done
	echo "moe_backend_cd: backend root not found from ${1:-}" >&2
	return 1
}

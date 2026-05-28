from pathlib import Path
import re
def bd(s): return s.count("{")-s.count("}")
def close(lines,i):
    ln=lines[i]
    if "FromMoe(&moe." not in ln: return
    d=bd(ln)
    if d==0:
        s=ln.rstrip()
        if s.endswith("})") and not s.endswith("}))"): lines[i]=s+")"
        return
    j=i+1
    while j<len(lines) and d>0:
        d+=bd(lines[j]); j+=1
    ci=j-1
    if ci>i and re.match(r"^\s+\}\)\s*$", lines[ci]):
        lines[ci]=re.sub(r"\}\)\s*$","}))",lines[ci])
p=Path(r"C:/Users/ZhuanZ1/Desktop/moe_social/backend/api/moehttp/user_compat.go")
lines=p.read_text(encoding="utf-8").splitlines()
lines=[re.sub(r"\}\)\)\s*$","})",x) for x in lines]
for i,ln in enumerate(lines):
    if re.search(r"app\.\w+\(ctx, (?:userv1|vipv1)\.\w+FromMoe", ln):
        close(lines,i)
p.write_text("\n".join(lines)+"\n",encoding="utf-8")
print("ok")

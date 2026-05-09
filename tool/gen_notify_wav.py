import math
import os
import struct
import wave

root = os.path.join(os.path.dirname(__file__), "..")
out_dir = os.path.join(root, "android", "app", "src", "main", "res", "raw")
os.makedirs(out_dir, exist_ok=True)
path = os.path.join(out_dir, "moe_notify.wav")

fr = 16000
dur = 0.12
n = int(fr * dur)
with wave.open(path, "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(fr)
    for i in range(n):
        t = i / fr
        s = 0.35 * math.sin(2 * math.pi * 880 * t) * math.exp(-12 * t)
        s += 0.2 * math.sin(2 * math.pi * 1320 * t) * math.exp(-10 * t)
        val = int(max(-32767, min(32767, s * 32767)))
        w.writeframes(struct.pack("<h", val))

print("wrote", path, os.path.getsize(path))

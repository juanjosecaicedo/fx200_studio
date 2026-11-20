"""Generates the FX200 Studio app icon (audio-waveform) for Windows/macOS/Linux."""
import math, os
from PIL import Image, ImageDraw

S = 4096  # supersampled canvas
BG, FG = (24, 26, 33), (255, 140, 50)

def arc(cx, cy, r, a0, a1, n=48):
    return [(cx + r*math.cos(math.radians(a0+(a1-a0)*i/n)),
             cy + r*math.sin(math.radians(a0+(a1-a0)*i/n))) for i in range(n+1)]

# Waveform path in 24-unit space (y down). Angles in screen coordinates.
pts = []
pts += arc(2, 11, 2, 90, 0)        # (2,13) -> (4,11)
pts += [(4, 7)]
pts += arc(6, 7, 2, 180, 360)      # top cap (4,7) -> (8,7)
pts += [(8, 20)]
pts += arc(10, 20, 2, 180, 0)      # bottom cap (8,20) -> (12,20)
pts += [(12, 4)]
pts += arc(14, 4, 2, 180, 360)     # top cap (12,4) -> (16,4)
pts += [(16, 17)]
pts += arc(18, 17, 2, 180, 0)      # bottom cap (16,17) -> (20,17)
pts += [(20, 13)]
pts += arc(22, 13, 2, 180, 270)    # (20,13) -> (22,11)

def render(size):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, S-1, S-1], radius=int(S*0.225), fill=BG)
    scale = S * 0.60 / 24.0
    ox = S/2 - 12*scale
    oy = S/2 - 12*scale
    w = 2.4 * scale
    p = [(ox + x*scale, oy + y*scale) for x, y in pts]
    # Stamp discs along a densely sampled path: smooth round joins/caps.
    dense = []
    for (x0, y0), (x1, y1) in zip(p, p[1:]):
        n = max(1, int(math.hypot(x1-x0, y1-y0) / (w/8)))
        dense += [(x0+(x1-x0)*i/n, y0+(y1-y0)*i/n) for i in range(n)]
    dense.append(p[-1])
    for x, y in dense:
        d.ellipse([x-w/2, y-w/2, x+w/2, y+w/2], fill=FG)
    return img.resize((size, size), Image.LANCZOS)

root = os.path.join(os.path.dirname(__file__), "..")
mac = os.path.join(root, "macos/Runner/Assets.xcassets/AppIcon.appiconset")
for s in (16, 32, 64, 128, 256, 512, 1024):
    render(s).save(os.path.join(mac, f"app_icon_{s}.png"))
render(256).save(os.path.join(root, "windows/runner/resources/app_icon.ico"),
                 sizes=[(16,16),(24,24),(32,32),(48,48),(64,64),(128,128),(256,256)])
os.makedirs(os.path.join(root, "linux/runner/resources"), exist_ok=True)
render(512).save(os.path.join(root, "linux/runner/resources/app_icon.png"))
print("ok")

"""Compare two capture folders pixel by pixel. Exit 1 if any image differs."""
import sys
from pathlib import Path
from PIL import Image, ImageChops

a, b = Path(sys.argv[1]), Path(sys.argv[2])
bad = 0
for left in sorted(a.glob("*.png")):
    right = b / left.name
    if not right.exists():
        print("MISSING", left.name); bad += 1; continue
    x, y = Image.open(left).convert("RGBA"), Image.open(right).convert("RGBA")
    if x.size != y.size:
        print("SIZE", left.name, x.size, y.size); bad += 1; continue
    diff = ImageChops.difference(x, y)
    # An opaque RGBA image has an all-zero difference alpha even when RGB
    # differs. Inspect every channel rather than silently ignoring RGB changes.
    box = diff.getbbox(alpha_only=False)
    if box:
        count = sum(1 for p in diff.get_flattened_data() if p != (0, 0, 0, 0))
        print(f"DIFF {left.name} pixels={count} box={box}"); bad += 1
print(f"GOLDEN_RESULT {len(list(a.glob('*.png')))} images, {bad} differ")
sys.exit(1 if bad else 0)

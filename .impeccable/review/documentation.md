# Scoped interface documentation

Disposition supplied by the independent finish review: **Ship**, with no visual findings.

Written files:
- `DESIGN.md`: machine-readable color, bitmap typography, square shape, spacing, and component tokens, followed by the canonical eight design sections.
- `.impeccable/design.json`: schema v2 extensions, source-derived pixel SVG previews for seven representative components, and the matching design narrative.

Scope: the implemented native HUD, original Minecraft bitmap fonts and GUI assets, neutral shared controls, and the opaque black character-stat sheet. The documentation records 640 × 360 logical rendering, integer scaling, truthful formula-derived values, and exact state restoration on L / Esc. No PRODUCT.md or additional product identity was invented.

Verified against `scripts/main.gd`, `scripts/game_data.gd`, `scripts/world.gd`, `data/balance.json`, `project.godot`, the local `.fnt` resources, and the approved presentation brief. Reviewed the supplied HUD and stats images without creating new captures. Parsed YAML and JSON; checked all component references, allowed frontmatter properties, canonical heading order, and seven embedded SVG documents. Tonal ramps are sidecar exploration metadata and do not add runtime colors.

Only the two design documents and this report were written. Game code, README, audio, tests, builds, and screenshot files were not modified by this documentation pass.

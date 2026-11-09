"""Compatibility entry point for the vanilla-textured character pipeline (0.5+).

The old imagegen-anchor rig is archived in docs/legacy for historical context.
"""
import argparse

from bake_minecraft_characters import generate

if __name__=="__main__":
    parser=argparse.ArgumentParser();parser.add_argument("--only",nargs="+")
    names=parser.parse_args().only
    generate(names)
    if names is None:
        from bake_nether_assets import generate as generate_nether
        generate_nether()
        from bake_herobrine_duel import generate as generate_duel
        generate_duel()

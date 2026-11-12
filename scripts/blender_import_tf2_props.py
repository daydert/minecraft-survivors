"""Prepare editable original TF2 props from extracted MDL/VVD/VTX.
Blender --background --python scripts/blender_import_tf2_props.py -- /path/to/SourceIO-parent
Pinned tool: SourceIO 5.5.4 (GPL-3.0), https://github.com/REDxEYE/SourceIO/releases/tag/5.5.4
See CHAPTER_FIVE_VISUAL_SOURCES.md: user-authorized local crossover, not a new asset license.
"""
import sys,json
from pathlib import Path
import bpy
ROOT=Path(__file__).resolve().parent.parent
sys.path.insert(0,sys.argv[sys.argv.index('--')+1])
from SourceIO.blender_bindings.models import import_model
from SourceIO.blender_bindings.operators.import_settings_base import ModelOptions
from SourceIO.library.shared.content_manager import ContentManager
from SourceIO.library.shared.content_manager.providers.loose_files import LooseFilesContentProvider
from SourceIO.library.shared.app_id import SteamAppId
from SourceIO.library.utils import TinyPath,FileBuffer
bpy.ops.wm.read_factory_settings(use_empty=True)
root=TinyPath(str(ROOT/'assets/art_source/ch5_finale/tf2'));cm=ContentManager();cm.add_child(LooseFilesContentProvider(root,SteamAppId.TEAM_FORTRESS_2))
opts=ModelOptions.default();opts.scale=.025;opts.import_textures=False
count=0
for file in sorted((ROOT/'assets/art_source/ch5_finale/tf2/models').rglob('*.mdl')):
    rel=file.relative_to(ROOT/'assets/art_source/ch5_finale/tf2');name=TinyPath(str(rel))
    try:
        c=import_model(name,FileBuffer(TinyPath(str(file))),cm,opts)
        collection=bpy.data.collections.new(str(rel));bpy.context.scene.collection.children.link(collection)
        for ob in c.objects:collection.objects.link(ob)
        count+=1
    except Exception as e:print('PROP_ERROR',rel,repr(e))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/art_source/ch5_finale/tf2_props.blend'))
print('NATIVE_PROPS',count)

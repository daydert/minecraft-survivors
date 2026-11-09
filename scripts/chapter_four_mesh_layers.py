"""IV detachable model layers. Same orthographic rasterizer as the existing
native asset pipeline, returning its depth so removal reveals the correct
surfaces below. Older bakes and the shared rasterizer remain unchanged.
"""
import math
import numpy as np
from PIL import Image

def bake_depth(mesh, size=(32, 32), scale=1.25, center=(16, 27), yaw=30, elevation=25):
    """Small orthographic, z-buffered texture rasterizer; no smoothing or paint."""
    yaw, elevation = math.radians(yaw), math.radians(elevation)
    right = np.array([math.cos(yaw), 0, math.sin(yaw)])
    up = np.array([-math.sin(yaw)*math.sin(elevation), math.cos(elevation), math.cos(yaw)*math.sin(elevation)])
    view = np.cross(up, right)
    output = np.zeros((size[1], size[0], 4), dtype=np.uint8)
    depth = np.full((size[1], size[0]), -np.inf)
    for verts, texture, rect, shade in mesh:
        # Normal convention varies between unwrap faces: rasterize both sides.
        projected = np.column_stack((verts @ right * scale + center[0],
                                     -verts @ up * scale + center[1], verts @ view))
        u, v, w, h = rect
        uv = np.array([[u,v],[u+w,v],[u+w,v+h],[u,v+h]], dtype=float)
        tex = np.asarray(texture)
        for indices in [(0,1,2), (0,2,3)]:
            tri = projected[list(indices)]
            tuv = uv[list(indices)]
            lo = np.maximum(np.floor(tri[:,:2].min(axis=0)).astype(int), [0,0])
            hi = np.minimum(np.ceil(tri[:,:2].max(axis=0)).astype(int), [size[0]-1,size[1]-1])
            if np.any(hi < lo):
                continue
            a, b, c = tri[:,:2]
            det = (b-a)[0]*(c-a)[1] - (b-a)[1]*(c-a)[0]
            if abs(det) < 1e-7:
                continue
            yy, xx = np.mgrid[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
            q = np.stack((xx+0.5, yy+0.5), axis=-1)-a
            b1 = (q[...,0]*(c-a)[1]-q[...,1]*(c-a)[0])/det
            b2 = ((b-a)[0]*q[...,1]-(b-a)[1]*q[...,0])/det
            b0 = 1-b1-b2
            inside = (b0 >= -1e-6)&(b1 >= -1e-6)&(b2 >= -1e-6)
            z = b0*tri[0,2]+b1*tri[1,2]+b2*tri[2,2]
            coords = b0[...,None]*tuv[0]+b1[...,None]*tuv[1]+b2[...,None]*tuv[2]
            tx = np.clip(np.floor(coords[...,0]).astype(int), 0, tex.shape[1]-1)
            ty = np.clip(np.floor(coords[...,1]).astype(int), 0, tex.shape[0]-1)
            pixels = tex[ty,tx].copy()
            pixels[:,:,:3] = (pixels[:,:,:3]*shade).astype(np.uint8)
            region = depth[lo[1]:hi[1]+1,lo[0]:hi[0]+1]
            mask = inside & (z > region) & (pixels[:,:,3] > 0)
            region[mask] = z[mask]
            output[yy[mask],xx[mask]] = pixels[mask]
    return Image.fromarray(output), depth


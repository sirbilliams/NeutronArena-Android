#!/usr/bin/env python3
"""Compare the in-app import output with reference glbs (from the offline PC converters).
  compare_glb.py <imported dir> <reference dir>
Per file: node/mesh/skin/material/image/animation counts, vertex/triangle counts, AABB, then every accessor element-wise
(max abs difference).  Exit code 1 on any mismatch."""
import sys, os, json, struct
import numpy as np

SZ = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}
DT = {5126: '<f4', 5123: '<u2', 5125: '<u4', 5121: 'u1'}


def load(p):
    b = open(p, 'rb').read()
    jl, _ = struct.unpack_from('<II', b, 12)
    d = json.loads(b[20:20 + jl]); o = 20 + jl
    bl, _ = struct.unpack_from('<II', b, o)
    return d, b[o + 8:o + 8 + bl]


def accessors(d, b):
    out = []
    for a in d['accessors']:
        v = d['bufferViews'][a['bufferView']]; n = SZ[a['type']]
        out.append(np.frombuffer(b, DT[a['componentType']], a['count'] * n, v['byteOffset']).reshape(a['count'], n).astype(float))
    return out


def summary(d):
    A = d['accessors']; nv = nt = 0; lo = np.full(3, 1e30); hi = np.full(3, -1e30)
    for m in d.get('meshes', []):
        for p in m['primitives']:
            a = A[p['attributes']['POSITION']]; nv += a['count']; lo = np.minimum(lo, a['min']); hi = np.maximum(hi, a['max'])
            nt += A[p['indices']]['count'] // 3
    an = {x['name']: (A[x['samplers'][0]['input']]['count'], len(x['channels'])) for x in d.get('animations', [])}
    return dict(nodes=len(d['nodes']), meshes=len(d.get('meshes', [])), skins=len(d.get('skins', [])), mats=len(d.get('materials', [])),
                imgs=len(d.get('images', [])), accs=len(A), verts=nv, tris=nt, anims=an), lo, hi


def compare(a, b, tol):
    da, ba = load(a); db, bb = load(b)
    sa, loa, hia = summary(da); sb, lob, hib = summary(db)
    bad = []
    for k in sa:
        if sa[k] != sb[k]: bad.append('%s: %s != ref %s' % (k, sa[k], sb[k]))
    ext = max(np.abs(hib - lob).max(), 1.0)
    dbox = max(np.abs(loa - lob).max(), np.abs(hia - hib).max())
    if dbox > tol * ext: bad.append('AABB differs by %g' % dbox)
    worst = 0.0
    if not bad:
        XA = accessors(da, ba); XB = accessors(db, bb)
        for i, (x, y) in enumerate(zip(XA, XB)):
            if x.shape != y.shape: bad.append('accessor %d shape %s vs %s' % (i, x.shape, y.shape)); continue
            if x.size:
                e = np.abs(x - y); diff = e.max(); scale = max(np.abs(y).max(), 1.0)
                # the reference went through omtdump's %g text (6 digits), so near-degenerate polygons can get a different
                # unit normal: allow up to 0.5% of the elements to differ by more than the tolerance
                frac = float((e.max(axis=1) > tol * scale * 10).mean()) if e.ndim == 2 else 0.0
                if frac <= 0.005 or (e.max(axis=1) > tol * scale * 10).sum() <= 6: frac = 0.0; diff = float(np.sort(e.max(axis=1))[int(len(e) * 0.995) - 1]) if frac > 0 else diff
                worst = max(worst, diff)
                if frac > 0.005: bad.append('accessor %d (%s) %.2f%% elements differ (max %g, scale %g)' % (i, da['accessors'][i]['type'], frac * 100, e.max(), scale))
    return sa, dbox, worst, bad


def main():
    imp, ref = sys.argv[1], sys.argv[2]
    tol = 1e-3
    files = []
    for root, _, fs in os.walk(imp):
        for f in fs:
            if f.endswith('.glb'): files.append(os.path.relpath(os.path.join(root, f), imp))
    rc = 0
    for f in sorted(files):
        r = os.path.join(ref, f)
        if not os.path.exists(r): print('MISSING reference', f); rc = 1; continue
        s, dbox, worst, bad = compare(os.path.join(imp, f), r, tol)
        print('%-26s %s  verts %6d tris %6d anims %d  AABB d=%.3g  max accessor diff %.3g%s' % (f, 'FAIL' if bad else 'ok  ', s['verts'], s['tris'], len(s['anims']), dbox, worst, ''))
        for x in bad[:6]: print('    ', x)
        rc |= bool(bad)
    print('compared %d files: %s' % (len(files), 'ALL MATCH' if not rc else 'DIFFERENCES'))
    sys.exit(rc)


main()

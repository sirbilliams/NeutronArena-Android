/*  grndump2 - dump a .grn model (+ animations) to .gdmp version 2 using the port's own decoder
    (game/granny/*.cpp); native, no Wine.  Feeds gdmp2gltf.py.

      build:  g++ -O2 -I../../game/granny -o grndump2 grndump2.cpp ../../game/granny/granny_*.cpp
      usage:  grndump2 <out.gdmp> <granny.dll> <model.grn> [anim.grn ...] [-fps N]

    Output (little-endian) = the v1 layout (see grndump.c) with version 2 and exactly one pose (the bind pose,
    unskinned render positions), followed by a trailer:
      "GDM2"
      u32 nbones;  per bone: u32 len, name, i32 parent(-1 root), f32 pos[3], f32 quat[4] (xyzw), f32 ss[9] (row-major)   (rest, local)
      u32 nmeshes; per mesh:
          u32 nbindings; per binding: i32 bone, f32 bt[3], f32 B[9] (row-major)   (skinning = world[bone] * B * (v + bt))
          u32 nrender;   f32 pos[3*n], nrm[3*n], uv[2*n]
          per render vertex: u32 ninfl, ninfl x { u32 binding, f32 weight }      (all influences, unsorted)
          u32 nstates;   per state: i32 texture(-1), u32 src_blend, u32 dst_blend, u32 ntris, ntris*3 u16
      u32 nanims;  per anim: u32 len, name, f32 duration, u32 fps, u32 nframes,
                   per frame per bone: f32 pos[3], quat[4], ss[9]   (local, parent space; sampled by the runtime incl. root motion)
    Textures index = FileData texture index (shared with the v1 texture table).                                    */
#include "granny_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
using namespace granny_internal;

static std::vector<unsigned char> *out;
static void wbytes(const void *p, size_t n) { const unsigned char *b = (const unsigned char *)p; out->insert(out->end(), b, b + n); }
static void w32(u32 v) { wbytes(&v, 4); }
static void wi32(int v) { wbytes(&v, 4); }
static void wf(const float *p, int n) { wbytes(p, 4 * (size_t)n); }
static void wstr(const std::string &s) { w32((u32)s.size()); wbytes(s.data(), s.size()); }

static std::string base(const char *p)
{
	std::string s(p);
	size_t a = s.find_last_of("/\\"); if (a != std::string::npos) s = s.substr(a + 1);
	size_t d = s.find_last_of('.'); if (d != std::string::npos) s.resize(d);
	return s;
}
static std::string dirof(const char *p)
{
	std::string s(p); size_t a = s.find_last_of("/\\");
	return a == std::string::npos ? "." : s.substr(0, a);
}

/* Library form of grndump2: returns the .gdmp v2 image in `result`. pos = { granny.dll, model.grn, anim.grn... }. */
bool grn_dump(const std::vector<std::string> &args, int fps, std::vector<unsigned char> &result, std::string &errmsg)
{
	std::vector<const char *> pos; pos.push_back("");   /* index 0 was the output path */
	for (size_t i = 0; i < args.size(); i++) pos.push_back(args[i].c_str());
	if (pos.size() < 3) { errmsg = "bad arguments"; return false; }
	out = &result;
	GrannyCompatSetDllPath(pos[1]);
	grn_set_dll_path(pos[1]);
	granny_uint32 ver, model[2], seq[2];
	GrannyOpenVersion("1.2b", "win32", "10-4-2000", "(C) Copyright 1999-2000 RAD Game Tools, Inc.  All Rights Reserved.", &ver);
	granny_result err = 0; std::vector<std::string> warn;
	FileData *g = grn_load(pos[2], &err, &warn);
	if (!g) { fprintf(stderr, "cannot load %s (err %d)\n", pos[2], (int)err); errmsg = std::string("cannot load ") + pos[2]; return false; }
	if (GrannyOpenModel(ver, pos[2], model) || GrannyOpenSequence(model[0], model[1], seq)) { errmsg = "granny open failed"; return false; }

	wbytes("GDMP", 4); w32(2);
	/* textures */
	w32((u32)g->textures.size());
	for (size_t i = 0; i < g->textures.size(); i++)
	{
		const TextureData &t = g->textures[i];
		w32(t.w); w32(t.h);
		if (t.bpp == 24 || t.bpp == 3) { wbytes(&t.pixels[0], (size_t)t.w * t.h * 3); }
		else { std::vector<unsigned char> z((size_t)t.w * t.h * 3, 128); wbytes(&z[0], z.size()); fprintf(stderr, "texture %zu bpp %u\n", i, t.bpp); }
	}
	/* pose 0 = bind pose, raw render positions */
	w32(1); wstr("bind"); w32(1); float secs = 0; wf(&secs, 1);
	size_t nst = 0; for (size_t m = 0; m < g->meshes.size(); m++) nst += g->meshes[m].states.size();
	w32((u32)nst);
	for (size_t m = 0; m < g->meshes.size(); m++)
	{
		const Mesh &M = g->meshes[m];
		for (size_t s = 0; s < M.states.size(); s++)
		{
			wi32(M.states[s].texture == 0xffffffffu ? -1 : (int)M.states[s].texture);
			w32(M.nrender);
			for (u32 v = 0; v < M.nrender; v++) { wf(&M.pos[v * 3], 3); wf(&M.nrm[v * 3], 3); wf(&M.uv[v * 3], 3); }
			w32((u32)M.states[s].tris.size() / 3);
			wbytes(&M.states[s].tris[0], 2 * M.states[s].tris.size());
		}
	}
	/* trailer */
	wbytes("GDM2", 4);
	w32((u32)g->bones.size());
	for (size_t i = 0; i < g->bones.size(); i++)
	{
		const BoneDef &b = g->bones[i];
		wstr(b.name); wi32(i == 0 ? -1 : b.parent);
		wf(b.rest.pos, 3); wf(b.rest.q, 4); wf(b.rest.ss, 9);
	}
	w32((u32)g->meshes.size());
	for (size_t m = 0; m < g->meshes.size(); m++)
	{
		const Mesh &M = g->meshes[m];
		w32((u32)M.bindings.size());
		for (size_t b = 0; b < M.bindings.size(); b++) { wi32((int)M.bindings[b].bone); wf(M.bindings[b].bt, 3); wf(M.bindings[b].B, 9); }
		w32(M.nrender);
		wf(&M.pos[0], M.nrender * 3); wf(&M.nrm[0], M.nrender * 3);
		for (u32 v = 0; v < M.nrender; v++) wf(&M.uv[v * 3], 2);
		/* influences per render vertex */
		std::vector<int> src(M.nrender, -1);
		if (!M.rigid())
		{
			for (u32 v = 0; v < M.nsource && v < M.nrender; v++) src[v] = (int)v;
			size_t p = 0;
			for (u32 v = 0; v < M.nsource && p < M.copies.size(); v++)
			{
				u32 cnt = M.copies[p++];
				for (u32 k = 0; k < cnt && p < M.copies.size(); k++) { u32 d = v + M.copies[p++]; if (d < M.nrender) src[d] = (int)v; }
			}
		}
		for (u32 v = 0; v < M.nrender; v++)
		{
			if (M.rigid() || src[v] < 0)
			{
				if (M.rigid() && !M.bindings.empty()) { w32(1); w32(0); float one = 1; wf(&one, 1); }
				else { w32(0); if (!M.rigid()) fprintf(stderr, "mesh %zu vertex %u has no source\n", m, v); }
			}
			else
			{
				const u32 *wl = &M.weights[M.wofs[src[v]]];
				w32(wl[0]);
				for (u32 k = 0; k < wl[0]; k++) { w32(wl[1 + 2 * k]); w32(wl[2 + 2 * k]); }
			}
		}
		w32((u32)M.states.size());
		for (size_t s = 0; s < M.states.size(); s++)
		{
			wi32(M.states[s].texture == 0xffffffffu ? -1 : (int)M.states[s].texture);
			w32(M.states[s].src_blend); w32(M.states[s].dst_blend);
			w32((u32)M.states[s].tris.size() / 3);
			wbytes(&M.states[s].tris[0], 2 * M.states[s].tris.size());
		}
	}
	/* animations */
	size_t nanim = pos.size() - 3;
	size_t cnt_pos = out->size(); w32(0);
	u32 written = 0;
	for (size_t a = 0; a < nanim; a++)
	{
		granny_uint32 an[2], ctl[3], seq[2];
		if (GrannyOpenSequence(model[0], model[1], seq)) continue;
		if (GrannyOpenAnimation(ver, pos[3 + a], an)) { fprintf(stderr, "animation %s failed\n", pos[3 + a]); continue; }
		FileData *af = grn_load(pos[3 + a], &err, 0);
		double dur = af ? af->duration : 0; delete af;
		if (GrannyAddControlledAnimation(seq[0], seq[1], an[0], an[1], ctl)) { fprintf(stderr, "control %s failed\n", pos[3 + a]); continue; }
		GrannySetAnimationParameter(ctl[0], ctl[1], ctl[2], 3, 1.0);
		float durf = (float)dur; wstr(base(pos[3 + a])); wf(&durf, 1); w32(fps);
		u32 nf = (u32)ceil(dur * fps - 1e-6) + 1; w32(nf);
		double clockv; GrannyGetCurrentTime(ver, &clockv);
		for (u32 f = 0; f < nf; f++)
		{
			if (f) GrannyAdvanceTime(ver, 1.0 / fps);
			for (size_t b = 0; b < g->bones.size(); b++)
			{
				granny_transform_state st;
				GrannyGetBoneState(seq[0], seq[1], (granny_uint32)b, 0x1ff, &st);
				float ss[9];
				for (int r = 0; r < 3; r++) for (int c = 0; c < 3; c++) ss[r * 3 + c] = st.scale_shear[c * 3 + r];
				wf(st.position, 3); wf(st.quaternion, 4); wf(ss, 9);
			}
		}
		GrannyRemoveControlledAnimation(ctl[0], ctl[1], ctl[2]);
		GrannyCloseSequence(seq[0], seq[1]);
		GrannyCloseAnimation(an[0], an[1]);
		written++;
			}
	memcpy(&result[cnt_pos], &written, 4);
	return true;
}

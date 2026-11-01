/* 3ds Max ASCII export (.ASE) of Neutron 1 / 2 -> .glb (mesh + UVs + texture + morph-target vertex animation).
   C++ port of tools/ase/ase2gltf.py (neutron2 branch gltf-export), which follows the engine's own reader
   (OMediaASEConverter): MESH_VERTEX as is (node TM not applied), game Max Z-up -> glTF (x, z, -y), UV v = 1 - v_max,
   key time = TIMEVALUE / 4800 s, each key is a morph target driven by one glTF weights animation. */
#include "converters.h"
#include "glb.h"
#include "m4.h"
#include <dirent.h>
#include <map>
#include <memory>
#include <regex>
#include <sstream>
#include <fstream>
#include <godot_cpp/classes/file_access.hpp>

using namespace godot;

namespace na {
namespace {

struct TNode { std::string key, args; std::vector<TNode> kids; bool block = false; };

std::string trim(const std::string &s) { size_t a = s.find_first_not_of(" \t\r\n"), b = s.find_last_not_of(" \t\r\n"); return a == std::string::npos ? "" : s.substr(a, b - a + 1); }

void parse_tree(const std::string &text, std::vector<TNode> &root)
{
	std::vector<size_t> open;   // index path of the currently open block
	std::istringstream in(text); std::string ln;
	while (std::getline(in, ln))
	{
		std::string s = trim(ln);
		if (s.empty()) continue;
		if (s == "}") { if (!open.empty()) open.pop_back(); continue; }
		if (s[0] != '*') continue;
		bool opens = s.back() == '{';
		if (opens) s = trim(s.substr(0, s.size() - 1));
		TNode n; size_t sp = s.find(' ');
		n.key = s.substr(1, sp == std::string::npos ? std::string::npos : sp - 1);
		n.args = sp == std::string::npos ? "" : trim(s.substr(sp + 1));
		n.block = opens;
		std::vector<TNode> *v = &root;
		for (size_t i : open) v = &(*v)[i].kids;
		v->push_back(std::move(n));
		if (opens) open.push_back(v->size() - 1);
	}
}

std::vector<double> fl(const std::string &s)
{
	std::vector<double> r; std::istringstream is(s); std::string t;
	while (is >> t) r.push_back(atof(t.c_str()));
	return r;
}
std::string unq(const std::string &s) { size_t a = s.find('"'); if (a == std::string::npos) return trim(s); size_t b = s.rfind('"'); return s.substr(a + 1, b > a ? b - a - 1 : std::string::npos); }

struct Mesh
{
	int time = 0;
	std::vector<std::array<double, 3>> verts; bool has_verts = false;
	std::vector<std::array<int, 3>> faces; std::vector<int> mtlid; bool has_faces = false;
	std::vector<std::array<double, 2>> tverts; bool has_tverts = false;
	std::map<int, std::array<int, 3>> tfaces;
	std::vector<std::array<double, 3>> cverts; bool has_cverts = false;
	std::map<int, std::array<int, 3>> cfaces;
	std::map<std::pair<int, int>, std::array<double, 3>> vn;
};
struct Mat { std::string name; double diffuse[3] = { 0.8, 0.8, 0.8 }, transp = 0; std::string bitmap; std::vector<Mat> subs; };
struct Obj { std::string name; int mat = -1; double R[3][3] = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }; Mesh base; bool has_base = false; std::vector<Mesh> frames; };

const TNode *child(const std::vector<TNode> &ch, const char *key) { for (auto &n : ch) if (n.key == key) return &n; return nullptr; }

Mesh parse_mesh(const std::vector<TNode> &ch)
{
	Mesh m;
	static const std::regex face_re(R"((\d+):\s*A:\s*(\d+)\s*B:\s*(\d+)\s*C:\s*(\d+))");
	static const std::regex mtl_re(R"(\*MESH_MTLID\s+(\d+))");
	for (auto &n : ch)
	{
		if (n.key == "TIMEVALUE") m.time = atoi(n.args.c_str());
		else if (n.key == "MESH_VERTEX_LIST")
		{
			std::map<int, std::array<double, 3>> v;
			for (auto &k : n.kids) if (k.key == "MESH_VERTEX") { auto t = fl(k.args); if (t.size() >= 4) v[(int)t[0]] = { t[1], t[2], t[3] }; }
			for (size_t i = 0; i < v.size(); i++) m.verts.push_back(v[(int)i]);
			m.has_verts = true;
		}
		else if (n.key == "MESH_FACE_LIST")
		{
			std::map<int, std::array<int, 3>> fs; std::map<int, int> mid;
			for (auto &k : n.kids) if (k.key == "MESH_FACE")
			{
				std::smatch g;
				if (!std::regex_search(k.args, g, face_re)) continue;
				int f = atoi(g[1].str().c_str());
				fs[f] = { atoi(g[2].str().c_str()), atoi(g[3].str().c_str()), atoi(g[4].str().c_str()) };
				std::smatch mm; mid[f] = std::regex_search(k.args, mm, mtl_re) ? atoi(mm[1].str().c_str()) : 0;
			}
			for (size_t i = 0; i < fs.size(); i++) { m.faces.push_back(fs[(int)i]); m.mtlid.push_back(mid[(int)i]); }
			m.has_faces = true;
		}
		else if (n.key == "MESH_TVERTLIST")
		{
			for (auto &k : n.kids) if (k.key == "MESH_TVERT") { auto t = fl(k.args); if (t.size() >= 3) m.tverts.push_back({ t[1], t[2] }); }
			m.has_tverts = true;
		}
		else if (n.key == "MESH_TFACELIST")
		{
			for (auto &k : n.kids) if (k.key == "MESH_TFACE") { auto t = fl(k.args); if (t.size() >= 4) m.tfaces[(int)t[0]] = { (int)t[1], (int)t[2], (int)t[3] }; }
		}
		else if (n.key == "MESH_CVERTLIST")
		{
			for (auto &k : n.kids) if (k.key == "MESH_VERTCOL") { auto t = fl(k.args); if (t.size() >= 4) m.cverts.push_back({ t[1], t[2], t[3] }); }
			m.has_cverts = true;
		}
		else if (n.key == "MESH_CFACELIST")
		{
			for (auto &k : n.kids) if (k.key == "MESH_CFACE") { auto t = fl(k.args); if (t.size() >= 4) m.cfaces[(int)t[0]] = { (int)t[1], (int)t[2], (int)t[3] }; }
		}
		else if (n.key == "MESH_NORMALS")
		{
			int f = -1;
			for (auto &k : n.kids)
			{
				if (k.key == "MESH_FACENORMAL") f = (int)fl(k.args)[0];
				else if (k.key == "MESH_VERTEXNORMAL") { auto t = fl(k.args); if (t.size() >= 4) m.vn[{ f, (int)t[0] }] = { t[1], t[2], t[3] }; }
			}
		}
	}
	return m;
}

Mat parse_material(const std::vector<TNode> &ch)
{
	Mat d;
	for (auto &n : ch)
	{
		if (n.key == "MATERIAL_NAME") d.name = unq(n.args);
		else if (n.key == "MATERIAL_DIFFUSE") { auto t = fl(n.args); for (int i = 0; i < 3 && i < (int)t.size(); i++) d.diffuse[i] = t[i]; }
		else if (n.key == "MATERIAL_TRANSPARENCY") { auto t = fl(n.args); if (!t.empty()) d.transp = t[0]; }
		else if (n.key == "MAP_DIFFUSE") { const TNode *b = child(n.kids, "BITMAP"); if (b) d.bitmap = unq(b->args); }
		else if (n.key == "SUBMATERIAL") d.subs.push_back(parse_material(n.kids));
	}
	return d;
}

bool load_ase(const std::string &path, std::vector<Mat> &mats, std::vector<Obj> &objs)
{
	std::ifstream f(path, std::ios::binary);
	if (!f) return false;
	std::stringstream ss; ss << f.rdbuf();
	std::vector<TNode> tree; parse_tree(ss.str(), tree);
	for (auto &n : tree) if (n.key == "MATERIAL_LIST") for (auto &c : n.kids) if (c.key == "MATERIAL") mats.push_back(parse_material(c.kids));
	for (auto &n : tree)
	{
		if (n.key != "GEOMOBJECT") continue;
		Obj o; bool named = false;
		for (auto &c : n.kids)
		{
			if (c.key == "NODE_NAME" && !named) { o.name = unq(c.args); named = !o.name.empty(); }
			else if (c.key == "MATERIAL_REF") o.mat = atoi(c.args.c_str());
			else if (c.key == "NODE_TM")
			{
				std::map<std::string, std::vector<double>> rows;
				for (auto &r : c.kids) if (r.key.compare(0, 6, "TM_ROW") == 0 && r.key != "TM_ROW3") rows[r.key] = fl(r.args);
				if (rows.size() == 3) for (int i = 0; i < 3; i++) { auto &r = rows["TM_ROW" + std::to_string(i)]; for (int j = 0; j < 3 && j < (int)r.size(); j++) o.R[i][j] = r[j]; }
			}
			else if (c.key == "MESH") { o.base = parse_mesh(c.kids); o.has_base = true; }
			else if (c.key == "MESH_ANIMATION") for (auto &m : c.kids) if (m.key == "MESH") o.frames.push_back(parse_mesh(m.kids));
		}
		objs.push_back(std::move(o));
	}
	return true;
}

std::string find_png(const std::string &dir, const std::string &name)
{
	if (dir.empty()) return "";
	DIR *d = opendir(dir.c_str());
	if (!d) return "";
	std::string want = name, res;
	for (auto &c : want) c = (char)tolower((unsigned char)c);
	while (dirent *e = readdir(d))
	{
		std::string f = e->d_name, l = f;
		for (auto &c : l) c = (char)tolower((unsigned char)c);
		if (l == want) { res = dir + "/" + f; break; }
	}
	closedir(d);
	return res;
}
std::string bitmap_png(const std::string &dir, const std::string &bitmap)
{
	size_t sl = bitmap.find_last_of("/\\");
	std::string base = sl == std::string::npos ? bitmap : bitmap.substr(sl + 1);
	size_t dot = base.find_last_of('.');
	std::string stem = dot == std::string::npos ? base : base.substr(0, dot);
	std::string r = find_png(dir, stem + ".png");
	return r.empty() ? find_png(dir, base) : r;
}

typedef std::array<double, 3> V3;
V3 mx2gl(const V3 &p, double scale) { return { p[0] * scale, p[2] * scale, -p[1] * scale }; }

}  // namespace

bool ase_to_glb(const std::string &path, const std::string &png_dir, const AseOptions &op, const std::string &out_path, std::string &err)
{
	std::vector<Mat> mats; std::vector<Obj> objs;
	if (!load_ase(path, mats, objs)) { err = "cannot read " + path; return false; }
	if (objs.empty()) { err = "no objects in " + path; return false; }
	if (!op.uv_from.empty())
	{
		std::vector<Mat> dmats; std::vector<Obj> dobjs;
		if (load_ase(op.uv_from, dmats, dobjs) && !dobjs.empty())
		{
			const Mesh &d = dobjs[0].base; Obj &o = objs[0];
			Mesh &tgt = o.has_base ? o.base : o.frames[0];
			if (d.faces.size() == tgt.faces.size())
			{
				if (d.has_tverts) { tgt.tverts = d.tverts; tgt.has_tverts = true; }
				if (!d.tfaces.empty()) tgt.tfaces = d.tfaces;
				if (d.has_cverts) { tgt.cverts = d.cverts; tgt.has_cverts = true; }
				if (!d.cfaces.empty()) tgt.cfaces = d.cfaces;
				if (!d.mtlid.empty()) tgt.mtlid = d.mtlid;
				mats = dmats; o.mat = dobjs[0].mat;
			}
		}
	}
	size_t sl = out_path.find_last_of("/\\"), dt = out_path.find_last_of('.');
	std::string stem = out_path.substr(sl == std::string::npos ? 0 : sl + 1, dt - (sl == std::string::npos ? 0 : sl + 1));

	Glb gl; Dictionary doc;
	Array nodes, meshes, materials, texs, images, samplers;
	{ Dictionary s; s["magFilter"] = 9729; s["minFilter"] = 9987; s["wrapS"] = 10497; s["wrapT"] = 10497; samplers.push_back(s); }
	Array root_children;
	{ Dictionary n; n["name"] = String(stem.c_str()); nodes.push_back(n); }
	if (op.unlit) { Array eu; eu.push_back("KHR_materials_unlit"); doc["extensionsUsed"] = eu; }
	struct TexRef { int idx; double clear, part; };
	std::map<std::string, TexRef> tex_cache; std::map<const Mat *, int> mat_cache;

	auto texture = [&](const std::string &p) -> TexRef {
		auto it = tex_cache.find(p);
		if (it != tex_cache.end()) return it->second;
		Ref<Image> im = Image::load_from_file(String(p.c_str()));
		TexRef t{ -1, 0, 0 };
		if (im.is_null() || im->is_empty()) return tex_cache[p] = t;
		im->convert(Image::FORMAT_RGBA8);
		PackedByteArray d = im->get_data(); int64_t n = d.size() / 4, cl = 0, pt = 0;
		for (int64_t i = 0; i < n; i++) { uint8_t a = d[i * 4 + 3]; if (a == 0) cl++; else if (a < 255) pt++; }
		t.clear = n ? (double)cl / n : 0; t.part = n ? (double)pt / n : 0;
		if (cl == 0 && pt == 0) im->convert(Image::FORMAT_RGB8);
		PackedByteArray png = im->save_png_to_buffer();
		size_t b = p.find_last_of('/');
		Dictionary id; id["bufferView"] = gl.view(png.ptr(), (size_t)png.size()); id["mimeType"] = "image/png"; id["name"] = String(p.substr(b == std::string::npos ? 0 : b + 1).c_str());
		images.push_back(id);
		Dictionary tx; tx["source"] = (int)images.size() - 1; tx["sampler"] = 0; texs.push_back(tx);
		t.idx = (int)texs.size() - 1;
		return tex_cache[p] = t;
	};
	auto material = [&](const Mat *m) {
		auto it = mat_cache.find(m);
		if (it != mat_cache.end()) return it->second;
		std::string pngp;
		if (!op.tex.empty()) pngp = find_png(png_dir, op.tex);
		else if (m && !m->bitmap.empty()) pngp = bitmap_png(png_dir, m->bitmap);
		double dif[3] = { 0.8, 0.8, 0.8 }; if (m) for (int i = 0; i < 3; i++) dif[i] = m->diffuse[i];
		auto rnd = [](double v) { return std::round(v * 10000.0) / 10000.0; };
		Dictionary pbr, mm; double bc[4];
		if (!pngp.empty()) { bc[0] = bc[1] = bc[2] = bc[3] = 1; } else { for (int i = 0; i < 3; i++) bc[i] = rnd(dif[i]); bc[3] = 1; }
		pbr["metallicFactor"] = 0.0; pbr["roughnessFactor"] = 1.0;
		mm["name"] = String(m && !m->name.empty() ? m->name.c_str() : "default"); mm["doubleSided"] = op.double_sided;
		double alpha = 1.0 - (m ? m->transp : 0.0);
		if (!pngp.empty())
		{
			TexRef t = texture(pngp);
			if (t.idx >= 0)
			{
				Dictionary bt; bt["index"] = t.idx; pbr["baseColorTexture"] = bt;
				if (t.part > 0.05) mm["alphaMode"] = "BLEND";
				else if (t.clear > 0) { mm["alphaMode"] = "MASK"; mm["alphaCutoff"] = 0.5; }
			}
		}
		if (alpha < 0.999) { bc[3] = rnd(alpha); mm["alphaMode"] = "BLEND"; }
		pbr["baseColorFactor"] = arr4(bc[0], bc[1], bc[2], bc[3]);
		mm["pbrMetallicRoughness"] = pbr;
		if (op.unlit) { Dictionary e, u; e["KHR_materials_unlit"] = u; mm["extensions"] = e; }
		materials.push_back(mm);
		return mat_cache[m] = (int)materials.size() - 1;
	};

	Array a_samplers, a_channels; double tmax = 0;
	std::map<std::string, int> names;
	for (Obj &o : objs)
	{
		Mesh *basep = o.has_base ? &o.base : (o.frames.empty() ? nullptr : &o.frames[0]);
		if (!basep || !basep->has_faces || !basep->has_verts) continue;
		Mesh &base = *basep;
		std::vector<Mesh> &frames = o.frames;
		if (op.center)
		{
			V3 lo = base.verts[0], hi = base.verts[0];
			for (auto &v : base.verts) for (int k = 0; k < 3; k++) { lo[k] = std::min(lo[k], v[k]); hi[k] = std::max(hi[k], v[k]); }
			V3 c0 = { (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2, (lo[2] + hi[2]) / 2 };
			std::vector<Mesh *> all{ &base };
			for (auto &f : frames) if (&f != &base) all.push_back(&f);
			for (Mesh *m : all) if (m->has_verts) for (auto &v : m->verts) for (int k = 0; k < 3; k++) v[k] -= c0[k];
		}
		double Ri[3][3]; if (!inv3(o.R, Ri)) { for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) Ri[i][j] = i == j; }
		auto computed = [&](const Mesh &m) {
			std::vector<V3> N(m.verts.size(), V3{ 0, 0, 0 });
			for (auto &f : m.faces)
			{
				const V3 &a = m.verts[f[0]], &b = m.verts[f[1]], &c = m.verts[f[2]];
				V3 u = { b[0] - a[0], b[1] - a[1], b[2] - a[2] }, w = { c[0] - a[0], c[1] - a[1], c[2] - a[2] };
				V3 n = { u[1] * w[2] - u[2] * w[1], u[2] * w[0] - u[0] * w[2], u[0] * w[1] - u[1] * w[0] };
				for (int k : f) for (int j = 0; j < 3; j++) N[k][j] += n[j];
			}
			for (auto &n : N) { double l = std::sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]); if (l == 0) l = 1; for (int j = 0; j < 3; j++) n[j] /= l; }
			return N;
		};
		auto normal_of = [&](const Mesh &m, int f, int v, V3 &out) {
			auto it = m.vn.find({ f, v });
			if (it == m.vn.end()) return false;
			V3 n = it->second, r;
			for (int i = 0; i < 3; i++) r[i] = Ri[i][0] * n[0] + Ri[i][1] * n[1] + Ri[i][2] * n[2];
			double l = std::sqrt(r[0] * r[0] + r[1] * r[1] + r[2] * r[2]);
			if (l > 0) for (int i = 0; i < 3; i++) r[i] /= l;
			out = r; return true;
		};
		std::vector<V3> base_fb = computed(base);
		std::vector<std::vector<V3>> frame_fb;
		for (auto &fr : frames) frame_fb.push_back(fr.has_verts && !fr.faces.empty() ? computed(fr) : base_fb);
		auto frame_norm = [&](const Mesh &m, int f, int v, const std::vector<V3> &fb) { V3 n; if (normal_of(m, f, v, n)) return n; return fb[v]; };

		const Mat *mat = (o.mat >= 0 && o.mat < (int)mats.size()) ? &mats[o.mat] : nullptr;
		const std::vector<Mat> *subs = (mat && !mat->subs.empty()) ? &mat->subs : nullptr;
		std::vector<const Mat *> gorder; std::map<const Mat *, std::vector<int>> groups;
		for (size_t f = 0; f < base.faces.size(); f++)
		{
			int mid = f < base.mtlid.size() ? base.mtlid[f] : 0;
			const Mat *m = subs ? &(*subs)[mid % subs->size()] : mat;
			if (!groups.count(m)) gorder.push_back(m);
			groups[m].push_back((int)f);
		}
		bool anim = frames.size() > 1 || (!frames.empty() && o.has_base);
		Array prims;
		for (const Mat *m : gorder)
		{
			std::map<std::array<int, 6>, int> keyd; struct Corner { int f, v, ti, ci; };
			std::vector<Corner> corners; std::vector<uint32_t> idx;
			for (int f : groups[m])
				for (int ci = 0; ci < 3; ci++)
				{
					int v = base.faces[f][ci];
					auto tf = base.tfaces.find(f); int ti = tf != base.tfaces.end() ? tf->second[ci] : -1;
					auto cf = base.cfaces.find(f); int cii = cf != base.cfaces.end() ? cf->second[ci] : -1;
					V3 n; if (!normal_of(base, f, v, n)) n = base_fb[v];
					std::array<int, 6> k = { v, ti, cii, (int)std::lrint(n[0] * 1000), (int)std::lrint(n[1] * 1000), (int)std::lrint(n[2] * 1000) };
					auto it = keyd.find(k);
					if (it == keyd.end()) { it = keyd.insert({ k, (int)corners.size() }).first; corners.push_back({ f, v, ti, cii }); }
					idx.push_back((uint32_t)it->second);
				}
			size_t nc = corners.size();
			std::vector<float> pos(nc * 3), nrm(nc * 3), uv(nc * 2, 0.f), col;
			std::vector<V3> pos_d(nc), nrm_d(nc);
			for (size_t i = 0; i < nc; i++)
			{
				pos_d[i] = mx2gl(base.verts[corners[i].v], op.scale);
				V3 n = mx2gl(frame_norm(base, corners[i].f, corners[i].v, base_fb), 1.0); nrm_d[i] = n;
				for (int k = 0; k < 3; k++) { pos[i * 3 + k] = (float)pos_d[i][k]; nrm[i * 3 + k] = (float)n[k]; }
				if (base.has_tverts && corners[i].ti >= 0 && corners[i].ti < (int)base.tverts.size())
				{ uv[i * 2] = (float)base.tverts[corners[i].ti][0]; uv[i * 2 + 1] = (float)(1.0 - base.tverts[corners[i].ti][1]); }
			}
			Dictionary attrs;
			attrs["POSITION"] = gl.accF3(pos, 34962, true); attrs["NORMAL"] = gl.accF3(nrm, 34962);
			if (base.has_tverts) attrs["TEXCOORD_0"] = gl.accF2(uv, 34962);
			if (base.has_cverts && !base.cfaces.empty())
			{
				col.resize(nc * 3);
				for (size_t i = 0; i < nc; i++)
					for (int k = 0; k < 3; k++)
					{
						double c = (corners[i].ci >= 0 && corners[i].ci < (int)base.cverts.size()) ? base.cverts[corners[i].ci][k] : 1.0;
						col[i * 3 + k] = (float)std::min(1.0, std::max(0.0, c));
					}
				attrs["COLOR_0"] = gl.accF3(col, 34962);
			}
			Dictionary p; p["attributes"] = attrs; p["indices"] = gl.acc(idx.data(), idx.size(), U32, "SCALAR", 1, 34963); p["mode"] = 4; p["material"] = material(m);
			if (anim)
			{
				Array targets;
				for (size_t fi = 0; fi < frames.size(); fi++)
				{
					const Mesh &fr = frames[fi];
					std::vector<float> dp(nc * 3, 0.f), dn(nc * 3, 0.f);
					if (fr.has_verts && fr.verts.size() == base.verts.size())
					{
						for (size_t i = 0; i < nc; i++)
						{
							V3 fp = mx2gl(fr.verts[corners[i].v], op.scale), fn = mx2gl(frame_norm(fr, corners[i].f, corners[i].v, frame_fb[fi]), 1.0);
							for (int k = 0; k < 3; k++) { dp[i * 3 + k] = (float)(fp[k] - pos_d[i][k]); dn[i * 3 + k] = (float)(fn[k] - nrm_d[i][k]); }
						}
					}
					Dictionary t; t["POSITION"] = gl.accF3(dp, 34962, true); t["NORMAL"] = gl.accF3(dn, 34962);
					targets.push_back(t);
				}
				p["targets"] = targets;
			}
			prims.push_back(p);
		}
		int cnt = ++names[o.name];
		std::string nm = cnt == 1 ? o.name : o.name + "_" + std::to_string(cnt);
		Dictionary mesh; mesh["name"] = String(nm.c_str()); mesh["primitives"] = prims;
		size_t nt = anim ? frames.size() : 0;
		if (nt) { Array w; for (size_t i = 0; i < nt; i++) w.push_back(0.0); mesh["weights"] = w; }
		meshes.push_back(mesh);
		Dictionary node; node["name"] = String(nm.c_str()); node["mesh"] = (int)meshes.size() - 1; nodes.push_back(node);
		int ni = (int)nodes.size() - 1; root_children.push_back(ni);
		if (nt)
		{
			std::vector<float> times(nt); bool inc = true;
			for (size_t i = 0; i < nt; i++) times[i] = (float)((frames[i].time - frames[0].time) / 4800.0);
			for (size_t i = 1; i < nt; i++) if (!(times[i] > times[i - 1])) inc = false;
			tmax = std::max(tmax, (double)times[nt - 1]);
			if (nt > 1 && inc)
			{
				std::vector<float> W(nt * nt, 0.f); for (size_t i = 0; i < nt; i++) W[i * nt + i] = 1.f;
				Dictionary s; s["input"] = gl.acc(times.data(), nt, F32, "SCALAR", 1, 0, true); s["output"] = gl.acc(W.data(), W.size(), F32, "SCALAR", 1); s["interpolation"] = "LINEAR";
				a_samplers.push_back(s);
				Dictionary tg; tg["node"] = ni; tg["path"] = "weights";
				Dictionary ch; ch["sampler"] = (int)a_samplers.size() - 1; ch["target"] = tg; a_channels.push_back(ch);
			}
		}
	}
	{ Dictionary n0 = nodes[0]; n0["children"] = root_children; }
	if (!a_channels.is_empty())
	{
		Dictionary an; an["name"] = String((op.loop ? stem + "-loop" : stem).c_str()); an["samplers"] = a_samplers; an["channels"] = a_channels;
		Array al; al.push_back(an); doc["animations"] = al;
	}
	{ Dictionary a; a["version"] = "2.0"; a["generator"] = "naimport ase2gltf"; doc["asset"] = a; }
	doc["scene"] = 0; { Array s; Dictionary sc; Array sn; sn.push_back(0); sc["nodes"] = sn; s.push_back(sc); doc["scenes"] = s; }
	doc["nodes"] = nodes; doc["meshes"] = meshes;
	if (!materials.is_empty()) doc["materials"] = materials;
	if (!texs.is_empty()) { doc["textures"] = texs; doc["samplers"] = samplers; }
	if (!images.is_empty()) doc["images"] = images;
	doc["bufferViews"] = gl.views; doc["accessors"] = gl.accs;
	{ Array b; Dictionary bd; bd["byteLength"] = (int64_t)gl.bin.size(); b.push_back(bd); doc["buffers"] = b; }
	if (!write_glb(out_path, doc, gl.bin)) { err = "cannot write " + out_path; return false; }
	return true;
}

}  // namespace na

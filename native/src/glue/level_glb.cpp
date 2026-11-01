/* OMT shapes -> static glTF 2.0 level.  C++ port of tools/omt/omt2gltf.py (neutron2 branch gltf-export), default options
   (scale 1.0, Z mirrored to go from the left-handed OMT space to glTF, winding auto-detected from the flat street/park polygons).
     <name>            root
       Level           ONE mesh, one primitive per (material, two-sided): the visible world
       Collision/*-colonly   polygons without a material (and shapes named block, colli, corner, rampblock or *_collision):
                       Godot turns "-colonly" nodes into trimesh collision
       Markers/*       untextured helper shapes (ik_turn ...)                                                                */
#include "converters.h"
#include "glb.h"
#include <algorithm>
#include <map>

using namespace godot;

namespace na {
namespace {

std::string lower(std::string s) { for (auto &c : s) c = (char)tolower((unsigned char)c); return s; }
bool starts(const std::string &s, const char *p) { return s.compare(0, strlen(p), p) == 0; }

struct V3 { double x, y, z; };
V3 newell(const std::vector<V3> &P)
{
	V3 n{ 0, 0, 0 };
	for (size_t i = 0; i < P.size(); i++)
	{
		const V3 &a = P[i], &b = P[(i + 1) % P.size()];
		n.x += (a.y - b.y) * (a.z + b.z); n.y += (a.z - b.z) * (a.x + b.x); n.z += (a.x - b.x) * (a.y + b.y);
	}
	return n;
}

struct Prim
{
	std::vector<float> pos, nrm, uv; std::vector<uint32_t> idx; uint32_t n = 0;
	void add(const std::vector<V3> &P, const V3 &N, const std::vector<std::pair<double, double>> &UV)
	{
		for (size_t i = 0; i < P.size(); i++)
		{
			pos.push_back((float)P[i].x); pos.push_back((float)P[i].y); pos.push_back((float)P[i].z);
			nrm.push_back((float)N.x); nrm.push_back((float)N.y); nrm.push_back((float)N.z);
			uv.push_back((float)UV[i].first); uv.push_back((float)UV[i].second);
		}
		size_t k = P.size();
		for (size_t i = 1; i + 1 < k; i++) { idx.push_back(n); idx.push_back(n + (uint32_t)i); idx.push_back(n + (uint32_t)i + 1); }
		n += (uint32_t)k;
	}
};
typedef std::pair<int, bool> Key;   // (material id, two sided); nomat polys use (0,false)
struct Group { std::vector<Key> order; std::map<Key, Prim> m; Prim &get(const Key &k) { if (!m.count(k)) order.push_back(k); return m[k]; } };

struct Poly { Key key; const OdPoly *p; };

}  // namespace

bool omt_to_glb(const OdDump &d, const std::string &name, const std::string &out_path, std::string &err)
{
	const bool mirror_z = true;
	// winding: +1 if the listed order is CCW seen from +Y on level ground
	double ws = 0;
	for (auto &sh : d.shapes)
	{
		std::string ln = lower(sh.name);
		if (!(starts(ln, "street") || starts(ln, "strteet") || starts(ln, "main") || starts(ln, "park") || starts(ln, "grassf"))) continue;
		for (auto &p : sh.polys)
		{
			if (p.mat < 0) continue;
			std::vector<V3> P;
			for (unsigned vi : p.vi) P.push_back({ sh.v[vi * 3], sh.v[vi * 3 + 1], sh.v[vi * 3 + 2] });
			V3 n = newell(P); double l = std::sqrt(n.x * n.x + n.y * n.y + n.z * n.z);
			if (std::fabs(n.y) > 0.9 * l && l > 0) ws += n.y > 0 ? 1 : -1;
		}
	}
	int wind = ws >= 0 ? 1 : -1;
	bool reverse = (wind > 0) == mirror_z;
	const double sx[3] = { 1, 1, mirror_z ? -1.0 : 1.0 };

	Glb gl; Dictionary doc;
	Array nodes, meshes, materials, texs, images, samplers;
	{ Dictionary s; s["magFilter"] = 9729; s["minFilter"] = 9987; s["wrapS"] = 10497; s["wrapT"] = 10497; samplers.push_back(s); }
	std::map<int, std::pair<int, PngInfo>> tex_idx; std::map<int, bool> tex_missing;
	std::map<Key, int> mat_idx;

	auto texture = [&](int tid) -> const std::pair<int, PngInfo> * {
		auto it = tex_idx.find(tid);
		if (it != tex_idx.end()) return &it->second;
		auto pi = d.png.find(tid);
		if (pi == d.png.end()) return nullptr;
		const std::vector<unsigned char> &png = pi->second;
		Dictionary im; im["bufferView"] = gl.view(png.data(), png.size()); im["mimeType"] = "image/png"; im["name"] = String("tex") + String::num_int64(tid);
		images.push_back(im);
		Dictionary tx; tx["sampler"] = 0; tx["source"] = (int)images.size() - 1; texs.push_back(tx);
		tex_idx[tid] = { (int)texs.size() - 1, png_info(png.data(), png.size()) };
		return &tex_idx[tid];
	};
	auto material = [&](const Key &k) {
		auto it = mat_idx.find(k);
		if (it != mat_idx.end()) return it->second;
		const OdMaterial &m = d.mats[k.first];
		const std::pair<int, PngInfo> *t = m.tex >= 0 ? texture(m.tex) : nullptr;
		Dictionary pbr, mm;
		auto rnd = [](double v) { return std::round(v * 10000.0) / 10000.0; };
		pbr["baseColorFactor"] = arr4(rnd(m.diffuse[0]), rnd(m.diffuse[1]), rnd(m.diffuse[2]), rnd(m.diffuse[3]));
		pbr["metallicFactor"] = 0.0; pbr["roughnessFactor"] = 1.0;
		mm["name"] = String(m.name.c_str()) + (k.second ? String("_2s") : String(""));
		mm["doubleSided"] = k.second;
		if (t)
		{
			Dictionary bt; bt["index"] = t->first; pbr["baseColorTexture"] = bt;
			if (t->second.part > 0.05) mm["alphaMode"] = "BLEND";
			else if (t->second.clear > 0.0) { mm["alphaMode"] = "MASK"; mm["alphaCutoff"] = 0.5; }
		}
		mm["pbrMetallicRoughness"] = pbr;
		materials.push_back(mm);
		return mat_idx[k] = (int)materials.size() - 1;
	};
	auto emit_poly = [&](Group &g, const Key &key, const OdShape &sh, const OdPoly &p) {
		std::vector<V3> P; std::vector<std::pair<double, double>> UV;
		for (size_t i = 0; i < p.vi.size(); i++)
		{
			unsigned vi = p.vi[i];
			P.push_back({ sh.v[vi * 3] * sx[0], sh.v[vi * 3 + 1] * sx[1], sh.v[vi * 3 + 2] * sx[2] });
			UV.push_back({ p.uv[i * 2], p.uv[i * 2 + 1] });
		}
		if (reverse) { std::reverse(P.begin(), P.end()); std::reverse(UV.begin(), UV.end()); }
		V3 n = newell(P); double l = std::sqrt(n.x * n.x + n.y * n.y + n.z * n.z);
		n = l > 0 ? V3{ n.x / l, n.y / l, n.z / l } : V3{ 0, 1, 0 };
		g.get(key).add(P, n, UV);
	};
	int tris = 0;
	auto write_prims = [&](Group &g, bool textured) {
		Array res;
		for (auto &k : g.order)
		{
			Prim &pr = g.m[k];
			if (pr.idx.empty()) continue;
			Dictionary at; at["POSITION"] = gl.accF3(pr.pos, 34962, true); at["NORMAL"] = gl.accF3(pr.nrm, 34962);
			if (textured) at["TEXCOORD_0"] = gl.accF2(pr.uv, 34962);
			Dictionary p; p["attributes"] = at; p["indices"] = gl.acc(pr.idx.data(), pr.idx.size(), U32, "SCALAR", 1, 34963); p["mode"] = 4;
			if (textured) p["material"] = material(k);
			tris += (int)pr.idx.size() / 3;
			res.push_back(p);
		}
		return res;
	};
	auto add_node = [&](const String &nm, int parent, int mesh = -1) {
		Dictionary n; n["name"] = nm; if (mesh >= 0) n["mesh"] = mesh;
		nodes.push_back(n); int i = (int)nodes.size() - 1;
		if (parent >= 0)
		{
			Dictionary pn = nodes[parent];
			Array ch = pn.has("children") ? Array(pn["children"]) : Array();
			ch.push_back(i); pn["children"] = ch;
		}
		return i;
	};
	auto add_mesh = [&](const Array &prims, const String &nm) { Dictionary m; m["name"] = nm; m["primitives"] = prims; meshes.push_back(m); return (int)meshes.size() - 1; };

	int root = add_node(String(name.c_str()), -1);
	int col_parent = add_node("Collision", root), mark_parent = add_node("Markers", root);
	Group world;
	for (auto &sh : d.shapes)
	{
		std::vector<Poly> vis; std::vector<const OdPoly *> nomat;
		for (auto &p : sh.polys)
		{
			if (p.flags & 4) continue;
			if (p.vi.size() < 3) continue;
			if (p.mat < 0) nomat.push_back(&p); else vis.push_back({ Key(p.mat, (p.flags & 2) != 0), &p });
		}
		std::string ln = lower(sh.name);
		bool name_col = starts(ln, "block") || starts(ln, "colli") || starts(ln, "corner") || starts(ln, "rampblock") || ln.find("_collision") != std::string::npos;
		bool iscol = name_col || (vis.empty() && !nomat.empty());
		bool allUntex = !vis.empty();
		for (auto &v : vis) if (d.mats[v.key.first].tex >= 0) { allUntex = false; break; }
		bool ismark = starts(ln, "ik_turn") || starts(ln, "ikturn") || allUntex;
		if (iscol && !vis.empty()) { for (auto &v : vis) nomat.push_back(v.p); vis.clear(); }
		if (ismark && !vis.empty() && !iscol)
		{
			Group g; for (auto &v : vis) emit_poly(g, Key(0, false), sh, *v.p);
			Array prims = write_prims(g, false);
			if (!prims.is_empty()) add_node(String(sh.name.c_str()), mark_parent, add_mesh(prims, String(sh.name.c_str())));
			vis.clear();
		}
		for (auto &v : vis) emit_poly(world, v.key, sh, *v.p);
		if (!nomat.empty())
		{
			Group g; for (auto *p : nomat) emit_poly(g, Key(0, false), sh, *p);
			Array prims = write_prims(g, false);
			if (!prims.is_empty())
			{
				String nm = String(sh.name.c_str()) + ((!vis.empty() || !iscol) ? String("_col") : String("")) + String("-colonly");
				add_node(nm, col_parent, add_mesh(prims, nm));
			}
		}
	}
	Array lp = write_prims(world, true);
	int lvl = add_node("Level", root, add_mesh(lp, "Level"));
	{
		Dictionary rn = nodes[root]; Array ch = rn["children"], nc;
		nc.push_back(lvl);
		for (int i = 0; i < ch.size(); i++) if ((int)ch[i] != lvl) nc.push_back(ch[i]);
		rn["children"] = nc;
	}
	for (int i = 0; i < nodes.size(); i++)
	{
		Dictionary nd = nodes[i];
		if (nd.has("children") && Array(nd["children"]).is_empty() && !nd.has("mesh")) nd.erase("children");
		if (!nd.has("mesh") && !nd.has("children")) {}
	}
	// empty containers keep no children entry
	{ Dictionary a; a["version"] = "2.0"; a["generator"] = "naimport omt2gltf"; doc["asset"] = a; }
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

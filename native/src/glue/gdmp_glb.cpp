/* gdmp (version 2, from grn_dump) -> binary glTF 2.0.  C++ port of tools/granny/gdmp2gltf.py (neutron2 branch gltf-export):
   meshes, UVs, normals, embedded PNG textures, the skeleton (one node per Granny bone), one skin per mesh, every animation
   sampled at the gdmp's frame rate.  Game space (Z up, facing -Y) -> glTF (Y up, facing +Z): (x, y, z) -> (x, z, -y).
   Root bones' translation is held at rest (no root motion). */
#include "converters.h"
#include "glb.h"
#include "m4.h"
#include <map>

using namespace godot;

namespace na {
namespace {

struct Reader
{
	const uint8_t *b; size_t n, p = 0; bool bad = false;
	Reader(const std::vector<uint8_t> &v) : b(v.data()), n(v.size()) {}
	uint32_t u32() { if (p + 4 > n) { bad = true; return 0; } uint32_t v; memcpy(&v, b + p, 4); p += 4; return v; }
	int32_t i32() { return (int32_t)u32(); }
	float f1() { uint32_t u = u32(); float f; memcpy(&f, &u, 4); return f; }
	void skip(size_t k) { if (p + k > n) { bad = true; p = n; } else p += k; }
	std::string str() { uint32_t l = u32(); if (p + l > n) { bad = true; return ""; } std::string s((const char *)b + p, l); p += l; return s; }
};

struct Bone { std::string name; int parent; double pos[3], q[4], ss[3][3]; };
struct Bind { int bone; double bt[3], B[3][3]; };
struct State { int tex; uint32_t src, dst; std::vector<uint16_t> tri; };
struct Mesh
{
	std::vector<Bind> bind; uint32_t n = 0;
	std::vector<double> pos, nrm, uv;
	std::vector<std::vector<std::pair<uint32_t, float>>> infl;
	std::vector<State> states;
};
struct Anim { std::string name; float duration; uint32_t fps, nf; std::vector<float> data; };
struct Tex { int w = 0, h = 0; std::vector<uint8_t> rgb; };

M4 local_matrix(const double *pos, const double *q, const double ss[3][3])
{
	M4 m = quat_mat(q, ss);
	for (int i = 0; i < 3; i++) m.m[i][3] = pos[i];
	return m;
}

}  // namespace

bool gdmp_to_glb(const std::vector<uint8_t> &gdmp, const std::string &out_path, std::string &err)
{
	Reader r(gdmp);
	if (gdmp.size() < 8 || memcmp(gdmp.data(), "GDMP", 4)) { err = "not a gdmp"; return false; }
	r.p = 8;
	std::vector<Tex> textures(r.u32());
	for (auto &t : textures)
	{
		t.w = (int)r.u32(); t.h = (int)r.u32();
		size_t sz = (size_t)t.w * t.h * 3;
		if (r.p + sz > r.n) { err = "truncated gdmp"; return false; }
		t.rgb.assign(r.b + r.p, r.b + r.p + sz); r.p += sz;
	}
	uint32_t nposes = r.u32();
	for (uint32_t i = 0; i < nposes && !r.bad; i++)
	{
		r.str(); uint32_t nframes = r.u32(); r.f1();
		for (uint32_t f = 0; f < nframes && !r.bad; f++)
		{
			uint32_t ns = r.u32();
			for (uint32_t s = 0; s < ns && !r.bad; s++) { r.i32(); uint32_t nv = r.u32(); r.skip((size_t)nv * 36); uint32_t nt = r.u32(); r.skip((size_t)nt * 6); }
		}
	}
	if (r.bad || r.p + 4 > r.n || memcmp(r.b + r.p, "GDM2", 4)) { err = "no GDM2 trailer"; return false; }
	r.p += 4;
	std::vector<Bone> bones(r.u32());
	for (auto &b : bones)
	{
		b.name = r.str(); b.parent = r.i32();
		for (int i = 0; i < 3; i++) b.pos[i] = r.f1();
		for (int i = 0; i < 4; i++) b.q[i] = r.f1();
		for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) b.ss[i][j] = r.f1();
	}
	std::vector<Mesh> meshes(r.u32());
	for (auto &m : meshes)
	{
		m.bind.resize(r.u32());
		for (auto &bd : m.bind)
		{
			bd.bone = r.i32();
			for (int i = 0; i < 3; i++) bd.bt[i] = r.f1();
			for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) bd.B[i][j] = r.f1();
		}
		m.n = r.u32();
		if (r.bad || (size_t)m.n * 32 > r.n) { err = "bad mesh"; return false; }
		m.pos.resize(m.n * 3); m.nrm.resize(m.n * 3); m.uv.resize(m.n * 2);
		for (auto &x : m.pos) x = r.f1();
		for (auto &x : m.nrm) x = r.f1();
		for (auto &x : m.uv) x = r.f1();
		m.infl.resize(m.n);
		for (uint32_t v = 0; v < m.n; v++)
		{
			uint32_t k = r.u32(); if (k > 1000) { err = "bad influences"; return false; }
			for (uint32_t i = 0; i < k; i++) { uint32_t bi = r.u32(); float w = r.f1(); m.infl[v].push_back({ bi, w }); }
		}
		m.states.resize(r.u32());
		for (auto &st : m.states)
		{
			st.tex = r.i32(); st.src = r.u32(); st.dst = r.u32(); uint32_t nt = r.u32();
			if (r.p + (size_t)nt * 6 > r.n) { err = "bad states"; return false; }
			st.tri.resize((size_t)nt * 3); memcpy(st.tri.data(), r.b + r.p, (size_t)nt * 6); r.p += (size_t)nt * 6;
		}
	}
	size_t nb = bones.size();
	std::vector<Anim> anims(r.u32());
	for (auto &a : anims)
	{
		a.name = r.str(); a.duration = r.f1(); a.fps = r.u32(); a.nf = r.u32();
		size_t cnt = (size_t)a.nf * nb * 16;
		if (r.p + cnt * 4 > r.n) { err = "bad anim"; return false; }
		a.data.resize(cnt); memcpy(a.data.data(), r.b + r.p, cnt * 4); r.p += cnt * 4;
	}
	if (r.bad) { err = "truncated gdmp"; return false; }

	// ------------------------------------------------------------------------------------------ build --
	M4 Z = m4id(); Z.m[1][1] = 0; Z.m[1][2] = 1; Z.m[2][1] = -1; Z.m[2][2] = 0;
	M4 C = Z, Ci = inverse(C);
	auto conv = [&](const M4 &M) { return mul(mul(C, M), Ci); };

	Glb gl; Dictionary doc;
	{ Dictionary a; a["version"] = "2.0"; a["generator"] = "naimport gdmp2gltf"; doc["asset"] = a; }
	Array nodes;
	std::vector<M4> rest_local(nb);
	for (size_t i = 0; i < nb; i++) rest_local[i] = local_matrix(bones[i].pos, bones[i].q, bones[i].ss);
	std::vector<std::vector<int>> children(nb); std::vector<int> roots;
	for (size_t i = 0; i < nb; i++) (bones[i].parent >= 0 ? children[bones[i].parent] : roots).push_back((int)i);
	std::vector<M4> restW(nb);
	for (size_t i = 0; i < nb; i++) restW[i] = bones[i].parent < 0 ? rest_local[i] : mul(restW[bones[i].parent], rest_local[i]);
	std::vector<std::array<double, 3>> rest_t(nb);
	for (size_t i = 0; i < nb; i++)
	{
		TRS d = decompose(conv(rest_local[i]));
		Dictionary nd; nd["name"] = String(bones[i].name.c_str());
		nd["translation"] = arr3(d.t[0], d.t[1], d.t[2]); nd["rotation"] = arr4(d.q[0], d.q[1], d.q[2], d.q[3]); nd["scale"] = arr3(d.s[0], d.s[1], d.s[2]);
		rest_t[i] = { d.t[0], d.t[1], d.t[2] };
		if (!children[i].empty()) { Array c; for (int k : children[i]) c.push_back(k); nd["children"] = c; }
		nodes.push_back(nd);
	}
	Array images, texs, samplers, materials;
	{ Dictionary s; s["magFilter"] = 9729; s["minFilter"] = 9987; s["wrapS"] = 10497; s["wrapT"] = 10497; samplers.push_back(s); }
	std::map<int, int> tex_node;
	for (size_t ti = 0; ti < textures.size(); ti++)
	{
		const Tex &t = textures[ti];
		if (t.w <= 0 || t.h <= 0) continue;
		PackedByteArray pb; pb.resize((int64_t)t.rgb.size()); memcpy(pb.ptrw(), t.rgb.data(), t.rgb.size());
		Ref<Image> im = Image::create_from_data(t.w, t.h, false, Image::FORMAT_RGB8, pb);
		PackedByteArray png = im->save_png_to_buffer();
		Dictionary i; i["bufferView"] = gl.view(png.ptr(), (size_t)png.size()); i["mimeType"] = "image/png"; i["name"] = String("tex") + String::num_int64((int64_t)ti);
		images.push_back(i);
		Dictionary tx; tx["sampler"] = 0; tx["source"] = (int)images.size() - 1; texs.push_back(tx);
		tex_node[(int)ti] = (int)texs.size() - 1;
	}
	std::map<std::tuple<int, uint32_t, uint32_t>, int> mat_cache;
	auto material = [&](int tex, uint32_t src, uint32_t dst) {
		auto key = std::make_tuple(tex, src, dst);
		auto it = mat_cache.find(key);
		if (it != mat_cache.end()) return it->second;
		Dictionary m, pbr;
		m["name"] = tex >= 0 ? String("tex") + String::num_int64(tex) : String("untextured");
		m["doubleSided"] = true;
		pbr["metallicFactor"] = 0.0; pbr["roughnessFactor"] = 1.0;
		if (tex_node.count(tex)) { pbr["baseColorFactor"] = arr4(1, 1, 1, 1); Dictionary bt; bt["index"] = tex_node[tex]; pbr["baseColorTexture"] = bt; }
		else pbr["baseColorFactor"] = arr4(0.75, 0.75, 0.75, 1);
		m["pbrMetallicRoughness"] = pbr;
		Dictionary ex; ex["src_blend"] = (int64_t)src; ex["dst_blend"] = (int64_t)dst; m["extras"] = ex;
		materials.push_back(m);
		return mat_cache[key] = (int)materials.size() - 1;
	};

	Array skins, gmeshes;
	for (size_t mi = 0; mi < meshes.size(); mi++)
	{
		Mesh &m = meshes[mi];
		size_t n = m.n;
		std::vector<float> P(n * 3), N(n * 3), UV(n * 2);
		for (size_t v = 0; v < n; v++)
		{
			const double *p = &m.pos[v * 3], *q = &m.nrm[v * 3];
			P[v * 3] = (float)p[0]; P[v * 3 + 1] = (float)p[2]; P[v * 3 + 2] = (float)-p[1];
			double nx = q[0], ny = q[2], nz = -q[1], l = std::max(std::sqrt(nx * nx + ny * ny + nz * nz), 1e-12);
			N[v * 3] = (float)(nx / l); N[v * 3 + 1] = (float)(ny / l); N[v * 3 + 2] = (float)(nz / l);
			UV[v * 2] = (float)m.uv[v * 2]; UV[v * 2 + 1] = (float)m.uv[v * 2 + 1];
		}
		bool skinned = !m.bind.empty();
		Dictionary attrs;
		attrs["POSITION"] = gl.accF3(P, 34962, true); attrs["NORMAL"] = gl.accF3(N, 34962); attrs["TEXCOORD_0"] = gl.accF2(UV, 34962);
		if (skinned)
		{
			std::vector<uint16_t> J(n * 4, 0); std::vector<float> W(n * 4, 0.f);
			size_t nbind = m.bind.size();
			for (size_t v = 0; v < n; v++)
			{
				std::vector<std::pair<int, double>> acc;   // insertion ordered, merged per bone
				for (auto &bw : m.infl[v])
				{
					if (bw.first >= nbind) continue;
					int bone = m.bind[bw.first].bone; bool found = false;
					for (auto &a : acc) if (a.first == bone) { a.second += bw.second; found = true; break; }
					if (!found) acc.push_back({ bone, bw.second });
				}
				std::stable_sort(acc.begin(), acc.end(), [](const std::pair<int, double> &a, const std::pair<int, double> &b) { return a.second > b.second; });
				if (acc.size() > 4) acc.resize(4);
				double tot = 0; for (auto &a : acc) tot += a.second;
				if (acc.empty() || tot <= 1e-9) { acc.clear(); acc.push_back({ 0, 1.0 }); tot = 1.0; }
				for (size_t k = 0; k < acc.size(); k++) { J[v * 4 + k] = (uint16_t)acc[k].first; W[v * 4 + k] = (float)(acc[k].second / tot); }
			}
			attrs["JOINTS_0"] = gl.acc(J.data(), n, U16, "VEC4", 4, 34962);
			attrs["WEIGHTS_0"] = gl.acc(W.data(), n, F32, "VEC4", 4, 34962);
		}
		Array prims;
		for (auto &st : m.states)
		{
			Dictionary pr; pr["attributes"] = attrs;
			pr["indices"] = gl.acc(st.tri.data(), st.tri.size(), U16, "SCALAR", 1, 34963);
			pr["material"] = material(st.tex, st.src, st.dst); pr["mode"] = 4;
			prims.push_back(pr);
		}
		Dictionary gm; gm["name"] = String("mesh") + String::num_int64((int64_t)mi); gm["primitives"] = prims; gmeshes.push_back(gm);
		Dictionary node; node["name"] = String("mesh") + String::num_int64((int64_t)mi); node["mesh"] = (int)mi;
		if (skinned)
		{
			std::vector<M4> ibm(nb);
			for (size_t i = 0; i < nb; i++) ibm[i] = inverse(restW[i]);
			for (auto &bd : m.bind)
			{
				M4 M = m4id();
				for (int i = 0; i < 3; i++)
				{
					for (int j = 0; j < 3; j++) M.m[i][j] = bd.B[i][j];
					M.m[i][3] = bd.B[i][0] * bd.bt[0] + bd.B[i][1] * bd.bt[1] + bd.B[i][2] * bd.bt[2];
				}
				if (bd.bone >= 0 && (size_t)bd.bone < nb) ibm[bd.bone] = M;
			}
			std::vector<float> arr(nb * 16);
			for (size_t i = 0; i < nb; i++)
			{
				M4 c = mul(mul(C, ibm[i]), Ci);
				for (int a = 0; a < 4; a++) for (int b = 0; b < 4; b++) arr[i * 16 + a * 4 + b] = (float)c.m[b][a];   // transposed = column-major
			}
			Dictionary sk; sk["name"] = String("skin") + String::num_int64((int64_t)mi);
			Array joints; for (size_t i = 0; i < nb; i++) joints.push_back((int)i);
			sk["joints"] = joints; sk["inverseBindMatrices"] = gl.acc(arr.data(), nb, F32, "MAT4", 16);
			sk["skeleton"] = roots.empty() ? 0 : roots[0];
			skins.push_back(sk);
			node["skin"] = (int)skins.size() - 1;
		}
		nodes.push_back(node);
	}
	Array ganims;
	for (auto &an : anims)
	{
		size_t nf = an.nf;
		std::vector<float> times(nf);
		for (size_t f = 0; f < nf; f++) times[f] = (float)((double)f / (double)an.fps);
		int tin = gl.acc(times.data(), nf, F32, "SCALAR", 1, 0, true);
		std::vector<std::vector<float>> T(nb, std::vector<float>(nf * 3)), R(nb, std::vector<float>(nf * 4)), S(nb, std::vector<float>(nf * 3));
		std::vector<std::vector<double>> Rd(nb, std::vector<double>(nf * 4));
		for (size_t f = 0; f < nf; f++)
			for (size_t i = 0; i < nb; i++)
			{
				const float *d = &an.data[(f * nb + i) * 16];
				double pos[3] = { d[0], d[1], d[2] }, q[4] = { d[3], d[4], d[5], d[6] }, ss[3][3];
				for (int a = 0; a < 3; a++) for (int b = 0; b < 3; b++) ss[a][b] = d[7 + a * 3 + b];
				TRS t = decompose(conv(local_matrix(pos, q, ss)));
				for (int k = 0; k < 3; k++) { T[i][f * 3 + k] = (float)t.t[k]; S[i][f * 3 + k] = (float)t.s[k]; }
				for (int k = 0; k < 4; k++) Rd[i][f * 4 + k] = t.q[k];
			}
		for (int i : roots) for (size_t f = 0; f < nf; f++) for (int k = 0; k < 3; k++) T[i][f * 3 + k] = (float)rest_t[i][k];
		for (size_t i = 0; i < nb; i++)
		{
			for (size_t f = 1; f < nf; f++)
			{
				double dt = 0; for (int k = 0; k < 4; k++) dt += Rd[i][f * 4 + k] * Rd[i][(f - 1) * 4 + k];
				if (dt < 0) for (int k = 0; k < 4; k++) Rd[i][f * 4 + k] = -Rd[i][f * 4 + k];
			}
			for (size_t f = 0; f < nf * 4; f++) R[i][f] = (float)Rd[i][f];
		}
		Array samp, chans;
		for (size_t i = 0; i < nb; i++)
		{
			const char *paths[3] = { "translation", "rotation", "scale" };
			for (int pth = 0; pth < 3; pth++)
			{
				int out = pth == 0 ? gl.acc(T[i].data(), nf, F32, "VEC3", 3) : pth == 1 ? gl.acc(R[i].data(), nf, F32, "VEC4", 4) : gl.acc(S[i].data(), nf, F32, "VEC3", 3);
				Dictionary s; s["input"] = tin; s["output"] = out; s["interpolation"] = "LINEAR"; samp.push_back(s);
				Dictionary tg; tg["node"] = (int)i; tg["path"] = paths[pth];
				Dictionary ch; ch["sampler"] = (int)samp.size() - 1; ch["target"] = tg; chans.push_back(ch);
			}
		}
		Dictionary ga; ga["name"] = String(an.name.c_str()); ga["samplers"] = samp; ga["channels"] = chans; ganims.push_back(ga);
	}
	Array sceneNodes; for (int i : roots) sceneNodes.push_back(i);
	for (size_t i = nb; i < (size_t)nodes.size(); i++) sceneNodes.push_back((int)i);
	Dictionary sc; sc["nodes"] = sceneNodes; Array scenes; scenes.push_back(sc);
	doc["scene"] = 0; doc["scenes"] = scenes; doc["nodes"] = nodes; doc["meshes"] = gmeshes;
	if (!materials.is_empty()) doc["materials"] = materials;
	if (!texs.is_empty()) { doc["textures"] = texs; doc["samplers"] = samplers; }
	if (!images.is_empty()) doc["images"] = images;
	doc["accessors"] = gl.accs; doc["bufferViews"] = gl.views;
	Array bufs; Dictionary bd; bd["byteLength"] = (int64_t)gl.bin.size(); bufs.push_back(bd); doc["buffers"] = bufs;
	if (!skins.is_empty()) doc["skins"] = skins;
	if (!ganims.is_empty()) doc["animations"] = ganims;
	if (!write_glb(out_path, doc, gl.bin)) { err = "cannot write " + out_path; return false; }
	return true;
}

}  // namespace na

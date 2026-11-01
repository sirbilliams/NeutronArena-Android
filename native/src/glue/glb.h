/* glTF 2.0 binary writer helpers shared by the three converters (ports of tools/granny/gdmp2gltf.py's Glb class + write_glb,
   neutron2 branch gltf-export).  The JSON document is built from Godot Dictionary/Array values. */
#pragma once
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <vector>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/image.hpp>

namespace na {

using godot::Array;
using godot::Dictionary;
using godot::String;
using godot::Variant;

enum { F32 = 5126, U16 = 5123, U32 = 5125 };

struct Glb
{
	std::vector<uint8_t> bin;
	Array views, accs;

	int view(const void *data, size_t len, int target = 0)
	{
		while (bin.size() % 4) bin.push_back(0);
		Dictionary v;
		v["buffer"] = 0; v["byteOffset"] = (int64_t)bin.size(); v["byteLength"] = (int64_t)len;
		if (target) v["target"] = target;
		const uint8_t *p = (const uint8_t *)data;
		bin.insert(bin.end(), p, p + len);
		views.push_back(v);
		return (int)views.size() - 1;
	}

	/* `count` elements of `ncomp` components each, component type ctype (F32/U16/U32). minmax only for float data. */
	int acc(const void *data, size_t count, int ctype, const char *atype, int ncomp, int target = 0, bool minmax = false)
	{
		size_t csz = ctype == U16 ? 2 : 4;
		Dictionary a;
		a["bufferView"] = view(data, count * ncomp * csz, target);
		a["componentType"] = ctype; a["count"] = (int64_t)count; a["type"] = String(atype);
		if (minmax && ctype == F32 && count)
		{
			const float *f = (const float *)data;
			Array mn, mx;
			for (int c = 0; c < ncomp; c++)
			{
				float lo = f[c], hi = f[c];
				for (size_t i = 1; i < count; i++) { float x = f[i * ncomp + c]; if (x < lo) lo = x; if (x > hi) hi = x; }
				mn.push_back((double)lo); mx.push_back((double)hi);
			}
			a["min"] = mn; a["max"] = mx;
		}
		accs.push_back(a);
		return (int)accs.size() - 1;
	}
	int accF3(const std::vector<float> &v, int target = 0, bool mm = false) { return acc(v.data(), v.size() / 3, F32, "VEC3", 3, target, mm); }
	int accF2(const std::vector<float> &v, int target = 0) { return acc(v.data(), v.size() / 2, F32, "VEC2", 2, target); }
};

inline Array arr3(double a, double b, double c) { Array r; r.push_back(a); r.push_back(b); r.push_back(c); return r; }
inline Array arr4(double a, double b, double c, double d) { Array r = arr3(a, b, c); r.push_back(d); return r; }

/* Writes the .glb: JSON chunk + BIN chunk, both padded to 4 bytes. */
inline bool write_glb(const std::string &path, const Dictionary &doc, std::vector<uint8_t> &bin)
{
	godot::CharString js8 = godot::JSON::stringify(doc).utf8();
	std::vector<uint8_t> js(js8.get_data(), js8.get_data() + js8.length());
	while (js.size() % 4) js.push_back(' ');
	while (bin.size() % 4) bin.push_back(0);
	uint32_t total = 12 + 8 + (uint32_t)js.size() + 8 + (uint32_t)bin.size();
	FILE *f = fopen(path.c_str(), "wb");
	if (!f) return false;
	uint32_t h[3] = { 0x46546C67u, 2u, total };
	fwrite(h, 4, 3, f);
	uint32_t c1[2] = { (uint32_t)js.size(), 0x4E4F534Au };
	fwrite(c1, 4, 2, f); fwrite(js.data(), 1, js.size(), f);
	uint32_t c2[2] = { (uint32_t)bin.size(), 0x004E4942u };
	fwrite(c2, 4, 2, f); fwrite(bin.data(), 1, bin.size(), f);
	return fclose(f) == 0;
}

/* RGBA bytes of a PNG (for the alpha statistics the converters use to pick MASK / BLEND). */
struct PngInfo { double clear = 0, part = 0; bool ok = false; };
inline PngInfo png_info(const uint8_t *data, size_t len)
{
	PngInfo r;
	godot::PackedByteArray pb; pb.resize((int64_t)len); memcpy(pb.ptrw(), data, len);
	godot::Ref<godot::Image> im; im.instantiate();
	if (im->load_png_from_buffer(pb) != godot::OK) return r;
	im->convert(godot::Image::FORMAT_RGBA8);
	godot::PackedByteArray d = im->get_data();
	int64_t n = d.size() / 4; if (!n) return r;
	int64_t cl = 0, pt = 0;
	const uint8_t *p = d.ptr();
	for (int64_t i = 0; i < n; i++) { uint8_t a = p[i * 4 + 3]; if (a == 0) cl++; else if (a < 255) pt++; }
	r.clear = (double)cl / n; r.part = (double)pt / n; r.ok = true;
	return r;
}

}  // namespace na

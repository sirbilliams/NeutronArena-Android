/* Entry points of the three converters (all produce a .glb the game's runtime loader reads). */
#pragma once
#include <cstdint>
#include <string>
#include <vector>
#include "../omt/omt_dump.h"

namespace na {
/* .gdmp v2 image (granny/grn_dump.cpp) -> skinned, animated .glb */
bool gdmp_to_glb(const std::vector<uint8_t> &gdmp, const std::string &out_path, std::string &err);
/* OMT level / prop shapes -> static .glb (collision shapes become "*-colonly" nodes) */
bool omt_to_glb(const OdDump &d, const std::string &name, const std::string &out_path, std::string &err);

struct AseOptions
{
	std::string tex;            // texture PNG name in png_dir overriding the ASE bitmaps
	std::string uv_from;        // donor ASE (same topology) for UVs + material
	bool loop = false, double_sided = false, unlit = false, center = false;
	double scale = 1.0;
};
/* 3ds Max ASCII export (.ASE) -> .glb with morph-target vertex animation */
bool ase_to_glb(const std::string &ase_path, const std::string &png_dir, const AseOptions &o, const std::string &out_path, std::string &err);
}

/* granny/grn_dump.cpp: args = { granny.dll, model.grn, anim.grn ... } */
bool grn_dump(const std::vector<std::string> &args, int fps, std::vector<unsigned char> &result, std::string &errmsg);

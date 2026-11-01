/* Level / prop geometry read through the OMT 2.5 engine reader (LGPL, see LICENSE-LGPL.txt). Plain C++ interface so the
   rest of the importer never sees the engine's (C++98) headers.  Port of tools/omt/omtdump.cpp (neutron2 branch gltf-export). */
#pragma once
#include <map>
#include <string>
#include <vector>

struct OdMaterial { int tex; float diffuse[4]; int flags; std::string name; };
struct OdPoly { int mat; int flags; std::vector<unsigned> vi; std::vector<float> uv; /* 2 per vertex */ };
struct OdShape { std::string name; std::vector<float> v; /* 3 per vertex */ std::vector<OdPoly> polys; };
struct OdDump
{
	std::vector<OdMaterial> mats;
	std::vector<OdShape> shapes;
	std::map<int, std::vector<unsigned char> > png;   /* texture canvas id -> PNG file bytes */
};

/* Reads every 3D shape of the database file `omt_path`; textures are exported through a temp file in `tmp_dir`.
   Returns false and fills `err` when the file can't be read. */
bool omt_dump(const std::string &omt_path, const std::string &tmp_dir, OdDump &out, std::string &err);

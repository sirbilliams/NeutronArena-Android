/* NaImporter: ISO 9660 -> InstallShield cabinet (unshield) -> only the files the converters need -> Granny / OMT / ASE
   converters -> the glb files Neutron Arena loads.  Everything runs on the device; nothing is written next to the ISO. */
#include "importer.h"
#include "converters.h"
#include "../iso/NegImport.h"
#include <dirent.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <unistd.h>
#include <chrono>
#include <cstdio>
#include <set>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

namespace {

std::string S(const String &s) { CharString c = s.utf8(); return std::string(c.get_data(), c.length()); }
std::string lower(std::string s) { for (auto &c : s) c = (char)tolower((unsigned char)c); return s; }

int mkdirs(const std::string &p)
{
	std::string cur;
	for (size_t i = 0; i <= p.size(); i++)
	{
		if (i == p.size() || p[i] == '/') { if (!cur.empty()) mkdir(cur.c_str(), 0755); }
		if (i < p.size()) cur += p[i];
	}
	return 0;
}
void rmtree(const std::string &p)
{
	DIR *d = opendir(p.c_str());
	if (!d) { unlink(p.c_str()); return; }
	while (dirent *e = readdir(d))
	{
		std::string n = e->d_name;
		if (n == "." || n == "..") continue;
		rmtree(p + "/" + n);
	}
	closedir(d);
	rmdir(p.c_str());
}
/* case-insensitive file lookup in a directory ("" when missing) */
std::string find_ci(const std::string &dir, const std::string &name)
{
	DIR *d = opendir(dir.c_str());
	if (!d) return "";
	std::string want = lower(name), res;
	while (dirent *e = readdir(d)) if (lower(e->d_name) == want) { res = dir + "/" + e->d_name; break; }
	closedir(d);
	return res;
}
std::string find_sub(const std::string &root, const std::string &sub, const std::string &name)
{
	std::string d = find_ci(root, sub);
	return d.empty() ? "" : find_ci(d, name);
}

/* ISO reader through Godot's FileAccess (works for content:// URIs on Android) */
struct IsoFile
{
	Ref<FileAccess> f;
	static int rd(void *user, void *buf, size_t n, long long off)
	{
		IsoFile *s = (IsoFile *)user;
		s->f->seek((uint64_t)off);
		PackedByteArray b = s->f->get_buffer((int64_t)n);
		if ((size_t)b.size() != n) return -1;
		memcpy(buf, b.ptr(), n);
		return 0;
	}
};

struct Ctx { NaImporter *imp; double base, span; const char *what; const std::set<std::string> *want; };

/* what to extract: "<dir>/<name>" lowercase, dir "" = top level */
int filter_cb(void *user, const char *dir, const char *name)
{
	Ctx *c = (Ctx *)user;
	std::string d = lower(dir ? dir : ""), n = lower(name);
	for (auto &ch : d) if (ch == '\\') ch = '/';
	return c->want->count(d.empty() ? n : d + "/" + n) ? 1 : 0;
}
int progress_cb(void *user, int stage, long long done, long long total)
{
	Ctx *c = (Ctx *)user;
	double f = total ? (double)done / (double)total : 0;
	// copy of the cabinet takes the first 45% of this unit, unpacking the rest
	double fr = stage == 0 ? 0.45 * f : 0.45 + 0.55 * f;
	c->imp->set_progress(String(stage == 0 ? "Reading " : "Unpacking ") + c->what, f, c->base + c->span * fr, 0);
	return c->imp->cancel_flag ? 1 : 0;
}

struct GrnJob { const char *out; const char *model; std::vector<const char *> anims; };
const GrnJob GRN_JOBS[] = {
	{ "jimmy.glb", "jimmybase.grn", { "jimmyfullrun.grn", "jimmyidle.grn", "jimmywalk.grn", "jimmyscooter.grn", "jimmyscooterstop.grn",
															  "jimmyjump.grn", "jimmyfall.grn", "jimmyfly.grn", "jimmyjumpgun.grn" } },
	{ "nummey.glb", "nummeybase.grn", { "nummeywalk.grn", "nummeyrun.grn", "nummeystop.grn", "nummeytalk.grn" } },
	{ "nummey_villain.glb", "nummeybase.grn", { "nummeylaugh.grn", "nummeydoom.grn", "nummeypushbuttons.grn", "nummeyflipsinair.grn", "nummeyfly.grn", "numflyair.grn" } },
	{ "jetpack.glb", "jetpack.grn", {} },   // backpack model (Granny); attached to the spine while the jetpack is equipped
	{ "nummey_scooter.glb", "nummeyscooterbase.grn", { "nummeyscooter.grn", "nummeyscootertalk.grn" } },
};
struct AseJob { int game; const char *stem; const char *tex; const char *uv_from; bool loop, dbl, unlit; };
const AseJob ASE_JOBS[] = {
	{ 1, "fire", "", "", true, true, true },
	{ 1, "hook", "", "", false, false, false },
	{ 1, "rocket", "", "", false, false, false },
	{ 1, "strato", "strato.png", "", false, false, false },
	{ 2, "jetpack01", "", "", true, false, false },
	{ 2, "goofbootfly", "goofbot.png", "goofbotstop", true, false, false },
	{ 2, "energybubble", "bubble.png", "", true, true, false },
};

std::set<std::string> want_n2()
{
	std::set<std::string> s{ "granny.dll", "omt/level5c.omt", "omt/scooter.omt", "ase/goofbotstop.ase",
							 "png/goofbot.png", "png/bubble.png", "png/jetpack.png" };
	for (auto &j : GRN_JOBS) { s.insert(std::string("grn/") + j.model); for (auto a : j.anims) s.insert(std::string("grn/") + a); }
	for (auto &a : ASE_JOBS) if (a.game == 2) s.insert(std::string("ase/") + a.stem + ".ase");
	return s;
}
std::set<std::string> want_n1()
{
	std::set<std::string> s{ "png/fire.png", "png/hook.png", "png/rocket.png", "png/strato.png" };
	for (auto &a : ASE_JOBS) if (a.game == 1) s.insert(std::string("ase/") + a.stem + ".ase");
	return s;
}

}  // namespace

void NaImporter::set_progress(const String &label, double frac, double base, double)
{
	std::lock_guard<std::mutex> l(mu);
	stage_label = label; stage_frac = frac; overall = base;
}

Dictionary NaImporter::get_progress()
{
	std::lock_guard<std::mutex> l(mu);
	Dictionary d; d["label"] = stage_label; d["stage"] = stage_frac; d["overall"] = overall;
	return d;
}

int64_t NaImporter::free_space(const String &dir)
{
	std::string p = S(dir); mkdirs(p);
	struct statvfs sv;
	if (statvfs(p.c_str(), &sv) != 0) return -1;
	return (int64_t)sv.f_bavail * (int64_t)sv.f_frsize;
}

Dictionary NaImporter::probe_iso(const String &path)
{
	Dictionary r; r["ok"] = false;
	Ref<FileAccess> f = FileAccess::open(path, FileAccess::READ);
	if (f.is_null()) { r["error"] = "Can't open that file."; return r; }
	IsoFile iso; iso.f = f;
	NegIso ni{ IsoFile::rd, &iso };
	if (!neg_is_iso(&ni)) { r["error"] = "That file isn't a CD image (.iso)."; return r; }
	unsigned char pvd[2048];
	if (IsoFile::rd(&iso, pvd, 2048, 16LL * 2048) == 0)
	{
		char lab[33]; memcpy(lab, pvd + 40, 32); lab[32] = 0;
		for (int i = 31; i >= 0 && (lab[i] == ' ' || lab[i] == 0); i--) lab[i] = 0;
		r["label"] = String(lab);
	}
	r["ok"] = true;
	return r;
}

Dictionary NaImporter::import_game(const String &iso_n2s, const String &iso_n1s, const String &out_dir_s, const String &cache_dir_s)
{
	Dictionary res; res["ok"] = false;
	cancel_flag = false;
	auto fail = [&](const std::string &m) { res["error"] = String(m.c_str()); return res; };
	std::string out = S(out_dir_s), cache = S(cache_dir_s);
	mkdirs(out); mkdirs(cache);
	std::string g2 = cache + "/n2", g1 = cache + "/n1", tmp = cache + "/cab";
	rmtree(g2); rmtree(g1); rmtree(tmp);
	bool have_n1 = !iso_n1s.is_empty();
	double w_n2 = 0.30, w_n1 = have_n1 ? 0.10 : 0.0;   // share of the whole bar for unpacking
	char err[512] = { 0 };

	auto unpack = [&](const String &iso_path, const std::string &dest, const char *want_exe, const char *other_exe, const char *what,
					  const std::set<std::string> &want, double base, double span) -> bool {
		Ref<FileAccess> f = FileAccess::open(iso_path, FileAccess::READ);
		if (f.is_null()) { snprintf(err, sizeof err, "Can't open the %s disc image.", what); return false; }
		IsoFile iso; iso.f = f;
		NegIso ni{ IsoFile::rd, &iso };
		Ctx c{ this, base, span, what, &want };
		int r = neg_import_iso(&ni, dest.c_str(), tmp.c_str(), want_exe, other_exe, filter_cb, progress_cb, &c, err, sizeof err);
		rmtree(tmp);
		return r == 0;
	};

	auto t0 = std::chrono::steady_clock::now();
	std::set<std::string> w2 = want_n2(), w1 = want_n1();
	if (!unpack(iso_n2s, g2, "Neutron2.exe", "Neutron.exe", "Neutron vs. Negatron disc", w2, 0.0, w_n2))
	{ rmtree(g2); return fail(err[0] ? err : "Couldn't read the disc image."); }
	if (have_n1 && !unpack(iso_n1s, g1, "Neutron.exe", "Neutron2.exe", "Boy Genius disc", w1, w_n2, w_n1))
	{ rmtree(g2); rmtree(g1); return fail(err[0] ? err : "Couldn't read the Boy Genius disc image."); }

	return convert_all(g2, g1, have_n1, out, cache, w_n2 + w_n1, true, t0);
}

/* Converts already-extracted game folders (g2 = Neutron vs. Negatron, g1 = Boy Genius or unused) into glbs in `out`.
   own = the folders are our own temporary extraction and are deleted afterwards; otherwise they are never touched. */
Dictionary NaImporter::convert_all(const std::string &g2, const std::string &g1, bool have_n1, const std::string &out, const std::string &cache,
								   double cbase, bool own, std::chrono::steady_clock::time_point t0)
{
	Dictionary res; res["ok"] = false;
	auto fail = [&](const std::string &m) { res["error"] = String(m.c_str()); return res; };
	auto cleanup = [&]() { if (own) { rmtree(g2); rmtree(g1); rmtree(cache + "/cab"); } };
	std::vector<std::string> made;
	size_t total = 5 + 3 + 1 + (have_n1 ? 4 : 0) + 3, done = 0;
	double cspan = 1.0 - cbase;
	auto step = [&](const std::string &what) { set_progress(String("Converting ") + String(what.c_str()), 0, cbase + cspan * (double)done / (double)total, 0); };
	std::string dll = find_ci(g2, "granny.dll");
	if (dll.empty()) { cleanup(); return fail("The Neutron vs. Negatron disc is missing granny.dll."); }
	mkdirs(out + "/levels"); mkdirs(out + "/ase/n1"); mkdirs(out + "/ase/n2");

	for (auto &j : GRN_JOBS)
	{
		step(j.out);
		if (cancel_flag) { cleanup(); return fail("Cancelled."); }
		std::vector<std::string> args{ dll, find_sub(g2, "grn", j.model) };
		bool missing = args[1].empty();
		for (auto a : j.anims) { std::string p = find_sub(g2, "grn", a); if (p.empty()) missing = true; args.push_back(p); }
		if (missing) { cleanup(); return fail(std::string("Missing model data for ") + j.out + " on the disc."); }
		std::vector<unsigned char> gdmp; std::string e;
		if (!grn_dump(args, 30, gdmp, e) || !na::gdmp_to_glb(gdmp, out + "/" + j.out, e)) { cleanup(); return fail(std::string("Converting ") + j.out + ": " + e); }
		made.push_back(j.out); done++;
	}
	struct OmtJob { const char *file; const char *out; const char *name; };
	for (OmtJob j : { OmtJob{ "level5c.omt", "levels/level5c.glb", "level5c" }, OmtJob{ "scooter.omt", "scooter.glb", "scooter" } })
	{
		step(j.out);
		if (cancel_flag) { cleanup(); return fail("Cancelled."); }
		std::string p = find_sub(g2, "omt", j.file);
		if (p.empty()) { cleanup(); return fail(std::string("Missing ") + j.file + " on the disc."); }
		OdDump d; std::string e;
		if (!omt_dump(p, cache, d, e) || !na::omt_to_glb(d, j.name, out + "/" + j.out, e)) { cleanup(); return fail(std::string("Converting ") + j.file + ": " + e); }
		made.push_back(j.out); done++;
	}
	done += 1;
	for (auto &a : ASE_JOBS)
	{
		if (a.game == 1 && !have_n1) continue;
		step(std::string(a.stem) + ".glb");
		const std::string &root = a.game == 1 ? g1 : g2;
		std::string src = find_sub(root, a.game == 1 ? "ASE" : "ase", std::string(a.stem) + ".ase");
		std::string pngdir = find_ci(root, "png");
		if (src.empty()) { cleanup(); return fail(std::string("Missing ") + a.stem + ".ase on the disc."); }
		na::AseOptions o; o.tex = a.tex; o.loop = a.loop; o.double_sided = a.dbl; o.unlit = a.unlit;
		if (a.uv_from[0]) o.uv_from = find_sub(root, "ase", std::string(a.uv_from) + ".ase");
		std::string rel = std::string("ase/n") + (a.game == 1 ? "1/" : "2/") + a.stem + ".glb", e;
		if (!na::ase_to_glb(src, pngdir, o, out + "/" + rel, e)) { cleanup(); return fail(std::string("Converting ") + a.stem + ".ase: " + e); }
		made.push_back(rel); done++;
	}
	cleanup();
	set_progress("Done", 1.0, 1.0, 0);
	Array files; for (auto &m : made) files.push_back(String(m.c_str()));
	res["ok"] = true; res["files"] = files; res["n1"] = have_n1;
	res["seconds"] = std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count();
	return res;
}


Dictionary NaImporter::import_from_dirs(const String &n2_dir, const String &n1_dir, const String &out_dir_s, const String &cache_dir_s, double progress_base)
{
	Dictionary res; res["ok"] = false;
	cancel_flag = false;
	std::string g2 = S(n2_dir), g1 = S(n1_dir), out = S(out_dir_s), cache = S(cache_dir_s);
	if (g2.empty() || find_ci(g2, "granny.dll").empty() || find_ci(g2, "omt").empty())
	{ res["error"] = "The Neutron vs. Negatron game files are missing or incomplete."; return res; }
	bool have_n1 = !g1.empty() && !find_ci(g1, "ase").empty();
	mkdirs(out); mkdirs(cache);
	return convert_all(g2, g1, have_n1, out, cache, progress_base, false, std::chrono::steady_clock::now());
}

/* Extracts only the files the converters need from a CD image into dest_dir (game 2 = Negatron, 1 = Boy Genius). */
Dictionary NaImporter::extract_iso(const String &iso_path, int game, const String &dest_dir, const String &cache_dir)
{
	Dictionary res; res["ok"] = false;
	cancel_flag = false;
	std::string dest = S(dest_dir), cache = S(cache_dir), tmp = cache + "/cab";
	mkdirs(cache); rmtree(dest); rmtree(tmp);
	const char *what = game == 1 ? "Boy Genius disc" : "Neutron vs. Negatron disc";
	Ref<FileAccess> f = FileAccess::open(iso_path, FileAccess::READ);
	if (f.is_null()) { res["error"] = String("Can't open the ") + what + " image."; return res; }
	IsoFile iso; iso.f = f;
	NegIso ni{ IsoFile::rd, &iso };
	std::set<std::string> want = game == 1 ? want_n1() : want_n2();
	Ctx c{ this, 0.0, game == 1 ? 0.1 : 0.3, what, &want };
	char err[512] = { 0 };
	int r = neg_import_iso(&ni, dest.c_str(), tmp.c_str(), game == 1 ? "Neutron.exe" : "Neutron2.exe", game == 1 ? "Neutron2.exe" : "Neutron.exe",
						   filter_cb, progress_cb, &c, err, sizeof err);
	rmtree(tmp);
	if (r != 0) { rmtree(dest); res["error"] = String(err[0] ? err : "Couldn't read the disc image."); return res; }
	res["ok"] = true;
	return res;
}

PackedStringArray NaImporter::wanted_files(int game)
{
	PackedStringArray r;
	for (auto &f : (game == 1 ? want_n1() : want_n2())) r.push_back(String(f.c_str()));
	return r;
}

void NaImporter::_bind_methods()
{
	ClassDB::bind_method(D_METHOD("import_game", "iso_n2", "iso_n1", "out_dir", "cache_dir"), &NaImporter::import_game);
	ClassDB::bind_method(D_METHOD("import_from_dirs", "n2_dir", "n1_dir", "out_dir", "cache_dir", "progress_base"), &NaImporter::import_from_dirs, DEFVAL(0.0));
	ClassDB::bind_method(D_METHOD("extract_iso", "iso", "game", "dest_dir", "cache_dir"), &NaImporter::extract_iso);
	ClassDB::bind_static_method("NaImporter", D_METHOD("wanted_files", "game"), &NaImporter::wanted_files);
	ClassDB::bind_method(D_METHOD("get_progress"), &NaImporter::get_progress);
	ClassDB::bind_method(D_METHOD("cancel"), &NaImporter::cancel);
	ClassDB::bind_method(D_METHOD("probe_iso", "path"), &NaImporter::probe_iso);
	ClassDB::bind_method(D_METHOD("free_space", "dir"), &NaImporter::free_space);
}

/*  port: HD texture pack loader (see OMediaHDPack.h, docs/hd-pack.md). */

#include "OMediaHDPack.h"
#include "OMediaHDPng.h"
#include <new>
#include "OMediaCanvas.h"
#include "OMediaFileStream.h"
#include "OMediaFilePath.h"
#include "OMediaError.h"
#include "OMediaSDLRetarget.h"
#include <SDL.h>
#include <zlib.h>
#include <stdio.h>
#include <dirent.h>
#include <sys/stat.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <map>
#include <set>
#include <string>
#include <vector>

using std::string;

namespace
{
	struct Pack
	{
		bool scanned;
		std::map<string, string> files;		// lower-case relative name -> real path
		std::set<string> logged;			// names already reported (bad size, too big)
		int replaced;
		double bytes, budget;
		bool budget_logged;

		Pack() : scanned(false), replaced(0), bytes(0), budget(0), budget_logged(false) {}
		~Pack()
		{
			if (!files.empty())
				SDL_Log("HD: %d textures replaced (%d files in the pack, %.0f MB at the end)", replaced,
						(int)files.size(), bytes / (1024.0 * 1024.0));
		}
	};

	Pack g_pack;

	string lower(string s) { for (size_t i = 0; i < s.size(); i++) s[i] = (char)tolower((unsigned char)s[i]); return s; }

	void scan_dir(const string &real, const string &rel, int depth)
	{
		DIR *d = opendir(real.c_str());
		if (!d) return;
		struct dirent *e;
		while ((e = readdir(d)) != NULL)
		{
			if (e->d_name[0] == '.') continue;
			const string r = real + "/" + e->d_name, l = rel + lower(e->d_name);
			struct stat st;
			if (stat(r.c_str(), &st) != 0) continue;
			if (S_ISDIR(st.st_mode)) { if (depth < 3) scan_dir(r, l + "/", depth + 1); }
			else if (l.size() > 4 && l.compare(l.size() - 4, 4, ".png") == 0) g_pack.files[l] = r;
		}
		closedir(d);
	}

	Pack &pack()
	{
		if (!g_pack.scanned)
		{
			g_pack.scanned = true;
			const char *dir = getenv("NEG_HD_DIR");			// default: hd/ in the game folder (the cwd)
			const char *enabled = getenv("NEG_HD_ENABLED");
			if (!enabled || atoi(enabled) != 0) scan_dir(dir && *dir ? dir : "hd", "", 0);
			const char *mb = getenv("NEG_HD_BUDGET_MB");
			g_pack.budget = (mb && atoi(mb) > 0 ? atoi(mb) : 1536) * 1024.0 * 1024.0;
			if (!g_pack.files.empty())
				SDL_Log("HD: texture pack with %d pictures (budget %.0f MB)", (int)g_pack.files.size(),
						g_pack.budget / (1024.0 * 1024.0));
		}
		return g_pack;
	}

	void log_once(const string &key, const char *msg)
	{
		if (g_pack.logged.insert(key).second) SDL_Log("HD: %s %s", key.c_str(), msg);
	}
}

void omhd::tag(OMediaCanvas *c, const string &rel)
{
	if (!c || c->hd_drawn) return;
	Pack &p = pack();
	if (p.files.empty()) return;
	const string l = lower(rel);
	if (p.files.find(l) != p.files.end()) c->hd_key = l;
}

// A complete PNG reader for the pack pictures (all colour types and bit depths, tRNS, several IDAT chunks,
// Adam7): OMT's own reader only knows the subset the 2002 game files use, and stays as it is for them.
// Fills 'c' with RGBA (memory order R, G, B, A).  Returns an error text or NULL.
static const char *read_png(const string &file, OMediaCanvas *c)
{
	const char *mb = getenv("NEG_HD_DECODE_MB");
	int limit = mb ? atoi(mb) : 192;
	if (limit < 32) limit = 32;
	if (limit > 512) limit = 512;
	omhd::DecodedPng image;
	const char *err = omhd::decode_png(file, image, (size_t)limit * 1024 * 1024);
	if (err) return err;
	c->create((int)image.width, (int)image.height);
	c->lock(omlf_Write);
	memcpy(c->get_pixels(), &image.pixels[0], image.pixels.size());
	c->unlock();
	return NULL;
}

// The path a file stream was opened with, '/' separated ("" if not a file stream).
static string stream_path(OMediaStreamOperators *stream)
{
	OMediaFileStream *fs = dynamic_cast<OMediaFileStream *>(stream);
	if (!fs) return "";
	OMediaFilePath fp;
	fs->getpath(&fp);
	string p = ((OMediaSDLRtgFilePath *)fp.getretarget())->path;
	for (size_t i = 0; i < p.size(); i++) if (p[i] == '\\') p[i] = '/';
	return p;
}

void omhd::tag_file(OMediaCanvas *c, OMediaStreamOperators *stream)
{
	if (pack().files.empty()) return;
	const string p = lower(stream_path(stream));
	const size_t s = p.find_last_of('/');
	if (s == string::npos) return;
	const string head = p.substr(0, s);
	const size_t s2 = head.find_last_of('/');
	if ((s2 == string::npos ? head : head.substr(s2 + 1)) == "png") tag(c, "png/" + p.substr(s + 1));
}

string omhd::db_name(OMediaStream *stream)
{
	if (pack().files.empty()) return "";
	string p = lower(stream_path(stream));
	const size_t s = p.find_last_of('/');
	if (s != string::npos) p = p.substr(s + 1);
	if (p.size() > 4 && p.compare(p.size() - 4, 4, ".omt") == 0) p.resize(p.size() - 4);
	return p;
}

OMediaCanvas *omhd::load(OMediaCanvas *orig, int max_size, int &scale)
{
	scale = 0;
	if (!orig || orig->hd_key.empty()) return NULL;
	Pack &p = pack();
	std::map<string, string>::iterator it = p.files.find(orig->hd_key);
	if (it == p.files.end()) return NULL;
	const int w = orig->get_width(), h = orig->get_height();
	if (w <= 0 || h <= 0) return NULL;

	OMediaCanvas *hd = NULL;
	const char *err = NULL;
	try { hd = new OMediaCanvas; err = read_png(it->second, hd); }
	catch (const std::bad_alloc &) { err = "cannot allocate the HD canvas"; }
	catch (OMediaError &) { err = "cannot create the HD canvas"; }
	if (err)
	{
		log_once(orig->hd_key, (string(err) + ": skipped").c_str());
		delete hd;
		return NULL;
	}
	const int hw = hd->get_width(), hh = hd->get_height();
	const int k = hw / w;
	char m[160];
	if (k < 1 || hw != w * k || hh != h * k)
	{
		snprintf(m, sizeof m, "is %dx%d, not an integer multiple of %dx%d: skipped", hw, hh, w, h);
		log_once(orig->hd_key, m);
		delete hd;
		return NULL;
	}
	int kf = k;
	const char *cap = getenv("NEG_HD_MAX_SCALE");
	if (cap && atoi(cap) >= 2 && kf > atoi(cap)) kf = atoi(cap);
	while (kf > 1 && (w * kf > max_size || h * kf > max_size)) kf--;
	if (kf < 2)
	{
		snprintf(m, sizeof m, "is %dx%d, over the texture size limit %d: skipped", hw, hh, max_size);
		if (k > 1) log_once(orig->hd_key, m);
		delete hd;
		return NULL;
	}
	if (kf != k)
	{
		snprintf(m, sizeof m, "is %dx%d, texture/preset limit %d: using %dx", hw, hh, max_size, kf);
		log_once(orig->hd_key, m);
		OMediaCanvas *s = NULL;
		try { s = new OMediaCanvas; s->create(w * kf, h * kf, hd); }
		catch (const std::bad_alloc &) {
			delete s; delete hd; log_once(orig->hd_key, "cannot allocate resized texture: skipped"); return NULL;
		}
		catch (OMediaError &) {
			delete s; delete hd; log_once(orig->hd_key, "cannot create resized texture: skipped"); return NULL;
		}
		delete hd;
		hd = s;
	}
	scale = kf;
	return hd;
}

bool omhd::add_bytes(OMediaCanvas *orig, double bytes)
{
	Pack &p = pack();
	if (p.bytes + bytes > p.budget)
	{
		if (!p.budget_logged) SDL_Log("HD: memory budget (%.0f MB) full at %s: the rest stays original",
									  p.budget / (1024.0 * 1024.0), orig ? orig->hd_key.c_str() : "?");
		p.budget_logged = true;
		return false;
	}
	p.bytes += bytes;
	p.replaced++;
	static const bool verbose = getenv("NEG_HD_LOG") && atoi(getenv("NEG_HD_LOG")) > 0;
	if (verbose && orig) SDL_Log("HD: %s (%.1f MB)", orig->hd_key.c_str(), bytes / (1024.0 * 1024.0));
	return true;
}

void omhd::sub_bytes(double bytes)
{
	g_pack.bytes -= bytes;
	if (g_pack.bytes < 0) g_pack.bytes = 0;
}

// Called only on the rendering thread, together with texture accounting.
std::string omhd::diagnostics()
{
    Pack &p = pack();
    char text[320];
    snprintf(text, sizeof text, "HD pack: %d indexed pictures\nHD uploads: %d (cumulative)\nHD textures: %.1f / %.0f MB estimated\nHD warnings: %d unique pictures\n",
        (int)p.files.size(), p.replaced, p.bytes / 1048576.0, p.budget / 1048576.0, (int)p.logged.size());
    std::string result = text;
    const char *enabled = getenv("NEG_HD_ENABLED"), *decode = getenv("NEG_HD_DECODE_MB"), *scale = getenv("NEG_HD_MAX_SCALE");
    result += string("HD runtime: ") + (enabled && atoi(enabled) == 0 ? "OFF" : "ON")
        + ", decode MB " + (decode ? decode : "192") + ", max scale " + (scale ? scale : "uncapped") + "\n";
    return result;
}

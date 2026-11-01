#pragma once
#include <atomic>
#include <chrono>
#include <string>
#include <mutex>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

namespace godot {

/* NaImporter: turns the player's own game CD images into the glb files the game loads.
     import_game(iso_n2, iso_n1, out_dir, cache_dir)  blocking (run it from a Thread); iso_n1 may be "".
     get_progress()                                   poll from the main thread
     cancel()
   Paths: real file system paths, or content:// URIs on Android (read through Godot's FileAccess, never copied whole). */
class NaImporter : public RefCounted
{
	GDCLASS(NaImporter, RefCounted)
public:
	Dictionary import_game(const String &iso_n2, const String &iso_n1, const String &out_dir, const String &cache_dir);
	/* same conversion from already-extracted game folders (n2_dir required, n1_dir "" = none); never modifies them */
	Dictionary import_from_dirs(const String &n2_dir, const String &n1_dir, const String &out_dir, const String &cache_dir, double progress_base = 0.0);
	/* extracts just the files the converters need from a CD image into dest_dir (game 2 = Negatron, 1 = Boy Genius) */
	Dictionary extract_iso(const String &iso, int game, const String &dest_dir, const String &cache_dir);
	/* the lowercase relative paths ("grn/jimmybase.grn", "granny.dll", ...) the converters read; game 2 = Negatron, 1 = Boy Genius */
	static PackedStringArray wanted_files(int game);
	Dictionary get_progress();
	void cancel() { cancel_flag = true; }
	/* {ok, error, label}: is it readable and an ISO 9660 image? label = the disc's volume name */
	Dictionary probe_iso(const String &path);
	/* free bytes on the file system holding `dir` (-1 = unknown) */
	int64_t free_space(const String &dir);

	// internal (progress callbacks)
	std::atomic<bool> cancel_flag{ false };
	std::mutex mu;
	String stage_label; double stage_frac = 0, overall = 0; int stage_no = 0;
	Dictionary convert_all(const std::string &g2, const std::string &g1, bool have_n1, const std::string &out, const std::string &cache,
						   double cbase, bool own, std::chrono::steady_clock::time_point t0);
	void set_progress(const String &label, double frac, double base, double span);

protected:
	static void _bind_methods();
};

}  // namespace godot

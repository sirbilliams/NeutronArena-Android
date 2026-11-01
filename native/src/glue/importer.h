#pragma once
#include <atomic>
#include <mutex>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/dictionary.hpp>

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
	void set_progress(const String &label, double frac, double base, double span);

protected:
	static void _bind_methods();
};

}  // namespace godot

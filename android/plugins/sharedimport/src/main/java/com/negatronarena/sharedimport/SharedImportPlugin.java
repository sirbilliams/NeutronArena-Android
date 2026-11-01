package com.negatronarena.sharedimport;

import android.content.ContentResolver;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.net.Uri;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

/**
 * Imports the game files from the sirbilliams port apps installed on this device. Each port shares its game
 * folder read-only through GameFilesProvider (authority "<package>.gamefiles"), guarded by a signature permission:
 * it is only granted when this app is signed with the same key as the port.
 *
 * Godot side: Engine.get_singleton("SharedImport").
 */
public class SharedImportPlugin extends GodotPlugin {
    static final String[] PACKAGES = { "com.sirbilliams.negatron", "com.sirbilliams.neutron1" };

    // copy progress, polled from the main thread
    private volatile int done = 0, total = 0;
    private volatile String current = "";

    public SharedImportPlugin(Godot godot) { super(godot); }

    @Override public String getPluginName() { return "SharedImport"; }

    private static Uri uri(String pkg, String rel) {
        Uri.Builder b = new Uri.Builder().scheme("content").authority(pkg + ".gamefiles");
        for (String seg : rel.split("/")) if (!seg.isEmpty()) b.appendPath(seg);
        return b.build();
    }

    /** Lists the provider's files: lowercase path -> {actual path, size}. Throws SecurityException when the permission is not granted. */
    private Map<String, Object[]> manifest(String pkg) {
        Map<String, Object[]> m = new HashMap<>();
        ContentResolver cr = getActivity().getContentResolver();
        try (Cursor c = cr.query(uri(pkg, "manifest"), null, null, null, null)) {
            if (c == null) return null;                                   // provider not found
            int ip = c.getColumnIndex("path"), is = c.getColumnIndex("size");
            while (c.moveToNext()) m.put(c.getString(ip).toLowerCase(Locale.ROOT), new Object[] { c.getString(ip), c.getLong(is) });
        }
        return m;
    }

    private boolean installed(String pkg) {
        try { getActivity().getPackageManager().getPackageInfo(pkg, 0); return true; }
        catch (PackageManager.NameNotFoundException e) { return false; }
    }

    /**
     * Port apps that are installed: package -> "ok" (has the game, readable), "no_game" (installed, game not set up),
     * "denied" (different signing key: the permission isn't granted) or "no_provider" (an older version without sharing).
     */
    @UsedByGodot
    public Dictionary installed_sources() {
        Dictionary r = new Dictionary();
        for (String pkg : PACKAGES) {
            if (!installed(pkg)) continue;
            String st;
            try {
                Map<String, Object[]> m = manifest(pkg);
                st = m == null ? "no_provider" : m.isEmpty() ? "no_game" : "ok";
            } catch (SecurityException e) { st = "denied"; }
            catch (RuntimeException e) { st = "no_provider"; }
            r.put(pkg, st);
        }
        return r;
    }

    /**
     * Copies the wanted files (lowercase relative paths, matched case-insensitively) of `pkg` into dest_dir, keeping
     * their relative paths. Returns {ok, code, error, copied}; code: denied | not_installed | no_game | missing | io.
     */
    @UsedByGodot
    public Dictionary copy_from(String pkg, String dest_dir, String[] wanted) {
        Dictionary r = new Dictionary();
        r.put("ok", false); r.put("copied", 0);
        done = 0; total = wanted.length; current = "";
        if (!installed(pkg)) return fail(r, "not_installed", "That app isn't installed.");
        Map<String, Object[]> m;
        try { m = manifest(pkg); }
        catch (SecurityException e) {
            return fail(r, "denied", "Android won't let this app read that app's files (they are signed with different keys). Use the .iso instead.");
        } catch (RuntimeException e) { m = null; }
        if (m == null) return fail(r, "no_game", "That app is too old to share its files. Update it, or use the .iso.");
        if (m.isEmpty()) return fail(r, "no_game", "The game isn't installed in that app yet. Open it and set up the game first, or use the .iso.");
        ContentResolver cr = getActivity().getContentResolver();
        File root = new File(dest_dir);
        try {
            String rootPath = root.getCanonicalPath() + File.separator;
            int n = 0;
            for (String w : wanted) {
                Object[] e = m.get(w.toLowerCase(Locale.ROOT));
                if (e == null) return fail(r, "missing", "That app's game files are incomplete (missing " + w + ").");
                String rel = (String) e[0];
                current = rel;
                File out = new File(root, rel).getCanonicalFile();
                if (!out.getPath().startsWith(rootPath)) return fail(r, "io", "Bad file name from the app.");
                File dir = out.getParentFile();
                if (dir != null) dir.mkdirs();
                try (InputStream in = cr.openInputStream(uri(pkg, rel)); OutputStream os = new FileOutputStream(out)) {
                    if (in == null) return fail(r, "missing", "Couldn't open " + w + " in that app.");
                    byte[] buf = new byte[1 << 16];
                    int k;
                    while ((k = in.read(buf)) > 0) os.write(buf, 0, k);
                }
                done = ++n;
            }
            r.put("copied", n);
        } catch (SecurityException e) {
            return fail(r, "denied", "Android won't let this app read that app's files (they are signed with different keys). Use the .iso instead.");
        } catch (IOException e) {
            return fail(r, "io", "Copy failed: " + e.getMessage());
        }
        r.put("ok", true);
        return r;
    }

    /** {done, total, current} of the running copy_from. */
    @UsedByGodot
    public Dictionary copy_progress() {
        Dictionary d = new Dictionary();
        d.put("done", done); d.put("total", total); d.put("current", current);
        return d;
    }

    private static Dictionary fail(Dictionary r, String code, String msg) {
        r.put("code", code); r.put("error", msg);
        return r;
    }
}

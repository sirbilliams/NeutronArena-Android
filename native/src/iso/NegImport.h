/*  Installs the game files from the game's CD image (.iso): finds the InstallShield cabinet on
    the disc (data1.hdr / data1.cab), copies it out, and extracts the "Program Executable Files"
    group (omt/, gam/, grn/ ... and Neutron2.exe) into a folder - what the CD's setup.exe does.

    Reworked for Negatron Arena: reads the image through a callback, extracts only the files the converters need. */
#pragma once
#include <stddef.h>
#ifdef __cplusplus
extern "C" {
#endif

/* Progress: stage 0 = copying the cabinet off the disc, 1 = extracting; done/total in bytes
   (stage 0) or files (stage 1). Return non-zero to cancel. */
typedef int (*NegImportProgress)(void *user, int stage, long long done, long long total);

/* Reader for the disc image: any source that can read at an offset (a file, an Android content:// URI, ...). */
typedef struct NegIso
{
	int (*read)(void *user, void *buf, size_t n, long long off);   /* 0 = ok */
	void *user;
} NegIso;

/* Which cabinet files to unpack: called with the sub-folder and name, non-zero = extract (NULL = everything). */
typedef int (*NegImportFilter)(void *user, const char *dir, const char *name);

/* Installs from the ISO into `dest_dir` (created; existing files are overwritten). `tmp_dir` holds the copied
   cabinet meanwhile. `want_exe` (e.g. "Neutron2.exe") must be at the top of the group, else the disc is wrong;
   `other_exe` only improves the message. Returns 0 on success, otherwise writes a message for the player into `err`. */
int neg_import_iso(const NegIso *iso, const char *dest_dir, const char *tmp_dir, const char *want_exe, const char *other_exe,
				   NegImportFilter filter, NegImportProgress progress, void *user, char *err, int err_size);

/* 1 if the image looks like an ISO 9660 image. */
int neg_is_iso(const NegIso *iso);

#ifdef __cplusplus
}
#endif

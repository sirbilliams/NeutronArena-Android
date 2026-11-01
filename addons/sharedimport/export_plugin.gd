@tool
extends EditorExportPlugin
## Adds the SharedImport Android plugin (AAR, built by tools/build_android_plugin.sh) to Android gradle exports.

const AAR := "res://addons/sharedimport/bin/sharedimport.aar"

func _get_name() -> String:
	return "SharedImport"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid

func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	return PackedStringArray([AAR])

@tool
extends EditorPlugin

var _export: EditorExportPlugin

func _enter_tree() -> void:
	_export = preload("res://addons/sharedimport/export_plugin.gd").new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)

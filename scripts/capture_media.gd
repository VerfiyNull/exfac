extends SceneTree
## Renders title + base frames for walkthrough media.


func _initialize() -> void:
	call_deferred("_capture")


func _session() -> Node:
	return root.get_node("GameSession")


func _capture() -> void:
	await process_frame
	var session := _session()
	# Seed meta without scene changes — SubViewport hosts UI.
	if (session.meta as Dictionary).is_empty():
		session.meta = MetaSim.create_meta_state()
		Skills.ensure(session.meta)
	session.status = "Kit up from the locker, then deploy."
	session.stipend_note = ""
	session.last_raid_result = {}
	session.raid_history = []
	await _shot("res://scenes/title.tscn", "/cursor/stores/self/media/exfac-title.png", "TITLE")
	await process_frame
	await _shot("res://scenes/hideout.tscn", "/cursor/stores/self/media/exfac-hideout.png", "BASE")
	print("CAPTURE_OK")
	quit(0)


func _make_viewport(size: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	return vp


func _shot(scene_path: String, out_path: String, tag: String) -> void:
	var vp := _make_viewport(Vector2i(1280, 720))
	var packed := load(scene_path) as PackedScene
	var node := packed.instantiate()
	vp.add_child(node)
	for _i in 10:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var err := img.save_png(out_path)
	print(tag, "_PNG ", out_path, " err=", err, " size=", img.get_width(), "x", img.get_height())
	node.queue_free()
	vp.queue_free()
	await process_frame

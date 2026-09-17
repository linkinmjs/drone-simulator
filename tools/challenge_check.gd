extends Node
## Checks the challenge mode without flying it:
##   godot --headless --path . res://tools/challenge_check.tscn
## The catalogue, the medal thresholds, the unlocking rule and the fact that every challenge
## loads and starts its countdown. Exits with code 0 when every check passes.
## The saved progress is only changed in memory and restored at the end.


const CHALLENGE_LEVEL := "res://sceneries/challenge_level.tscn"

var failures := 0
var shots_dir := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shots_dir = arg.trim_prefix("--shots=")
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	print("  %s %s" % ["ok  " if condition else "FAIL", label])
	if not condition:
		failures += 1


func frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


## Saves a picture of the track with --shots, to look at the layout without flying it.
func shot(file_name: String) -> void:
	if shots_dir.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var _err := image.save_png("%s/%s" % [shots_dir, file_name])


func _run() -> void:
	Global.startup = false
	var saved_progress: Dictionary = GameSettings.challenge_progress.duplicate()

	var saved_records := _read_records()

	_check_catalog()
	_check_medals()
	_check_unlocking()
	await _check_levels()
	await _check_full_run()

	_write_records(saved_records)
	GameSettings.challenge_progress = saved_progress
	print("== Result: %d failure(s)" % [failures])
	get_tree().quit(1 if failures > 0 else 0)


func _check_catalog() -> void:
	print("== Catalogo (%d desafios)" % [ChallengeCatalog.count()])
	check(ChallengeCatalog.count() > 0, "hay desafios")
	var ids: Array[String] = []
	for i in ChallengeCatalog.count():
		var challenge := ChallengeCatalog.get_challenge(i)
		var id := str(challenge["id"])
		check(not ids.has(id), "el id %s no se repite" % [id])
		ids.append(id)
		check(ResourceLoader.exists(str(challenge["track"])),
				"%s: la pista existe" % [id])
		check(int(challenge["laps"]) >= 1, "%s: tiene al menos una vuelta" % [id])
		var gold := float(challenge["gold"])
		var silver := float(challenge["silver"])
		var bronze := float(challenge["bronze"])
		check(gold < silver and silver < bronze,
				"%s: oro %.1f < plata %.1f < bronce %.1f" % [id, gold, silver, bronze])
		check(ChallengeCatalog.get_index(id) == i, "%s: el indice coincide" % [id])
		for key: String in ["name", "goal"]:
			var translated := TranslationServer.translate(str(challenge[key]))
			check(translated != str(challenge[key]), "%s: %s esta traducido" % [id, key])


## The exact edges matter: a run that hits the gold time to the hundredth earns gold.
func _check_medals() -> void:
	print("== Medallas")
	var challenge := ChallengeCatalog.get_challenge(0)
	var gold := float(challenge["gold"])
	var silver := float(challenge["silver"])
	var bronze := float(challenge["bronze"])
	check(ChallengeCatalog.medal_for(0, gold) == ChallengeCatalog.Medal.GOLD, "el tiempo de oro da oro")
	check(ChallengeCatalog.medal_for(0, gold - 1.0) == ChallengeCatalog.Medal.GOLD, "mejor que el oro da oro")
	check(ChallengeCatalog.medal_for(0, gold + 0.01) == ChallengeCatalog.Medal.SILVER, "apenas peor que el oro da plata")
	check(ChallengeCatalog.medal_for(0, silver) == ChallengeCatalog.Medal.SILVER, "el tiempo de plata da plata")
	check(ChallengeCatalog.medal_for(0, silver + 0.01) == ChallengeCatalog.Medal.BRONZE, "apenas peor que la plata da bronce")
	check(ChallengeCatalog.medal_for(0, bronze) == ChallengeCatalog.Medal.BRONZE, "el tiempo de bronce da bronce")
	check(ChallengeCatalog.medal_for(0, bronze + 0.01) == ChallengeCatalog.Medal.NONE, "peor que el bronce no da medalla")
	check(ChallengeCatalog.medal_for(0, 0.0) == ChallengeCatalog.Medal.NONE, "sin tiempo no hay medalla")
	check(ChallengeCatalog.format_time(83.45) == "01:23.45", "el tiempo se formatea (%s)"
			% [ChallengeCatalog.format_time(83.45)])


func _check_unlocking() -> void:
	print("== Desbloqueo")
	GameSettings.challenge_progress = {}
	check(GameSettings.is_challenge_unlocked(0), "el primero siempre esta abierto")
	check(not GameSettings.is_challenge_unlocked(1), "el segundo arranca cerrado")
	check(GameSettings.get_finished_challenge_count() == 0, "no hay desafios completados")
	check(GameSettings.get_first_unfinished_challenge() == 0, "el pendiente es el primero")

	var first := str(ChallengeCatalog.get_challenge(0)["id"])
	GameSettings.challenge_progress[first] = float(ChallengeCatalog.get_challenge(0)["bronze"]) + 5.0
	check(GameSettings.is_challenge_unlocked(1), "terminarlo abre el siguiente aunque no haya medalla")
	check(not GameSettings.is_challenge_unlocked(2), "el tercero sigue cerrado")
	check(GameSettings.get_challenge_medal(0) == ChallengeCatalog.Medal.NONE, "sin medalla queda sin medalla")
	check(GameSettings.get_first_unfinished_challenge() == 1, "el pendiente pasa a ser el segundo")

	GameSettings.challenge_progress[first] = float(ChallengeCatalog.get_challenge(0)["gold"])
	check(GameSettings.get_challenge_medal(0) == ChallengeCatalog.Medal.GOLD, "el tiempo de oro da la medalla de oro")

	var entries := ChallengeCatalog.menu_entries()
	check(entries.size() == ChallengeCatalog.count(), "el menu lista todos los desafios")
	check(not bool(entries[0]["locked"]), "el primero aparece abierto")
	check(bool(entries[2]["locked"]), "el tercero aparece cerrado")


## Every challenge has to load into the shared level and start its countdown by itself.
func _check_levels() -> void:
	var packed := load(CHALLENGE_LEVEL) as PackedScene
	if packed == null:
		check(false, "el nivel de desafio carga")
		return
	for i in ChallengeCatalog.count():
		var challenge := ChallengeCatalog.get_challenge(i)
		var id := str(challenge["id"])
		print("== %s" % [id])
		Global.selected_challenge = id
		var level := packed.instantiate() as ChallengeLevel
		level.persist_progress = false
		get_tree().root.add_child(level)
		await frames(8)

		check(level.track != null, "la pista se instancio")
		if level.track != null:
			check(level.track.laps == int(challenge["laps"]),
					"corre %d vuelta(s)" % [int(challenge["laps"])])
			check(not level.track.show_time_table, "la tabla de vueltas queda apagada")
			check(level.track.has_launchpad, "la pista tiene plataforma de largada")
			check(level.track.checkpoints.size() >= 2, "tiene al menos dos checkpoints")
			check(level.track.current_checkpoint != null, "hay un checkpoint activo")
		check(Global.game_mode == Global.GameMode.RACE, "el juego quedo en modo carrera")
		check(Global.active_track == level.track, "la pista del desafio es la activa")
		check(level.challenge_index == i, "el indice del desafio es %d" % [i])

		if not shots_dir.is_empty():
			# A fixed camera above and behind the launchpad shows the whole track at once.
			for c in level.cameras.size():
				if level.cameras[c].name == "CameraFixed":
					level.camera_index = c
			level.change_camera()
			level.camera.global_transform = Transform3D(
					Basis.from_euler(Vector3(deg_to_rad(-40.0), 0.0, 0.0)), Vector3(0, 52, 52))
			level.camera.fov = 70.0
			await frames(8)
			await shot("challenge_%d_%s.png" % [i + 1, id])

		# Stop the countdown first: its timers would be left outside the tree.
		if level.track != null:
			level.track.stop_race()
		get_tree().root.remove_child(level)
		level.queue_free()
		await frames(2)


## Runs a whole challenge without flying it: the checkpoints are marked as passed in the
## order of the course, so the laps, the finish and the saved record are all exercised.
func _check_full_run() -> void:
	print("== Carrera simulada")
	var challenge := ChallengeCatalog.get_challenge(0)
	var id := str(challenge["id"])
	GameSettings.challenge_progress = {}
	Global.selected_challenge = id

	var packed := load(CHALLENGE_LEVEL) as PackedScene
	var level := packed.instantiate() as ChallengeLevel
	get_tree().root.add_child(level)
	await frames(8)
	var track := level.track
	if track == null:
		check(false, "la pista se instancio")
		return

	# Skip the countdown and cross every checkpoint of the course in order.
	track.start_race()
	check(track.race_state == Global.RaceState.RACE, "la carrera arranco")
	var crossed := 0
	while track.race_state == Global.RaceState.RACE and crossed < 200:
		var checkpoint: Checkpoint = track.current_checkpoint
		if checkpoint == null:
			break
		checkpoint.passed.emit(checkpoint)
		crossed += 1
		await get_tree().physics_frame
	check(track.race_state == Global.RaceState.END, "la carrera termino")
	check(track.current_lap == track.laps, "corrio las %d vueltas (%d)"
			% [track.laps, track.current_lap])
	check(level.total_time() > 0.0, "el tiempo total es mayor que cero")

	# The result screen waits for the "Finished!" sign of the track before showing up.
	await frames(int(ChallengeLevel.RESULT_DELAY * 60.0) + 30)
	var best := GameSettings.get_best_time(id)
	check(best > 0.0, "el tiempo quedo guardado (%.2f s)" % [best])
	check(GameSettings.is_challenge_unlocked(1), "el segundo desafio quedo abierto")
	check(GameSettings.get_finished_challenge_count() == 1, "figura un desafio completado")

	get_tree().root.remove_child(level)
	level.queue_free()
	await frames(2)


func _read_records() -> String:
	var file := FileAccess.open(Global.highscore_path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


## Puts the highscore file back as it was: a simulated race must not leave a record behind.
func _write_records(text: String) -> void:
	var file := FileAccess.open(Global.highscore_path, FileAccess.WRITE)
	if file != null:
		var _discard := file.store_string(text)

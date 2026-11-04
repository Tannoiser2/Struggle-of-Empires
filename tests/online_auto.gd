extends SceneTree
## Prova online: due istanze (host e ospite) giocano una partita intera sul finto Firebase;
## le decisioni dei giocatori umani le prende l'IA. Alla fine stampano l'impronta della partita.
## SOE_ROLE=host|guest SOE_CODEFILE=file  (più FR_DB_URL, FR_AUTH_URL, FR_REFRESH_URL, FR_SESSION)
var main
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func _w(s: float):
	await create_timer(s).timeout
func _run():
	await _w(0.3)
	var role := OS.get_environment("SOE_ROLE")
	var cf := OS.get_environment("SOE_CODEFILE")
	main.scelta_np = 3
	main._menu_online()
	main.on_nome.text = "Host" if role == "host" else "Ospite"
	main.on_pot.selected = 0 if role == "host" else 1
	if role == "host":
		await main._online_crea()
		var f := FileAccess.open(cf, FileAccess.WRITE)
		f.store_string(main.codice)
		f.close()
		print("SOE stanza ", main.codice)
		while true:
			var room: Dictionary = await main.net.room(main.codice)
			if Rete._as_dict(room.get("seats", {})).size() >= 2:
				break
			await _w(0.4)
		await _w(1.0)
		await main._online_inizia()
	else:
		var code := ""
		while code == "":
			if FileAccess.file_exists(cf):
				code = FileAccess.get_file_as_string(cf).strip_edges()
			await _w(0.3)
		main.on_codice.text = code
		await main._online_entra()
		while not main.in_partita:
			await _w(0.3)
	main.velocita = 60.0
	var t0 := Time.get_ticks_msec()
	while not main.m.finita() and Time.get_ticks_msec() - t0 < 900000:
		await process_frame
		if main.popup_aperto:
			main._chiudi_popup()
		var r: Dictionary = main.m.richiesta()
		if not r.is_empty() and main.io(r["g"]) and main.richiesta_mostrata == int(main.m.s["passo"]):
			main.richiesta_mostrata = -5
			await main._decidi(main.ia.decidi(r))
	print("SOE fine ", role, " passo ", main.m.s["passo"], " vince ", main.m.s["esito"].get("vince", "?"), " impronta ", str(main.m.s["log"]).hash())
	quit()

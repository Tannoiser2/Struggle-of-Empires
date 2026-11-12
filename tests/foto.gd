extends SceneTree
## Screenshot dell'interfaccia: xvfb-run godot --path . -s res://tests/foto.gd -- <modo> [n]
## modo: menu | nuova | partita | asta | azione | fine
var main
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func shot(nome: String):
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % nome)
	print("shot ", nome)
func _run():
	var args := OS.get_cmdline_user_args()
	var modo: String = args[0] if args.size() > 0 else "menu"
	await shot("menu")
	if modo == "menu":
		quit(); return
	main._menu_nuova()
	await shot("nuova")
	if modo == "nuova":
		quit(); return
	main.scelta_np = 4
	main.scelta_pot = "fr"
	main._avvia_locale()
	main.velocita = 200.0
	if modo == "banco":
		for q in 30: await process_frame
		main._mostra_banco()
		for q in 5: await process_frame
		var pan = main.popup.get_child(0)
		print("pannello ", pan.size, " ", pan.get_combined_minimum_size())
		for ch in pan.get_child(0).get_children():
			print("  ", ch.get_class(), " ", ch.get_combined_minimum_size())
		await shot("banco")
		quit(); return
	if modo == "scheda":
		for q in 30: await process_frame
		var gi: int = main.m.gioc_di("fr")
		var gg: Dictionary = main.m.g(gi)
		for t in ["banca", "c_costa", "c_indie", "milizia", "diplomazia", "agricoltura", "sorpresa", "ritirata"]:
			if Dati.TESSERE.has(t):
				gg["tessere"].append({"t": t, "usata": t == "agricoltura"})
		gg["tens"] = 2
		gg["oro"] = 13
		main._mostra_giocatore(gi)
		await shot("scheda")
		quit(); return
	var target := int(args[1]) if args.size() > 1 else 1
	var passi := 0
	var visti := 0
	while passi < 6000 and not main.m.finita():
		await process_frame
		if main.popup_aperto:
			main._chiudi_popup()
		var r: Dictionary = main.m.richiesta()
		if r.is_empty() or not main.io(r["g"]):
			continue
		if r["k"] == modo or (modo == "partita" and r["k"] == "azione"):
			visti += 1
			if visti >= target:
				for q in 10: await process_frame
				await shot(modo)
				if main.vista != null:
					main.vista.distanza = 14.0
					main.vista.pitch = deg_to_rad(40.0)
					main.vista.bersaglio = Vector3(12, 0, -5)
					main.vista._aggiorna_camera()
					await shot(modo + "_zoom")
					main.vista.distanza = 16.0
					main.vista.pitch = deg_to_rad(45.0)
					main.vista.bersaglio = Vector3(-40, 0, 18)
					main.vista._aggiorna_camera()
					await shot(modo + "_pv")
				break
		var id: String = main.ia.decidi(r)
		await main._decidi(id)
		passi += 1
	if modo == "fine":
		while not main.m.finita() and passi < 20000:
			var r2: Dictionary = main.m.richiesta()
			main.m.applica({"id": main.ia.decidi(r2)})
			passi += 1
		main._aggiorna_tutto()
		for i in 30: await process_frame
		await shot("fine")
	quit()

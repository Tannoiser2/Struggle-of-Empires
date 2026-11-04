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

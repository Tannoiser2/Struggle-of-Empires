extends SceneTree
## Screenshot di una battaglia mostrata sulla mappa (3D e 2D) e di un viaggio in mare aperto.
## xvfb-run godot --path . -s res://tests/foto_battaglia.gd
var main
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func shot(nome: String):
	await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/shot_%s.png" % nome)
	print("shot ", nome)
func _run():
	for i in 5: await process_frame
	main.scelta_np = 4
	main.scelta_pot = "fr"
	main._avvia_locale()
	# gioca da IA finché c'è un combattimento terrestre fra potenze
	var g := 0
	while g < 4000:
		g += 1
		var r: Dictionary = main.m.richiesta()
		var cb: Dictionary = main.m.s.get("ultimo_cb", {})
		if not cb.is_empty() and cb.get("dpot", "") != "" and cb.get("rapporto", []).size() > 0:
			break
		main.m.applica({"id": main.ia.decidi(r)})
	main.ultimo_evento_visto = int(main.m.s["passo"]) - 1
	main.ultimo_cb_visto = -1
	main.animazioni = []
	main.velocita = 1.0
	main._aggiorna_tutto()
	for t in [0.6, 1.6, 2.6, 3.4, 4.4]:
		await create_timer(t - (0.0 if t == 0.6 else 0.0)).timeout
		await shot("batt3d_%s" % str(t).replace(".", "_"))
	# 2D
	while main.animazione_in_corso:
		await process_frame
		if main.popup_aperto:
			main._chiudi_popup()
	main.vista_3d = false
	main._mostra_vista()
	main.ultimo_cb_visto = -1
	main._controlla_eventi()
	await create_timer(0.6).timeout
	await shot("batt2d_a")
	await create_timer(2.0).timeout
	await shot("batt2d_b")
	quit()

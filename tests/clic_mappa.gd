extends SceneTree
## Prova delle scelte fatte cliccando sulla mappa (pezzi, pile, tessere).
## xvfb-run godot --path . -s res://tests/clic_mappa.gd
var main
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()
func _w(n := 5):
	for i in n: await process_frame
func _fino_a_mia_azione() -> Dictionary:
	var g := 0
	while g < 5000:
		g += 1
		await process_frame
		if main.popup_aperto:
			main._chiudi_popup()
		if main.vista.bottone_riquadro.visible:
			main.vista.continua_premuto.emit()
		var r: Dictionary = main.m.richiesta()
		if r.is_empty():
			continue
		if main.io(r["g"]) and r["k"] == "azione" and int(main.m.s["t"]["az"]) == 2:
			return r
		if main.io(r["g"]):
			await main._decidi(main.ia.decidi(r))
	return {}
func _run():
	await _w()
	main.scelta_np = 4
	main.scelta_pot = "fr"
	main._avvia_locale()
	main.velocita = 300.0
	var ok := 0
	# 1) movimento: clic su un mio pezzo
	var r := await _fino_a_mia_azione()
	var i: int = r["g"]
	var gm: Array = main.m.gruppi_mobili(i, [])
	if not gm.is_empty():
		var key: String = gm[0]
		var t := Motore.SIGLA_U.find(key.get_slice("|", 1))
		main._oggetto_cliccato("u:%s:%s:%d" % [key.get_slice("|", 0), main.m.pot(i), t], key.get_slice("|", 0))
		await _w(10)
		var r2: Dictionary = main.m.richiesta()
		print("MOVIMENTO: ", r2.get("k", ""), " ", "OK" if r2.get("k", "") == "muovi_a" else "NO")
		if r2.get("k", "") == "muovi_a":
			ok += 1
			main.vista.aggiorna()
			await _w(10)
			root.get_viewport().get_texture().get_image().save_png("/tmp/shot_clic_muovi.png")
			var dest: String = r2["opz"][0]["id"]
			main._regione_cliccata(dest)
			await _w(5)
			print("   dopo destinazione: ", main.m.richiesta().get("k", ""))
	# 2) tessera: clic su una pila di tessere
	r = await _fino_a_mia_azione()
	i = r["g"]
	var prendibili: Array = main.m.tessere_prendibili(i)
	var prima: int = main.m.g(i)["tessere"].size()
	var scelta := ""
	for t2 in ["agricoltura", "riserve", "banca", "diplomazia", "riforma"]:
		if t2 in prendibili:
			scelta = t2
			break
	if scelta != "":
		var pv_prima: int = main.m.s["banco"][scelta]
		main._oggetto_cliccato("tessera:" + scelta, "")
		await _w(10)
		print("TESSERA ", scelta, ": banco ", pv_prima, " -> ", main.m.s["banco"][scelta], " ", "OK" if int(main.m.s["banco"][scelta]) == pv_prima - 1 else "NO")
		if int(main.m.s["banco"][scelta]) == pv_prima - 1:
			ok += 1
	# 3) attacco: clic su un bersaglio
	for giro in 6:
		r = await _fino_a_mia_azione()
		i = r["g"]
		var regs: Array = main.m.regioni_attacco(i)
		if regs.is_empty():
			await main._decidi("passa")
			continue
		var reg: String = regs[0]
		var b: Dictionary = main.m.bersagli(i, reg)[0]
		var chiave: String = main._chiave_bersaglio(reg, b["id"])
		var log_prima: int = main.m.s["log"].size()
		main._oggetto_cliccato(chiave, reg)
		await _w(10)
		var attaccato := false
		for l in main.m.s["log"].slice(log_prima):
			if " attacca " in str(l):
				attaccato = true
		print("ATTACCO ", chiave, ": ", "OK" if attaccato else "NO", " ora ", main.m.richiesta().get("k", ""))
		if attaccato:
			ok += 1
		break
	print("RISULTATO ", ok, "/3")
	quit()

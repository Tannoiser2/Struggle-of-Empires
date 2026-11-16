extends SceneTree
## Gioca il tutorial attraverso l'interfaccia: Avanti sulle pagine, le mosse richieste, Continua nelle battaglie.
## xvfb-run godot --path . -s res://tests/tutorial_auto.gd [-- foto]
var main
var foto := false
func _initialize():
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run.call_deferred()

func shot(nome: String):
	for i in 14: await process_frame
	root.get_viewport().get_texture().get_image().save_png("/tmp/tut_%s.png" % nome)
	print("shot ", nome)

func _run():
	foto = "foto" in OS.get_cmdline_user_args()
	for q in 10: await process_frame
	main._avvia_tutorial()
	main.velocita = 3.0 if foto else 40.0
	var tut: Tutorial = main.tutorial
	var cicli := 0
	var provato_errore := false
	var ultimo_idx := -1
	var fotografati := {}
	while cicli < 60000 and not tut.libero:
		cicli += 1
		await process_frame
		if main.popup_aperto:
			main._chiudi_popup()
		if main.vista != null and main.vista.bottone_riquadro.visible:
			if foto and not fotografati.has("batt%d" % tut.idx):
				fotografati["batt%d" % tut.idx] = true
				await shot("battaglia_%d" % tut.idx)
			main.vista.continua_premuto.emit()
		var p: Dictionary = tut._passo()
		if p.is_empty():
			break
		if tut.idx != ultimo_idx:
			ultimo_idx = tut.idx
			print("PASSO %d %s: %s" % [tut.idx + 1, p["t"], p["titolo"]])
			if "ipad" in OS.get_cmdline_user_args() and tut.idx > 27:
				break
			if foto and tut.idx in ([0, 1, 3, 6, 12, 27, 35, 50, 60] if not "ipad" in OS.get_cmdline_user_args() else [6, 26]):
				await shot("passo_%02d" % (tut.idx + 1))
		if p["t"] == "pagina":
			if not tut.in_attesa_anim:
				for q in 3: await process_frame
				tut._avanti()
			continue
		if p["t"] == "mossa":
			var r: Dictionary = main.m.richiesta()
			if r.is_empty() or not main.io(int(r["g"])) or main.piano_in_corso:
				continue
			if r["k"] != p["k"]:
				continue
			if not provato_errore and r["k"] == "piazza":
				provato_errore = true
				var passo0: int = main.m.s["passo"]
				await main._decidi("e|casa_gb")
				print("MOSSA SBAGLIATA rifiutata: ", main.m.s["passo"] == passo0, " avviso: ", tut.avviso.text)
				if foto:
					await shot("rifiuto")
			await main._decidi(p["id"])
	if "ipad" in OS.get_cmdline_user_args():
		quit(); return
	print("FINE COPIONE libero=", tut.libero, " cicli=", cicli, " passo=", main.m.s["passo"])
	var g: Dictionary = main.m.g(0)
	print("STATO gb oro=%d pop=%d tens=%d proiezione=%s" % [g["oro"], g["pop"], g["tens"], str(main.m.punti_proiezione())])
	if foto:
		await shot("libero")
	quit()

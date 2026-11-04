extends SceneTree
## Partite automatiche tutte IA: controlla che finiscano e mostra i punteggi.
## godot --headless --path . -s res://tests/sim.gd -- [partite] [giocatori]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 5
	var np := int(args[1]) if args.size() > 1 else 4
	var vittorie := {}
	var tot_passi := 0
	var t0 := Time.get_ticks_msec()
	for p in n:
		var mo := Motore.new()
		var pots: Array = Dati.POTENZE.duplicate()
		var r := RandomNumberGenerator.new()
		r.seed = p * 13 + 5 + np * 1000
		for k in range(pots.size() - 1, 0, -1):
			var j := r.randi_range(0, k)
			var t = pots[k]; pots[k] = pots[j]; pots[j] = t
		pots = pots.slice(0, np)
		mo.nuova({"pot": pots, "seat": [], "seed": p * 101 + 7 + np})
		var ia := IA.new(mo)
		var passi := 0
		var conta := {}
		while not mo.finita() and passi < 30000:
			var rq := mo.richiesta()
			if rq.is_empty():
				push_error("nessuna richiesta ma partita non finita, stadio " + str(mo.s["stadio"]))
				break
			var id := ia.decidi(rq)
			conta[rq["k"]] = conta.get(rq["k"], 0) + 1
			if not mo.applica({"id": id}):
				push_error("decisione rifiutata %s %s" % [rq["k"], id])
				break
			passi += 1
		tot_passi += passi
		var w = mo.s["esito"].get("vince", -1)
		var riga := []
		for i in mo.np():
			riga.append("%s %dpv %dt %do" % [mo.pot(i), int(mo.g(i)["pv"]), int(mo.g(i)["tens"]), int(mo.g(i)["oro"])])
		print("partita %d (%s): passi %d, vince %s | %s" % [p, "FINITA" if mo.finita() else "NON FINITA", passi, mo.pot(w) if w is int and w >= 0 else "?", ", ".join(riga)])
		if p == 0:
			print("   decisioni: ", conta)
		if not mo.finita():
			print(mo.richiesta())
			for l in mo.s["log"].slice(-25):
				print("   ", l)
	print("passi medi ", tot_passi / max(1, n), " tempo ms ", Time.get_ticks_msec() - t0)
	quit()

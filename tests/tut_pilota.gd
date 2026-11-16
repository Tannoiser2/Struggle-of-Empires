extends SceneTree
## Gioca la partita del tutorial con le mosse previste e stampa richieste e registro.
## godot --headless -s res://tests/tut_pilota.gd -- "k=id;k=id;..."
func _initialize():
	var args := OS.get_cmdline_user_args()
	var mosse: Array = []
	if args.size() > 0 and args[0] != "":
		for x in args[0].split(";"):
			mosse.append(x.split("=", true, 1))
	var m := Motore.new()
	m.nuova({"pot": ["gb", "fr", "sp", "ru"], "seat": [0, -1, -1, -1], "seed": 23, "nomi": ["", "", "", ""]})
	var ia := IA.new(m)
	var visto := 0
	var k := 0
	var guard := 0
	while guard < 5000 and not m.finita():
		guard += 1
		var r := m.richiesta()
		if r.is_empty():
			break
		while visto < m.s["log"].size():
			print("   LOG ", m.s["log"][visto])
			visto += 1
		if int(m.g(r["g"])["seat"]) < 0:
			m.applica({"id": ia.decidi(r)})
			continue
		if k >= mosse.size():
			print("RICHIESTA UMANA k=", r["k"], " passo=", m.s["passo"], " testo=", r["testo"])
			var n := 0
			for o in r["opz"]:
				n += 1
				if n > 60: break
				print("     ", o["id"], "  ", o.get("testo", ""))
			print("STATO gb oro=%d pop=%d tens=%d" % [m.g(0)["oro"], m.g(0)["pop"], m.g(0)["tens"]])
			break
		var mv: Array = mosse[k]
		if mv[1].ends_with("*"):
			if mv[0] == r["k"]:
				print(">> TU ", r["k"], " = ", mv[1].trim_suffix("*"), "   [passo ", m.s["passo"], "]")
				m.applica({"id": mv[1].trim_suffix("*")})
				continue
			k += 1
			continue
		if mv[0] != r["k"]:
			print("ATTESO ", mv, " MA RICHIESTA ", r["k"], " ", r["testo"])
			for o in r["opz"]:
				print("     ", o["id"], "  ", o.get("testo", ""))
			break
		print(">> TU ", r["k"], " = ", mv[1], "   [passo ", m.s["passo"], "]")
		if not m.applica({"id": mv[1]}):
			print("NON VALIDA")
			break
		k += 1
	while visto < m.s["log"].size():
		print("   LOG ", m.s["log"][visto])
		visto += 1
	print("PROIEZIONE ", m.punti_proiezione())
	for i in 4:
		var cs := []
		for r in m.s["reg"]:
			if m.c(r, m.pot(i)) > 0:
				cs.append("%s:%d" % [r, m.c(r, m.pot(i))])
		print("  ", m.pot(i), " oro=", m.g(i)["oro"], " pop=", m.g(i)["pop"], " tens=", m.g(i)["tens"], " C=", ", ".join(cs))
	var us := []
	for r in m.s["reg"]:
		if m.s["reg"][r]["u"].has("gb"):
			us.append("%s:%s" % [r, str(m.s["reg"][r]["u"]["gb"])])
	print("  unita gb: ", ", ".join(us))
	quit()

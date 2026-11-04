extends SceneTree
## Stampa il diario di una partita tutta IA.  -- [giocatori] [seme]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var np := int(args[0]) if args.size() > 0 else 4
	var seed := int(args[1]) if args.size() > 1 else 11
	var mo := Motore.new()
	mo.nuova({"pot": Dati.POTENZE.slice(0, np), "seat": [], "seed": seed})
	var ia := IA.new(mo)
	var passi := 0
	while not mo.finita() and passi < 30000:
		var rq := mo.richiesta()
		if rq.is_empty():
			break
		mo.applica({"id": ia.decidi(rq)})
		passi += 1
	for l in mo.s["log"]:
		print(l)
	quit()

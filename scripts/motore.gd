## Motore delle regole di Struggle of Empires (Martin Wallace, edizione Deluxe).
## Tutto lo stato della partita sta in `s` (un dizionario salvabile in JSON e trasmissibile in rete).
## Il motore va avanti da solo finché serve una decisione: `richiesta()` dice chi decide cosa,
## con l'elenco delle opzioni; `applica({"id": ...})` la esegue. I dadi usano un generatore con seme:
## la stessa sequenza di decisioni dà sempre la stessa partita (così funziona il gioco online).
class_name Motore
extends RefCounted

var s: Dictionary = {}
var rng := RandomNumberGenerator.new()

const MAX_LOG := 3000
const U_E := 0
const U_F := 1
const U_FO := 2
const NOMI_U := ["Esercito", "Flotta", "Forte"]
const NOMI_U_PL := ["Eserciti", "Flotte", "Forti"]
const SIGLA_U := ["e", "f", "fo"]

# ============================================================ avvio

## cfg: {pot: [potenze dei giocatori, in ordine di posto], seat: [-1 = IA, altrimenti posto], nomi: [...], seed}
func nuova(cfg: Dictionary) -> void:
	rng.seed = int(cfg.get("seed", 1))
	var pots: Array = cfg["pot"]
	var np := pots.size()
	s = {"seed": int(cfg.get("seed", 1)), "passo": 0, "np": np, "guerra": 1, "round": 0, "stadio": "piazzamento",
		"giocatori": [], "reg": {}, "locali": {}, "banco": Dati.tessere_per(np), "sacchetto": [], "esposti": 0,
		"all": {}, "slot": {"R": [], "B": []}, "ordine": [], "tidx": 0, "martelletto": 0, "t": {}, "ctx": {},
		"cb": {}, "asta": {}, "coda": [], "log": [], "segrete": {"pirati": {}, "rivolta": {}}, "vietate": {},
		"blocco": {}, "np_pot": [], "piaz": {"giro": 0, "k": 0}, "esito": {}, "ultimo_cb": {}, "patti": [],
		"rep": [], "eventi": [], "storia_pv": []}
	for r in Dati.REGIONI:
		s["reg"][r] = {"n": [], "c": {}, "u": {}}
	for la in Dati.ALLEANZE:
		s["locali"][la] = ""
	var seats: Array = cfg.get("seat", [])
	var nomi: Array = cfg.get("nomi", [])
	for i in np:
		var p: String = pots[i]
		s["giocatori"].append({"pot": p, "seat": int(seats[i]) if i < seats.size() else -1,
			"nome": str(nomi[i]) if i < nomi.size() and str(nomi[i]) != "" else Dati.NOME_POT[p],
			"oro": 10, "pop": 5, "tens": 0, "pv": 0, "tessere": [], "fuori": false})
		s["rep"].append(0.75)
	for p in Dati.POTENZE:
		if not (p in pots):
			s["np_pot"].append(p)
	# sacchetto dei segnalini neutrali
	s["sacchetto"] = Dati.segnalini_neutrali()
	_mescola(s["sacchetto"])
	_log("Inizia la Lotta degli Imperi: %d potenze guidate da giocatori." % np)
	# potenze non giocanti: 5 regioni diverse ciascuna, con un Esercito (o una Flotta su 1-2 in mare)
	for p in s["np_pot"]:
		var regs := _pesca_regioni_diverse(5)
		for r in regs:
			if r in Dati.NAVALI and r != "baltico" and r != "mediterraneo" and rng.randi_range(1, 6) <= 2:
				_add_u(r, p, U_F, 1)
			elif r in Dati.NAVALI and rng.randi_range(1, 6) <= 2:
				_add_u(r, p, U_F, 1)
			else:
				_add_u(r, p, U_E, 1)
		if np <= 3:
			# una delle sue regioni ha un segnalino Controllo invece dell'Esercito
			var r: String = regs[rng.randi_range(0, regs.size() - 1)]
			var u: Array = s["reg"][r]["u"][p]
			u[U_E] = 0
			u[U_F] = 0
			_add_c(r, p, 1)
	# segnalini neutrali sulla plancia
	_piazza_neutrali(Dati.neutrali_per_guerra(np))
	# ogni giocatore riceve segnalini Controllo in regioni diverse
	for i in np:
		var regs := _pesca_regioni_diverse(6 if np <= 3 else 5)
		for r in regs:
			_add_c(r, pot(i), 1)
		if np <= 3:
			_prendi_tessera_gratis(i, "agricoltura")
			_prendi_tessera_gratis(i, "riserve")
	s["piaz"] = {"giro": 0, "k": 0}
	_log("Ogni potenza piazza a turno 5 unità militari.")
	avanza()

func _prendi_tessera_gratis(i: int, t: String) -> void:
	g(i)["tessere"].append({"t": t, "usata": false})

## pesca segnalini finché ottiene n regioni diverse; i doppioni tornano nel sacchetto.
func _pesca_regioni_diverse(n: int) -> Array:
	var regs: Array = []
	var rimessi: Array = []
	while regs.size() < n and not s["sacchetto"].is_empty():
		var seg: Dictionary = s["sacchetto"].pop_back()
		if seg["reg"] in regs:
			rimessi.append(seg)
		else:
			regs.append(seg["reg"])
			s["esposti"] += 1
	for x in rimessi:
		s["sacchetto"].append(x)
	_mescola(s["sacchetto"])
	return regs

func _piazza_neutrali(n: int) -> void:
	var piazzati: Array = []
	for k in n:
		if s["sacchetto"].is_empty():
			break
		var seg: Dictionary = s["sacchetto"].pop_back()
		s["reg"][seg["reg"]]["n"].append(seg)
		piazzati.append(Dati.REGIONI[seg["reg"]]["nome"])
	if not piazzati.is_empty():
		_log("Nuovi segnalini neutrali: " + ", ".join(piazzati) + ".")

func _mescola(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

func _salva_rng() -> void:
	s["rng"] = str(rng.state)

## dopo il caricamento di uno stato salvato
func ripristina(stato: Dictionary) -> void:
	s = stato
	rng.seed = int(s["seed"])
	rng.state = int(str(s.get("rng", "0")))

# ============================================================ accesso

func g(i: int) -> Dictionary:
	return s["giocatori"][i]

func pot(i: int) -> String:
	return g(i)["pot"]

func np() -> int:
	return int(s["np"])

## indice del giocatore che guida la potenza, -1 se non giocante
func gioc_di(p: String) -> int:
	for i in np():
		if pot(i) == p:
			return i
	return -1

func nome(i: int) -> String:
	return g(i)["nome"]

func nome_pot(p: String) -> String:
	var i := gioc_di(p)
	return nome(i) if i >= 0 else Dati.NOME_POT[p]

func alleanza(p: String) -> String:
	return str(s["all"].get(p, ""))

## due potenze sono alleate se stanno nella stessa Grande Alleanza
func alleati(a: String, b: String) -> bool:
	if a == b:
		return true
	var x := alleanza(a)
	return x != "" and x == alleanza(b)

func u(reg: String, p: String, t: int) -> int:
	var d: Dictionary = s["reg"][reg]["u"]
	if not d.has(p):
		return 0
	return int(d[p][t])

func _add_u(reg: String, p: String, t: int, n: int) -> void:
	var d: Dictionary = s["reg"][reg]["u"]
	if not d.has(p):
		d[p] = [0, 0, 0]
	d[p][t] = maxi(0, int(d[p][t]) + n)
	if d[p][0] == 0 and d[p][1] == 0 and d[p][2] == 0:
		d.erase(p)

func c(reg: String, p: String) -> int:
	return int(s["reg"][reg]["c"].get(p, 0))

func _add_c(reg: String, p: String, n: int) -> void:
	var d: Dictionary = s["reg"][reg]["c"]
	d[p] = maxi(0, int(d.get(p, 0)) + n)
	if d[p] == 0:
		d.erase(p)

func tot_u(p: String, t: int) -> int:
	var n := 0
	for r in s["reg"]:
		n += u(r, p, t)
	return n

func tot_unita(p: String) -> int:
	return tot_u(p, U_E) + tot_u(p, U_F) + tot_u(p, U_FO)

## segnalini Controllo sulla mappa (quelli sotto un segnalino Pirati/Rivolta non contano)
func tot_c(p: String) -> int:
	var n := 0
	for r in s["reg"]:
		n += c(r, p)
	return n

func tot_c_posati(p: String) -> int:
	var n := tot_c(p)
	for k in s["segrete"]:
		if s["segrete"][k].get("pot", "") == p:
			n += 1
	return n

func pezzi_liberi(p: String, t: int) -> int:
	return [Dati.MAX_ESERCITI, Dati.MAX_FLOTTE, Dati.MAX_FORTI][t] - tot_u(p, t)

func casa(p: String) -> String:
	return Dati.CASA[p]

func ha_tessera(i: int, t: String, solo_pronte := false) -> bool:
	for x in g(i)["tessere"]:
		if x["t"] == t and (not solo_pronte or not x["usata"]):
			return true
	return false

func conta_tessere(i: int, t: String) -> int:
	var n := 0
	for x in g(i)["tessere"]:
		if x["t"] == t:
			n += 1
	return n

func conta_tessere_pot(p: String, t: String) -> int:
	var i := gioc_di(p)
	return conta_tessere(i, t) if i >= 0 else 0

func locali_di(p: String) -> int:
	var n := 0
	for la in s["locali"]:
		if s["locali"][la] == p:
			n += 1
	return n

func corrente() -> int:
	if s["ordine"].is_empty():
		return -1
	return int(s["ordine"][s["tidx"]])

func _log(t: String) -> void:
	s["log"].append(t)
	if s["log"].size() > MAX_LOG:
		s["log"] = s["log"].slice(s["log"].size() - MAX_LOG)

func _evento(d: Dictionary) -> void:
	d["n"] = int(s["passo"])
	s["eventi"].append(d)
	if s["eventi"].size() > 60:
		s["eventi"] = s["eventi"].slice(s["eventi"].size() - 60)

# ============================================================ denaro, tensione, popolazione

## paga una spesa; se l'oro non basta usa la Tassazione (2 Oro, o 3 con la Banca, e 1 Tensione ciascuna)
func _paga(i: int, n: int, motivo := "") -> void:
	if n <= 0:
		return
	var gg := g(i)
	var tasse := 0
	while int(gg["oro"]) < n:
		gg["oro"] += 3 if ha_tessera(i, "banca") else 2
		gg["tens"] += 1
		tasse += 1
	gg["oro"] -= n
	if tasse > 0:
		_log("%s ricorre alla Tassazione %d volt%s (+%d Tensione)%s." % [nome(i), tasse, "a" if tasse == 1 else "e", tasse,
			" per " + motivo if motivo != "" else ""])

## quante tassazioni servirebbero per pagare n
func tasse_per(i: int, n: int) -> int:
	var oro: int = g(i)["oro"]
	var k := 0
	var per := 3 if ha_tessera(i, "banca") else 2
	while oro < n:
		oro += per
		k += 1
	return k

func _tensione(p: String, n: int) -> void:
	var i := gioc_di(p)
	if i >= 0:
		g(i)["tens"] = maxi(0, int(g(i)["tens"]) + n)

func _pop(i: int, n: int) -> void:
	g(i)["pop"] = clampi(int(g(i)["pop"]) + n, 0, 9)

# ============================================================ ciclo principale

func richiesta() -> Dictionary:
	if s["coda"].is_empty():
		return {}
	return s["coda"][0]

func finita() -> bool:
	return s["stadio"] == "fine"

func _chiedi(i: int, k: String, testo: String, opz: Array, extra := {}) -> void:
	var r := {"k": k, "g": i, "testo": testo, "opz": opz}
	for x in extra:
		r[x] = extra[x]
	s["coda"].append(r)

func avanza() -> void:
	var guard := 0
	while s["coda"].is_empty() and s["stadio"] != "fine":
		guard += 1
		if guard > 2000:
			push_error("motore bloccato in " + str(s["stadio"]))
			return
		_passo_auto()
	_salva_rng()

func applica(dec: Dictionary) -> bool:
	var r := richiesta()
	if r.is_empty():
		return false
	var scelta = null
	for o in r["opz"]:
		if str(o["id"]) == str(dec.get("id", "")):
			scelta = o
			break
	if scelta == null:
		push_warning("decisione non valida: %s per %s" % [dec, r["k"]])
		return false
	s["coda"].pop_front()
	s["passo"] += 1
	call("_dec_" + str(r["k"]), int(r["g"]), scelta, r)
	avanza()
	return true

func _passo_auto() -> void:
	match s["stadio"]:
		"piazzamento":
			_chiedi_piazzamento()
		"asta":
			_chiedi_asta()
		"turno":
			_passo_turno()
		"combattimento":
			_passo_combattimento()
		"fine_turno":
			_fine_turno()
		"rendita":
			_rendita()
		"punteggio":
			_punteggio()
		"fine_guerra":
			_fine_guerra()
		"inizio_guerra":
			_inizio_guerra()
		_:
			push_error("stadio sconosciuto " + str(s["stadio"]))
			s["stadio"] = "fine"

# ============================================================ piazzamento iniziale

func _chiedi_piazzamento() -> void:
	var pz: Dictionary = s["piaz"]
	if int(pz["giro"]) >= 5:
		_log("Piazzamento concluso. Si formano le Grandi Alleanze della prima guerra.")
		s["stadio"] = "inizio_guerra"
		s["asta"] = {}
		return
	var i := (int(s["martelletto"]) + int(pz["k"])) % np()
	var opz: Array = []
	var p := pot(i)
	for t in [U_E, U_F, U_FO]:
		if pezzi_liberi(p, t) <= 0:
			continue
		var regs: Array = Dati.REGIONI_PV.duplicate() if t != U_F else Dati.NAVALI.duplicate()
		regs.append(casa(p))
		for r in regs:
			opz.append({"id": "%s|%s" % [SIGLA_U[t], r], "reg": r, "testo": "%s in %s" % [NOMI_U[t], Dati.REGIONI[r]["nome"]]})
	_chiedi(i, "piazza", "Piazzamento %d di 5: scegli un'unità e la regione." % (int(pz["giro"]) + 1), opz)

func _dec_piazza(i: int, o: Dictionary, _r: Dictionary) -> void:
	var parti: PackedStringArray = str(o["id"]).split("|")
	var t: int = SIGLA_U.find(parti[0])
	_add_u(parti[1], pot(i), t, 1)
	_log("%s piazza %s in %s." % [nome(i), NOMI_U[t].to_lower(), Dati.REGIONI[parti[1]]["nome"]])
	var pz: Dictionary = s["piaz"]
	pz["k"] += 1
	if int(pz["k"]) >= np():
		pz["k"] = 0
		pz["giro"] += 1

# ============================================================ guerre e Grandi Alleanze

func _inizio_guerra() -> void:
	if int(s["guerra"]) > 1:
		_piazza_neutrali(Dati.neutrali_per_guerra(np()))
	s["all"] = {}
	s["slot"] = {"R": [], "B": []}
	s["ordine"] = []
	_log("=== %s GUERRA ===" % ["PRIMA", "SECONDA", "TERZA"][int(s["guerra"]) - 1])
	_nuova_asta()
	s["stadio"] = "asta"

func liberi_giocatori() -> Array:
	var out: Array = []
	for i in np():
		if alleanza(pot(i)) == "":
			out.append(pot(i))
	return out

func liberi_np() -> Array:
	var out: Array = []
	for p in s["np_pot"]:
		if alleanza(p) == "":
			out.append(p)
	return out

func _nuova_asta() -> void:
	var prop := int(s["martelletto"])
	s["martelletto"] = (prop + 1) % np()
	s["asta"] = {"turno": prop, "R": "", "B": "", "offerta": -1, "ultimo": -1, "passi": 0}

## coppie che si possono proporre: [rossa, blu]; "" = nessuno (solo per l'ultimo giocatore dispari a 7)
func coppie_asta() -> Array:
	var lib := liberi_giocatori()
	var out: Array = []
	if lib.size() >= 2:
		for a in lib:
			for b in lib:
				if a != b:
					out.append([a, b])
	elif lib.size() == 1:
		var npl := liberi_np()
		if npl.is_empty():
			out.append([lib[0], ""])
			out.append(["", lib[0]])
		else:
			for x in npl:
				out.append([lib[0], x])
				out.append([x, lib[0]])
	return out

func _chiedi_asta() -> void:
	var a: Dictionary = s["asta"]
	var i: int = a["turno"]
	var opz: Array = []
	var minimo := int(a["offerta"]) + 1
	var massimo := minimo + 5 if int(a["offerta"]) >= 0 else 10
	if int(a["offerta"]) >= 0:
		opz.append({"id": "passa", "testo": "Passo (mi va bene la proposta)"})
	for cp in coppie_asta():
		for b in range(minimo, massimo + 1):
			opz.append({"id": "%s|%s|%d" % [cp[0], cp[1], b], "R": cp[0], "B": cp[1], "offerta": b})
	var testo := "Proponi le due potenze da mettere nelle Grandi Alleanze e la tua offerta." if int(a["offerta"]) < 0 \
		else "Proposta attuale di %s (%d Oro): %s nell'Alleanza Rossa, %s nell'Alleanza Blu. Passi o rilanci?" % [
			nome(int(a["ultimo"])), int(a["offerta"]), _np_o_vuoto(a["R"]), _np_o_vuoto(a["B"])]
	_chiedi(i, "asta", testo, opz, {"minimo": minimo, "massimo": massimo})

func _np_o_vuoto(p: String) -> String:
	return "nessuno" if p == "" else nome_pot(p)

func _dec_asta(i: int, o: Dictionary, _r: Dictionary) -> void:
	var a: Dictionary = s["asta"]
	if o["id"] == "passa":
		a["passi"] += 1
		_log("%s passa." % nome(i))
	else:
		a["R"] = o["R"]
		a["B"] = o["B"]
		a["offerta"] = int(o["offerta"])
		a["ultimo"] = i
		a["passi"] = 0
		_log("%s propone %s (Rossa) e %s (Blu), offrendo %d Oro." % [nome(i), _np_o_vuoto(o["R"]), _np_o_vuoto(o["B"]), int(o["offerta"])])
	if int(a["passi"]) >= np() - 1:
		_vinci_asta()
	else:
		a["turno"] = (i + 1) % np()

func _vinci_asta() -> void:
	var a: Dictionary = s["asta"]
	var w: int = a["ultimo"]
	_paga(w, int(a["offerta"]), "l'asta")
	for lato in ["R", "B"]:
		var p: String = a[lato]
		if p != "":
			s["all"][p] = lato
			s["slot"][lato].append(p)
	_log("%s vince l'asta per %d Oro: %s entra nell'Alleanza Rossa, %s nella Blu." % [nome(w), int(a["offerta"]),
		_np_o_vuoto(a["R"]), _np_o_vuoto(a["B"])])
	_evento({"tipo": "asta", "g": w, "R": a["R"], "B": a["B"], "offerta": a["offerta"]})
	if liberi_giocatori().is_empty():
		_ordine_di_turno()
	else:
		_nuova_asta()

func _ordine_di_turno() -> void:
	var ordine: Array = []
	var n := maxi(s["slot"]["R"].size(), s["slot"]["B"].size())
	for k in n:
		for lato in ["R", "B"]:
			if k < s["slot"][lato].size():
				var i := gioc_di(s["slot"][lato][k])
				if i >= 0:
					ordine.append(i)
	s["ordine"] = ordine
	s["martelletto"] = ordine[ordine.size() - 1]
	var nomi: Array = []
	for i in ordine:
		nomi.append(nome(i))
	_log("Ordine di gioco: " + ", ".join(nomi) + ".")
	s["round"] = 1
	s["tidx"] = 0
	s["asta"] = {}
	_inizia_turno()

# ============================================================ turni dei giocatori

func _inizia_turno() -> void:
	s["t"] = {"az": 2, "spec": false, "colgcc": false, "attacco": false, "passi": 0, "ricatti": [], "costruito": false}
	s["ctx"] = {}
	s["stadio"] = "turno"
	_log("-- Round %d, tocca a %s --" % [int(s["round"]), nome(corrente())])

func _fine_turno() -> void:
	var t: Dictionary = s["t"]
	var i := corrente()
	# Passare: chi passa entrambe le azioni, o ne passa una senza attaccare, riduce di 1 la Tensione
	if int(t.get("passi", 0)) >= 2 or (int(t.get("passi", 0)) >= 1 and not t.get("attacco", false)):
		if int(g(i)["tens"]) > 0:
			g(i)["tens"] -= 1
			_log("%s passa e riduce la Tensione di 1." % nome(i))
	s["tidx"] += 1
	if int(s["tidx"]) >= s["ordine"].size():
		s["tidx"] = 0
		s["round"] += 1
		s["vietate"] = {}
		for k in np():
			s["rep"][k] = minf(1.0, float(s["rep"][k]) + 0.03)
		if int(s["round"]) > Dati.round_per_guerra(np()):
			s["stadio"] = "rendita"
			return
	_inizia_turno()

func _passo_turno() -> void:
	var i := corrente()
	var ctx: Dictionary = s["ctx"]
	if ctx.has("fase"):
		call("_chiedi_" + str(ctx["fase"]), i)
		return
	var opz := opzioni_azione(i)
	if opz.size() == 1 and opz[0]["id"] == "fine":
		s["stadio"] = "fine_turno"
		return
	var t: Dictionary = s["t"]
	var testo := "Hai ancora %d azion%s." % [int(t["az"]), "e" if int(t["az"]) == 1 else "i"] if int(t["az"]) > 0 \
		else "Hai usato le tue azioni: puoi ancora usare azioni gratuite o finire il turno."
	_chiedi(i, "azione", testo, opz)

func opzioni_azione(i: int) -> Array:
	var t: Dictionary = s["t"]
	var p := pot(i)
	var gg := g(i)
	var opz: Array = []
	var az := int(t["az"])
	if az > 0:
		if int(gg["pop"]) >= 1 and (pezzi_liberi(p, U_E) > 0 or pezzi_liberi(p, U_F) > 0 or pezzi_liberi(p, U_FO) > 0):
			opz.append({"id": "costruisci", "testo": "Costruire 1 unità", "cat": "reg"})
		if not gruppi_mobili(i, []).is_empty():
			opz.append({"id": "muovi", "testo": "Muovere %d unità" % (3 if ha_tessera(i, "logistica") else 2), "cat": "reg"})
		if not regioni_attacco(i).is_empty():
			opz.append({"id": "attacca", "testo": "Eseguire 1 attacco (2 Oro)", "cat": "reg"})
		if not t["colgcc"] and int(gg["pop"]) >= 1 and not segnalini_tipo("col").is_empty() and tot_c_posati(p) < Dati.MAX_CONTROLLO:
			opz.append({"id": "colonizza", "testo": "Colonizzare (1 Popolazione)", "cat": "reg"})
		if not t["colgcc"] and u("africa", p, U_F) > 0 and not segnalini_tipo("gcc").is_empty() and tot_c_posati(p) < Dati.MAX_CONTROLLO:
			opz.append({"id": "commercio", "testo": "Commercio Costa d'Oro", "cat": "reg"})
		if not t["spec"]:
			if not alleanze_disponibili(i).is_empty():
				opz.append({"id": "alleanza", "testo": "Stipulare un'Alleanza Locale", "cat": "spec"})
			if not tessere_prendibili(i).is_empty():
				opz.append({"id": "tessera", "testo": "Reclamare 1 tessera", "cat": "spec"})
			if not segrete_disponibili(i).is_empty():
				opz.append({"id": "segreta", "testo": "Usare un'azione segreta", "cat": "spec"})
		opz.append({"id": "passa", "testo": "Passare", "cat": "reg"})
	# azioni gratuite
	for k in gg["tessere"].size():
		var x: Dictionary = gg["tessere"][k]
		if x["usata"]:
			continue
		var tt: String = x["t"]
		var cat: String = Dati.TESSERE[tt]["cat"]
		var ok := false
		match tt:
			"agricoltura":
				ok = int(gg["pop"]) < 9
			"mercenari":
				ok = pezzi_liberi(p, U_E) > 0
			"reclutamento":
				ok = pezzi_liberi(p, U_F) > 0
			"milizia_indigena":
				ok = pezzi_liberi(p, U_E) > 0 and not colonie_milizia(i).is_empty()
			"ministero":
				ok = not regioni_attacco(i).is_empty()
			"diplomazia":
				ok = not alleanze_disponibili(i).is_empty()
			"blocco":
				ok = s["blocco"].is_empty() and not colonie_blocco(i).is_empty()
			_:
				ok = cat == "com" and _oro_commercio(i, tt) > 0
		if ok:
			opz.append({"id": "lib|%d" % k, "testo": "Usare: " + Dati.TESSERE[tt]["nome"], "cat": "lib", "tessera": tt})
	for j in np():
		if j != i and not (j in t["ricatti"]) and not g(j)["fuori"]:
			opz.append({"id": "ricatto|%d" % j, "testo": "Trattare con %s" % nome(j), "cat": "tratt", "chi": j})
	opz.append({"id": "fine", "testo": "Fine del turno" if az == 0 else "Fine del turno (rinunci alle azioni rimaste)", "cat": "fine"})
	return opz

func _usa_azione() -> void:
	s["t"]["az"] = maxi(0, int(s["t"]["az"]) - 1)

func _dec_azione(i: int, o: Dictionary, _r: Dictionary) -> void:
	var id: String = o["id"]
	var t: Dictionary = s["t"]
	if id == "fine":
		s["stadio"] = "fine_turno"
		return
	if id == "passa":
		_usa_azione()
		t["passi"] += 1
		_log("%s passa un'azione." % nome(i))
		return
	if id.begins_with("lib|"):
		_usa_libera(i, int(id.get_slice("|", 1)))
		return
	if id.begins_with("ricatto|"):
		s["ctx"] = {"fase": "ricatto_quanto", "chi": int(id.get_slice("|", 1))}
		return
	match id:
		"costruisci":
			s["ctx"] = {"fase": "costr_tipo"}
		"muovi":
			s["ctx"] = {"fase": "muovi_da", "rest": 3 if ha_tessera(i, "logistica") else 2, "fatti": 0, "falliti": []}
		"attacca":
			s["ctx"] = {"fase": "att_reg", "gratis": false}
		"colonizza":
			s["ctx"] = {"fase": "colonizza"}
		"commercio":
			s["ctx"] = {"fase": "commercio"}
		"alleanza":
			s["ctx"] = {"fase": "alleanza", "gratis": false}
		"tessera":
			s["ctx"] = {"fase": "tessera"}
		"segreta":
			s["ctx"] = {"fase": "segreta"}

func _annulla_opz() -> Dictionary:
	return {"id": "annulla", "testo": "Annulla"}

# ------------------------------------------------------------ costruire

func _chiedi_costr_tipo(i: int) -> void:
	var p := pot(i)
	var opz: Array = []
	for t in [U_E, U_F, U_FO]:
		if pezzi_liberi(p, t) > 0:
			opz.append({"id": SIGLA_U[t], "testo": "%s (restano %d)" % [NOMI_U[t], pezzi_liberi(p, t)]})
	opz.append(_annulla_opz())
	_chiedi(i, "costr_tipo", "Che unità costruisci in patria (costa 1 Popolazione)?", opz)

func _dec_costr_tipo(i: int, o: Dictionary, _r: Dictionary) -> void:
	if o["id"] == "annulla":
		s["ctx"] = {}
		return
	var t: int = SIGLA_U.find(o["id"])
	_usa_azione()
	_pop(i, -1)
	_add_u(casa(pot(i)), pot(i), t, 1)
	s["t"]["costruito"] = true
	_log("%s costruisce %s in patria." % [nome(i), NOMI_U[t].to_lower()])
	s["ctx"] = {"fase": "costr_dest", "tipo": t, "da": casa(pot(i)), "milizia": ha_tessera(i, "milizia") and t == U_E}

func _chiedi_costr_dest(i: int) -> void:
	var ctx: Dictionary = s["ctx"]
	var t: int = ctx["tipo"]
	var opz: Array = [{"id": "resta", "testo": "Resta in %s" % Dati.REGIONI[ctx["da"]]["nome"]}]
	for r in destinazioni(i, ctx["da"], t):
		opz.append({"id": r, "reg": r, "testo": Dati.REGIONI[r]["nome"] + (" (mare aperto)" if lontano(ctx["da"], r) else "")})
	_chiedi(i, "costr_dest", "Dove mandi %s appena costruit%s?" % [["l'Esercito", "la Flotta", "il Forte"][t], "a" if t == U_F else "o"], opz)

func _dec_costr_dest(i: int, o: Dictionary, _r: Dictionary) -> void:
	var ctx: Dictionary = s["ctx"]
	if o["id"] == "resta":
		_dopo_costruzione(i)
		return
	_sposta(i, ctx["da"], o["id"], int(ctx["tipo"]), "costr")

func _dopo_costruzione(i: int) -> void:
	var ctx: Dictionary = s["ctx"]
	if ctx.get("milizia", false) and int(g(i)["pop"]) >= 1 and pezzi_liberi(pot(i), U_E) > 0:
		s["ctx"] = {"fase": "milizia"}
	else:
		s["ctx"] = {}

func _chiedi_milizia(i: int) -> void:
	_chiedi(i, "milizia", "Milizia: costruisci un altro Esercito in patria (1 Popolazione)?",
		[{"id": "si", "testo": "Sì, un Esercito in più"}, {"id": "no", "testo": "No"}])

func _dec_milizia(i: int, o: Dictionary, _r: Dictionary) -> void:
	if o["id"] == "no":
		s["ctx"] = {}
		return
	_pop(i, -1)
	_add_u(casa(pot(i)), pot(i), U_E, 1)
	_log("%s usa la Milizia: un Esercito in più." % nome(i))
	s["ctx"] = {"fase": "costr_dest", "tipo": U_E, "da": casa(pot(i)), "milizia": false}

# ------------------------------------------------------------ muovere

## regioni dove un'unità di tipo t può andare partendo da `da`
func destinazioni(i: int, da: String, t: int) -> Array:
	var p := pot(i)
	var out: Array = []
	var cands: Array = Dati.NAVALI.duplicate() if t == U_F else Dati.REGIONI_PV.duplicate()
	cands.append(casa(p))
	for r in cands:
		if r == da:
			continue
		if t != U_F and r in Dati.COLONIE:
			if u(r, p, U_F) <= 0:
				continue
			var bl: Dictionary = s["blocco"]
			if not bl.is_empty() and bl["reg"] == r and not alleati(bl["pot"], p) and u(r, p, U_F) <= u(r, bl["pot"], U_F):
				continue
		out.append(r)
	return out

func lontano(a: String, b: String) -> bool:
	var ga: String = Dati.REGIONI[a]["gruppo"]
	var gb: String = Dati.REGIONI[b]["gruppo"]
	return ga != gb

## gruppi di unità che si possono muovere: "reg|sigla"
func gruppi_mobili(i: int, falliti: Array) -> Array:
	var p := pot(i)
	var out: Array = []
	for r in s["reg"]:
		for t in [U_E, U_F, U_FO]:
			if u(r, p, t) <= 0:
				continue
			if t == U_FO and r != casa(p):
				continue
			var key := "%s|%s" % [r, SIGLA_U[t]]
			if falliti.count(key) >= u(r, p, t):
				continue
			if destinazioni(i, r, t).is_empty():
				continue
			out.append(key)
	return out

func _chiedi_muovi_da(i: int) -> void:
	var ctx: Dictionary = s["ctx"]
	var opz: Array = []
	for key in gruppi_mobili(i, ctx["falliti"]):
		var r: String = key.get_slice("|", 0)
		var t: int = SIGLA_U.find(key.get_slice("|", 1))
		opz.append({"id": key, "reg": r, "testo": "%s da %s (%d)" % [NOMI_U[t], Dati.REGIONI[r]["nome"], u(r, pot(i), t)]})
	if int(ctx["fatti"]) > 0:
		opz.append({"id": "fine", "testo": "Basta movimenti"})
	else:
		opz.append(_annulla_opz())
	if opz.size() == 1 and int(ctx["fatti"]) > 0:
		s["ctx"] = {}
		return
	_chiedi(i, "muovi_da", "Movimento %d di %d: scegli l'unità da muovere." % [int(ctx["fatti"]) + 1, int(ctx["fatti"]) + int(ctx["rest"])], opz)

func _dec_muovi_da(i: int, o: Dictionary, _r: Dictionary) -> void:
	if o["id"] == "annulla" or o["id"] == "fine":
		s["ctx"] = {}
		return
	var ctx: Dictionary = s["ctx"]
	ctx["sel"] = o["id"]
	ctx["fase"] = "muovi_a"

func _chiedi_muovi_a(i: int) -> void:
	var ctx: Dictionary = s["ctx"]
	var da: String = str(ctx["sel"]).get_slice("|", 0)
	var t: int = SIGLA_U.find(str(ctx["sel"]).get_slice("|", 1))
	var opz: Array = []
	for r in destinazioni(i, da, t):
		opz.append({"id": r, "reg": r, "testo": Dati.REGIONI[r]["nome"] + (" (mare aperto)" if lontano(da, r) else "")})
	opz.append({"id": "indietro", "testo": "Scegli un'altra unità"})
	_chiedi(i, "muovi_a", "Dove muovi %s da %s?" % [NOMI_U[t].to_lower(), Dati.REGIONI[da]["nome"]], opz, {"da": da})

func _dec_muovi_a(i: int, o: Dictionary, _r: Dictionary) -> void:
	var ctx: Dictionary = s["ctx"]
	if o["id"] == "indietro":
		ctx["fase"] = "muovi_da"
		return
	var da: String = str(ctx["sel"]).get_slice("|", 0)
	var t: int = SIGLA_U.find(str(ctx["sel"]).get_slice("|", 1))
	if int(ctx["fatti"]) == 0:
		_usa_azione()
	ctx["fatti"] += 1
	ctx["rest"] -= 1
	_sposta(i, da, o["id"], t, "muovi")

func _dopo_movimento(i: int) -> void:
	var ctx: Dictionary = s["ctx"]
	if int(ctx["rest"]) <= 0:
		s["ctx"] = {}
	else:
		ctx["fase"] = "muovi_da"
	var _x := i

## sposta un'unità; se attraversa il mare aperto tira il dado del Viaggio (4 riuscito, 1 fermo, 1 affonda).
func _sposta(i: int, da: String, a: String, t: int, cont: String) -> void:
	var p := pot(i)
	if not lontano(da, a):
		_muovi_unita(i, da, a, t)
		_continua(i, cont)
		return
	var d := rng.randi_range(1, 6)
	var esito := "ok" if d <= 4 else ("fermo" if d == 5 else "affonda")
	_evento({"tipo": "viaggio", "g": i, "esito": esito, "da": da, "a": a, "t": t})
	if esito == "ok":
		_log("Viaggio in mare aperto riuscito.")
		_muovi_unita(i, da, a, t)
		_continua(i, cont)
		return
	var ctx: Dictionary = s["ctx"]
	ctx["dsm"] = {"da": da, "a": a, "t": t, "esito": esito, "cont": cont}
	ctx["fase"] = "dsm"
	_log("Viaggio in mare aperto: %s!" % ("l'unità resta ferma" if esito == "fermo" else "tempesta, l'unità rischia di affondare"))
	var _x := p

func _chiedi_dsm(i: int) -> void:
	var d: Dictionary = s["ctx"]["dsm"]
	var opz: Array = []
	var nu: String = NOMI_U[int(d["t"])].to_lower()
	if d["esito"] == "fermo":
		opz.append({"id": "paga1", "testo": "Paga 1 Oro e completa il viaggio"})
		opz.append({"id": "resta", "testo": "L'unità resta in %s" % Dati.REGIONI[d["da"]]["nome"]})
		_chiedi(i, "dsm", "Il dado dice FERMO: %s non parte." % nu, opz)
	else:
		opz.append({"id": "paga3", "testo": "Paga 3 Oro e completa il viaggio"})
		opz.append({"id": "paga2", "testo": "Paga 2 Oro e resta in %s" % Dati.REGIONI[d["da"]]["nome"]})
		opz.append({"id": "affonda", "testo": "Lascia affondare l'unità (+1 Tensione)"})
		_chiedi(i, "dsm", "Il dado dice AFFONDA: %s è in pericolo." % nu, opz)

func _dec_dsm(i: int, o: Dictionary, _r: Dictionary) -> void:
	var ctx: Dictionary = s["ctx"]
	var d: Dictionary = ctx["dsm"]
	ctx.erase("dsm")
	var t: int = d["t"]
	match o["id"]:
		"paga1":
			_paga(i, 1, "il viaggio")
			_muovi_unita(i, d["da"], d["a"], t)
		"paga3":
			_paga(i, 3, "il viaggio")
			_muovi_unita(i, d["da"], d["a"], t)
		"paga2":
			_paga(i, 2, "salvare l'unità")
			_segna_fallito(d)
		"resta":
			_segna_fallito(d)
		"affonda":
			_add_u(d["da"], pot(i), t, -1)
			_tensione(pot(i), 1)
			_log("%s perde %s in mare (+1 Tensione)." % [nome(i), NOMI_U[t].to_lower()])
	_continua(i, d["cont"])

func _segna_fallito(d: Dictionary) -> void:
	var ctx: Dictionary = s["ctx"]
	if ctx.has("falliti"):
		ctx["falliti"].append("%s|%s" % [d["da"], SIGLA_U[int(d["t"])]])

func _continua(i: int, cont: String) -> void:
	match cont:
		"costr":
			_dopo_costruzione(i)
		"muovi":
			_dopo_movimento(i)
		_:
			s["ctx"] = {}

func _muovi_unita(i: int, da: String, a: String, t: int) -> void:
	_add_u(da, pot(i), t, -1)
	_add_u(a, pot(i), t, 1)
	_log("%s muove %s da %s a %s." % [nome(i), NOMI_U[t].to_lower(), Dati.REGIONI[da]["nome"], Dati.REGIONI[a]["nome"]])
	# un blocco cade se chi lo ha posto non ha più flotte nella colonia
	_controlla_blocco()

func _controlla_blocco() -> void:
	var bl: Dictionary = s["blocco"]
	if not bl.is_empty() and u(bl["reg"], bl["pot"], U_F) <= 0:
		_log("Il blocco navale in %s è tolto." % Dati.REGIONI[bl["reg"]]["nome"])
		s["blocco"] = {}
		s["banco"]["blocco"] = int(s["banco"].get("blocco", 0)) + 1

# ------------------------------------------------------------ colonizzare e commercio

func segnalini_tipo(t: String) -> Array:
	var out: Array = []
	for r in Dati.REGIONI_PV:
		for seg in s["reg"][r]["n"]:
			if seg["t"] == t:
				out.append(seg)
	return out

func _chiedi_colonizza(i: int) -> void:
	var opz: Array = []
	var visti := {}
	for seg in segnalini_tipo("col"):
		if visti.has(seg["reg"]):
			continue
		visti[seg["reg"]] = true
		opz.append({"id": str(seg["id"]), "reg": seg["reg"], "testo": "Colonizzare: " + Dati.REGIONI[seg["reg"]]["nome"]})
	opz.append(_annulla_opz())
	_chiedi(i, "colonizza", "Quale segnalino Colonizzare converti (1 Popolazione)?", opz)

func _dec_colonizza(i: int, o: Dictionary, _r: Dictionary) -> void:
	s["ctx"] = {}
	if o["id"] == "annulla":
		return
	_usa_azione()
	s["t"]["colgcc"] = true
	_pop(i, -1)
	var reg := _converti_neutrale(i, int(o["id"]))
	_log("%s colonizza in %s." % [nome(i), Dati.REGIONI[reg]["nome"]])

func _chiedi_commercio(i: int) -> void:
	var opz: Array = []
	var visti := {}
	for seg in segnalini_tipo("gcc"):
		if visti.has(seg["reg"]):
			continue
		visti[seg["reg"]] = true
		opz.append({"id": str(seg["id"]), "reg": seg["reg"], "testo": "Costa d'Oro: " + Dati.REGIONI[seg["reg"]]["nome"]})
	opz.append(_annulla_opz())
	_chiedi(i, "commercio", "Quale segnalino Commercio Costa d'Oro converti?", opz)

func _dec_commercio(i: int, o: Dictionary, _r: Dictionary) -> void:
	s["ctx"] = {}
	if o["id"] == "annulla":
		return
	_usa_azione()
	s["t"]["colgcc"] = true
	var reg := _converti_neutrale(i, int(o["id"]))
	_log("%s converte un segnalino Costa d'Oro in %s." % [nome(i), Dati.REGIONI[reg]["nome"]])

## toglie il segnalino neutrale e mette un Controllo del giocatore; restituisce la regione
func _converti_neutrale(i: int, sid: int) -> String:
	for r in Dati.REGIONI_PV:
		var arr: Array = s["reg"][r]["n"]
		for k in arr.size():
			if int(arr[k]["id"]) == sid:
				var seg: Dictionary = arr[k]
				arr.remove_at(k)
				s["esposti"] += 1
				_add_c(r, pot(i), 1)
				if seg["bonus"] == "oro":
					g(i)["oro"] += 3
					_log("%s guadagna 3 Oro dal segnalino." % nome(i))
				elif seg["bonus"] == "pv":
					g(i)["pv"] += 1
					_log("%s guadagna 1 Punto Vittoria dal segnalino." % nome(i))
				return r
	return ""

# ------------------------------------------------------------ alleanze locali

func alleanze_disponibili(i: int) -> Array:
	if locali_di(pot(i)) >= Dati.MAX_ALLEANZE_LOCALI:
		return []
	var out: Array = []
	for la in Dati.ALLEANZE:
		if s["locali"][la] == "":
			out.append(la)
	return out

func _chiedi_alleanza(i: int) -> void:
	var opz: Array = []
	for la in alleanze_disponibili(i):
		var d: Dictionary = Dati.ALLEANZE[la]
		var regs: Array = []
		for r in d["reg"]:
			regs.append(Dati.REGIONI[r]["nome"])
		opz.append({"id": la, "reg": d["reg"][0], "testo": "%s (%s, %s)%s" % [d["nome"], ", ".join(regs),
			"Esercito" if d["tipo"] == "e" else "Esercito o Flotta", " - 1 Oro" if int(d["costo"]) > 0 else ""]})
	opz.append(_annulla_opz())
	_chiedi(i, "alleanza", "Con chi stipuli un'Alleanza Locale (+1 nei combattimenti di quella regione, per questa guerra)?", opz)

func _dec_alleanza(i: int, o: Dictionary, _r: Dictionary) -> void:
	var gratis: bool = s["ctx"].get("gratis", false)
	s["ctx"] = {}
	if o["id"] == "annulla":
		return
	if not gratis:
		_usa_azione()
		s["t"]["spec"] = true
	var d: Dictionary = Dati.ALLEANZE[o["id"]]
	_paga(i, int(d["costo"]), "l'alleanza")
	s["locali"][o["id"]] = pot(i)
	_log("%s stipula un'Alleanza Locale con %s." % [nome(i), d["nome"]])

## +1 di un'alleanza locale per la potenza p nella regione reg, per il dominio "n" (navale) o "t" (terra)
func alleanze_in(p: String, reg: String) -> Array:
	var out: Array = []
	for la in s["locali"]:
		if s["locali"][la] == p and reg in Dati.ALLEANZE[la]["reg"]:
			out.append(la)
	return out

# ------------------------------------------------------------ tessere

func tessere_prendibili(i: int) -> Array:
	var out: Array = []
	var gg := g(i)
	var ncom := 0
	for x in gg["tessere"]:
		if Dati.TESSERE[x["t"]]["cat"] == "com":
			ncom += 1
	for t in Dati.ORDINE_TESSERE:
		if int(s["banco"].get(t, 0)) <= 0:
			continue
		var d: Dictionary = Dati.TESSERE[t]
		if int(d.get("pop", 0)) > int(gg["pop"]):
			continue
		if d["cat"] == "com" and np() <= 3 and ncom >= 3:
			continue
		if t == "riforma" and int(gg["tens"]) <= 0:
			continue
		out.append(t)
	return out

func costo_testo(t: String) -> String:
	var d: Dictionary = Dati.TESSERE[t]
	var parti: Array = []
	if int(d.get("oro", 0)) > 0:
		parti.append("%d Oro" % int(d["oro"]))
	if int(d.get("pop", 0)) > 0:
		parti.append("%d Popolazione" % int(d["pop"]))
	if int(d.get("tens", 0)) > 0:
		parti.append("%d Tensione" % int(d["tens"]))
	return "gratis" if parti.is_empty() else ", ".join(parti)

func _chiedi_tessera(i: int) -> void:
	var opz: Array = []
	for t in tessere_prendibili(i):
		var d: Dictionary = Dati.TESSERE[t]
		var tasse := tasse_per(i, int(d.get("oro", 0)))
		opz.append({"id": t, "testo": "%s (%s)%s" % [d["nome"], costo_testo(t),
			" - servono %d tassazion%s" % [tasse, "e" if tasse == 1 else "i"] if tasse > 0 else ""], "tessera": t})
	opz.append(_annulla_opz())
	_chiedi(i, "tessera", "Quale tessera reclami?", opz)

func _dec_tessera(i: int, o: Dictionary, _r: Dictionary) -> void:
	s["ctx"] = {}
	if o["id"] == "annulla":
		return
	_usa_azione()
	s["t"]["spec"] = true
	var t: String = o["id"]
	var d: Dictionary = Dati.TESSERE[t]
	s["banco"][t] = int(s["banco"][t]) - 1
	_paga(i, int(d.get("oro", 0)), d["nome"])
	_pop(i, -int(d.get("pop", 0)))
	if int(d.get("tens", 0)) > 0:
		g(i)["tens"] += int(d["tens"])
	_log("%s reclama la tessera %s." % [nome(i), d["nome"]])
	match t:
		"riforma":
			g(i)["tens"] = maxi(0, int(g(i)["tens"]) - 2)
			_log("La Riforma del governo toglie 2 punti Tensione a %s." % nome(i))
			s["esposti"] += 0
		"industria":
			var bonus := 3 + conta_tessere(i, "agricoltura")
			g(i)["pv"] += bonus
			_log("L'Industria porta %d Punti Vittoria a %s." % [bonus, nome(i)])
		"agricoltura":
			_pop(i, 1)
			g(i)["tessere"].append({"t": t, "usata": false})
		_:
			g(i)["tessere"].append({"t": t, "usata": false})

# ------------------------------------------------------------ azioni gratuite

func _oro_commercio(i: int, t: String) -> int:
	var best := 0
	for r in Dati.TESSERE[t]["reg"]:
		best = maxi(best, c(r, pot(i)))
	return best

func colonie_milizia(i: int) -> Array:
	var out: Array = []
	var p := pot(i)
	for r in Dati.COLONIE:
		if c(r, p) > 0 or u(r, p, U_E) + u(r, p, U_F) + u(r, p, U_FO) > 0:
			out.append(r)
	return out

func colonie_blocco(i: int) -> Array:
	var out: Array = []
	for r in Dati.COLONIE:
		if u(r, pot(i), U_F) > 0:
			out.append(r)
	return out

func _usa_libera(i: int, k: int) -> void:
	var x: Dictionary = g(i)["tessere"][k]
	var t: String = x["t"]
	var p := pot(i)
	match t:
		"agricoltura":
			x["usata"] = true
			_pop(i, 1)
			_log("%s usa l'Agricoltura migliorata: +1 Popolazione." % nome(i))
		"mercenari", "reclutamento":
			x["usata"] = true
			var tu := U_E if t == "mercenari" else U_F
			_add_u(casa(p), p, tu, 1)
			_log("%s usa %s: %s in patria." % [nome(i), Dati.TESSERE[t]["nome"], NOMI_U[tu].to_lower()])
			s["ctx"] = {"fase": "costr_dest", "tipo": tu, "da": casa(p), "milizia": false}
		"milizia_indigena":
			s["ctx"] = {"fase": "milind", "k": k}
		"ministero":
			s["ctx"] = {"fase": "att_reg", "gratis": true, "k": k}
		"diplomazia":
			x["usata"] = true
			s["ctx"] = {"fase": "alleanza", "gratis": true}
		"blocco":
			s["ctx"] = {"fase": "blocco_reg", "k": k}
		_:
			var regs: Array = Dati.TESSERE[t]["reg"]
			if regs.size() > 1 and c(regs[0], p) > 0 and c(regs[1], p) > 0 and c(regs[0], p) != c(regs[1], p):
				# sceglie automaticamente la regione che rende di più
				pass
			x["usata"] = true
			var oro := _oro_commercio(i, t)
			g(i)["oro"] += oro
			_log("%s usa %s: +%d Oro." % [nome(i), Dati.TESSERE[t]["nome"], oro])

func _chiedi_milind(i: int) -> void:
	var opz: Array = []
	for r in colonie_milizia(i):
		opz.append({"id": r, "reg": r, "testo": Dati.REGIONI[r]["nome"]})
	opz.append(_annulla_opz())
	_chiedi(i, "milind", "Milizia indigena: in quale colonia arruoli l'Esercito?", opz)

func _dec_milind(i: int, o: Dictionary, _r: Dictionary) -> void:
	var k: int = s["ctx"]["k"]
	if o["id"] == "annulla":
		s["ctx"] = {}
		return
	g(i)["tessere"][k]["usata"] = true
	_add_u(o["id"], pot(i), U_E, 1)
	_log("%s arruola la Milizia indigena in %s." % [nome(i), Dati.REGIONI[o["id"]]["nome"]])
	s["ctx"] = {"fase": "costr_dest", "tipo": U_E, "da": o["id"], "milizia": false}

func _chiedi_blocco_reg(i: int) -> void:
	var opz: Array = []
	for r in colonie_blocco(i):
		opz.append({"id": r, "reg": r, "testo": "Blocco in " + Dati.REGIONI[r]["nome"]})
	opz.append(_annulla_opz())
	_chiedi(i, "blocco_reg", "Dove poni il blocco navale? (chi non è tuo alleato non può sbarcare eserciti senza più flotte delle tue)", opz)

func _dec_blocco_reg(i: int, o: Dictionary, _r: Dictionary) -> void:
	var k: int = s["ctx"]["k"]
	s["ctx"] = {}
	if o["id"] == "annulla":
		return
	g(i)["tessere"].remove_at(k)
	s["blocco"] = {"reg": o["id"], "pot": pot(i)}
	_log("%s pone un blocco navale in %s." % [nome(i), Dati.REGIONI[o["id"]]["nome"]])

func _togli_tessera(i: int, t: String) -> void:
	var tt: Array = g(i)["tessere"]
	for k in tt.size():
		if tt[k]["t"] == t:
			tt.remove_at(k)
			s["banco"][t] = int(s["banco"].get(t, 0)) + 1
			return

func _usa_tessera(i: int, t: String) -> void:
	for x in g(i)["tessere"]:
		if x["t"] == t and not x["usata"]:
			x["usata"] = true
			return

# ------------------------------------------------------------ trattative (ricatti, accordi di non aggressione)

func _chiedi_ricatto_quanto(i: int) -> void:
	var j: int = s["ctx"]["chi"]
	var opz: Array = []
	if int(s["t"]["az"]) > 0:
		for k in [1, 2, 3, 4, 5]:
			opz.append({"id": "chiedi|%d" % k, "testo": "Chiedi %d Oro per non attaccarlo in questo turno" % k})
	for k in [1, 2, 3]:
		if int(g(i)["oro"]) >= k:
			opz.append({"id": "dai|%d" % k, "testo": "Offri %d Oro in cambio di non essere attaccato da lui in questa guerra" % k})
	opz.append(_annulla_opz())
	_chiedi(i, "ricatto_quanto", "Trattativa con %s: che cosa proponi?" % nome(j), opz)

func _dec_ricatto_quanto(i: int, o: Dictionary, _r: Dictionary) -> void:
	var j: int = s["ctx"]["chi"]
	if o["id"] == "annulla":
		s["ctx"] = {}
		return
	s["t"]["ricatti"].append(j)
	var tipo: String = str(o["id"]).get_slice("|", 0)
	var k := int(str(o["id"]).get_slice("|", 1))
	s["ctx"] = {"fase": "ricatto_risp", "chi": j, "tipo": tipo, "k": k}

func _chiedi_ricatto_risp(i: int) -> void:
	var ctx: Dictionary = s["ctx"]
	var j: int = ctx["chi"]
	var k: int = ctx["k"]
	if ctx["tipo"] == "chiedi":
		_chiedi(j, "ricatto_risp", "%s minaccia di attaccarti se non gli paghi %d Oro. L'accordo non è vincolante." % [nome(i), k],
			[{"id": "paga", "testo": "Paga %d Oro" % k}, {"id": "rifiuta", "testo": "Rifiuta"}], {"da": i})
	else:
		_chiedi(j, "ricatto_risp", "%s ti offre %d Oro perché tu non lo attacchi per il resto della guerra." % [nome(i), k],
			[{"id": "paga", "testo": "Accetta %d Oro e prometti" % k}, {"id": "rifiuta", "testo": "Rifiuta"}], {"da": i})

func _dec_ricatto_risp(j: int, o: Dictionary, _r: Dictionary) -> void:
	var ctx: Dictionary = s["ctx"]
	var i := corrente()
	var k: int = ctx["k"]
	s["ctx"] = {}
	if o["id"] == "rifiuta":
		_log("%s rifiuta la proposta di %s." % [nome(j), nome(i)])
		_evento({"tipo": "trattativa", "g": j, "da": i, "esito": "no"})
		return
	if ctx["tipo"] == "chiedi":
		_paga(j, k, "il ricatto")
		g(i)["oro"] += k
		s["patti"].append({"da": i, "a": j, "guerra": s["guerra"], "round": s["round"], "tipo": "turno"})
		_log("%s paga %d Oro a %s, che promette di non attaccarlo in questo turno." % [nome(j), k, nome(i)])
	else:
		_paga(i, k, "l'accordo")
		g(j)["oro"] += k
		s["patti"].append({"da": j, "a": i, "guerra": s["guerra"], "round": 0, "tipo": "guerra"})
		_log("%s accetta %d Oro da %s e promette di non attaccarlo in questa guerra." % [nome(j), k, nome(i)])
	_evento({"tipo": "trattativa", "g": j, "da": i, "esito": "si"})

## i ha promesso di non attaccare j?
func ha_patto(i: int, j: int) -> bool:
	for pt in s["patti"]:
		if int(pt["da"]) == i and int(pt["a"]) == j and int(pt["guerra"]) == int(s["guerra"]):
			if pt["tipo"] == "guerra" or int(pt["round"]) == int(s["round"]):
				return true
	return false

func _rompi_patti(i: int, j: int) -> void:
	var rotto := false
	for pt in s["patti"]:
		if int(pt["da"]) == i and int(pt["a"]) == j and int(pt["guerra"]) == int(s["guerra"]):
			if pt["tipo"] == "guerra" or int(pt["round"]) == int(s["round"]):
				rotto = true
				pt["guerra"] = -1
	if rotto:
		s["rep"][i] = maxf(0.0, float(s["rep"][i]) - 0.3)
		_log("%s rompe la parola data a %s!" % [nome(i), nome(j)])

# ============================================================ attacchi

## bersagli d'attacco in una regione per il giocatore i: {id, testo}
func bersagli(i: int, reg: String) -> Array:
	var p := pot(i)
	var out: Array = []
	if not (reg in Dati.REGIONI_PV):
		return out
	var esercito := u(reg, p, U_E) > 0
	var mare := Dati.mare_di(reg)
	var flotta := mare != "" and u(mare, p, U_F) > 0
	var pieno := tot_c_posati(p) >= Dati.MAX_CONTROLLO
	if esercito and not pieno:
		var visti := {}
		for seg in s["reg"][reg]["n"]:
			if seg["t"] == "d" and not visti.has(int(seg["v"])):
				visti[int(seg["v"])] = true
				out.append({"id": "n|%d" % int(seg["id"]), "testo": "Segnalino neutrale (difesa %d)%s" % [int(seg["v"]),
					" +3 Oro" if seg["bonus"] == "oro" else (" +1 PV" if seg["bonus"] == "pv" else "")]})
		for q in s["reg"][reg]["c"]:
			if q == p or alleati(p, q):
				continue
			out.append({"id": "c|%s" % q, "testo": "Controllo di %s" % nome_pot(q), "pot": q})
	for tok in ["pirati", "rivolta"]:
		var st: Dictionary = s["segrete"][tok]
		if st.get("reg", "") == reg and st.get("pot", "") != p and not pieno:
			if (tok == "pirati" and flotta) or (tok == "rivolta" and esercito):
				out.append({"id": "s|" + tok, "testo": "Segnalino %s (difesa %d)" % ["Pirati" if tok == "pirati" else "Rivolta", Dati.FORZA_SEGRETA[tok]]})
	if flotta and reg in Dati.NAVALI:
		for q in s["reg"][reg]["u"]:
			if q != p and not alleati(p, q) and u(reg, q, U_F) > 0 and gioc_di(q) >= 0:
				out.append({"id": "f|%s" % q, "testo": "Solo battaglia navale contro le flotte di %s" % nome_pot(q), "pot": q})
	return out

func regioni_attacco(i: int) -> Array:
	var out: Array = []
	for r in Dati.REGIONI_PV:
		if not bersagli(i, r).is_empty():
			out.append(r)
	return out

func _chiedi_att_reg(i: int) -> void:
	var opz: Array = []
	for r in regioni_attacco(i):
		opz.append({"id": r, "reg": r, "testo": Dati.REGIONI[r]["nome"]})
	opz.append(_annulla_opz())
	_chiedi(i, "att_reg", "In quale regione attacchi?%s" % ("" if s["ctx"].get("gratis", false) else " (costa 2 Oro)"), opz)

func _dec_att_reg(i: int, o: Dictionary, _r: Dictionary) -> void:
	if o["id"] == "annulla":
		s["ctx"] = {}
		return
	s["ctx"]["reg"] = o["id"]
	s["ctx"]["fase"] = "att_bers"

func _chiedi_att_bers(i: int) -> void:
	var reg: String = s["ctx"]["reg"]
	var opz: Array = bersagli(i, reg).duplicate(true)
	for o in opz:
		o["reg"] = reg
	opz.append({"id": "indietro", "testo": "Scegli un'altra regione"})
	_chiedi(i, "att_bers", "Che cosa attacchi in %s?" % Dati.REGIONI[reg]["nome"], opz)

func _dec_att_bers(i: int, o: Dictionary, _r: Dictionary) -> void:
	var ctx: Dictionary = s["ctx"]
	if o["id"] == "indietro":
		ctx["fase"] = "att_reg"
		return
	var gratis: bool = ctx.get("gratis", false)
	if gratis:
		g(i)["tessere"][int(ctx["k"])]["usata"] = true
		_log("%s usa il Ministero della Guerra: attacco senza costo." % nome(i))
	else:
		_usa_azione()
		_paga(i, 2, "l'attacco")
	s["t"]["attacco"] = true
	var reg: String = ctx["reg"]
	s["ctx"] = {}
	_inizia_attacco(i, reg, o["id"], "")

## crea il combattimento. id: "n|seg", "c|pot", "s|token", "f|pot". segreta: "pirati"/"rivolta" se è un'azione segreta.
func _inizia_attacco(i: int, reg: String, id: String, segreta: String, bersaglio_pot := "") -> void:
	var tipo: String = id.get_slice("|", 0)
	var dpot := ""
	var val := 0
	var seg_id := -1
	if tipo == "n":
		seg_id = int(id.get_slice("|", 1))
		for seg in s["reg"][reg]["n"]:
			if int(seg["id"]) == seg_id:
				val = int(seg["v"])
	elif tipo == "c" or tipo == "f":
		dpot = id.get_slice("|", 1)
	elif tipo == "s":
		val = Dati.FORZA_SEGRETA[id.get_slice("|", 1)]
	if segreta != "":
		dpot = bersaglio_pot
		tipo = "x"
	var cb := {"att": i, "apot": pot(i), "reg": reg, "mare": Dati.mare_di(reg), "tipo": tipo, "id": id, "dpot": dpot,
		"dg": gioc_di(dpot) if dpot != "" else -1, "val": val, "seg": seg_id, "segreta": segreta,
		"sorpresa": false, "all_a": {}, "all_d": {}, "promesse": {}, "offerti": [], "nav": "", "fase": "inizio",
		"lista_imp": [], "la_nav": {"a": [], "d": []}, "rapporto": [], "vinto": false, "blocco": false}
	s["cb"] = cb
	s["stadio"] = "combattimento"
	var desc := ""
	match tipo:
		"n": desc = "il segnalino neutrale (difesa %d)" % val
		"c": desc = "il Controllo di %s" % nome_pot(dpot)
		"f": desc = "le flotte di %s" % nome_pot(dpot)
		"s": desc = "il segnalino %s" % ("Pirati" if id.ends_with("pirati") else "Rivolta")
		"x": desc = "il Controllo di %s con %s" % [nome_pot(dpot), Dati.NOME_SEGRETA[segreta].to_lower()]
	_log("%s attacca %s in %s." % [nome(i), desc, Dati.REGIONI[reg]["nome"]])
	cb["titolo"] = "%s attacca %s in %s" % [nome(i), desc, Dati.REGIONI[reg]["nome"]]
	if dpot != "" and cb["dg"] >= 0:
		_rompi_patti(i, int(cb["dg"]))

## giocatori che possono unirsi all'attaccante ("a") o al difensore ("d")
func possibili_alleati(lato: String) -> Array:
	var cb: Dictionary = s["cb"]
	var out: Array = []
	if cb["tipo"] == "x" or cb["tipo"] == "s":
		return out
	var princ: String = cb["apot"] if lato == "a" else cb["dpot"]
	if princ == "":
		return out
	if lato == "d" and (cb["sorpresa"] or cb["tipo"] == "n"):
		return out
	var altro: String = cb["dpot"] if lato == "a" else cb["apot"]
	for j in np():
		var q := pot(j)
		if q == princ or q == altro or g(j)["fuori"]:
			continue
		if not alleati(princ, q) or alleanza(q) == "":
			continue
		var ne := u(cb["reg"], q, U_E) if cb["tipo"] != "f" else 0
		var nf := u(cb["mare"], q, U_F) if cb["mare"] != "" else 0
		if cb["tipo"] == "n" and lato == "a":
			nf = nf
		if ne + nf > 0:
			out.append(j)
	return out

func _passo_combattimento() -> void:
	var cb: Dictionary = s["cb"]
	match cb["fase"]:
		"inizio":
			cb["fase"] = "sorpresa"
			var i: int = cb["att"]
			if cb["dg"] >= 0 and cb["tipo"] in ["c", "f"] and ha_tessera(i, "sorpresa") and not possibili_alleati("d").is_empty():
				_chiedi(i, "sorpresa", "Usi l'Attacco a sorpresa? Nessuno potrà unirsi al difensore.",
					[{"id": "si", "testo": "Sì, attacco a sorpresa"}, {"id": "no", "testo": "No, tienila"}])
		"sorpresa":
			cb["fase"] = "tratt_a"
			cb["lista_imp"] = []
			for j in possibili_alleati("a"):
				cb["lista_imp"].append([j, "a"])
			for j in possibili_alleati("d"):
				cb["lista_imp"].append([j, "d"])
		"tratt_a":
			_passo_trattativa("a", "tratt_d")
		"tratt_d":
			_passo_trattativa("d", "impegni")
		"impegni":
			if cb["lista_imp"].is_empty():
				cb["fase"] = "navale"
			else:
				var x: Array = cb["lista_imp"][0]
				_chiedi_impegno(int(x[0]), str(x[1]))
		"navale":
			_fase_navale()
		"nav_tiro":
			_tiro("n")
		"nav_riserve":
			_riserve("n", "nav_esito")
		"nav_esito":
			_esito("n")
		"terra":
			_fase_terra()
		"ter_tiro":
			_tiro("t")
		"ter_riserve":
			_riserve("t", "ter_esito")
		"ter_esito":
			_esito("t")
		"fine":
			_fine_combattimento()

func _dec_sorpresa(i: int, o: Dictionary, _r: Dictionary) -> void:
	if o["id"] == "si":
		s["cb"]["sorpresa"] = true
		_togli_tessera(i, "sorpresa")
		_log("%s attacca a sorpresa: il difensore resta solo." % nome(i))

# ------------------------------------------------------------ trattative prima della chiamata agli alleati

func _passo_trattativa(lato: String, prossima: String) -> void:
	var cb: Dictionary = s["cb"]
	var chi: int = cb["att"] if lato == "a" else int(cb["dg"])
	if chi < 0:
		cb["fase"] = prossima
		return
	var opz: Array = []
	for x in cb["lista_imp"]:
		var j: int = x[0]
		if x[1] != lato or j in cb["offerti"]:
			continue
		for k in [1, 2, 3, 4]:
			opz.append({"id": "offri|%d|%d" % [j, k], "testo": "Offri %d Oro a %s perché impegni le sue unità" % [k, nome(j)], "chi": j, "k": k})
	if opz.is_empty():
		cb["fase"] = prossima
		return
	opz.push_front({"id": "basta", "testo": "Nessuna offerta, si passa alla chiamata degli alleati"})
	_chiedi(chi, "tratt", "Trattative informali: puoi offrire Oro ai tuoi alleati presenti perché si uniscano a te.", opz, {"lato": lato, "prossima": prossima})

func _dec_tratt(i: int, o: Dictionary, r: Dictionary) -> void:
	var cb: Dictionary = s["cb"]
	if o["id"] == "basta":
		cb["fase"] = r["prossima"]
		return
	var j: int = o["chi"]
	var k: int = o["k"]
	cb["offerti"].append(j)
	_chiedi(j, "tratt_risp", "%s ti offre %d Oro se impegni le tue unità nel combattimento in %s (promessa non vincolante)." % [nome(i), k, Dati.REGIONI[cb["reg"]]["nome"]],
		[{"id": "accetta", "testo": "Accetta %d Oro" % k}, {"id": "chiedi|%d" % (k + 1), "testo": "Chiedi %d Oro" % (k + 1)},
		{"id": "chiedi|%d" % (k + 2), "testo": "Chiedi %d Oro" % (k + 2)}, {"id": "rifiuta", "testo": "Rifiuta"}],
		{"da": i, "q": k, "lato": r["lato"]})

func _dec_tratt_risp(j: int, o: Dictionary, r: Dictionary) -> void:
	var i: int = r["da"]
	if o["id"] == "rifiuta":
		_log("%s rifiuta l'offerta di %s." % [nome(j), nome(i)])
		_evento({"tipo": "trattativa", "g": j, "da": i, "esito": "no"})
		return
	if o["id"] == "accetta":
		_accordo(i, j, int(r["q"]), str(r["lato"]))
		return
	var k := int(str(o["id"]).get_slice("|", 1))
	# la controproposta va in testa alla coda
	s["coda"].push_front({"k": "tratt_contro", "g": i, "testo": "%s chiede %d Oro invece di %d per unirsi a te." % [nome(j), k, int(r["q"])],
		"opz": [{"id": "accetta", "testo": "Accetta, paga %d Oro" % k}, {"id": "rifiuta", "testo": "Rifiuta"}], "a": j, "q": k, "lato": r["lato"]})

func _dec_tratt_contro(i: int, o: Dictionary, r: Dictionary) -> void:
	var j: int = r["a"]
	if o["id"] == "accetta":
		_accordo(i, j, int(r["q"]), str(r["lato"]))
	else:
		_log("%s non accetta la richiesta di %s." % [nome(i), nome(j)])

func _accordo(i: int, j: int, k: int, lato: String) -> void:
	_paga(i, k, "l'accordo")
	g(j)["oro"] += k
	s["cb"]["promesse"][str(j)] = lato
	_log("%s paga %d Oro a %s, che promette di unirsi." % [nome(i), k, nome(j)])
	_evento({"tipo": "trattativa", "g": j, "da": i, "esito": "si"})

func _chiedi_impegno(j: int, lato: String) -> void:
	var cb: Dictionary = s["cb"]
	var q := pot(j)
	var ne := u(cb["reg"], q, U_E) if cb["tipo"] != "f" else 0
	var nf := u(cb["mare"], q, U_F) if cb["mare"] != "" else 0
	var princ: int = cb["att"] if lato == "a" else int(cb["dg"])
	var opz: Array = []
	if ne > 0 and nf > 0:
		opz.append({"id": "tutto", "testo": "Impegna %d Esercit%s e %d Flott%s" % [ne, "o" if ne == 1 else "i", nf, "a" if nf == 1 else "e"]})
	if ne > 0:
		opz.append({"id": "e", "testo": "Impegna %d Esercit%s" % [ne, "o" if ne == 1 else "i"]})
	if nf > 0:
		opz.append({"id": "f", "testo": "Impegna %d Flott%s" % [nf, "a" if nf == 1 else "e"]})
	opz.append({"id": "no", "testo": "Non partecipare"})
	var prom := " Hai promesso di aiutarlo." if cb["promesse"].get(str(j), "") == lato else ""
	_chiedi(j, "impegno", "Chiamata agli alleati: %s %s in %s. Impegni le tue unità al suo fianco? Le perdite possono toccare anche a te.%s" % [
		nome(princ), "attacca" if lato == "a" else "si difende", Dati.REGIONI[cb["reg"]]["nome"], prom], opz, {"lato": lato})

func _dec_impegno(j: int, o: Dictionary, r: Dictionary) -> void:
	var cb: Dictionary = s["cb"]
	cb["lista_imp"].pop_front()
	var lato: String = r["lato"]
	var q := pot(j)
	var ne := 0
	var nf := 0
	if o["id"] == "tutto" or o["id"] == "e":
		ne = u(cb["reg"], q, U_E)
	if o["id"] == "tutto" or o["id"] == "f":
		nf = u(cb["mare"], q, U_F) if cb["mare"] != "" else 0
	if o["id"] == "no":
		if cb["promesse"].get(str(j), "") == lato:
			s["rep"][j] = maxf(0.0, float(s["rep"][j]) - 0.3)
			_log("%s non mantiene la promessa e resta a guardare!" % nome(j))
		else:
			_log("%s non partecipa." % nome(j))
		return
	cb["all_" + lato][str(j)] = [ne, nf]
	_log("%s impegna %s al fianco di %s." % [nome(j), _desc_unita(ne, nf), nome(cb["att"] if lato == "a" else int(cb["dg"]))])

func _desc_unita(ne: int, nf: int) -> String:
	var parti: Array = []
	if ne > 0:
		parti.append("%d Esercit%s" % [ne, "o" if ne == 1 else "i"])
	if nf > 0:
		parti.append("%d Flott%s" % [nf, "a" if nf == 1 else "e"])
	return " e ".join(parti)

# ------------------------------------------------------------ forze in campo

## unità delle potenze non giocanti della stessa Grande Alleanza (aiutano automaticamente, mai contro i neutrali)
func np_alleati(p: String, reg: String, t: int) -> int:
	var cb: Dictionary = s["cb"]
	if cb.get("tipo", "") == "n" or cb.get("tipo", "") in ["x", "s"] or alleanza(p) == "":
		return 0
	var n := 0
	for q in s["np_pot"]:
		if q != p and alleati(p, q):
			n += u(reg, q, t)
	if gioc_di(p) < 0:
		n += u(reg, p, t)
	return n

func flotte_lato(lato: String) -> int:
	var cb: Dictionary = s["cb"]
	if cb["mare"] == "":
		return 0
	if lato == "a" and cb["tipo"] == "x":
		return 1 if cb["segreta"] == "pirati" else 0
	if lato == "d" and cb["tipo"] == "s":
		return 1 if cb["id"].ends_with("pirati") else 0
	var princ: String = cb["apot"] if lato == "a" else cb["dpot"]
	if princ == "":
		return 0
	var n := u(cb["mare"], princ, U_F) if gioc_di(princ) >= 0 else 0
	for j in cb["all_" + lato]:
		n += int(cb["all_" + lato][j][1])
	n += np_alleati(princ, cb["mare"], U_F)
	return n

func _la_lato(lato: String, dominio: String) -> int:
	var cb: Dictionary = s["cb"]
	var princ: String = cb["apot"] if lato == "a" else cb["dpot"]
	if princ == "" or (cb["tipo"] == "x" and lato == "a"):
		return 0
	var n := 0
	for la in alleanze_in(princ, cb["reg"]):
		var usata_nav: bool = la in cb["la_nav"][lato]
		if dominio == "n" and usata_nav:
			n += 1
		elif dominio == "t" and not usata_nav:
			n += 1
	return n

## base della forza navale
func forza_navale(lato: String) -> int:
	var cb: Dictionary = s["cb"]
	if cb["tipo"] == "x" and lato == "a":
		return Dati.FORZA_SEGRETA["pirati"]
	if cb["tipo"] == "s" and lato == "d":
		return Dati.FORZA_SEGRETA["pirati"]
	var f := flotte_lato(lato)
	if cb["tipo"] == "x" and lato == "d":
		f = u(cb["mare"], cb["dpot"], U_F)
	var princ: String = cb["apot"] if lato == "a" else cb["dpot"]
	var altro: String = cb["dpot"] if lato == "a" else cb["apot"]
	if princ != "" and gioc_di(princ) >= 0 and u(cb["mare"], princ, U_F) > 0:
		if conta_tessere_pot(princ, "addestr_navale") > conta_tessere_pot(altro, "addestr_navale") or (altro == "" and conta_tessere_pot(princ, "addestr_navale") > 0):
			f += 1
	f += _la_lato(lato, "n")
	return f

func forza_terra(lato: String) -> int:
	var cb: Dictionary = s["cb"]
	var reg: String = cb["reg"]
	var f := 0
	var princ: String = cb["apot"] if lato == "a" else cb["dpot"]
	var altro: String = cb["dpot"] if lato == "a" else cb["apot"]
	if lato == "a" and cb["tipo"] == "x":
		f = Dati.FORZA_SEGRETA["rivolta"]
	elif lato == "d" and cb["tipo"] == "n":
		f = int(cb["val"])
	elif lato == "d" and cb["tipo"] == "s":
		f = int(cb["val"])
	elif lato == "d" and gioc_di(princ) < 0:
		# Controllo di una potenza non giocante (partite a 2 o 3): difesa 3, più le unità della sua alleanza
		f = 3 + np_alleati(princ, reg, U_E)
	else:
		f = u(reg, princ, U_E)
		if lato == "d":
			f += 2 * u(reg, princ, U_FO)
		if cb["tipo"] != "x":
			for j in cb["all_" + lato]:
				f += int(cb["all_" + lato][j][0])
			f += np_alleati(princ, reg, U_E)
		var mio := conta_tessere_pot(princ, "addestr_esercito")
		var suo := conta_tessere_pot(altro, "addestr_esercito") if altro != "" else 0
		var presente := u(reg, princ, U_E) > 0 or (lato == "d" and u(reg, princ, U_FO) > 0)
		if presente and mio > suo:
			f += 1
		f += _la_lato(lato, "t")
	if cb["nav"] == lato:
		f += 2 if cb["blocco"] else 1
	return f

# ------------------------------------------------------------ fase navale

func _fase_navale() -> void:
	var cb: Dictionary = s["cb"]
	cb["fase"] = "terra"
	if cb["mare"] == "" or cb["tipo"] == "x" and cb["segreta"] == "rivolta" or cb["tipo"] == "s" and cb["id"].ends_with("rivolta"):
		return
	# alleanze locali "esercito o flotta": si usano in mare se non c'è combattimento terrestre per quel lato
	for lato in ["a", "d"]:
		var princ: String = cb["apot"] if lato == "a" else cb["dpot"]
		if princ == "":
			continue
		var terra: bool = u(cb["reg"], princ, U_E) > 0 or (lato == "d" and u(cb["reg"], princ, U_FO) > 0)
		if cb["tipo"] == "f":
			terra = false
		for la in alleanze_in(princ, cb["reg"]):
			if Dati.ALLEANZE[la]["tipo"] == "en" and not terra and u(cb["mare"], princ, U_F) > 0:
				cb["la_nav"][lato].append(la)
	var fa := flotte_lato("a")
	var fd := flotte_lato("d")
	if cb["tipo"] == "n":
		if fa > 0:
			cb["nav"] = "a"
			_log("Il segnalino neutrale cede il Supporto navale all'attaccante.")
		return
	if cb["tipo"] == "x" or cb["tipo"] == "s":
		# pirati: combattimento solo navale contro le flotte del difensore
		cb["fase"] = "nav_tiro"
		return
	if fa > 0 and fd == 0:
		cb["nav"] = "a"
		_log("Solo l'attaccante ha flotte: Supporto navale all'attaccante.")
		if cb["tipo"] == "f":
			cb["fase"] = "fine"
		return
	if fd > 0 and fa == 0:
		cb["nav"] = "d"
		_log("Solo il difensore ha flotte: Supporto navale al difensore.")
		return
	if fa == 0 and fd == 0:
		return
	cb["fase"] = "nav_scelta_a"
	var i: int = cb["att"]
	_chiedi(i, "nav_att", "Flotte presenti da entrambe le parti (tu %d, difensore %d). Combatti in mare per il Supporto navale?" % [fa, fd],
		[{"id": "si", "testo": "Combatti in mare"}, {"id": "no", "testo": "Rinuncia: il Supporto navale va al difensore"}])

func _dec_nav_att(i: int, o: Dictionary, _r: Dictionary) -> void:
	var cb: Dictionary = s["cb"]
	if o["id"] == "no":
		cb["nav"] = "d"
		cb["fase"] = "terra" if cb["tipo"] != "f" else "fine"
		_log("%s non combatte in mare: Supporto navale al difensore." % nome(i))
		return
	var dg: int = cb["dg"]
	if dg < 0:
		cb["fase"] = "nav_tiro"
		return
	cb["fase"] = "nav_scelta_d"
	_chiedi(dg, "nav_def", "%s porta battaglia in mare (attaccante %d flotte, tu %d). Accetti lo scontro navale?" % [nome(i), flotte_lato("a"), flotte_lato("d")],
		[{"id": "si", "testo": "Combatti in mare"}, {"id": "no", "testo": "Rinuncia: il Supporto navale va all'attaccante"}])

func _dec_nav_def(j: int, o: Dictionary, _r: Dictionary) -> void:
	var cb: Dictionary = s["cb"]
	if o["id"] == "no":
		cb["nav"] = "a"
		cb["fase"] = "terra" if cb["tipo"] != "f" else "fine"
		_log("%s evita lo scontro navale: Supporto navale all'attaccante." % nome(j))
		return
	cb["fase"] = "nav_tiro"

# ------------------------------------------------------------ fase terrestre

func _fase_terra() -> void:
	var cb: Dictionary = s["cb"]
	cb["fase"] = "fine"
	if cb["tipo"] == "f":
		return
	if cb["tipo"] == "x" and cb["segreta"] == "pirati":
		return
	if cb["tipo"] == "s" and cb["id"].ends_with("pirati"):
		return
	if cb["tipo"] != "x" and u(cb["reg"], cb["apot"], U_E) <= 0:
		_log("L'attaccante non ha più eserciti: niente combattimento terrestre.")
		return
	cb["fase"] = "ter_tiro"
	# Blocco navale: +2 invece di +1 di supporto navale
	if cb["nav"] != "":
		var lato: String = cb["nav"]
		var chi: int = cb["att"] if lato == "a" else int(cb["dg"])
		if chi >= 0 and ha_tessera(chi, "blocco") and s["blocco"].get("pot", "") != pot(chi):
			cb["fase"] = "ter_blocco"
			_chiedi(chi, "blocco_uso", "Usi la tessera Blocco navale per avere +2 di Supporto navale invece di +1? (la tessera torna sul tabellone)",
				[{"id": "si", "testo": "Sì, +2"}, {"id": "no", "testo": "No"}])

func _dec_blocco_uso(i: int, o: Dictionary, _r: Dictionary) -> void:
	var cb: Dictionary = s["cb"]
	cb["fase"] = "ter_tiro"
	if o["id"] == "si":
		cb["blocco"] = true
		_togli_tessera(i, "blocco")
		_log("%s usa il Blocco navale: +2 di Supporto navale." % nome(i))

# ------------------------------------------------------------ dadi ed esiti

func _tiro(dominio: String) -> void:
	var cb: Dictionary = s["cb"]
	var fa := forza_navale("a") if dominio == "n" else forza_terra("a")
	var fd := forza_navale("d") if dominio == "n" else forza_terra("d")
	var a1 := rng.randi_range(1, 6)
	var a2 := rng.randi_range(1, 6)
	var d1 := rng.randi_range(1, 6)
	var d2 := rng.randi_range(1, 6)
	cb["tiro"] = {"dom": dominio, "fa": fa, "fd": fd, "a": [a1, a2], "d": [d1, d2], "ta": fa + absi(a1 - a2), "td": fd + absi(d1 - d2), "riserve": []}
	_log("%s: attaccante %d + dadi %d-%d = %d; difensore %d + dadi %d-%d = %d." % ["Battaglia navale" if dominio == "n" else "Battaglia terrestre",
		fa, a1, a2, fa + absi(a1 - a2), fd, d1, d2, fd + absi(d1 - d2)])
	cb["fase"] = "nav_riserve" if dominio == "n" else "ter_riserve"
	cb["chiesto_ris"] = []

## dopo il tiro, chi perde o pareggia può usare le Riserve per far ritirare tutti i dadi
func _riserve(dominio: String, dopo: String) -> void:
	var cb: Dictionary = s["cb"]
	var tr: Dictionary = cb["tiro"]
	for lato in ["a", "d"]:
		var chi: int = cb["att"] if lato == "a" else int(cb["dg"])
		if chi < 0 or (cb["tipo"] == "x" and lato == "a"):
			continue
		var key := "%s%d" % [lato, tr["riserve"].size()]
		if key in cb["chiesto_ris"]:
			continue
		var mio: int = tr["ta"] if lato == "a" else tr["td"]
		var suo: int = tr["td"] if lato == "a" else tr["ta"]
		if mio > suo or not ha_tessera(chi, "riserve", true):
			continue
		cb["chiesto_ris"].append(key)
		_chiedi(chi, "riserve", "Il tiro ti dà %d contro %d. Usi le Riserve per far ritirare tutti i dadi?" % [mio, suo],
			[{"id": "si", "testo": "Sì, ritirate tutto"}, {"id": "no", "testo": "No"}], {"lato": lato, "dom": dominio})
		return
	cb["fase"] = dopo

func _dec_riserve(i: int, o: Dictionary, r: Dictionary) -> void:
	if o["id"] != "si":
		return
	var cb: Dictionary = s["cb"]
	_usa_tessera(i, "riserve")
	var tr: Dictionary = cb["tiro"]
	var a1 := rng.randi_range(1, 6)
	var a2 := rng.randi_range(1, 6)
	var d1 := rng.randi_range(1, 6)
	var d2 := rng.randi_range(1, 6)
	tr["a"] = [a1, a2]
	tr["d"] = [d1, d2]
	tr["ta"] = int(tr["fa"]) + absi(a1 - a2)
	tr["td"] = int(tr["fd"]) + absi(d1 - d2)
	tr["riserve"].append(r["lato"])
	_log("%s usa le Riserve: nuovo tiro, attaccante %d, difensore %d." % [nome(i), tr["ta"], tr["td"]])

func _esito(dominio: String) -> void:
	var cb: Dictionary = s["cb"]
	var tr: Dictionary = cb["tiro"]
	var ta: int = tr["ta"]
	var td: int = tr["td"]
	var sette_a: bool = int(tr["a"][0]) + int(tr["a"][1]) == 7
	var sette_d: bool = int(tr["d"][0]) + int(tr["d"][1]) == 7
	var vince := "a" if ta > td else ("d" if td > ta else "")
	var riga := {"dom": dominio, "fa": tr["fa"], "fd": tr["fd"], "a": tr["a"], "d": tr["d"], "ta": ta, "td": td, "vince": vince, "perdite": []}
	cb["rapporto"].append(riga)
	cb["perdite_correnti"] = riga["perdite"]
	# Ritirata combattendo: il difensore sconfitto evita tutte le perdite del suo lato
	var evita_d := false
	if vince == "a" and int(cb["dg"]) >= 0 and ha_tessera(int(cb["dg"]), "ritirata") and not cb.get("chiesta_rit", false):
		var n_perdite := (1 if true else 0) + (1 if sette_d else 0)
		if n_perdite > 0 and (dominio == "n" and flotte_lato("d") > 0 or dominio == "t" and _unita_perdibili("d", "t", false) > 0):
			cb["chiesta_rit"] = true
			cb["fase"] = "rit_" + dominio
			_chiedi(int(cb["dg"]), "ritirata", "Hai perso. Usi la Ritirata combattendo per non perdere unità (tue e degli alleati)?",
				[{"id": "si", "testo": "Sì, ritirata"}, {"id": "no", "testo": "No, tienila"}], {"dom": dominio, "sette_a": sette_a, "sette_d": sette_d, "vince": vince})
			cb["rapporto"].pop_back()
			return
	_applica_esito(dominio, vince, sette_a, sette_d, evita_d)

func _dec_ritirata(j: int, o: Dictionary, r: Dictionary) -> void:
	var evita: bool = o["id"] == "si"
	if evita:
		_togli_tessera(j, "ritirata")
		_log("%s ripiega combattendo: nessuna perdita per il suo schieramento." % nome(j))
	var cb: Dictionary = s["cb"]
	var tr: Dictionary = cb["tiro"]
	var riga := {"dom": r["dom"], "fa": tr["fa"], "fd": tr["fd"], "a": tr["a"], "d": tr["d"], "ta": tr["ta"], "td": tr["td"], "vince": r["vince"], "perdite": []}
	cb["rapporto"].append(riga)
	cb["perdite_correnti"] = riga["perdite"]
	_applica_esito(str(r["dom"]), str(r["vince"]), bool(r["sette_a"]), bool(r["sette_d"]), evita)

func _applica_esito(dominio: String, vince: String, sette_a: bool, sette_d: bool, evita_d: bool) -> void:
	var cb: Dictionary = s["cb"]
	var pari := vince == ""
	# perdite dell'attaccante
	var perde_a := vince == "d" or pari
	_perdite("a", dominio, perde_a, sette_a, pari)
	if not evita_d:
		_perdite("d", dominio, vince == "a" or pari, sette_d, pari)
	if dominio == "n":
		if vince != "":
			cb["nav"] = vince
			_log("Battaglia navale vinta %s: Supporto navale." % ("dall'attaccante" if vince == "a" else "dal difensore"))
		else:
			_log("Battaglia navale pari: nessun Supporto navale.")
		cb["fase"] = "terra"
		if cb["tipo"] == "f":
			cb["fase"] = "fine"
		if cb["tipo"] == "x" or cb["tipo"] == "s":
			cb["vinto"] = vince == "a"
			cb["fase"] = "fine"
	else:
		cb["vinto"] = vince == "a"
		cb["fase"] = "fine"
	_controlla_blocco()

## unità che un lato può perdere in un dominio. principale: perdita per sconfitta/pareggio (i Forti non cadono per i pareggi)
func _unita_perdibili(lato: String, dominio: String, solo_alleati: bool) -> int:
	var cb: Dictionary = s["cb"]
	var princ: String = cb["apot"] if lato == "a" else cb["dpot"]
	var n := 0
	if not solo_alleati and princ != "" and gioc_di(princ) >= 0 and not (cb["tipo"] == "x" and lato == "a") and not (cb["tipo"] == "s" and lato == "d"):
		if dominio == "n":
			n += u(cb["mare"], princ, U_F)
		else:
			n += u(cb["reg"], princ, U_E) + u(cb["reg"], princ, U_FO)
	if cb["tipo"] != "x":
		for j in cb["all_" + lato]:
			var x: Array = cb["all_" + lato][j]
			n += int(x[1]) if dominio == "n" else int(x[0])
	return n

func _perdite(lato: String, dominio: String, principale: bool, sette: bool, pari: bool) -> void:
	var cb: Dictionary = s["cb"]
	var princ: String = cb["apot"] if lato == "a" else cb["dpot"]
	if princ == "":
		return
	if cb["tipo"] == "x" and lato == "a" or cb["tipo"] == "s" and lato == "d" or cb["tipo"] == "n" and lato == "d":
		return
	var proprio_preso := false
	if principale:
		proprio_preso = _togli_una(lato, dominio, true, pari, false)
		if not proprio_preso:
			_togli_una(lato, dominio, false, pari, true)
	if sette:
		if proprio_preso:
			if not _togli_una(lato, dominio, false, false, true):
				_togli_una(lato, dominio, true, false, false)
		elif principale:
			if not _togli_una(lato, dominio, true, false, false):
				_togli_una(lato, dominio, false, false, true)
		else:
			if not _togli_una(lato, dominio, true, false, false):
				_togli_una(lato, dominio, false, false, true)

## toglie un'unità propria (proprio=true) o di un alleato impegnato (alleato=true). Restituisce true se ha tolto qualcosa.
func _togli_una(lato: String, dominio: String, proprio: bool, pari: bool, alleato: bool) -> bool:
	var cb: Dictionary = s["cb"]
	var princ: String = cb["apot"] if lato == "a" else cb["dpot"]
	var reg: String = cb["reg"] if dominio == "t" else cb["mare"]
	if proprio:
		if gioc_di(princ) < 0:
			return false
		if dominio == "n":
			if u(reg, princ, U_F) > 0:
				_perdi_unita(princ, reg, U_F)
				return true
			return false
		if u(reg, princ, U_E) > 0:
			_perdi_unita(princ, reg, U_E)
			return true
		if not pari and lato == "d" and u(reg, princ, U_FO) > 0:
			_perdi_unita(princ, reg, U_FO)
			return true
		return false
	if alleato and cb["tipo"] != "x":
		var best := ""
		var bn := 0
		for j in cb["all_" + lato]:
			var x: Array = cb["all_" + lato][j]
			var n: int = int(x[1]) if dominio == "n" else int(x[0])
			if n > bn:
				bn = n
				best = j
		if best == "":
			return false
		var x2: Array = cb["all_" + lato][best]
		if dominio == "n":
			x2[1] = int(x2[1]) - 1
		else:
			x2[0] = int(x2[0]) - 1
		_perdi_unita(pot(int(best)), reg, U_F if dominio == "n" else U_E)
		return true
	return false

func _perdi_unita(p: String, reg: String, t: int) -> void:
	_add_u(reg, p, t, -1)
	_tensione(p, 1)
	_log("%s perde %s in %s (+1 Tensione)." % [nome_pot(p), NOMI_U[t].to_lower(), Dati.REGIONI[reg]["nome"]])
	if s["cb"].has("perdite_correnti"):
		s["cb"]["perdite_correnti"].append([p, t])

func _fine_combattimento() -> void:
	var cb: Dictionary = s["cb"]
	var i: int = cb["att"]
	var reg: String = cb["reg"]
	var esito := ""
	if cb["vinto"]:
		match cb["tipo"]:
			"n":
				_converti_neutrale(i, int(cb["seg"]))
				esito = "%s conquista il segnalino neutrale in %s." % [nome(i), Dati.REGIONI[reg]["nome"]]
			"c":
				if c(reg, cb["dpot"]) > 0:
					_add_c(reg, cb["dpot"], -1)
					_add_c(reg, cb["apot"], 1)
				esito = "%s strappa un segnalino Controllo a %s in %s." % [nome(i), nome_pot(cb["dpot"]), Dati.REGIONI[reg]["nome"]]
			"s":
				var tok: String = str(cb["id"]).get_slice("|", 1)
				s["segrete"][tok] = {}
				_add_c(reg, cb["apot"], 1)
				esito = "%s sconfigge %s e prende il segnalino Controllo in %s." % [nome(i), "i Pirati" if tok == "pirati" else "i rivoltosi", Dati.REGIONI[reg]["nome"]]
			"x":
				var tok2: String = cb["segreta"]
				_add_c(reg, cb["dpot"], -1)
				s["segrete"][tok2] = {"reg": reg, "pot": cb["dpot"]}
				esito = "%s riesce: il Controllo di %s in %s passa sotto il segnalino." % [Dati.NOME_SEGRETA[tok2], nome_pot(cb["dpot"]), Dati.REGIONI[reg]["nome"]]
			"f":
				esito = "Battaglia navale vinta da %s." % nome(i)
	else:
		if cb["tipo"] == "x":
			s["vietate"][cb["segreta"]] = i
			esito = "%s fallisce: il segnalino torna sul tabellone." % Dati.NOME_SEGRETA[cb["segreta"]]
		elif cb["tipo"] == "f":
			esito = "La battaglia navale non dà vantaggi a %s." % nome(i)
		else:
			esito = "L'attacco di %s fallisce." % nome(i)
	_log(esito)
	cb["esito"] = esito
	s["ultimo_cb"] = {"titolo": cb.get("titolo", ""), "rapporto": cb["rapporto"], "esito": esito, "vinto": cb["vinto"], "att": i,
		"dpot": cb["dpot"], "reg": reg, "passo": s["passo"]}
	_evento({"tipo": "combattimento", "g": i, "vinto": cb["vinto"], "reg": reg})
	s["cb"] = {}
	s["stadio"] = "turno"
	s["ctx"] = {}

# ============================================================ azioni segrete

func segrete_disponibili(i: int) -> Array:
	var out: Array = []
	for tok in ["pirati", "rivolta"]:
		if not s["segrete"][tok].is_empty():
			continue
		if int(s["vietate"].get(tok, -1)) == i:
			continue
		if not bersagli_segreta(i, tok).is_empty():
			out.append(tok)
	return out

func bersagli_segreta(i: int, tok: String) -> Array:
	var out: Array = []
	var regs: Array = Dati.COLONIE if tok == "pirati" else Dati.AMERICHE
	for r in regs:
		for q in s["reg"][r]["c"]:
			if q != pot(i) and gioc_di(q) >= 0:
				out.append({"id": "%s|%s" % [r, q], "reg": r, "pot": q, "testo": "%s: Controllo di %s" % [Dati.REGIONI[r]["nome"], nome_pot(q)]})
	return out

func _chiedi_segreta(i: int) -> void:
	var opz: Array = []
	for tok in segrete_disponibili(i):
		opz.append({"id": tok, "testo": Dati.NOME_SEGRETA[tok] + (" (forza 1, combattimento navale in una colonia)" if tok == "pirati" else " (forza 3, combattimento terrestre nelle Americhe)")})
	opz.append(_annulla_opz())
	_chiedi(i, "segreta", "Quale azione segreta usi? Colpisce un segnalino Controllo di qualsiasi potenza, anche alleata, e nessuno può aiutarla.", opz)

func _dec_segreta(i: int, o: Dictionary, _r: Dictionary) -> void:
	if o["id"] == "annulla":
		s["ctx"] = {}
		return
	s["ctx"] = {"fase": "segreta_bers", "tok": o["id"]}

func _chiedi_segreta_bers(i: int) -> void:
	var tok: String = s["ctx"]["tok"]
	var opz: Array = bersagli_segreta(i, tok)
	opz.append(_annulla_opz())
	_chiedi(i, "segreta_bers", "Quale segnalino Controllo colpisci?", opz)

func _dec_segreta_bers(i: int, o: Dictionary, _r: Dictionary) -> void:
	var tok: String = s["ctx"]["tok"]
	s["ctx"] = {}
	if o["id"] == "annulla":
		return
	_usa_azione()
	s["t"]["spec"] = true
	_inizia_attacco(i, o["reg"], "x|" + tok, tok, o["pot"])

# ============================================================ fine guerra

func _rendita() -> void:
	_log("--- Rendita e manutenzione ---")
	for i in np():
		var gg := g(i)
		var p := pot(i)
		var entrate: int = int(gg["pop"]) + tot_c(p)
		var spese := tot_unita(p)
		gg["oro"] += entrate
		_paga(i, spese, "la manutenzione")
		_pop(i, 5)
		_log("%s: +%d Oro di rendita, -%d di manutenzione. Popolazione %d." % [nome(i), entrate, spese, int(gg["pop"])])
	s["stadio"] = "punteggio"

## punti di una regione: {pot: pv} considerando i segnalini Controllo attivi
func punti_regione(reg: String, cc = null) -> Dictionary:
	var src: Dictionary = cc if cc != null else s["reg"][reg]["c"]
	var conti := {}
	for q in src:
		if int(src[q]) > 0 and (gioc_di(q) >= 0 or np() <= 3):
			conti[q] = int(src[q])
	var valori: Array = []
	for q in conti:
		if not (conti[q] in valori):
			valori.append(conti[q])
	valori.sort()
	valori.reverse()
	var pv: Array = Dati.REGIONI[reg]["pv"]
	var out := {}
	for q in conti:
		if gioc_di(q) < 0:
			continue
		var rango: int = valori.find(conti[q])
		# a 2-3 giocatori, chi pareggia con una potenza non giocante scende di un posto
		for x in conti:
			if x != q and gioc_di(x) < 0 and conti[x] == conti[q]:
				rango += 1
				break
		out[q] = int(pv[rango]) if rango < pv.size() else 0
	return out

func punti_proiezione() -> Dictionary:
	var tot := {}
	for i in np():
		tot[pot(i)] = 0
	for r in Dati.REGIONI_PV:
		var pr := punti_regione(r)
		for q in pr:
			tot[q] += pr[q]
	return tot

func _punteggio() -> void:
	_log("--- Punti vittoria della %s guerra ---" % ["prima", "seconda", "terza"][int(s["guerra"]) - 1])
	var tot := punti_proiezione()
	var riga := {}
	for i in np():
		var p := pot(i)
		g(i)["pv"] += int(tot[p])
		riga[p] = int(tot[p])
		_log("%s: +%d PV (totale %d)." % [nome(i), int(tot[p]), int(g(i)["pv"])])
	s["storia_pv"].append(riga)
	_evento({"tipo": "punteggio", "guerra": s["guerra"], "pv": riga})
	if int(s["guerra"]) >= 3:
		_fine_partita()
	else:
		s["stadio"] = "fine_guerra"

func _fine_guerra() -> void:
	for la in s["locali"]:
		s["locali"][la] = ""
	for i in np():
		for x in g(i)["tessere"]:
			x["usata"] = false
	if not s["blocco"].is_empty():
		s["blocco"] = {}
		s["banco"]["blocco"] = int(s["banco"].get("blocco", 0)) + 1
	s["patti"] = []
	s["guerra"] += 1
	s["stadio"] = "inizio_guerra"

func _fine_partita() -> void:
	_log("=== FINE DELLA PARTITA ===")
	var n := np()
	for i in n:
		if int(g(i)["tens"]) >= 20:
			g(i)["pv"] = 0
			g(i)["fuori"] = true
			_log("%s ha %d Tensione: rivoluzione! La potenza crolla e perde tutti i punti." % [nome(i), int(g(i)["tens"])])
	var restanti: Array = []
	for i in n:
		if not g(i)["fuori"]:
			restanti.append(i)
	var valori: Array = []
	for i in restanti:
		if not (int(g(i)["tens"]) in valori):
			valori.append(int(g(i)["tens"]))
	valori.sort()
	valori.reverse()
	if n == 2:
		if restanti.size() == 2 and valori.size() == 2:
			for i in restanti:
				if int(g(i)["tens"]) == valori[0]:
					g(i)["pv"] -= 7
					_log("%s ha più Tensione: -7 PV." % nome(i))
	else:
		for i in restanti:
			var tt := int(g(i)["tens"])
			if valori.size() > 0 and tt == valori[0] and tt > 0:
				g(i)["pv"] -= 7
				_log("%s ha la Tensione più alta (%d): -7 PV." % [nome(i), tt])
			elif valori.size() > 1 and tt == valori[1] and tt > 0:
				g(i)["pv"] -= 4
				_log("%s ha la seconda Tensione più alta (%d): -4 PV." % [nome(i), tt])
	var classifica: Array = range(n)
	classifica.sort_custom(func(a, b):
		if int(g(a)["pv"]) != int(g(b)["pv"]):
			return int(g(a)["pv"]) > int(g(b)["pv"])
		return int(g(a)["tens"]) < int(g(b)["tens"]))
	var w: int = classifica[0]
	s["esito"] = {"vince": w, "classifica": classifica, "testo": "%s vince con %d Punti Vittoria." % [nome(w), int(g(w)["pv"])]}
	_log(s["esito"]["testo"])
	s["stadio"] = "fine"

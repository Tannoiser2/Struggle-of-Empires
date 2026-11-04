## Intelligenza artificiale per Struggle of Empires.
## Decide solo in base allo stato della partita (e a un generatore con seme preso dallo stato), quindi
## dà la stessa scelta su tutti i dispositivi: serve per il gioco online.
## Fa tutto quello che fa un giocatore: aste per le Grandi Alleanze, trattative e offerte di Oro,
## promesse (che di solito mantiene), ricatti, chiamata agli alleati, attacchi, colonie e tessere.
class_name IA
extends RefCounted

var m: Motore
var rng := RandomNumberGenerator.new()
var me := 0

## distribuzione della differenza fra due dadi (0..5), su 36
const DIFF := [6.0, 10.0, 8.0, 6.0, 4.0, 2.0]

func _init(motore: Motore) -> void:
	m = motore

func s() -> Dictionary:
	return m.s

## carattere di ogni IA: onestà (mantiene le promesse), aggressività, prudenza con l'Oro
func carattere(i: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = int(m.s["seed"]) * 131 + i * 977
	return {"onesta": r.randf_range(0.78, 0.98), "aggr": r.randf_range(0.85, 1.25), "avaro": r.randf_range(0.8, 1.2)}

func decidi(r: Dictionary) -> String:
	me = int(r["g"])
	rng.seed = int(m.s["seed"]) * 7919 + int(m.s["passo"]) * 31 + me
	var k: String = r["k"]
	if has_method("_d_" + k):
		var id = call("_d_" + k, r)
		if id != null and _valida(r, str(id)):
			return str(id)
	return _prima_valida(r)

func _valida(r: Dictionary, id: String) -> bool:
	for o in r["opz"]:
		if str(o["id"]) == id:
			return true
	return false

func _prima_valida(r: Dictionary) -> String:
	for o in r["opz"]:
		if not (str(o["id"]) in ["annulla", "indietro"]):
			return str(o["id"])
	return str(r["opz"][0]["id"])

func _opz_id(r: Dictionary, id: String) -> bool:
	return _valida(r, id)

# ============================================================ probabilità di combattimento

static func p_vince(a: float, d: float) -> float:
	var p := 0.0
	for x in 6:
		for y in 6:
			if a + x > d + y:
				p += DIFF[x] * DIFF[y]
	return p / 1296.0

static func p_pari(a: float, d: float) -> float:
	var p := 0.0
	for x in 6:
		for y in 6:
			if absf((a + x) - (d + y)) < 0.01:
				p += DIFF[x] * DIFF[y]
	return p / 1296.0

# ============================================================ valore dei segnalini Controllo

## moltiplicatore: un segnalino resta per le guerre che mancano
func peso_guerre() -> float:
	return 1.0 + 0.55 * float(3 - int(m.s["guerra"]))

func pv_totali(p: String) -> int:
	var i := m.gioc_di(p)
	return int(m.g(i)["pv"]) if i >= 0 else 0

## valore per `chi` del cambiamento: +1 Controllo a `piu`, -1 a `meno` nella regione
func valore_cambio(chi: String, reg: String, piu: String, meno: String) -> float:
	# lavora su una copia: l'IA non deve mai toccare lo stato (nemmeno l'ordine delle chiavi)
	var prima := m.punti_regione(reg)
	var d: Dictionary = m.s["reg"][reg]["c"].duplicate()
	if piu != "":
		d[piu] = int(d.get(piu, 0)) + 1
	if meno != "":
		d[meno] = int(d.get(meno, 0)) - 1
		if int(d[meno]) <= 0:
			d.erase(meno)
	var dopo := m.punti_regione(reg, d)
	var v := 0.0
	var leader := _leader_pv(chi)
	var tutti := {}
	for q in prima:
		tutti[q] = true
	for q in dopo:
		tutti[q] = true
	for q in tutti:
		var delta := float(int(dopo.get(q, 0)) - int(prima.get(q, 0)))
		if q == chi:
			v += delta
		else:
			var w := 0.3
			if q == leader:
				w = 0.55
			v -= delta * w
	# +1 Oro di rendita a guerra per ogni segnalino
	if piu == chi:
		v += 0.25
	if meno == chi:
		v -= 0.25
	return v * peso_guerre()

## il miglior avversario in classifica (con la proiezione dei punti)
func _leader_pv(escluso: String) -> String:
	var best := ""
	var bv := -999
	var proj := m.punti_proiezione()
	for i in m.np():
		var q := m.pot(i)
		if q == escluso:
			continue
		var v := int(m.g(i)["pv"]) + int(proj.get(q, 0))
		if v > bv:
			bv = v
			best = q
	return best

# ============================================================ stima delle forze

func _nav_bonus_stimato(p: String, reg: String, nemico: String) -> float:
	var mare := Dati.mare_di(reg)
	if mare == "":
		return 0.0
	var mie := m.u(mare, p, Motore.U_F)
	var loro := 0
	if nemico != "":
		loro = m.u(mare, nemico, Motore.U_F)
	if mie > 0 and loro == 0:
		return 1.0
	if loro > 0 and mie == 0:
		return -1.0
	if mie > loro:
		return 0.5
	if loro > mie:
		return -0.5
	return 0.0

func _alleati_attesi(p: String, reg: String, t: int, escludi: String) -> float:
	var n := 0.0
	for j in m.np():
		var q := m.pot(j)
		if q == p or q == escludi or not m.alleati(p, q) or m.alleanza(q) == "":
			continue
		n += 0.45 * m.u(reg, q, t) * float(m.s["rep"][j])
	for q in m.s["np_pot"]:
		if q != p and m.alleati(p, q) and m.alleanza(p) != "":
			n += m.u(reg, q, t)
	return n

func forza_attacco(p: String, reg: String, extra := 0) -> float:
	var f := float(m.u(reg, p, Motore.U_E) + extra)
	f += _alleati_attesi(p, reg, Motore.U_E, "")
	for la in m.alleanze_in(p, reg):
		f += 1.0
	return f

func forza_difesa(q: String, reg: String, contro: String) -> float:
	if m.gioc_di(q) < 0:
		var f := 3.0
		for x in m.s["np_pot"]:
			if m.alleati(q, x) and m.alleanza(q) != "":
				f += m.u(reg, x, Motore.U_E)
		return f
	var f := float(m.u(reg, q, Motore.U_E) + 2 * m.u(reg, q, Motore.U_FO))
	f += _alleati_attesi(q, reg, Motore.U_E, contro)
	f += m.alleanze_in(q, reg).size()
	return f

func _addestr(p: String, q: String) -> float:
	var a := m.conta_tessere_pot(p, "addestr_esercito")
	var b := m.conta_tessere_pot(q, "addestr_esercito") if q != "" else 0
	if a > b:
		return 1.0
	if b > a:
		return -1.0
	return 0.0

## valutazione di un attacco: {v, p}
func valuta_attacco(i: int, reg: String, bid: String, extra_eserciti := 0, gratis := false) -> Dictionary:
	var p := m.pot(i)
	var tipo := bid.get_slice("|", 0)
	var guadagno := 0.0
	var a := forza_attacco(p, reg, extra_eserciti)
	var d := 0.0
	var nemico := ""
	match tipo:
		"n":
			var sid := int(bid.get_slice("|", 1))
			for seg in m.s["reg"][reg]["n"]:
				if int(seg["id"]) == sid:
					d = float(seg["v"])
					if seg["bonus"] == "oro":
						guadagno += 1.2
					elif seg["bonus"] == "pv":
						guadagno += 1.0
			guadagno += valore_cambio(p, reg, p, "")
			if Dati.mare_di(reg) != "" and m.u(Dati.mare_di(reg), p, Motore.U_F) > 0:
				a += 1.0
			a += 1.0 if m.conta_tessere(i, "addestr_esercito") > 0 else 0.0
		"c":
			nemico = bid.get_slice("|", 1)
			d = forza_difesa(nemico, reg, p)
			var nb := _nav_bonus_stimato(p, reg, nemico)
			if nb > 0:
				a += nb
			else:
				d -= nb
			var ad := _addestr(p, nemico)
			if ad > 0:
				a += 1.0
			elif ad < 0:
				d += 1.0
			guadagno += valore_cambio(p, reg, p, nemico)
			# rispetta i patti (quasi sempre)
			var j := m.gioc_di(nemico)
			if j >= 0 and m.ha_patto(i, j):
				guadagno -= 3.0 * carattere(i)["onesta"]
		"s":
			d = float(Dati.FORZA_SEGRETA[bid.get_slice("|", 1)])
			guadagno += valore_cambio(p, reg, p, "")
			if bid.ends_with("pirati"):
				a = float(m.u(reg, p, Motore.U_F))
		"f":
			return {"v": -1.0, "p": 0.0}
	var pw := p_vince(a, d)
	var pt := p_pari(a, d)
	var costo: float = 0.0 if gratis else 2.0 * 0.3 * float(carattere(i)["avaro"])
	costo += m.tasse_per(i, 2) * 0.7 if not gratis else 0.0
	var perdite := (1.0 - pw) * 0.8 + pt * 0.3 + 0.17 * 0.5
	if m.u(reg, p, Motore.U_E) + extra_eserciti <= 1:
		perdite += (1.0 - pw) * 0.2
	var tens := int(m.g(i)["tens"])
	if tens >= 10:
		perdite *= 1.0 + 0.2 * (tens - 9)
		costo += m.tasse_per(i, 2) * 0.3 * (tens - 9)
	var v: float = pw * guadagno * float(carattere(i)["aggr"]) - costo - perdite
	return {"v": v, "p": pw, "a": a, "d": d}

func miglior_attacco(i: int, gratis := false) -> Dictionary:
	var best := {"v": -99.0}
	for reg in m.regioni_attacco(i):
		for b in m.bersagli(i, reg):
			var va := valuta_attacco(i, reg, b["id"], 0, gratis)
			if float(va["v"]) > float(best["v"]):
				best = va.duplicate()
				best["reg"] = reg
				best["id"] = b["id"]
	return best

# ============================================================ utilità delle unità nelle regioni

## quanto vale avere un Esercito in più (n -> n+1) nella regione
func valore_esercito(i: int, reg: String, delta := 1) -> float:
	var p := m.pot(i)
	if not (reg in Dati.REGIONI_PV):
		return -0.3
	var v := 0.0
	# attacco: miglior bersaglio qui
	for b in m.bersagli(i, reg):
		if str(b["id"]).begins_with("f|"):
			continue
		var a0 := valuta_attacco(i, reg, b["id"], 0)
		var a1 := valuta_attacco(i, reg, b["id"], delta)
		v = maxf(v, (float(a1["v"]) - maxf(0.0, float(a0["v"]))) * 0.8)
	# se ora non ho eserciti, i bersagli possibili sono quelli con l'esercito
	if m.u(reg, p, Motore.U_E) == 0 and delta > 0:
		for seg in m.s["reg"][reg]["n"]:
			if seg["t"] == "d":
				var a := 1.0 + (1.0 if Dati.mare_di(reg) != "" and m.u(Dati.mare_di(reg), p, Motore.U_F) > 0 else 0.0)
				v = maxf(v, p_vince(a, float(seg["v"])) * valore_cambio(p, reg, p, "") * 0.7 - 0.6)
		for q in m.s["reg"][reg]["c"]:
			if q != p and not m.alleati(p, q):
				v = maxf(v, p_vince(1.0, forza_difesa(q, reg, p)) * valore_cambio(p, reg, p, q) * 0.7 - 0.6)
	# difesa dei miei segnalini
	var miei := m.c(reg, p)
	if miei > 0:
		var minaccia := 0.0
		for q in m.s["reg"][reg]["u"]:
			if q != p and not m.alleati(p, q):
				minaccia = maxf(minaccia, float(m.u(reg, q, Motore.U_E)))
		if minaccia > 0:
			var dif := float(m.u(reg, p, Motore.U_E) + 2 * m.u(reg, p, Motore.U_FO))
			var lv := -valore_cambio(p, reg, "", p)
			v += lv * (p_vince(minaccia, dif) - p_vince(minaccia, dif + delta)) * 1.2
		else:
			v += 0.1 * miei / (1.0 + m.u(reg, p, Motore.U_E))
	return v

func valore_flotta(i: int, reg: String) -> float:
	var p := m.pot(i)
	if not (reg in Dati.NAVALI):
		return -0.3
	var gia := m.u(reg, p, Motore.U_F)
	var v := 0.0
	var miei := m.c(reg, p)
	if reg in Dati.COLONIE:
		var bersagli := 0.0
		for seg in m.s["reg"][reg]["n"]:
			if seg["t"] == "d":
				bersagli += 1.0
		var nemiche := 0
		for q in m.s["reg"][reg]["u"]:
			if q != p and not m.alleati(p, q):
				nemiche = maxi(nemiche, m.u(reg, q, Motore.U_F))
		v = (0.6 + 0.35 * miei + 0.3 * bersagli) / (1.0 + gia * 1.4)
		if nemiche >= gia and miei > 0:
			v += 0.4
		if reg == "africa" and gia == 0 and not m.segnalini_tipo("gcc").is_empty():
			v += 0.9
	else:
		v = (0.25 + 0.2 * (miei + (m.c("ottomano", p) if reg == "mediterraneo" else 0))) / (1.0 + gia)
	return v

func valore_forte(i: int, reg: String) -> float:
	var p := m.pot(i)
	if not (reg in Dati.REGIONI_PV):
		return -0.5
	var miei := m.c(reg, p)
	if miei < 2:
		return -0.2
	var minaccia := 0
	for q in m.s["reg"][reg]["u"]:
		if q != p and not m.alleati(p, q):
			minaccia = maxi(minaccia, m.u(reg, q, Motore.U_E))
	return 0.25 * miei + 0.3 * minaccia - 0.3 * m.u(reg, p, Motore.U_FO)

func valore_unita(i: int, reg: String, t: int, delta := 1) -> float:
	match t:
		Motore.U_E:
			return valore_esercito(i, reg, delta)
		Motore.U_F:
			return valore_flotta(i, reg)
	return valore_forte(i, reg)

## miglior destinazione per un'unità di tipo t che parte da `da`
func miglior_dest(i: int, da: String, t: int) -> Dictionary:
	var best := {"reg": "", "v": -99.0}
	for r in m.destinazioni(i, da, t):
		var v := valore_unita(i, r, t)
		if m.lontano(da, r):
			v -= 0.25
		if v > float(best["v"]):
			best = {"reg": r, "v": v}
	return best

func miglior_movimento(i: int, falliti: Array) -> Dictionary:
	var best := {"v": 0.3}
	var p := m.pot(i)
	for key in m.gruppi_mobili(i, falliti):
		var da: String = key.get_slice("|", 0)
		var t: int = Motore.SIGLA_U.find(key.get_slice("|", 1))
		# valuta tutto come se l'unità fosse già stata tolta da `da`
		m.s["reg"][da]["u"][p][t] -= 1
		var resta := valore_unita(i, da, t) if da in Dati.REGIONI_PV else -0.4
		if t == Motore.U_F and da in Dati.COLONIE and m.u(da, p, Motore.U_E) > 0 and m.u(da, p, Motore.U_F) == 0:
			resta += 0.4
		var dd := {"reg": "", "v": -99.0}
		for r in m.destinazioni(i, da, t):
			var v := valore_unita(i, r, t)
			if m.lontano(da, r):
				v -= 0.25
			if v > float(dd["v"]):
				dd = {"reg": r, "v": v}
		m.s["reg"][da]["u"][p][t] += 1
		if dd["reg"] == "":
			continue
		var guad: float = float(dd["v"]) - maxf(resta, 0.0)
		if guad > float(best["v"]):
			best = {"v": guad, "key": key, "dest": dd["reg"]}
	return best

# ============================================================ piazzamento iniziale

func _d_piazza(r: Dictionary) -> String:
	var best := ""
	var bv := -99.0
	var p := m.pot(me)
	for o in r["opz"]:
		var t: int = Motore.SIGLA_U.find(str(o["id"]).get_slice("|", 0))
		var reg: String = o["reg"]
		var v := 0.0
		if reg == m.casa(p):
			v = -0.5
		elif t == Motore.U_E:
			v = valore_esercito(me, reg) + 0.35 * m.c(reg, p) + float(Dati.REGIONI[reg]["pv"][0]) * 0.04
			if reg in Dati.COLONIE and m.u(reg, p, Motore.U_F) == 0:
				v -= 0.25
			v -= 0.5 * m.u(reg, p, Motore.U_E)
		elif t == Motore.U_F:
			v = valore_flotta(me, reg) + (0.9 if reg in Dati.COLONIE and m.c(reg, p) > 0 and m.u(reg, p, Motore.U_F) == 0 else 0.0)
		else:
			v = valore_forte(me, reg) - 0.3
		v += rng.randf() * 0.15
		if v > bv:
			bv = v
			best = o["id"]
	return best

# ============================================================ Grandi Alleanze

## preferenza di i verso la potenza q: positiva = la voglio alleata (mi minaccia), negativa = la voglio nemica
func preferenza(i: int, q: String) -> float:
	var p := m.pot(i)
	if q == p:
		return 0.0
	var minaccia := 0.0
	var occasione := 0.0
	for reg in Dati.REGIONI_PV:
		var mie := m.c(reg, p)
		var sue := m.c(reg, q)
		var sue_u := m.u(reg, q, Motore.U_E) + 0.6 * m.u(Dati.mare_di(reg) if Dati.mare_di(reg) != "" else reg, q, Motore.U_F)
		var mie_u := m.u(reg, p, Motore.U_E)
		var peso := float(Dati.REGIONI[reg]["pv"][0]) / 5.0
		if mie > 0:
			minaccia += sue_u * peso * 0.5
		if sue > 0:
			occasione += mie_u * peso * 0.45 * sue
		if mie > 0 and sue > 0:
			# chi divide con me una regione: meglio alleato se è forte, nemico se è debole
			occasione += 0.2 * peso
	var leader := _leader_pv(p)
	var v := minaccia - occasione
	if q == leader and int(m.s["guerra"]) >= 2:
		v -= 0.8
	if m.gioc_di(q) < 0:
		v *= 0.6
	return v

## valore per i di mettere a nella Rossa e b nella Blu
func valore_coppia(i: int, a: String, b: String) -> float:
	var p := m.pot(i)
	var mia := m.alleanza(p)
	var v := 0.0
	if a == p or b == p:
		var lato := "R" if a == p else "B"
		var altro := b if a == p else a
		if altro != "":
			v -= preferenza(i, altro)
		for q in m.s["slot"]["R"]:
			v += preferenza(i, q) if lato == "R" else -preferenza(i, q)
		for q in m.s["slot"]["B"]:
			v += preferenza(i, q) if lato == "B" else -preferenza(i, q)
		# posizione nell'ordine di gioco: presto nella prima guerra, tardi nella terza
		var pos: int = m.s["slot"][lato].size()
		if int(m.s["guerra"]) == 1:
			v += 0.25 - 0.08 * pos
		elif int(m.s["guerra"]) == 3:
			v += 0.08 * pos
		v += 0.3
	elif mia != "":
		for x in [[a, "R"], [b, "B"]]:
			if x[0] == "":
				continue
			v += 0.7 * (preferenza(i, x[0]) if x[1] == mia else -preferenza(i, x[0]))
	else:
		v += 0.15 * absf(preferenza(i, a) - preferenza(i, b)) if a != "" and b != "" else 0.0
	return v

func _d_asta(r: Dictionary) -> String:
	var a: Dictionary = m.s["asta"]
	var cur := -999.0
	var offerta := int(a["offerta"])
	if offerta >= 0:
		cur = valore_coppia(me, a["R"], a["B"])
	var best := []
	var bv := -999.0
	for cp in m.coppie_asta():
		var v := valore_coppia(me, cp[0], cp[1]) + rng.randf() * 0.05
		if v > bv:
			bv = v
			best = cp
	var oro: int = m.g(me)["oro"]
	var car := carattere(me)
	if offerta < 0:
		var b0 := 0
		if bv > 1.2 and oro >= 3:
			b0 = 1
		return "%s|%s|%d" % [best[0], best[1], b0]
	var guadagno := bv - cur
	if best.size() == 0 or guadagno < 0.35:
		return "passa"
	var massimo := int(floor(guadagno * 1.6 / car["avaro"]))
	massimo = mini(massimo, oro + 1)
	if int(m.s["guerra"]) == 3:
		massimo = mini(massimo, oro)
	var bid := offerta + 1
	if bid > massimo:
		return "passa"
	return "%s|%s|%d" % [best[0], best[1], bid]

# ============================================================ turno

func _valuta_azioni(r: Dictionary) -> Dictionary:
	var i := me
	var p := m.pot(i)
	var gg := m.g(i)
	var t: Dictionary = m.s["t"]
	var car := carattere(i)
	var val := {}
	for o in r["opz"]:
		var id: String = o["id"]
		var v := -99.0
		match id:
			"costruisci":
				var bb := -99.0
				for tt in [Motore.U_E, Motore.U_F, Motore.U_FO]:
					if m.pezzi_liberi(p, tt) <= 0:
						continue
					var d := miglior_dest(i, m.casa(p), tt)
					bb = maxf(bb, float(d["v"]))
				var unita := m.tot_unita(p)
				v = bb - 0.45 - 0.2 * float(3 - int(m.s["guerra"])) * 0.2
				if unita < 5:
					v += 0.5
				if int(gg["pop"]) <= 1:
					v -= 0.3
				if int(m.s["round"]) >= Dati.round_per_guerra(m.np()) and int(m.s["guerra"]) == 3:
					v -= 0.6
			"muovi":
				var mv := miglior_movimento(i, [])
				v = float(mv["v"]) * 1.5 if mv.has("key") else -1.0
			"attacca":
				var at := miglior_attacco(i)
				v = float(at["v"])
			"colonizza":
				var best := -99.0
				for seg in m.segnalini_tipo("col"):
					best = maxf(best, valore_cambio(p, seg["reg"], p, ""))
				v = best - 0.5 - (0.4 if int(gg["pop"]) <= 2 else 0.0)
			"commercio":
				var best2 := -99.0
				for seg in m.segnalini_tipo("gcc"):
					best2 = maxf(best2, valore_cambio(p, seg["reg"], p, ""))
				v = best2
			"tessera":
				var tb := miglior_tessera(i)
				v = float(tb["v"])
			"alleanza":
				var al := miglior_alleanza(i)
				v = float(al["v"])
			"segreta":
				var sg := miglior_segreta(i)
				v = float(sg["v"])
			"passa":
				v = 0.15 + (0.35 + maxf(0.0, (int(gg["tens"]) - 10) * 0.15) if int(gg["tens"]) > 0 and not t["attacco"] else 0.0)
				if int(m.s["guerra"]) == 3:
					v += 0.25
			"fine":
				v = 0.0 if int(t["az"]) == 0 else -5.0
			_:
				if id.begins_with("lib|"):
					v = valore_libera(i, int(id.get_slice("|", 1)))
				elif id.begins_with("ricatto|"):
					v = valore_ricatto(i, int(id.get_slice("|", 1)))
		val[id] = v
	return val

func _d_azione(r: Dictionary) -> String:
	var val := _valuta_azioni(r)
	var best := "fine"
	var bv := -99.0
	for id in val:
		var v: float = val[id] + rng.randf() * 0.05
		if v > bv:
			bv = v
			best = id
	# se nessuna azione vale qualcosa, meglio passare che sprecare risorse
	if bv < 0.05 and _opz_id(r, "passa"):
		return "passa"
	return best

func valore_libera(i: int, k: int) -> float:
	var x: Dictionary = m.g(i)["tessere"][k]
	var t: String = x["t"]
	var p := m.pot(i)
	match t:
		"agricoltura":
			return 1.0 if int(m.g(i)["pop"]) < 9 else -1.0
		"mercenari":
			return maxf(-1.0, float(miglior_dest(i, m.casa(p), Motore.U_E)["v"]) + 0.2)
		"reclutamento":
			return maxf(-1.0, float(miglior_dest(i, m.casa(p), Motore.U_F)["v"]) + 0.2)
		"milizia_indigena":
			var bv := -1.0
			for r in m.colonie_milizia(i):
				bv = maxf(bv, valore_esercito(i, r) + 0.3)
			return bv
		"ministero":
			return float(miglior_attacco(i, true)["v"]) + 0.3
		"diplomazia":
			return float(miglior_alleanza(i)["v"]) + 0.3
		"blocco":
			for r in m.colonie_blocco(i):
				if m.c(r, p) > 0:
					for q in m.s["reg"][r]["c"]:
						if q != p and not m.alleati(p, q):
							return 0.6
			return -0.5
	if Dati.TESSERE[t]["cat"] == "com":
		return 0.4 * m._oro_commercio(i, t)
	return -1.0

func valore_ricatto(i: int, j: int) -> float:
	# chiede Oro a chi potrebbe attaccare con buone probabilità, ma solo se poi è disposta a non farlo
	var p := m.pot(i)
	var q := m.pot(j)
	if m.alleati(p, q) or int(m.g(j)["oro"]) < 2 or int(m.s["t"]["az"]) <= 0 or m.s["t"]["attacco"]:
		return -1.0
	var best := -1.0
	for reg in m.regioni_attacco(i):
		for b in m.bersagli(i, reg):
			if b["id"] == "c|" + q:
				var va := valuta_attacco(i, reg, b["id"])
				best = maxf(best, float(va["p"]))
	if best < 0.55:
		return -1.0
	# solo ogni tanto, per non trasformare ogni turno in una trattativa
	return 0.35 if rng.randf() < 0.35 else -1.0

func _d_ricatto_quanto(r: Dictionary) -> String:
	var j: int = m.s["ctx"]["chi"]
	var k := clampi(int(m.g(j)["oro"]) / 3, 1, 3)
	return "chiedi|%d" % k

func _d_ricatto_risp(r: Dictionary) -> String:
	var ctx: Dictionary = m.s["ctx"]
	var da: int = r["da"]
	var k: int = ctx["k"]
	if ctx["tipo"] == "chiedi":
		# vale la pena pagare? stima il danno di un attacco riuscito
		var danno := 0.0
		for reg in m.regioni_attacco(da):
			for b in m.bersagli(da, reg):
				if b["id"] == "c|" + m.pot(me):
					var va := valuta_attacco(da, reg, b["id"])
					danno = maxf(danno, float(va["p"]) * -valore_cambio(m.pot(me), reg, m.pot(da), m.pot(me)))
		var fid := float(m.s["rep"][da])
		if danno * fid > k * 0.45 and int(m.g(me)["oro"]) >= k:
			return "paga"
		return "rifiuta"
	# offerta di Oro in cambio di non attaccare: accetta se non ha grandi piani contro di lui
	var piani := 0.0
	for reg in m.regioni_attacco(me):
		for b in m.bersagli(me, reg):
			if b["id"] == "c|" + m.pot(da):
				piani = maxf(piani, float(valuta_attacco(me, reg, b["id"])["v"]))
	return "paga" if piani < k * 0.6 else "rifiuta"

# ------------------------------------------------------------ sotto-decisioni del turno

func _d_costr_tipo(r: Dictionary) -> String:
	var p := m.pot(me)
	var best := "e"
	var bv := -99.0
	for o in r["opz"]:
		if o["id"] == "annulla":
			continue
		var t: int = Motore.SIGLA_U.find(o["id"])
		var d := miglior_dest(me, m.casa(p), t)
		var v := float(d["v"])
		if v > bv:
			bv = v
			best = o["id"]
	return best

func _d_costr_dest(r: Dictionary) -> String:
	var ctx: Dictionary = m.s["ctx"]
	var d := miglior_dest(me, ctx["da"], int(ctx["tipo"]))
	if d["reg"] == "" or float(d["v"]) < -0.2:
		return "resta"
	return d["reg"]

func _d_milizia(_r: Dictionary) -> String:
	return "si" if int(m.g(me)["pop"]) >= 2 and float(miglior_dest(me, m.casa(m.pot(me)), Motore.U_E)["v"]) > 0.2 else "no"

func _d_muovi_da(r: Dictionary) -> String:
	var ctx: Dictionary = m.s["ctx"]
	var mv := miglior_movimento(me, ctx["falliti"])
	if mv.has("key"):
		return mv["key"]
	return "fine" if _opz_id(r, "fine") else "annulla"

func _d_muovi_a(r: Dictionary) -> String:
	var ctx: Dictionary = m.s["ctx"]
	var mv := miglior_movimento(me, ctx["falliti"])
	if mv.has("key") and mv["key"] == ctx["sel"]:
		return mv["dest"]
	var da: String = str(ctx["sel"]).get_slice("|", 0)
	var t: int = Motore.SIGLA_U.find(str(ctx["sel"]).get_slice("|", 1))
	var d := miglior_dest(me, da, t)
	return d["reg"] if d["reg"] != "" else "indietro"

func _d_dsm(r: Dictionary) -> String:
	var oro: int = m.g(me)["oro"]
	if _opz_id(r, "paga1"):
		return "paga1" if oro >= 2 else "resta"
	if oro >= 5:
		return "paga3"
	if oro >= 2:
		return "paga2"
	return "affonda"

func _d_colonizza(r: Dictionary) -> String:
	return _miglior_segnalino(r)

func _d_commercio(r: Dictionary) -> String:
	return _miglior_segnalino(r)

func _miglior_segnalino(r: Dictionary) -> String:
	var p := m.pot(me)
	var best := "annulla"
	var bv := -99.0
	for o in r["opz"]:
		if o["id"] == "annulla":
			continue
		var v := valore_cambio(p, o["reg"], p, "") + rng.randf() * 0.05
		if v > bv:
			bv = v
			best = o["id"]
	return best

func miglior_alleanza(i: int) -> Dictionary:
	var p := m.pot(i)
	var best := {"v": -1.0, "id": ""}
	for la in m.alleanze_disponibili(i):
		var d: Dictionary = Dati.ALLEANZE[la]
		var v := -0.2 - 0.3 * int(d["costo"])
		for reg in d["reg"]:
			var mie := m.c(reg, p)
			var miei_u := m.u(reg, p, Motore.U_E) + m.u(reg, p, Motore.U_FO)
			var nemici := 0
			for q in m.s["reg"][reg]["u"]:
				if q != p and not m.alleati(p, q):
					nemici += m.u(reg, q, Motore.U_E)
			var bers := 0
			for seg in m.s["reg"][reg]["n"]:
				if seg["t"] == "d":
					bers += 1
			if miei_u > 0:
				v += 0.25 * bers + 0.2 * mie * mini(nemici, 2) + 0.15
		if int(m.s["round"]) >= Dati.round_per_guerra(m.np()) - 1:
			v -= 0.4
		if v > float(best["v"]):
			best = {"v": v, "id": la}
	return best

func _d_alleanza(r: Dictionary) -> String:
	var al := miglior_alleanza(me)
	return al["id"] if al["id"] != "" else "annulla"

func valore_tessera(i: int, t: String) -> float:
	var gg := m.g(i)
	var p := m.pot(i)
	var d: Dictionary = Dati.TESSERE[t]
	var gu := int(m.s["guerra"])
	var resto := float(3 - gu)
	var v := 0.0
	match t:
		"agricoltura": v = 1.5 + 0.6 * resto
		"riforma": v = 0.9 * mini(int(gg["tens"]), 2) * (1.0 if gu == 3 else 0.55)
		"industria": v = 3.0 + m.conta_tessere(i, "agricoltura") - 1.0 - 2.0 * (0.9 if gu == 3 else 0.6)
		"addestr_esercito": v = 0.9 + 0.6 * resto
		"addestr_navale": v = 0.3 + 0.25 * resto
		"banca": v = 0.4 + 0.35 * resto
		"logistica": v = 0.5 + 0.3 * resto
		"milizia": v = 0.4 + 0.35 * resto
		"mercenari": v = 0.7 + 0.5 * resto
		"reclutamento": v = 0.45 + 0.35 * resto
		"riserve": v = 0.55 + 0.3 * resto
		"milizia_indigena": v = (0.5 + 0.4 * resto) if not m.colonie_milizia(i).is_empty() else 0.1
		"ministero": v = 0.6 + 0.45 * resto
		"diplomazia": v = 0.3 + 0.3 * resto
		"blocco", "ritirata", "sorpresa": v = 0.45
		_:
			if d["cat"] == "com":
				var best := 0
				for reg in d["reg"]:
					best = maxi(best, m.c(reg, p))
				v = 0.4 * best * (resto + 1.0)
	var oro := int(d.get("oro", 0))
	v -= 0.15 * oro * float(carattere(i)["avaro"])
	v -= 0.7 * m.tasse_per(i, oro)
	v -= 0.45 * int(d.get("pop", 0)) if t != "industria" else 0.0
	return v

func miglior_tessera(i: int) -> Dictionary:
	var best := {"v": -1.0, "id": ""}
	for t in m.tessere_prendibili(i):
		var v := valore_tessera(i, t) + rng.randf() * 0.05
		if v > float(best["v"]):
			best = {"v": v, "id": t}
	return best

func _d_tessera(r: Dictionary) -> String:
	var tb := miglior_tessera(me)
	return tb["id"] if tb["id"] != "" else "annulla"

func miglior_segreta(i: int) -> Dictionary:
	var best := {"v": -1.0, "tok": "", "id": ""}
	var p := m.pot(i)
	for tok in m.segrete_disponibili(i):
		for b in m.bersagli_segreta(i, tok):
			var q: String = b["pot"]
			var reg: String = b["reg"]
			var dif := 0.0
			if tok == "pirati":
				dif = m.u(reg, q, Motore.U_F)
			else:
				dif = m.u(reg, q, Motore.U_E) + 2 * m.u(reg, q, Motore.U_FO)
			var pw := p_vince(Dati.FORZA_SEGRETA[tok], dif)
			var guad := valore_cambio(p, reg, "", q)
			# colpire un alleato è possibile ma lo fa solo se è il primo in classifica
			if m.alleati(p, q) and q != _leader_pv(p):
				guad *= 0.3
			var v := pw * guad - 0.4
			if v > float(best["v"]):
				best = {"v": v, "tok": tok, "id": b["id"]}
	return best

func _d_segreta(r: Dictionary) -> String:
	var sg := miglior_segreta(me)
	return sg["tok"] if sg["tok"] != "" else "annulla"

func _d_segreta_bers(r: Dictionary) -> String:
	var sg := miglior_segreta(me)
	if sg["id"] != "" and _opz_id(r, sg["id"]):
		return sg["id"]
	return "annulla"

func _d_milind(r: Dictionary) -> String:
	var best := "annulla"
	var bv := -99.0
	for o in r["opz"]:
		if o["id"] == "annulla":
			continue
		var v := valore_esercito(me, o["id"])
		if v > bv:
			bv = v
			best = o["id"]
	return best

func _d_blocco_reg(r: Dictionary) -> String:
	var p := m.pot(me)
	var best := "annulla"
	var bv := 0.0
	for o in r["opz"]:
		if o["id"] == "annulla":
			continue
		var v := float(m.c(o["id"], p)) + m.u(o["id"], p, Motore.U_F) * 0.5
		if v > bv:
			bv = v
			best = o["id"]
	return best

func _d_att_reg(r: Dictionary) -> String:
	var gratis: bool = m.s["ctx"].get("gratis", false)
	var at := miglior_attacco(me, gratis)
	if at.has("reg") and float(at["v"]) > -0.5:
		return at["reg"]
	return "annulla"

func _d_att_bers(r: Dictionary) -> String:
	var reg: String = m.s["ctx"]["reg"]
	var gratis: bool = m.s["ctx"].get("gratis", false)
	var best := "indietro"
	var bv := -99.0
	for o in r["opz"]:
		if o["id"] == "indietro":
			continue
		var v := float(valuta_attacco(me, reg, o["id"], 0, gratis)["v"])
		if v > bv:
			bv = v
			best = o["id"]
	return best

# ============================================================ combattimento

func _cb() -> Dictionary:
	return m.s["cb"]

func _d_sorpresa(_r: Dictionary) -> String:
	var n := 0
	for j in m.possibili_alleati("d"):
		n += m.u(_cb()["reg"], m.pot(j), Motore.U_E)
	return "si" if n >= 1 else "no"

## stima della probabilità di vittoria del combattimento terrestre (con gli impegni già fatti)
func _p_terra(extra_a := 0.0, extra_d := 0.0) -> float:
	var cb := _cb()
	var fa := float(m.forza_terra("a")) + extra_a
	var fd := float(m.forza_terra("d")) + extra_d
	if cb["nav"] == "":
		var nb := 0.0
		if m.flotte_lato("a") > m.flotte_lato("d"):
			nb = 0.5
		elif m.flotte_lato("d") > m.flotte_lato("a"):
			nb = -0.5
		if nb > 0:
			fa += nb
		else:
			fd -= nb
	return p_vince(fa, fd)

## la posta in gioco per il giocatore j se vince il lato `lato`
func _interesse(j: int, lato: String) -> float:
	var cb := _cb()
	var p := m.pot(j)
	var reg: String = cb["reg"]
	var v := 0.0
	match cb["tipo"]:
		"c":
			# se vince l'attaccante: +1 attaccante, -1 difensore
			var delta := valore_cambio(p, reg, cb["apot"], cb["dpot"])
			v = delta if lato == "a" else -delta
		"n":
			var d2 := valore_cambio(p, reg, cb["apot"], "")
			v = d2 if lato == "a" else -d2
	# lealtà verso la propria Grande Alleanza
	v += 0.35
	return v

func _d_tratt(r: Dictionary) -> String:
	var cb := _cb()
	var lato: String = r["lato"]
	var oro: int = m.g(me)["oro"]
	var p_att := _p_terra()
	var mia_p := p_att if lato == "a" else 1.0 - p_att
	if mia_p > 0.7 or oro < 2:
		return "basta"
	# offre a chi ha più unità e una buona reputazione
	var best := "basta"
	var bv := 0.0
	for o in r["opz"]:
		if o["id"] == "basta":
			continue
		var j: int = o["chi"]
		var k: int = o["k"]
		var ne := m.u(cb["reg"], m.pot(j), Motore.U_E)
		var guad := (p_vince(m.forza_terra("a") + (ne if lato == "a" else 0), m.forza_terra("d") + (ne if lato == "d" else 0)) - p_att)
		if lato == "d":
			guad = -guad
		var posta := 2.0 * peso_guerre()
		var v := guad * posta * float(m.s["rep"][j]) - 0.35 * k
		# l'IA preferisce offerte piccole
		if k > 2:
			v -= 0.3 * (k - 2)
		if v > bv and k <= oro:
			bv = v
			best = o["id"]
	return best

func _d_tratt_risp(r: Dictionary) -> String:
	var lato: String = r["lato"]
	var k: int = r["q"]
	var interesse := _interesse(me, lato)
	var rischio := 0.5 * (1.0 - _p_terra() if lato == "a" else _p_terra())
	var v := interesse + 0.5 * k - rischio
	if v > 0.6:
		return "accetta"
	if v > 0.1:
		return "chiedi|%d" % (k + 1)
	if v > -0.4 and k <= 2:
		return "chiedi|%d" % (k + 2)
	return "rifiuta"

func _d_tratt_contro(r: Dictionary) -> String:
	var k: int = r["q"]
	var lato: String = r["lato"]
	var p_att := _p_terra()
	var mia_p := p_att if lato == "a" else 1.0 - p_att
	if int(m.g(me)["oro"]) >= k and mia_p < 0.55 and k <= 4:
		return "accetta"
	return "rifiuta"

func _d_impegno(r: Dictionary) -> String:
	var cb := _cb()
	var lato: String = r["lato"]
	var promesso: bool = cb["promesse"].get(str(me), "") == lato
	var car := carattere(me)
	if promesso and rng.randf() < car["onesta"]:
		return "tutto" if _opz_id(r, "tutto") else (r["opz"][0]["id"])
	var interesse := _interesse(me, lato)
	var ne := m.u(cb["reg"], m.pot(me), Motore.U_E) if cb["tipo"] != "f" else 0
	var p0 := _p_terra()
	var p1 := p_vince(m.forza_terra("a") + (ne if lato == "a" else 0), m.forza_terra("d") + (ne if lato == "d" else 0))
	var aiuto := absf(p1 - p0)
	var rischio := 0.35 * minf(2.0, float(ne)) * (1.0 - (p1 if lato == "a" else 1.0 - p1))
	var v := interesse * aiuto * 2.0 - rischio + 0.1
	if v > 0.0:
		if _opz_id(r, "tutto") and interesse > 0.6:
			return "tutto"
		if _opz_id(r, "e"):
			return "e"
		return r["opz"][0]["id"]
	return "no"

func _d_nav_att(_r: Dictionary) -> String:
	return "si" if p_vince(m.forza_navale("a"), m.forza_navale("d")) >= 0.38 else "no"

func _d_nav_def(_r: Dictionary) -> String:
	return "si" if p_vince(m.forza_navale("d"), m.forza_navale("a")) >= 0.38 else "no"

func _d_blocco_uso(_r: Dictionary) -> String:
	var p := _p_terra()
	return "si" if p > 0.2 and p < 0.85 else "no"

func _d_riserve(_r: Dictionary) -> String:
	return "si"

func _d_ritirata(_r: Dictionary) -> String:
	return "si"

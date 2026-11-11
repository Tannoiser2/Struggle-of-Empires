## La plancia di gioco: l'immagine del tabellone con sopra segnalini, unità, tracciati.
## Si può ingrandire (rotella o pizzico) e spostare trascinando. Le regioni valide per la
## decisione in corso si illuminano; cliccandole si sceglie.
class_name Plancia
extends Control

signal regione_cliccata(reg: String)
signal regione_sopra(reg: String)
signal oggetto_cliccato(chiave: String, reg: String)

var m: Motore
var tex_plancia: Texture2D
var tex := {}
var font: Font
var font_titoli: Font
var evidenzia: Array = []
var evid_oggetti: Array = []
## [rettangolo sullo schermo, chiave]
var cliccabili: Array = []
var selezionata := ""
var sopra := ""
var zoom := 1.0
var offset := Vector2.ZERO
var _trascina := false
var _trascinato := 0.0
var _ultimo := Vector2.ZERO
var _tocchi := {}
var _dist_pizzico := 0.0
var tempo := 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	tex_plancia = load("res://assets/mappa/plancia.jpg")
	font = load("res://assets/font/EBGaramond.ttf")
	font_titoli = load("res://assets/font/IMFellSC.ttf")
	for p in Dati.POTENZE:
		for k in ["controllo", "esercito", "flotta", "forte"]:
			tex["%s_%s" % [k, p]] = load("res://assets/segnalini/%s_%s.png" % [k, p])
	for la in Dati.ALLEANZE:
		tex["la_" + la] = load("res://assets/alleanze/%s.jpg" % la)
	tex["pirati"] = load("res://assets/alleanze/pirati.jpg")
	tex["rivolta"] = load("res://assets/alleanze/rivolta.jpg")
	tex["blocco"] = load("res://assets/tessere/blocco.jpg")

func _process(delta: float) -> void:
	tempo += delta
	if not evidenzia.is_empty() or not evid_oggetti.is_empty():
		queue_redraw()

## rettangolo dove si disegna il tabellone (adattato e con zoom)
func area() -> Rect2:
	var ts := tex_plancia.get_size()
	var sc := minf(size.x / ts.x, size.y / ts.y) * zoom
	var dim := ts * sc
	var base := (size - dim) / 2.0
	return Rect2(base + offset, dim)

func a_schermo(v: Vector2) -> Vector2:
	var r := area()
	return r.position + v * r.size

func scala() -> float:
	return area().size.x / 1800.0

func _limita() -> void:
	var r := area()
	var lim := r.size * 0.45
	offset.x = clampf(offset.x, -lim.x, lim.x)
	offset.y = clampf(offset.y, -lim.y, lim.y)
	if zoom <= 1.0:
		offset = Vector2.ZERO

func zooma(f: float, centro: Vector2) -> void:
	var prima := area()
	var rel := (centro - prima.position) / prima.size
	zoom = clampf(zoom * f, 1.0, 3.2)
	var dopo := area()
	offset += centro - (dopo.position + rel * dopo.size)
	_limita()
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			zooma(1.15, ev.position)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			zooma(1.0 / 1.15, ev.position)
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				_trascina = true
				_trascinato = 0.0
				_ultimo = ev.position
			else:
				_trascina = false
				if _trascinato < 8.0:
					var r := regione_a(ev.position)
					var ogg := oggetto_a(ev.position)
					if ogg != "":
						oggetto_cliccato.emit(ogg, r)
					elif r != "":
						regione_cliccata.emit(r)
	elif ev is InputEventMouseMotion:
		if _trascina and _tocchi.size() < 2:
			var d: Vector2 = ev.position - _ultimo
			_trascinato += d.length()
			if zoom > 1.0:
				offset += d
				_limita()
				queue_redraw()
			_ultimo = ev.position
		var r2 := regione_a(ev.position)
		if r2 != sopra:
			sopra = r2
			regione_sopra.emit(r2)
			queue_redraw()
	elif ev is InputEventScreenTouch:
		if ev.pressed:
			_tocchi[ev.index] = ev.position
		else:
			_tocchi.erase(ev.index)
		if _tocchi.size() == 2:
			var k: Array = _tocchi.keys()
			_dist_pizzico = (_tocchi[k[0]] as Vector2).distance_to(_tocchi[k[1]])
	elif ev is InputEventScreenDrag:
		_tocchi[ev.index] = ev.position
		if _tocchi.size() == 2:
			var k: Array = _tocchi.keys()
			var a: Vector2 = _tocchi[k[0]]
			var b: Vector2 = _tocchi[k[1]]
			var dist := a.distance_to(b)
			if _dist_pizzico > 0:
				zooma(dist / _dist_pizzico, (a + b) / 2.0)
			_dist_pizzico = dist
	elif ev is InputEventMagnifyGesture:
		zooma(ev.factor, ev.position)

func oggetto_a(pos: Vector2) -> String:
	for x in cliccabili:
		if (x[0] as Rect2).grow(3).has_point(pos):
			return x[1]
	return ""

func _cliccabile(r: Rect2, chiave: String) -> void:
	cliccabili.append([r, chiave])
	if chiave in evid_oggetti:
		var puls := 0.55 + 0.45 * sin(tempo * 4.0)
		draw_rect(r.grow(3), Color(1.0, 0.82, 0.25, 0.5 + 0.4 * puls), false, 3.0)

func regione_a(pos: Vector2) -> String:
	var best := ""
	var bd := 70.0 * scala()
	for r in Dati.REGIONI:
		var d := pos.distance_to(a_schermo(Dati.REGIONI[r]["pos"]))
		if d < bd:
			bd = d
			best = r
	return best

# ============================================================ disegno

func _draw() -> void:
	if tex_plancia == null:
		return
	var r := area()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.07, 0.05))
	draw_texture_rect(tex_plancia, r, false)
	if m == null or m.s.is_empty():
		return
	var sc := scala()
	cliccabili = []
	_disegna_tracciati(sc)
	for la in Dati.ALLEANZE:
		_disegna_alleanza(la, sc)
	for reg in Dati.REGIONI:
		_disegna_regione(reg, sc)
	# regioni da scegliere
	var puls := 0.55 + 0.45 * sin(tempo * 4.0)
	for reg in evidenzia:
		var c := a_schermo(Dati.REGIONI[reg]["pos"])
		draw_arc(c, 46.0 * sc, 0, TAU, 48, Color(1.0, 0.85, 0.3, 0.5 + 0.4 * puls), 4.0 * sc, true)
		draw_arc(c, 52.0 * sc, 0, TAU, 48, Color(0.55, 0.1, 0.05, 0.35 * puls), 2.5 * sc, true)
	if selezionata != "":
		var c2 := a_schermo(Dati.REGIONI[selezionata]["pos"])
		draw_arc(c2, 50.0 * sc, 0, TAU, 48, Color(0.75, 0.1, 0.08, 0.9), 4.0 * sc, true)
	if sopra != "":
		var c3 := a_schermo(Dati.REGIONI[sopra]["pos"])
		draw_arc(c3, 44.0 * sc, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0 * sc, true)

func _testo(pos: Vector2, t: String, size_px: float, col := Color.WHITE, ombra := true, f: Font = null) -> void:
	var ff := f if f != null else font
	var fs := maxi(8, int(size_px))
	if ombra:
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_string(ff, pos + d, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.85))
	draw_string(ff, pos, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _numero(centro: Vector2, n: int, sc: float) -> void:
	if n <= 1:
		return
	var rr := 10.0 * sc
	draw_circle(centro, rr, Color(0.12, 0.08, 0.05))
	draw_arc(centro, rr, 0, TAU, 20, Color(0.95, 0.85, 0.55), 1.4 * sc, true)
	var t := str(n)
	var fs := maxi(9, int(15 * sc))
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, centro + Vector2(-w / 2.0, 4.5 * sc), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.95, 0.8))

func _disegna_regione(reg: String, sc: float) -> void:
	var d: Dictionary = m.s["reg"][reg]
	var c := a_schermo(Dati.REGIONI[reg]["pos"])
	# righe: neutrali (raggruppati per tipo), segnalini Controllo, unità
	var righe: Array = []
	var gruppi := {}
	var ordine: Array = []
	var chiavi := {}
	for seg in d["n"]:
		var k := Dati.img_neutrale(seg)
		if not gruppi.has(k):
			gruppi[k] = 0
			ordine.append(k)
			chiavi[k] = "n:%s:%s" % [reg, str(int(seg["v"])) if seg["t"] == "d" else seg["t"]]
		gruppi[k] += 1
	var wn := 33.0 * sc
	var wc := 32.0 * sc
	var wu := 27.0 * sc
	var gap := 8.0 * sc
	if not ordine.is_empty():
		righe.append({"t": "n", "w": wn, "h": wn * 1.08, "items": ordine})
	var ctrl: Array = d["c"].keys()
	ctrl.sort_custom(func(a, b): return int(d["c"][a]) > int(d["c"][b]))
	if not ctrl.is_empty():
		righe.append({"t": "c", "w": wc, "h": wc, "items": ctrl})
	var pezzi: Array = []
	for p in d["u"].keys():
		for t in 3:
			var n: int = int(d["u"][p][t])
			if n > 0:
				pezzi.append([p, t, n])
	if not pezzi.is_empty():
		righe.append({"t": "u", "w": wu, "h": wu, "items": pezzi})
	if righe.is_empty():
		return
	var alto := 0.0
	var largo := 0.0
	for rg in righe:
		alto += float(rg["h"]) + 4.0 * sc
		largo = maxf(largo, rg["items"].size() * (float(rg["w"]) + gap) - gap)
	var y := c.y - alto / 2.0
	var lastra := Rect2(c.x - largo / 2.0 - 7.0 * sc, y - 5.0 * sc, largo + 14.0 * sc, alto + 8.0 * sc)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.91, 0.78, 0.78)
	sb.border_color = Color(0.25, 0.16, 0.08, 0.7)
	sb.set_border_width_all(maxi(1, int(1.5 * sc)))
	sb.set_corner_radius_all(int(8 * sc))
	draw_style_box(sb, lastra)
	for rg in righe:
		var w: float = rg["w"]
		var tot: float = rg["items"].size() * (w + gap) - gap
		var x := c.x - tot / 2.0
		for it in rg["items"]:
			match rg["t"]:
				"n":
					draw_texture_rect(_tex(it), Rect2(x, y, w, w * 1.08), false)
					_cliccabile(Rect2(x, y, w, w * 1.08), chiavi[it])
					_numero(Vector2(x + w - 1.0 * sc, y + w * 0.95), gruppi[it], sc)
				"c":
					draw_texture_rect(tex["controllo_" + it], Rect2(x, y, w, w), false)
					_cliccabile(Rect2(x, y, w, w), "c:%s:%s" % [reg, it])
					_numero(Vector2(x + w - 1.0 * sc, y + w - 2.0 * sc), int(d["c"][it]), sc)
				"u":
					var k: String = ["esercito", "flotta", "forte"][it[1]] + "_" + it[0]
					draw_texture_rect(tex[k], Rect2(x, y, w, w), false)
					_cliccabile(Rect2(x, y, w, w), "u:%s:%s:%d" % [reg, it[0], int(it[1])])
					_numero(Vector2(x + w - 1.0 * sc, y + w - 2.0 * sc), int(it[2]), sc)
			x += w + gap
		y += float(rg["h"]) + 4.0 * sc
	# segnalini delle azioni segrete e blocco navale
	for tok in ["pirati", "rivolta"]:
		var st: Dictionary = m.s["segrete"][tok]
		if st.get("reg", "") == reg:
			var rr := Rect2(lastra.end.x + 4.0 * sc, c.y - 26.0 * sc, 34.0 * sc, 50.0 * sc)
			draw_texture_rect(tex[tok], rr, false)
			_cliccabile(rr, "s:%s:%s" % [reg, tok])
			draw_texture_rect(tex["controllo_" + st["pot"]], Rect2(rr.position + Vector2(6, 28) * sc, Vector2(22, 22) * sc), false)
	var bl: Dictionary = m.s["blocco"]
	if bl.get("reg", "") == reg:
		var rb := Rect2(lastra.position.x - 40.0 * sc, c.y - 26.0 * sc, 36.0 * sc, 50.0 * sc)
		draw_texture_rect(tex["blocco"], rb, false)
		draw_texture_rect(tex["controllo_" + bl["pot"]], Rect2(rb.position + Vector2(7, 26) * sc, Vector2(22, 22) * sc), false)

func _disegna_alleanza(la: String, sc: float) -> void:
	var p: String = m.s["locali"].get(la, "")
	var c := a_schermo(Dati.ALLEANZE[la]["pos"])
	var w := 26.0 * sc
	var h := 38.0 * sc
	var rr := Rect2(c - Vector2(w, h) / 2.0, Vector2(w, h))
	draw_texture_rect(tex["la_" + la], rr, false, Color(1, 1, 1, 1.0 if p != "" else 0.55))
	_cliccabile(rr, "la:" + la)
	if p != "":
		draw_texture_rect(tex["controllo_" + p], Rect2(c + Vector2(-11, 4) * sc, Vector2(22, 22) * sc), false)

func _tex(path: String) -> Texture2D:
	if not tex.has(path):
		tex[path] = load(path)
	return tex[path]

func _disco(pos: Vector2, p: String, rr: float) -> void:
	draw_circle(pos, rr + 1.5, Color(0, 0, 0, 0.8))
	draw_circle(pos, rr, Dati.COLORE_POT[p])

func _disegna_tracciati(sc: float) -> void:
	# round e guerra
	var rnd := int(m.s.get("round", 0))
	if rnd >= 1 and rnd <= 6:
		var c := a_schermo(Dati.POS_ROUND[rnd - 1])
		draw_arc(c, 21.0 * sc, 0, TAU, 40, Color(0.7, 0.05, 0.05, 0.95), 4.0 * sc, true)
	var gu := clampi(int(m.s.get("guerra", 1)), 1, 3)
	var cg := a_schermo(Dati.POS_GUERRA[gu - 1])
	draw_arc(cg, 15.0 * sc, 0, TAU, 32, Color(0.7, 0.05, 0.05, 0.95), 4.0 * sc, true)
	# proposta dell'asta in corso
	var a: Dictionary = m.s.get("asta", {})
	if not a.is_empty() and int(a.get("offerta", -1)) >= 0:
		for k in 2:
			var p: String = a["R"] if k == 0 else a["B"]
			if p != "":
				var cp := a_schermo(Dati.POS_PROPOSTA[k])
				draw_texture_rect(tex["controllo_" + p], Rect2(cp - Vector2(19, 19) * sc, Vector2(38, 38) * sc), false)
	# Grandi Alleanze
	for lato in ["R", "B"]:
		var arr: Array = m.s["slot"][lato]
		var pos: Array = Dati.POS_ALLEANZE_R if lato == "R" else Dati.POS_ALLEANZE_B
		for k in mini(arr.size(), pos.size()):
			var cc := a_schermo(pos[k])
			var col := Color(0.75, 0.12, 0.1) if lato == "R" else Color(0.15, 0.3, 0.7)
			draw_circle(cc, 19.0 * sc, col)
			draw_texture_rect(tex["controllo_" + arr[k]], Rect2(cc - Vector2(16, 16) * sc, Vector2(32, 32) * sc), false)
	# popolazione e punti vittoria
	var per_pop := {}
	var per_pv := {}
	for i in m.np():
		var gg := m.g(i)
		var pp: int = gg["pop"]
		per_pop[pp] = per_pop.get(pp, []) + [gg["pot"]]
		var pv := clampi(int(gg["pv"]), 0, 100)
		per_pv[pv] = per_pv.get(pv, []) + [gg["pot"]]
	for v in per_pop:
		var cpop := a_schermo(Dati.pos_popolazione(int(v)))
		var arr2: Array = per_pop[v]
		for k in arr2.size():
			var off := Vector2((k % 4) * 14.0 - 21.0, (k / 4) * 10.0 - 5.0) * sc
			_disco(cpop + off, arr2[k], 7.5 * sc)
	for v in per_pv:
		var cpv := a_schermo(Dati.pos_pv(int(v)))
		var arr3: Array = per_pv[v]
		for k in arr3.size():
			var off2 := Vector2((k % 3) - 1, (k / 3)) * 8.0 * sc
			_disco(cpv + off2, arr3[k], 7.0 * sc)

## La scheda originale di una nazione, con le tessere infilate nelle fasce colorate a sinistra
## (verde: Miglioramento e Commercio, bianca: Azione Gratuita, arancio: Tattiche) e sotto la
## riserva: i pezzi ancora da piazzare, i segnalini Controllo e Alleanza rimasti, l'oro e la Tensione.
class_name SchedaNazione
extends Control

const F_TITOLO := preload("res://assets/font/IMFellSC.ttf")
const F_BASE := preload("res://assets/font/EBGaramond.ttf")
const INK := Color(0.2, 0.13, 0.07)

var m  # Motore
var i_gioc := 0
var pot := ""
var larghezza := 1400.0

# geometria (calcolata in _calcola)
var sx := 0.0          # scala della scheda
var orig := Vector2()  # angolo della scheda
var aree_tessere := []  # [Rect2, testo]
var aree_pezzi := []
var tex_cache := {}

## fasce della scheda (in pixel dell'immagine 2042x942): [y0, y1]
const FASCE := {"mig": [62, 305], "lib": [322, 497], "tat": [515, 865]}
const ZONA_TESSERE := 470.0  # spazio a sinistra della scheda per le file di tessere
const STRISCIA := 150.0  # larghezza (in pixel immagine) della fascia colorata

func imposta(motore, i: int, larg: float) -> void:
	m = motore
	i_gioc = i
	pot = m.g(i)["pot"]
	larghezza = larg
	tooltip_text = " "
	_calcola()
	queue_redraw()

func _tex(path: String) -> Texture2D:
	if not tex_cache.has(path):
		tex_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return tex_cache[path]

func _calcola() -> void:
	var w_scheda := larghezza - ZONA_TESSERE - 10
	sx = w_scheda / 2042.0
	orig = Vector2(ZONA_TESSERE + 4, 4)
	var h_scheda := 942.0 * sx
	custom_minimum_size = Vector2(larghezza, h_scheda + 8 + 190)

func _gruppo(cat: String) -> String:
	if cat == "lib":
		return "lib"
	if cat == "tat":
		return "tat"
	return "mig"

func _draw() -> void:
	if m == null:
		return
	aree_tessere.clear()
	aree_pezzi.clear()
	var h_scheda := 942.0 * sx
	# ombra e scheda
	draw_rect(Rect2(orig + Vector2(6, 6), Vector2(2042 * sx, h_scheda)), Color(0, 0, 0, 0.35))
	var t := _tex("res://assets/schede/%s.jpg" % Dati.STEMMA[pot])
	if t:
		draw_texture_rect(t, Rect2(orig, Vector2(2042 * sx, h_scheda)), false)
	# tessere, raggruppate per fascia
	var gruppi := {"mig": [], "lib": [], "tat": []}
	for x in m.g(i_gioc)["tessere"]:
		var d: Dictionary = Dati.TESSERE[x["t"]]
		gruppi[_gruppo(d["cat"])].append(x)
	for gk in ["mig", "lib", "tat"]:
		var lista: Array = gruppi[gk]
		var y0: float = orig.y + FASCE[gk][0] * sx
		var y1: float = orig.y + FASCE[gk][1] * sx
		var at := minf(y1 - y0 - 6, 150.0)
		var lt := at * 300.0 / 252.0
		# la prima tessera copre la fascia colorata, le altre in fila verso sinistra
		var destra := orig.x + STRISCIA * sx
		var n := lista.size()
		var passo := lt + 8
		if n > 1:
			passo = minf(lt + 8, (destra - 4 - lt) / float(n - 1))
		for k in n:
			var x: Dictionary = lista[k]
			var d: Dictionary = Dati.TESSERE[x["t"]]
			var r := Rect2(Vector2(destra - lt - k * passo, (y0 + y1) / 2.0 - at / 2.0), Vector2(lt, at))
			draw_rect(Rect2(r.position + Vector2(4, 4), r.size), Color(0, 0, 0, 0.4))
			var tt := _tex("res://assets/tessere/%s.jpg" % d["img"])
			if tt:
				draw_texture_rect(tt, r, false, Color(0.62, 0.6, 0.58) if x["usata"] else Color.WHITE)
			draw_rect(r, Color(0.25, 0.16, 0.08), false, 2.0)
			if x["usata"]:
				var s2 := "usata"
				var ls := F_TITOLO.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
				var c := r.get_center()
				draw_rect(Rect2(c - ls / 2 - Vector2(6, 2), ls + Vector2(12, 4)), Color(0.96, 0.9, 0.75, 0.9))
				draw_string(F_TITOLO, Vector2(c.x - ls.x / 2, c.y + 6), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.55, 0.1, 0.06))
			aree_tessere.append([r, "%s\n%s%s" % [d["nome"], d["testo"], "\n(già usata in questa guerra)" if x["usata"] else ""]])
	# riserva sotto la scheda
	var yb := orig.y + h_scheda + 14
	draw_rect(Rect2(Vector2(4, yb), Vector2(larghezza - 8, 170)), Color(0.42, 0.28, 0.16))
	draw_rect(Rect2(Vector2(4, yb), Vector2(larghezza - 8, 170)), Color(0.25, 0.15, 0.07), false, 3.0)
	draw_string(F_TITOLO, Vector2(16, yb + 26), "Riserva", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.98, 0.9, 0.7))
	var gg: Dictionary = m.g(i_gioc)
	var voci := [
		["esercito", m.pezzi_liberi(pot, 0), "Eserciti da costruire", 44.0, "Eserciti"],
		["flotta", m.pezzi_liberi(pot, 1), "Flotte da costruire", 56.0, "Flotte"],
		["forte", m.pezzi_liberi(pot, 2), "Forti da costruire", 52.0, "Forti"],
		["controllo", maxi(0, Dati.MAX_CONTROLLO - m.tot_c_posati(pot)), "Segnalini Controllo rimasti", 50.0, "Controllo"],
		["alleanza", maxi(0, Dati.MAX_ALLEANZE_LOCALI - m.locali_di(pot)), "Segnalini Alleanza Locale rimasti", 58.0, "Alleanze"]]
	var xx := 24.0
	for v in voci:
		var tex := _tex("res://assets/pezzi/%s_%s.png" % [v[0], pot])
		var n: int = v[1]
		var hh: float = v[3]
		var larg_u := 0.0
		if tex:
			larg_u = hh * tex.get_width() / float(tex.get_height())
		var mostra := mini(n, 6)
		var passo_x := larg_u * 0.32
		var largo_tot := larg_u + passo_x * maxf(0, mostra - 1)
		var base_y := yb + 40
		for k in mostra:
			if tex:
				draw_texture_rect(tex, Rect2(Vector2(xx + k * passo_x, base_y + (64 - hh)), Vector2(larg_u, hh)), false)
		if mostra == 0 and tex:
			draw_texture_rect(tex, Rect2(Vector2(xx, base_y + (64 - hh)), Vector2(larg_u, hh)), false, Color(1, 1, 1, 0.25))
			largo_tot = larg_u
		var cella := maxf(largo_tot, 120.0) + 30
		draw_string(F_TITOLO, Vector2(xx, base_y + 98), "%d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.98, 0.9, 0.7))
		draw_string(F_BASE, Vector2(xx + 34, base_y + 96), v[4], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.86, 0.68))
		aree_pezzi.append([Rect2(Vector2(xx, base_y), Vector2(cella, 110)), "%s: %d" % [v[2], n]])
		xx += cella
	# oro: monete da 5 e da 1
	var oro := int(gg["oro"])
	var mon := []
	for k in oro / 5:
		mon.append("oro5")
	for k in oro % 5:
		mon.append("oro1")
	var x0 := xx
	var base := yb + 48
	for k in mon.size():
		var tex := _tex("res://assets/ui/%s.png" % mon[k])
		if tex:
			draw_texture_rect(tex, Rect2(Vector2(xx + (k % 8) * 20, base + (k / 8) * 22), Vector2(48, 48)), false)
	var largo_oro := 48.0 + 20 * mini(maxi(mon.size() - 1, 0), 7)
	draw_string(F_TITOLO, Vector2(x0, yb + 138), "%d" % oro, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.98, 0.9, 0.7))
	draw_string(F_BASE, Vector2(x0 + 34, yb + 136), "Oro", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.86, 0.68))
	aree_pezzi.append([Rect2(Vector2(x0, base), Vector2(largo_oro + 20, 100)), "Oro: %d" % oro])
	xx += maxf(largo_oro, 70.0) + 30
	# Tensione: dischetti neri
	var tens := int(gg["tens"])
	for k in tens:
		var c := Vector2(xx + 22 + (k % 6) * 16, base + 22 + (k / 6) * 18)
		draw_circle(c + Vector2(2, 3), 19, Color(0, 0, 0, 0.4))
		draw_circle(c, 19, Color(0.12, 0.1, 0.09))
		draw_circle(c, 15, Color(0.55, 0.1, 0.06))
	if tens == 0:
		draw_circle(Vector2(xx + 22, base + 22), 19, Color(0.12, 0.1, 0.09, 0.25))
	draw_string(F_TITOLO, Vector2(xx, yb + 138), "%d" % tens, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.98, 0.9, 0.7))
	draw_string(F_BASE, Vector2(xx + 30, yb + 136), "Tensione", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.86, 0.68))
	aree_pezzi.append([Rect2(Vector2(xx, base), Vector2(140, 100)), "Segnalini Tensione: %d" % tens])

func _get_tooltip(at: Vector2) -> String:
	for k in range(aree_tessere.size() - 1, -1, -1):
		if aree_tessere[k][0].has_point(at):
			return aree_tessere[k][1]
	for a in aree_pezzi:
		if a[0].has_point(at):
			return a[1]
	return ""

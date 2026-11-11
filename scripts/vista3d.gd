## Il tabellone in 3D: la plancia Deluxe su un tavolo, con i pezzi estrusi (eserciti, flotte, forti,
## alleanze), i segnalini Controllo e neutrali come counter sottili, tessere sul loro spazio,
## cilindri e cubi per i tracciati.
## Comandi: trascina per spostare, rotella o pizzico per lo zoom, tasto destro (o due dita che
## ruotano) per girare, due dita in su e in giù per inclinare. Un clic su una regione la sceglie.
class_name Vista3D
extends SubViewportContainer

signal regione_cliccata(reg: String)
signal regione_sopra(reg: String)
## clic su un pezzo, una pila, una tessera o un segnalino: chiave come "u:reg:pot:tipo", "c:reg:pot",
## "n:reg:valore", "tessera:id", "la:id", "tok:id"; reg è la regione sotto il punto
signal oggetto_cliccato(chiave: String, reg: String)

const W := 86.0
const H := 86.0 * 998.4 / 1800.0

var m: Motore
var evidenzia: Array = []
## chiavi degli oggetti da illuminare (pezzi, pile, tessere da scegliere)
var evid_oggetti: Array = []
## oggetti cliccabili: [posizione nel mondo, chiave]
var cliccabili: Array = []
var selezionata := ""
var sopra := ""

var vp: SubViewport
var mondo: Node3D
var cam: Camera3D
var pezzi: Node3D
var anelli: Node3D
var font: Font
var tempo := 0.0

# camera in orbita
var bersaglio := Vector3(2.5, 0, 2.5)
var distanza := 84.0
var yaw := 0.0
var pitch := deg_to_rad(60.0)

var _premuto := false
var _ruota := false
var _mosso := 0.0
var _tocchi := {}
var _dist0 := 0.0
var _ang0 := 0.0
var _medio0 := Vector2.ZERO
var _ultima_firma := ""

## posizioni (pixel della plancia 1800 x 998) degli spazi per le navi e delle tessere
const NAVI := {"nordamerica": Vector2(755, 240), "caraibi": Vector2(715, 335), "sudamerica": Vector2(770, 490),
	"africa": Vector2(700, 860), "india": Vector2(1085, 860), "indie": Vector2(1460, 800),
	"baltico": Vector2(1450, 165), "mediterraneo": Vector2(1185, 605)}
## spazi delle tessere sul tabellone: [centro x, centro y, larghezza, altezza]
const SPAZI_TESSERE := {
	"riforma": [193, 595, 49, 79], "ministero": [193, 682, 49, 79], "industria": [251, 682, 49, 79],
	"diplomazia": [193, 768, 49, 79], "reclutamento": [251, 768, 49, 79], "milizia": [408, 768, 69, 79], "blocco": [512, 768, 100, 79],
	"mercenari": [193, 855, 49, 79], "riserve": [251, 855, 49, 79], "logistica": [329, 855, 69, 79], "banca": [408, 855, 69, 79], "sorpresa": [512, 855, 100, 79],
	"milizia_indigena": [193, 941, 49, 79], "agricoltura": [251, 941, 49, 79], "addestr_esercito": [329, 941, 69, 79], "addestr_navale": [408, 941, 69, 79], "ritirata": [512, 941, 100, 79]}
const POS_PIRATI := Vector2(318, 640)
const POS_RIVOLTA := Vector2(318, 691)

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = load("res://assets/font/EBGaramond.ttf")
	vp = SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	vp.handle_input_locally = false
	vp.own_world_3d = true
	add_child(vp)
	mondo = Node3D.new()
	vp.add_child(mondo)
	_costruisci_scena()

func _costruisci_scena() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.08, 0.06, 0.045)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.95, 0.85)
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	mondo.add_child(env)
	var sole := DirectionalLight3D.new()
	sole.rotation_degrees = Vector3(-58, -32, 0)
	sole.light_energy = 0.62
	sole.light_color = Color(1.0, 0.96, 0.88)
	sole.shadow_enabled = true
	sole.shadow_opacity = 0.55
	sole.directional_shadow_max_distance = 140.0
	mondo.add_child(sole)
	# tavolo
	var tavolo := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(260, 200)
	tavolo.mesh = pm
	tavolo.material_override = Pezzi3D.materiale_colore(Color(0.26, 0.16, 0.09), 0.9)
	tavolo.position.y = -0.45
	mondo.add_child(tavolo)
	# spessore della plancia
	var bordo := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(W, 0.42, H)
	bordo.mesh = bm
	bordo.material_override = Pezzi3D.materiale_colore(Color(0.2, 0.15, 0.1), 0.8)
	bordo.position.y = -0.22
	mondo.add_child(bordo)
	var plancia := MeshInstance3D.new()
	var pp := PlaneMesh.new()
	pp.size = Vector2(W, H)
	plancia.mesh = pp
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/mappa/plancia.jpg")
	mat.roughness = 1.0
	mat.metallic_specular = 0.15
	mat.albedo_color = Color(0.92, 0.9, 0.86)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	plancia.material_override = mat
	mondo.add_child(plancia)
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.near = 0.5
	cam.far = 500.0
	mondo.add_child(cam)
	pezzi = Node3D.new()
	mondo.add_child(pezzi)
	anelli = Node3D.new()
	mondo.add_child(anelli)
	_aggiorna_camera()

## torna all'inquadratura di tutta la plancia
func inquadra_tutto() -> void:
	bersaglio = Vector3(2.5, 0, 2.5)
	distanza = 84.0
	yaw = 0.0
	pitch = deg_to_rad(60.0)
	_aggiorna_camera()

func _aggiorna_camera() -> void:
	pitch = clampf(pitch, deg_to_rad(18.0), deg_to_rad(89.0))
	distanza = clampf(distanza, 12.0, 120.0)
	bersaglio.x = clampf(bersaglio.x, -W * 0.6, W * 0.6)
	bersaglio.z = clampf(bersaglio.z, -H * 0.6, H * 0.6)
	var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	cam.position = bersaglio + dir * distanza
	cam.look_at(bersaglio, Vector3.UP)

## pixel della plancia (1800 x 998) -> mondo
static func pp(v: Vector2) -> Vector3:
	return Vector3((v.x / 1800.0 - 0.5) * W, 0, (v.y / 998.4 - 0.5) * H)

## frazioni (come in Dati) -> mondo
static func pf(v: Vector2) -> Vector3:
	return Vector3((v.x - 0.5) * W, 0, (v.y - 0.5) * H)

# ============================================================ input

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if ev.pressed:
					distanza *= 0.9
					_aggiorna_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if ev.pressed:
					distanza /= 0.9
					_aggiorna_camera()
			MOUSE_BUTTON_LEFT:
				if ev.pressed:
					_premuto = true
					_mosso = 0.0
				else:
					_premuto = false
					if _mosso < 8.0 and _tocchi.size() <= 1:
						var r := regione_a(ev.position)
						var ogg := oggetto_a(ev.position)
						if ogg != "":
							oggetto_cliccato.emit(ogg, r)
						elif r != "":
							regione_cliccata.emit(r)
			MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
				_ruota = ev.pressed
		accept_event()
	elif ev is InputEventMouseMotion:
		if _tocchi.size() >= 2:
			return
		if _ruota:
			yaw -= ev.relative.x * 0.006
			pitch += ev.relative.y * 0.005
			_aggiorna_camera()
		elif _premuto:
			_mosso += ev.relative.length()
			_sposta(ev.relative)
		var r2 := regione_a(ev.position)
		if r2 != sopra:
			sopra = r2
			regione_sopra.emit(r2)
	elif ev is InputEventScreenTouch:
		if ev.pressed:
			_tocchi[ev.index] = ev.position
		else:
			_tocchi.erase(ev.index)
		if _tocchi.size() == 2:
			var k: Array = _tocchi.keys()
			var a: Vector2 = _tocchi[k[0]]
			var b: Vector2 = _tocchi[k[1]]
			_dist0 = a.distance_to(b)
			_ang0 = (b - a).angle()
			_medio0 = (a + b) / 2.0
			_mosso = 99.0
		accept_event()
	elif ev is InputEventScreenDrag:
		_tocchi[ev.index] = ev.position
		if _tocchi.size() >= 2:
			var k: Array = _tocchi.keys()
			var a: Vector2 = _tocchi[k[0]]
			var b: Vector2 = _tocchi[k[1]]
			var d := a.distance_to(b)
			var ang := (b - a).angle()
			var medio := (a + b) / 2.0
			if _dist0 > 0:
				distanza *= _dist0 / maxf(d, 1.0)
			yaw -= wrapf(ang - _ang0, -PI, PI)
			pitch += (medio.y - _medio0.y) * 0.004
			_dist0 = d
			_ang0 = ang
			_medio0 = medio
			_aggiorna_camera()
		accept_event()
	elif ev is InputEventMagnifyGesture:
		distanza /= ev.factor
		_aggiorna_camera()
	elif ev is InputEventPanGesture:
		_sposta(-ev.delta * 6.0)

func _sposta(rel: Vector2) -> void:
	var k := distanza * 0.0016
	var destra := Vector3(cos(yaw), 0, -sin(yaw))
	var avanti := Vector3(sin(yaw), 0, cos(yaw))
	bersaglio -= destra * rel.x * k + avanti * rel.y * k
	_aggiorna_camera()

## dal punto dello schermo alla regione più vicina sulla plancia
func regione_a(pos: Vector2) -> String:
	if cam == null:
		return ""
	var sc := Vector2(vp.size) / size if size.x > 0 else Vector2.ONE
	var p := pos * sc
	var o := cam.project_ray_origin(p)
	var dn := cam.project_ray_normal(p)
	if absf(dn.y) < 0.0001:
		return ""
	var t := -o.y / dn.y
	if t < 0:
		return ""
	var hit := o + dn * t
	var px := Vector2((hit.x / W + 0.5) * 1800.0, (hit.z / H + 0.5) * 998.4)
	var best := ""
	var bd := 75.0
	for r in Dati.REGIONI:
		var q: Vector2 = Dati.REGIONI[r]["pos"]
		var d := px.distance_to(Vector2(q.x * 1800.0, q.y * 998.4))
		if d < bd:
			bd = d
			best = r
	return best

## l'oggetto cliccabile più vicino al punto dello schermo (entro 30 pixel)
func oggetto_a(pos: Vector2) -> String:
	if cam == null:
		return ""
	var sc := Vector2(vp.size) / size if size.x > 0 else Vector2.ONE
	var best := ""
	var bd := 30.0
	for x in cliccabili:
		var w: Vector3 = x[0]
		if cam.is_position_behind(w):
			continue
		var p: Vector2 = cam.unproject_position(w) / sc
		var d := p.distance_to(pos)
		if d < bd:
			bd = d
			best = x[1]
	return best

func _cliccabile(pos: Vector3, chiave: String, alto := 0.5) -> void:
	cliccabili.append([pos + Vector3(0, alto, 0), chiave])
	if chiave in evid_oggetti:
		var mi := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.0
		tm.outer_radius = 1.22
		tm.rings = 32
		mi.mesh = tm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.2)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.2)
		mat.emission_energy_multiplier = 1.6
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		mi.position = Vector3(pos.x, 0.08, pos.z)
		anelli.add_child(mi)

# ============================================================ disegno

func _process(delta: float) -> void:
	tempo += delta
	var k := 0
	for a in anelli.get_children():
		var s := 1.0 + 0.08 * sin(tempo * 4.0 + k)
		a.scale = Vector3(s, 1, s)
		k += 1

func aggiorna() -> void:
	if m == null or m.s.is_empty() or pezzi == null:
		return
	var firma := str(m.s["passo"]) + "|" + str(evidenzia) + "|" + selezionata + "|" + str(evid_oggetti)
	if firma == _ultima_firma:
		return
	_ultima_firma = firma
	for c in pezzi.get_children():
		c.queue_free()
	for c in anelli.get_children():
		c.queue_free()
	cliccabili = []
	for reg in Dati.REGIONI:
		_regione(reg)
	_alleanze_locali()
	_tracciati()
	_tessere()
	for reg in evidenzia:
		_anello(reg, Color(1.0, 0.82, 0.25), 3.2)
	if selezionata != "":
		_anello(selezionata, Color(0.8, 0.1, 0.06), 3.6)

func _metti(n: Node3D, pos: Vector3) -> Node3D:
	n.position += pos
	pezzi.add_child(n)
	return n

func _etichetta(testo: String, pos: Vector3, dim := 64) -> void:
	var l := Label3D.new()
	l.text = testo
	l.font = font
	l.font_size = dim
	l.pixel_size = 0.012
	l.outline_size = 14
	l.modulate = Color(1, 0.96, 0.85)
	l.outline_modulate = Color(0.1, 0.06, 0.03)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	pezzi.add_child(l)

func _pila_counter(nome: String, n: int, pos: Vector3, larg: float, immagine := "") -> void:
	var sp := 0.22
	for k in mini(n, 12):
		var p := Pezzi3D.pezzo(nome, larg, sp, true, immagine)
		p.position.y += k * sp
		_metti(p, pos)
	if n > 1:
		_etichetta(str(n), pos + Vector3(0, mini(n, 12) * sp + 0.9, 0))

func _regione(reg: String) -> void:
	var d: Dictionary = m.s["reg"][reg]
	var c := pf(Dati.REGIONI[reg]["pos"])
	# segnalini neutrali: pile per tipo, in alto
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
	var passo := 1.55
	var x0 := -passo * (ordine.size() - 1) / 2.0
	for i in ordine.size():
		var pn := c + Vector3(x0 + i * passo, 0, -1.7)
		_pila_counter("neutro", gruppi[ordine[i]], pn, 1.35, ordine[i])
		_cliccabile(pn, chiavi[ordine[i]], 0.3 + 0.22 * gruppi[ordine[i]])
	# segnalini Controllo: pile per potenza, al centro
	var ctrl: Array = d["c"].keys()
	ctrl.sort_custom(func(a, b): return int(d["c"][a]) > int(d["c"][b]))
	x0 = -1.6 * (ctrl.size() - 1) / 2.0
	for i in ctrl.size():
		var pc := c + Vector3(x0 + i * 1.6, 0, 0)
		_pila_counter("controllo_" + ctrl[i], int(d["c"][ctrl[i]]), pc, 1.35)
		_cliccabile(pc, "c:%s:%s" % [reg, ctrl[i]], 0.3 + 0.22 * int(d["c"][ctrl[i]]))
	# unità: in piedi, davanti
	var navi_altrove := NAVI.has(reg)
	var gruppi_u: Array = []
	for p in d["u"]:
		for t in 3:
			var n: int = int(d["u"][p][t])
			if n <= 0:
				continue
			if t == Motore.U_F and navi_altrove:
				continue
			gruppi_u.append([p, t, n])
	_fila_unita(gruppi_u, c + Vector3(0, 0, 2.0), reg)
	if navi_altrove:
		var flotte: Array = []
		for p in d["u"]:
			var n2: int = int(d["u"][p][Motore.U_F])
			if n2 > 0:
				flotte.append([p, Motore.U_F, n2])
		_fila_unita(flotte, pp(NAVI[reg]) + Vector3(0, 0, 0.4), reg)
	# azioni segrete e blocco
	for tok in ["pirati", "rivolta"]:
		var st: Dictionary = m.s["segrete"][tok]
		if st.get("reg", "") == reg:
			var pos := c + Vector3(3.2, 0, -0.4)
			_metti(Pezzi3D.pezzo(tok, 1.8, 0.22, true), pos)
			_cliccabile(pos, "s:%s:%s" % [reg, tok], 0.5)
			_metti(Pezzi3D.pezzo("controllo_" + st["pot"], 1.0, 0.22, true), pos + Vector3(0, 0.24, 0))
	var bl: Dictionary = m.s["blocco"]
	if bl.get("reg", "") == reg:
		var t := Pezzi3D.tessera("res://assets/tessere/blocco.jpg", 2.0, 2.9)
		_metti(t, c + Vector3(-3.4, 0, -0.4))
		_metti(Pezzi3D.pezzo("controllo_" + bl["pot"], 1.0, 0.22, true), c + Vector3(-3.4, 0.14, -0.4))

## dispone in fila le unità (gruppi [pot, tipo, quante]); oltre 4 dello stesso tipo mostra il numero
func _fila_unita(gruppi_u: Array, centro: Vector3, reg: String) -> void:
	if gruppi_u.is_empty():
		return
	var larghezze := {Motore.U_E: 0.95, Motore.U_F: 1.7, Motore.U_FO: 1.25}
	var blocchi: Array = []
	var tot := 0.0
	for gr in gruppi_u:
		var t: int = gr[1]
		var vis := mini(int(gr[2]), 4)
		var w: float = larghezze[t]
		var sp := w * 0.62 if t == Motore.U_E else w * 0.75
		var lung := w + sp * (vis - 1)
		blocchi.append([gr, vis, w, sp, lung])
		tot += lung + 0.45
	var x := -tot / 2.0
	for b in blocchi:
		var gr: Array = b[0]
		var nome: String = ["esercito", "flotta", "forte"][gr[1]] + "_" + gr[0]
		var w2: float = b[2]
		for k in int(b[1]):
			var p := Pezzi3D.pezzo(nome, w2, 0.5)
			var dz := 0.32 if k % 2 == 1 else 0.0
			_metti(p, centro + Vector3(x + w2 / 2.0 + k * float(b[3]), 0, dz))
		if int(gr[2]) > int(b[1]):
			_etichetta(str(gr[2]), centro + Vector3(x + float(b[4]) / 2.0, 2.6, 0))
		_cliccabile(centro + Vector3(x + float(b[4]) / 2.0, 0, 0.15), "u:%s:%s:%d" % [reg, gr[0], int(gr[1])], 1.0)
		x += float(b[4]) + 0.45

func _alleanze_locali() -> void:
	for la in Dati.ALLEANZE:
		_cliccabile(pf(Dati.ALLEANZE[la]["pos"]), "la:" + la, 0.4)
		var p: String = m.s["locali"].get(la, "")
		if p != "":
			var pz := Pezzi3D.pezzo("alleanza_" + p, 1.6, 0.5)
			_metti(pz, pf(Dati.ALLEANZE[la]["pos"]) + Vector3(0, 0, 0.3))

func _tracciati() -> void:
	# round: cilindro di legno
	var rnd := int(m.s.get("round", 0))
	if rnd >= 1 and rnd <= 6:
		_metti(Pezzi3D.cilindro(0.75, 0.9, Color(0.82, 0.68, 0.45)), pf(Dati.POS_ROUND[rnd - 1]))
	# guerra: cubo rosso
	var gu := clampi(int(m.s.get("guerra", 1)), 1, 3)
	_metti(Pezzi3D.cubo(0.9, Color(0.7, 0.08, 0.06)), pf(Dati.POS_GUERRA[gu - 1]))
	# proposta dell'asta
	var a: Dictionary = m.s.get("asta", {})
	if not a.is_empty() and int(a.get("offerta", -1)) >= 0:
		for k in 2:
			var p: String = a["R"] if k == 0 else a["B"]
			if p != "":
				_metti(Pezzi3D.cilindro(0.75, 0.55, Dati.COLORE_POT[p]), pf(Dati.POS_PROPOSTA[k]))
	# Grandi Alleanze: cilindri bassi nel colore della potenza
	var corrente := m.corrente() if m.s["stadio"] in ["turno", "combattimento"] else -1
	for lato in ["R", "B"]:
		var arr: Array = m.s["slot"][lato]
		var pos: Array = Dati.POS_ALLEANZE_R if lato == "R" else Dati.POS_ALLEANZE_B
		for k in mini(arr.size(), pos.size()):
			_metti(Pezzi3D.cilindro(0.75, 0.55, Dati.COLORE_POT[arr[k]]), pf(pos[k]))
			if corrente >= 0 and m.pot(corrente) == arr[k]:
				# la rosa dei venti segna il giocatore attivo
				_metti(Pezzi3D.pezzo("rosa", 1.5, 0.2, true), pf(pos[k]) + Vector3(0, 0.56, 0))
	# popolazione: cubetti; punti vittoria: meeple
	var per_pop := {}
	var per_pv := {}
	for i in m.np():
		var gg := m.g(i)
		per_pop[int(gg["pop"])] = per_pop.get(int(gg["pop"]), []) + [gg["pot"]]
		var pv := clampi(int(gg["pv"]), 0, 100)
		per_pv[pv] = per_pv.get(pv, []) + [gg["pot"]]
	for v in per_pop:
		var arr2: Array = per_pop[v]
		for k in arr2.size():
			_metti(Pezzi3D.cubo(0.6, Dati.COLORE_POT[arr2[k]]), pf(Dati.pos_popolazione(int(v))) + Vector3(-1.2 + k * 0.8, 0, 0))
	for v in per_pv:
		var arr3: Array = per_pv[v]
		for k in arr3.size():
			var mp := Pezzi3D.pezzo("meeple_" + arr3[k], 0.95, 0.45)
			_metti(mp, pf(Dati.pos_pv(int(v))) + Vector3(-0.35 + (k % 3) * 0.35, 0, -0.3 + k * 0.22))

func _tessere() -> void:
	var banco: Dictionary = m.s["banco"]
	for t in SPAZI_TESSERE:
		var n := int(banco.get(t, 0))
		if n <= 0:
			continue
		var sz: Array = SPAZI_TESSERE[t]
		var centro := pp(Vector2(sz[0], sz[1]))
		var w: float = float(sz[2]) / 1800.0 * W * 0.92
		var h: float = float(sz[3]) / 998.4 * H * 0.92
		var img := "res://assets/tessere/%s.jpg" % Dati.TESSERE[t]["img"]
		var tex: Texture2D = load(img)
		var ruota := tex.get_width() > tex.get_height()
		for k in mini(n, 8):
			var ts := Pezzi3D.tessera(img, h if ruota else w, w if ruota else h, 0.12)
			if ruota:
				ts.rotation.y = PI / 2.0
			ts.position.y = k * 0.12
			_metti(ts, centro)
		_cliccabile(centro, "tessera:" + t, mini(n, 8) * 0.12 + 0.2)
		if n > 1:
			_etichetta(str(n), centro + Vector3(0, mini(n, 8) * 0.12 + 0.7, 0), 56)
	# compagnie commerciali: sul tavolo a destra della plancia
	var k2 := 0
	for t in Dati.ORDINE_TESSERE:
		if Dati.TESSERE[t]["cat"] != "com":
			continue
		var n2 := int(banco.get(t, 0))
		var pos := Vector3(W / 2.0 + 4.0, -0.42, -H / 2.0 + 4.0 + k2 * 6.2)
		k2 += 1
		for k in n2:
			var ts2 := Pezzi3D.tessera("res://assets/tessere/%s.jpg" % Dati.TESSERE[t]["img"], 5.4, 3.9, 0.12)
			ts2.position.y = k * 0.12
			_metti(ts2, pos)
		if n2 > 0:
			_cliccabile(pos, "tessera:" + t, n2 * 0.12 + 0.2)
		if n2 > 1:
			_etichetta(str(n2), pos + Vector3(0, n2 * 0.12 + 0.7, 0), 56)
	# segnalini delle azioni segrete ancora disponibili
	for tok in ["pirati", "rivolta"]:
		if m.s["segrete"][tok].is_empty():
			_metti(Pezzi3D.pezzo(tok, 1.9, 0.22, true), pp(POS_PIRATI if tok == "pirati" else POS_RIVOLTA))
			_cliccabile(pp(POS_PIRATI if tok == "pirati" else POS_RIVOLTA), "tok:" + tok, 0.4)

func _anello(reg: String, col: Color, r: float) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.18
	tm.outer_radius = r
	tm.rings = 48
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.4
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = pf(Dati.REGIONI[reg]["pos"]) + Vector3(0, 0.12, 0.3)
	anelli.add_child(mi)

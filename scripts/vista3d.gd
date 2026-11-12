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
var dadi: Dadi3D
var scena_battaglia: Node3D
var riquadro: PanelContainer
var testo_riquadro: RichTextLabel
var bottone_riquadro: Button
signal continua_premuto
var velocita := 1.0

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
	riquadro = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.96, 0.91, 0.78, 0.96)
	sb.border_color = Color(0.55, 0.1, 0.06)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	riquadro.add_theme_stylebox_override("panel", sb)
	riquadro.anchor_left = 1.0
	riquadro.anchor_right = 1.0
	riquadro.offset_right = -14
	riquadro.offset_left = -14
	riquadro.offset_top = 14
	riquadro.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	riquadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riquadro.visible = false
	add_child(riquadro)
	testo_riquadro = RichTextLabel.new()
	testo_riquadro.bbcode_enabled = true
	testo_riquadro.fit_content = true
	testo_riquadro.custom_minimum_size = Vector2(500, 0)
	testo_riquadro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	testo_riquadro.add_theme_font_override("normal_font", font)
	testo_riquadro.add_theme_font_size_override("normal_font_size", 19)
	testo_riquadro.add_theme_font_override("bold_font", load("res://assets/font/IMFellSC.ttf"))
	testo_riquadro.add_theme_font_size_override("bold_font_size", 26)
	testo_riquadro.add_theme_color_override("default_color", Color(0.2, 0.13, 0.07))
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	riquadro.add_child(vb)
	vb.add_child(testo_riquadro)
	bottone_riquadro = Button.new()
	bottone_riquadro.text = "Continua"
	bottone_riquadro.add_theme_font_override("font", font)
	bottone_riquadro.add_theme_font_size_override("font_size", 22)
	bottone_riquadro.custom_minimum_size = Vector2(220, 44)
	bottone_riquadro.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bottone_riquadro.visible = false
	bottone_riquadro.pressed.connect(func(): continua_premuto.emit())
	vb.add_child(bottone_riquadro)

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
	scena_battaglia = Node3D.new()
	mondo.add_child(scena_battaglia)
	dadi = Dadi3D.new()
	mondo.add_child(dadi)
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
	var dentro := Dati.regione_in(Vector2(hit.x / W + 0.5, hit.z / H + 0.5))
	if dentro != "":
		return dentro
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

func _cliccabile(pos: Vector3, chiave: String, alto := 0.5, rett := Vector2.ZERO) -> void:
	cliccabili.append([pos + Vector3(0, alto, 0), chiave])
	if chiave in evid_oggetti and rett != Vector2.ZERO:
		_cornice(Vector3(pos.x, pos.y + alto - 0.12, pos.z), rett + Vector2(0.3, 0.3), Color(1.0, 0.82, 0.2))
		return
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
		if reg != selezionata:
			_contorno(reg, Color(1.0, 0.82, 0.25), 0.32, 0.16)
	if selezionata != "":
		_contorno(selezionata, Color(0.9, 0.12, 0.06), 0.42, 0.22)

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
			# a faccia in su sullo spazio dell'alleanza
			var pz := Pezzi3D.pezzo("alleanza_" + p, 1.7, 0.4, true)
			_metti(pz, pf(Dati.ALLEANZE[la]["pos"]))

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
	# popolazione: meeple della potenza sul tracciato della popolazione
	for v in per_pop:
		var arr2: Array = per_pop[v]
		for k in arr2.size():
			var mp := Pezzi3D.pezzo("meeple_" + arr2[k], 0.8, 0.45)
			_metti(mp, pf(Dati.pos_popolazione(int(v))) + Vector3(-1.5 + (k % 4) * 0.75, 0, -0.25 + (k / 4) * 0.6))
	# punti vittoria: segnalini esagonali con lo stemma della potenza
	for v in per_pv:
		var arr3: Array = per_pv[v]
		for k in arr3.size():
			var hx := _esagono(arr3[k])
			hx.position.y = k * 0.24
			_metti(hx, pf(Dati.pos_pv(int(v))))
		if arr3.size() > 1:
			_etichetta(str(arr3.size()), pf(Dati.pos_pv(int(v))) + Vector3(0, arr3.size() * 0.24 + 0.8, 0), 48)

## segnalino esagonale dei punti vittoria: prisma a 6 lati nel colore della potenza con lo stemma sopra
func _esagono(p: String) -> Node3D:
	var n := Node3D.new()
	var base := Pezzi3D.cilindro(0.82, 0.22, Dati.COLORE_POT[p])
	(base.mesh as CylinderMesh).radial_segments = 6
	base.rotation.y = PI / 6.0
	n.add_child(base)
	var top := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.95, 1.15)
	top.mesh = pm
	var mat: StandardMaterial3D = Pezzi3D.materiale_immagine("res://assets/stemmi/%s.png" % Dati.STEMMA[p])
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	top.material_override = mat
	top.position.y = 0.225
	n.add_child(top)
	return n

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
		_cliccabile(centro, "tessera:" + t, mini(n, 8) * 0.12 + 0.2, Vector2(w, h))
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
			_cliccabile(pos, "tessera:" + t, n2 * 0.12 + 0.2, Vector2(5.4, 3.9))
		if n2 > 1:
			_etichetta(str(n2), pos + Vector3(0, n2 * 0.12 + 0.7, 0), 56)
	# segnalini delle azioni segrete ancora disponibili
	for tok in ["pirati", "rivolta"]:
		if m.s["segrete"][tok].is_empty():
			_metti(Pezzi3D.pezzo(tok, 1.9, 0.22, true), pp(POS_PIRATI if tok == "pirati" else POS_RIVOLTA))
			_cliccabile(pp(POS_PIRATI if tok == "pirati" else POS_RIVOLTA), "tok:" + tok, 0.4)

## cornice luminosa attorno a una tessera (rett: larghezza in x e profondità in z)
func _cornice(c: Vector3, rett: Vector2, col: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hx := rett.x / 2.0
	var hz := rett.y / 2.0
	var l := 0.22
	var pezzi_c := [[Vector2(-hx - l, -hz - l), Vector2(hx + l, -hz)], [Vector2(-hx - l, hz), Vector2(hx + l, hz + l)],
		[Vector2(-hx - l, -hz), Vector2(-hx, hz)], [Vector2(hx, -hz), Vector2(hx + l, hz)]]
	for r in pezzi_c:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var v := [Vector3(a.x, 0, a.y), Vector3(b.x, 0, a.y), Vector3(b.x, 0, b.y), Vector3(a.x, 0, b.y)]
		for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
			st.add_vertex(v[idx] + c)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	anelli.add_child(mi)

## evidenzia una regione seguendo il suo confine vero: un nastro luminoso e un velo di colore sopra la terra
func _contorno(reg: String, col: Color, largo: float, velo: float) -> void:
	var polys: Array = Dati.confini(reg)
	if polys.is_empty():
		_anello(reg, col, 3.2)
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fill := SurfaceTool.new()
	fill.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ha_fill := false
	var y := 0.07
	for poly in polys:
		var pts: Array = []
		for q in poly:
			var w3 := pf(q)
			pts.append(Vector2(w3.x, w3.z))
		var n := pts.size()
		for i in n:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % n]
			var d := b - a
			if d.length() < 0.0001:
				continue
			var nn := Vector2(-d.y, d.x).normalized() * largo * 0.5
			var ext := d.normalized() * largo * 0.5
			var a1 := a - ext
			var b1 := b + ext
			var v := [Vector3(a1.x + nn.x, y, a1.y + nn.y), Vector3(b1.x + nn.x, y, b1.y + nn.y),
				Vector3(b1.x - nn.x, y, b1.y - nn.y), Vector3(a1.x - nn.x, y, a1.y - nn.y)]
			for idx in [0, 1, 2, 0, 2, 3, 0, 2, 1, 0, 3, 2]:
				st.add_vertex(v[idx])
		var tri := Geometry2D.triangulate_polygon(PackedVector2Array(pts))
		for t in tri:
			var p2: Vector2 = pts[t]
			fill.add_vertex(Vector3(p2.x, y - 0.01, p2.y))
			ha_fill = true
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	anelli.add_child(mi)
	if ha_fill:
		var mf := StandardMaterial3D.new()
		mf.albedo_color = Color(col.r, col.g, col.b, velo)
		mf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mf.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mf.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi2 := MeshInstance3D.new()
		mi2.mesh = fill.commit()
		mi2.material_override = mf
		anelli.add_child(mi2)

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


# ============================================================ battaglie e dadi sulla mappa

func _attendi(sec: float) -> void:
	await get_tree().create_timer(sec / maxf(velocita, 0.5)).timeout

func _vola_camera(dest: Vector3, dist: float, pit: float, yw: float, sec := 0.7) -> void:
	var b0 := bersaglio
	var d0 := distanza
	var p0 := pitch
	var y0 := yaw
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var e := t * t * (3.0 - 2.0 * t)
		bersaglio = b0.lerp(dest, e)
		distanza = lerpf(d0, dist, e)
		pitch = lerpf(p0, pit, e)
		yaw = lerp_angle(y0, yw, e)
		_aggiorna_camera(), 0.0, 1.0, sec)
	await tw.finished

func _scritta(testo: String, pos: Vector3, col: Color, dim := 46) -> Label3D:
	var l := Label3D.new()
	l.text = testo
	l.font = font
	l.font_size = dim
	l.pixel_size = 0.02
	l.outline_size = 22
	l.modulate = col
	l.outline_modulate = Color(0.08, 0.05, 0.03)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = pos
	scena_battaglia.add_child(l)
	return l

func _anello_a(pos: Vector3, col: Color, r := 1.3) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.2
	tm.outer_radius = r
	mi.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	mi.position = Vector3(pos.x, 0.1, pos.z)
	scena_battaglia.add_child(mi)

func _pos_chiave(chiave: String) -> Variant:
	for x in cliccabili:
		if x[1] == chiave:
			return x[0]
	return null

func _pulisci_battaglia() -> void:
	for c in scena_battaglia.get_children():
		c.queue_free()
	dadi.pulisci()

## mostra un combattimento concluso: forze in campo, dadi che rotolano, esito
func mostra_battaglia(cb: Dictionary, continua := false) -> void:
	var reg: String = cb.get("reg", "")
	if reg == "" or not Dati.REGIONI.has(reg):
		return
	var cam0 := [bersaglio, distanza, pitch, yaw]
	var rossa := Color(1.0, 0.3, 0.22)
	var blu := Color(0.3, 0.55, 1.0)
	for riga in cb.get("rapporto", []):
		_pulisci_battaglia()
		var navale: bool = riga["dom"] == "n"
		var mare := Dati.mare_di(reg)
		var centro := pf(Dati.REGIONI[reg]["pos"])
		if navale and NAVI.has(mare):
			centro = pp(NAVI[mare])
		await _vola_camera(centro + Vector3(5.5, 0, 3.0), 29.0, deg_to_rad(55.0), 0.0)
		# unità coinvolte: anelli rossi (attaccante) e blu (difensore)
		var reg_u := mare if navale else reg
		var comp: Dictionary = riga.get("comp", {})
		for lato in ["a", "d"]:
			var c: Dictionary = comp.get(lato, {})
			for un in c.get("unita", []):
				var pos = _pos_chiave("u:%s:%s:%d" % [reg_u, un[0], int(un[1])])
				if pos != null:
					_anello_a(pos, rossa if lato == "a" else blu, 1.5)
		var intest := "[b]%s - %s[/b]\n%s\n" % ["Battaglia navale" if navale else "Battaglia terrestre", Dati.REGIONI[reg]["nome"], str(cb.get("titolo", ""))]
		var forze := "[color=#9e1a10]ATTACCANTE[/color]\n" + "\n".join(comp.get("a", {}).get("parti", [])) + "\n[color=#9e1a10]Forza %d[/color]\n\n" % int(riga["fa"])
		forze += "[color=#1f3f8c]DIFENSORE[/color]\n" + "\n".join(comp.get("d", {}).get("parti", [])) + "\n[color=#1f3f8c]Forza %d[/color]" % int(riga["fd"])
		testo_riquadro.text = intest + forze
		riquadro.visible = true
		riquadro.reset_size()
		await _attendi(1.3)
		# i dadi: rossi per l'attaccante a sinistra, bianchi per il difensore a destra
		var base := centro + Vector3(0, 0, 4.2)
		var specs := [
			{"tipo": "rosso", "valore": int(riga["a"][0]), "da": base + Vector3(-6, 5, 5), "a": base + Vector3(-3.0, 0, 0)},
			{"tipo": "rosso", "valore": int(riga["a"][1]), "da": base + Vector3(-5, 5.5, 6), "a": base + Vector3(-1.4, 0, 0.6)},
			{"tipo": "bianco", "valore": int(riga["d"][0]), "da": base + Vector3(6, 5, 5), "a": base + Vector3(1.4, 0, 0)},
			{"tipo": "bianco", "valore": int(riga["d"][1]), "da": base + Vector3(5, 5.5, 6), "a": base + Vector3(3.0, 0, 0.6)}]
		dadi.lancia(specs)
		await dadi.finito
		var da1: int = int(riga["a"][0])
		var da2: int = int(riga["a"][1])
		var dd1: int = int(riga["d"][0])
		var dd2: int = int(riga["d"][1])
		_scritta(str(int(riga["ta"])), base + Vector3(-2.2, 2.2, 0.3), rossa, 90)
		_scritta(str(int(riga["td"])), base + Vector3(2.2, 2.2, 0.3), blu, 90)
		var esito := "Vince l'attaccante" if riga["vince"] == "a" else ("Vince il difensore" if riga["vince"] == "d" else "Pareggio: perdono tutti e due")
		var tot := "\n\n[color=#9e1a10]Attaccante: %d + differenza dei dadi %d = %d%s[/color]" % [int(riga["fa"]), absi(da1 - da2), int(riga["ta"]), " (ha tirato 7: un'unità in più persa)" if da1 + da2 == 7 else ""]
		tot += "\n[color=#1f3f8c]Difensore: %d + differenza dei dadi %d = %d%s[/color]" % [int(riga["fd"]), absi(dd1 - dd2), int(riga["td"]), " (ha tirato 7: un'unità in più persa)" if dd1 + dd2 == 7 else ""]
		tot += "\n[b]%s[/b]" % esito
		var perdite: Array = []
		for pz in riga.get("perdite", []):
			perdite.append("%s: %s" % [Dati.NOME_POT.get(pz[0], str(pz[0])), str(Motore.NOMI_U[int(pz[1])]).to_lower()])
		tot += "\nPerdite: " + (", ".join(perdite) if not perdite.is_empty() else "nessuna") + "."
		var ultima: bool = riga == cb["rapporto"][cb["rapporto"].size() - 1]
		if ultima and str(cb.get("esito", "")) != "":
			tot += "\n\n[b]%s[/b]" % str(cb["esito"])
		testo_riquadro.text = intest + forze + tot
		riquadro.reset_size()
		if ultima and continua:
			bottone_riquadro.visible = true
			riquadro.reset_size()
			await continua_premuto
			bottone_riquadro.visible = false
		else:
			await _attendi(3.2 if ultima else 2.4)
	_pulisci_battaglia()
	riquadro.visible = false
	await _vola_camera(cam0[0], cam0[1], cam0[2], cam0[3], 0.6)

## il dado del Viaggio in mare aperto
func mostra_viaggio(ev: Dictionary) -> void:
	var da: String = ev.get("da", "")
	if not Dati.REGIONI.has(da):
		return
	_pulisci_battaglia()
	var centro := pf(Dati.REGIONI[da]["pos"]) + Vector3(0, 0, 4.0)
	dadi.lancia([{"tipo": "viaggio", "valore": str(ev.get("esito", "ok")), "da": centro + Vector3(-6, 6, 5), "a": centro}])
	await dadi.finito
	var testo: String = {"ok": "VIAGGIO RIUSCITO", "fermo": "FERMO IN PORTO", "affonda": "TEMPESTA!"}.get(str(ev.get("esito", "ok")), "")
	_scritta("Mare aperto: " + testo, centro + Vector3(0, 3.5, 0), Color(1, 0.92, 0.7), 64)
	await _attendi(1.4)
	_pulisci_battaglia()

## Dadi 3D che rotolano davvero sul tabellone.
## Il risultato lo decide il motore di gioco: qui si simula prima il lancio (gravità, rimbalzi e
## attrito su un piano), si guarda quale faccia finisce in alto e si stampano i valori sulle facce
## in modo che in alto esca proprio il numero giusto. Poi si riproduce il lancio.
class_name Dadi3D
extends Node3D

signal finito

const LATO := 1.25
const G := 700.0
const DT := 1.0 / 120.0
## i dadi veri sono piccoli e pesanti: si riproduce il lancio un po' rallentato perché si veda rotolare
const RALLENTA := 0.55

## facce del cubo nell'ordine delle superfici: +X, -X, +Y, -Y, +Z, -Z
const ASSI := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]

static var _tex := {}
static var _mesh: ArrayMesh

var _dadi: Array = []      # [MeshInstance3D, frames]
var _frame := 0.0
var _attivo := false

static func mesh_cubo() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var h := LATO / 2.0
	_mesh = ArrayMesh.new()
	for k in 6:
		var n: Vector3 = ASSI[k]
		# due assi del piano della faccia
		var u := Vector3.UP if absf(n.y) < 0.5 else Vector3.BACK
		var a := n.cross(u).normalized()
		var b := n.cross(a).normalized()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var v := [n * h - a * h - b * h, n * h + a * h - b * h, n * h + a * h + b * h, n * h - a * h + b * h]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var ordine := [0, 1, 2, 0, 2, 3]
		if (v[1] - v[0]).cross(v[2] - v[0]).dot(n) > 0:
			ordine = [0, 2, 1, 0, 3, 2]
		for o in ordine:
			st.set_normal(n)
			st.set_uv(uv[o])
			st.add_vertex(v[o])
		st.commit(_mesh)
	return _mesh

## faccia con i punti (disegnati, niente font)
static func tex_punti(valore: int, fondo: Color, punto: Color) -> Texture2D:
	var key := "%d%s%s" % [valore, fondo.to_html(), punto.to_html()]
	if _tex.has(key):
		return _tex[key]
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(fondo)
	# bordo un po' più scuro
	for i in s:
		for t in 4:
			var c := fondo.darkened(0.25)
			img.set_pixel(i, t, c)
			img.set_pixel(i, s - 1 - t, c)
			img.set_pixel(t, i, c)
			img.set_pixel(s - 1 - t, i, c)
	var pos := {1: [Vector2(0.5, 0.5)], 2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
		3: [Vector2(0.25, 0.25), Vector2(0.5, 0.5), Vector2(0.75, 0.75)],
		4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
		5: [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5, 0.5), Vector2(0.25, 0.75), Vector2(0.75, 0.75)],
		6: [Vector2(0.27, 0.22), Vector2(0.73, 0.22), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.78), Vector2(0.73, 0.78)]}
	var r := s * 0.09
	for p in pos[clampi(valore, 1, 6)]:
		var c: Vector2 = p * s
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			for y in range(int(c.y - r - 1), int(c.y + r + 2)):
				var d: float = Vector2(x, y).distance_to(c)
				if d <= r:
					img.set_pixel(x, y, punto)
				elif d <= r + 1.0:
					img.set_pixel(x, y, punto.lerp(fondo, d - r))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t

static func materiale(tex: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = 0.35
	m.metallic_specular = 0.6
	return m

## simula un lancio: restituisce i fotogrammi [posizione, quaternione] a 60 al secondo
static func simula(x: Vector3, v: Vector3, w: Vector3, q: Quaternion) -> Array:
	var h := LATO / 2.0
	var inv_m := 1.0
	var inv_i := 6.0 / (LATO * LATO)
	var mu := 0.55
	var angoli: Array = []
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			for sz in [-1, 1]:
				angoli.append(Vector3(sx, sy, sz) * h)
	var frames: Array = []
	var fermo := 0
	var n := Vector3.UP
	for step in 1200:
		v.y -= G * DT
		# contatti: spigoli sotto (o quasi) il piano
		var contatti: Array = []
		for c in angoli:
			var r: Vector3 = q * c
			var p := x + r
			if p.y < 0.02:
				var vn0 := (v + w.cross(r)).y
				contatti.append({"r": r, "pen": -p.y, "pn": 0.0, "pt": Vector3.ZERO,
					"bounce": -0.38 * (vn0 + G * DT) if vn0 + G * DT < -3.0 else 0.0})
		# impulsi sequenziali, più passate per distribuire il peso su tutti gli spigoli
		for it in 12:
			for ct in contatti:
				var r: Vector3 = ct["r"]
				var vp := v + w.cross(r)
				var rn := r.cross(n)
				var k_n := inv_m + inv_i * rn.length_squared()
				var bias := maxf(0.0, float(ct["pen"]) - 0.005) * 0.25 / DT
				var dpn: float = (-vp.y + float(ct["bounce"]) + bias) / k_n
				var pn0: float = ct["pn"]
				var pn := maxf(pn0 + dpn, 0.0)
				dpn = pn - pn0
				ct["pn"] = pn
				v += n * dpn * inv_m
				w += r.cross(n * dpn) * inv_i
				# attrito (cono di Coulomb sul piano)
				vp = v + w.cross(r)
				var vt := Vector3(vp.x, 0, vp.z)
				if vt.length() > 0.00001:
					var t := vt.normalized()
					var k_t := inv_m + inv_i * r.cross(t).length_squared()
					var pt_nuovo: Vector3 = ct["pt"] - t * (vt.length() / k_t)
					var lim: float = mu * pn
					if pt_nuovo.length() > lim:
						pt_nuovo = pt_nuovo.normalized() * lim
					var dpt: Vector3 = pt_nuovo - ct["pt"]
					ct["pt"] = pt_nuovo
					v += dpt * inv_m
					w += r.cross(dpt) * inv_i
		x += v * DT
		if w.length() > 0.00001:
			q = (Quaternion(w.normalized(), w.length() * DT) * q).normalized()
		if contatti.size() > 0:
			# resistenza al rotolamento e allo spin quando tocca il tavolo
			w *= 0.985
			v.x *= 0.995
			v.z *= 0.995
		if step % 2 == 0:
			frames.append([x, q])
		if contatti.size() >= 3 and v.length() < 0.4 and w.length() < 0.6:
			fermo += 1
			if fermo > 16:
				break
		else:
			fermo = 0
	# assestamento finale: la faccia più in alto diventa esattamente orizzontale
	var su := _faccia_su(q)
	var q_fine: Quaternion = Quaternion(q * ASSI[su], Vector3.UP) * q
	var x_fine := Vector3(x.x, h, x.z)
	for k in 6:
		var t2 := (k + 1) / 6.0
		frames.append([x.lerp(x_fine, t2), q.slerp(q_fine, t2)])
	return frames

static func _faccia_su(q: Quaternion) -> int:
	var best := 0
	var by := -2.0
	for k in 6:
		var y: float = (q * ASSI[k]).y
		if y > by:
			by = y
			best = k
	return best

## lancia i dadi. specs: [{"tipo": "rosso"|"bianco"|"viaggio", "valore": 1..6 oppure "ok"/"fermo"/"affonda", "da": Vector3, "a": Vector3}]
func lancia(specs: Array) -> void:
	pulisci()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for sp in specs:
		var da: Vector3 = sp["da"]
		var a: Vector3 = sp["a"]
		var dir := Vector3(a.x - da.x, 0, a.z - da.z)
		var vel := 24.0 + rng.randf_range(-3, 4)
		var v := dir.normalized() * vel + Vector3(0, rng.randf_range(2.0, 5.0), 0)
		# il dado esce di mano già ruotando in avanti (rotolamento) con un po' di disordine
		var asse := Vector3.UP.cross(dir.normalized())
		var w := asse * rng.randf_range(16, 26) + Vector3(rng.randf_range(-6, 6), rng.randf_range(-4, 4), rng.randf_range(-6, 6))
		var q := Quaternion(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized(), rng.randf_range(0, TAU))
		var frames := simula(da, v, w, q)
		# si sposta tutto il lancio in modo che il dado si fermi proprio nel punto voluto
		var fine: Vector3 = frames[frames.size() - 1][0]
		var sposta := Vector3(a.x - fine.x, 0, a.z - fine.z)
		for f in frames:
			f[0] = f[0] + sposta
		var q_ultimo: Quaternion = frames[frames.size() - 1][1]
		var su := _faccia_su(q_ultimo)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh_cubo()
		var facce := _facce(sp, su, rng)
		for k in 6:
			mi.set_surface_override_material(k, materiale(facce[k]))
		mi.position = da
		add_child(mi)
		_dadi.append([mi, frames])
	_frame = 0.0
	_attivo = true

func _facce(sp: Dictionary, su: int, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	out.resize(6)
	if sp["tipo"] == "viaggio":
		var nomi := ["ok", "fermo", "affonda", "vuoto", "vuoto", "vuoto"]
		var voluto: String = str(sp["valore"])
		if voluto == "ok" and rng.randf() < 0.75:
			voluto = "vuoto" if rng.randf() < 0.75 else "ok"
		nomi.erase(voluto)
		for k in range(nomi.size() - 1, 0, -1):
			var j := rng.randi_range(0, k)
			var t = nomi[k]
			nomi[k] = nomi[j]
			nomi[j] = t
		var idx := 0
		for k in 6:
			if k == su:
				out[k] = load("res://assets/dadi/viaggio_%s.jpg" % voluto)
			else:
				out[k] = load("res://assets/dadi/viaggio_%s.jpg" % nomi[idx])
				idx += 1
		return out
	var fondo := Color(0.72, 0.09, 0.07) if sp["tipo"] == "rosso" else Color(0.95, 0.92, 0.84)
	var punto := Color(0.98, 0.95, 0.9) if sp["tipo"] == "rosso" else Color(0.1, 0.07, 0.05)
	var v: int = int(sp["valore"])
	var valori := [0, 0, 0, 0, 0, 0]
	valori[su] = v
	valori[su ^ 1] = 7 - v
	var coppie := [[1, 6], [2, 5], [3, 4]]
	var resto: Array = []
	for cp in coppie:
		if not (v in cp):
			resto.append(cp)
	var liberi: Array = []
	for k in [0, 2, 4]:
		if k != (su & ~1):
			liberi.append(k)
	for i in 2:
		var k2: int = liberi[i]
		var cp2: Array = resto[i]
		var inv := rng.randf() < 0.5
		valori[k2] = cp2[1] if inv else cp2[0]
		valori[k2 ^ 1] = cp2[0] if inv else cp2[1]
	for k in 6:
		out[k] = tex_punti(valori[k], fondo, punto)
	return out

func pulisci() -> void:
	for d in _dadi:
		if is_instance_valid(d[0]):
			d[0].queue_free()
	_dadi = []
	_attivo = false

func _process(delta: float) -> void:
	if not _attivo:
		return
	_frame += delta * 60.0 * RALLENTA
	var tutti_fermi := true
	for d in _dadi:
		var fr: Array = d[1]
		var i := mini(int(_frame), fr.size() - 1)
		var j := mini(i + 1, fr.size() - 1)
		var t := clampf(_frame - int(_frame), 0.0, 1.0)
		var mi: MeshInstance3D = d[0]
		mi.position = (fr[i][0] as Vector3).lerp(fr[j][0], t)
		mi.quaternion = (fr[i][1] as Quaternion).slerp(fr[j][1], t)
		if int(_frame) < fr.size() - 1:
			tutti_fermi = false
	if tutti_fermi:
		_attivo = false
		finito.emit()

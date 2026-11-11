## Costruisce i pezzi 3D estrudendo le sagome dei segnalini (assets/pezzi/*.png).
## Ogni sagoma ha il suo contorno in assets/pezzi/forme.json: la faccia davanti e dietro porta
## l'immagine, i fianchi hanno il colore del bordo del pezzo.
class_name Pezzi3D
extends RefCounted

static var _forme := {}
static var _mesh := {}
static var _mat := {}

static func forme() -> Dictionary:
	if _forme.is_empty():
		var f := FileAccess.open("res://assets/pezzi/forme.json", FileAccess.READ)
		_forme = JSON.parse_string(f.get_as_text())
		f.close()
	return _forme

static func materiale_immagine(path: String) -> StandardMaterial3D:
	if _mat.has(path):
		return _mat[path]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.35
	m.roughness = 0.75
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mat[path] = m
	return m

static func materiale_colore(c: Color, rough := 0.7) -> StandardMaterial3D:
	var k := "c" + c.to_html()
	if _mat.has(k):
		return _mat[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	_mat[k] = m
	return m

## sagoma estrusa. nome: chiave in forme.json (anche "neutro" con immagine a parte).
## larg: larghezza in cm; spessore in cm. In piedi: base a y=0, faccia verso +Z.
## Piatto (disteso): la faccia guarda in alto, centrato, base a y=0.
static func sagoma(nome: String, larg: float, spessore: float, piatto: bool, immagine := "") -> Mesh:
	var img := immagine if immagine != "" else "res://assets/pezzi/%s.png" % nome
	var key := "%s|%s|%.2f|%.2f|%s" % [nome, img, larg, spessore, piatto]
	if _mesh.has(key):
		return _mesh[key]
	var f: Dictionary = forme()[nome]
	var alto: float = larg * float(f["h"]) / float(f["w"])
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for p in f["p"]:
		var x: float = float(p[0])
		var y: float = float(p[1])
		uvs.append(Vector2(x, y))
		pts.append(Vector2((x - 0.5) * larg, (1.0 - y) * alto if not piatto else (0.5 - y) * alto))
	var tri := Geometry2D.triangulate_polygon(pts)
	if tri.is_empty():
		# contorno con autointersezioni: si usa l'inviluppo convesso
		var hull := Geometry2D.convex_hull(pts)
		pts = hull
		uvs = PackedVector2Array()
		for q in hull:
			uvs.append(Vector2(q.x / larg + 0.5, (1.0 - q.y / alto) if not piatto else (0.5 - q.y / alto)))
		tri = Geometry2D.triangulate_polygon(pts)
	var h2 := spessore / 2.0
	var mesh := ArrayMesh.new()
	# facce con l'immagine
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lato in [1.0, -1.0]:
		var n := Vector3(0, 0, lato)
		for k in range(0, tri.size(), 3):
			var ids := [tri[k], tri[k + 1], tri[k + 2]]
			# l'ordine dei vertici deve dare la normale verso l'esterno
			var a := pts[ids[0]]
			var b := pts[ids[1]]
			var c := pts[ids[2]]
			var orient := (b - a).cross(c - a)
			if (orient > 0) == (lato > 0):
				ids = [ids[0], ids[2], ids[1]]
			for id in ids:
				st.set_normal(n)
				st.set_uv(uvs[id])
				st.add_vertex(Vector3(pts[id].x, pts[id].y, h2 * lato))
	st.commit(mesh)
	# fianchi
	var sf := SurfaceTool.new()
	sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var area := 0.0
	for i in pts.size():
		area += pts[i].cross(pts[(i + 1) % pts.size()])
	for i in pts.size():
		var a2 := pts[i]
		var b2 := pts[(i + 1) % pts.size()]
		var d := (b2 - a2).normalized()
		var nn := Vector3(d.y, -d.x, 0) if area > 0 else Vector3(-d.y, d.x, 0)
		var v := [Vector3(a2.x, a2.y, h2), Vector3(b2.x, b2.y, h2), Vector3(b2.x, b2.y, -h2), Vector3(a2.x, a2.y, -h2)]
		# Godot considera "davanti" le facce con i vertici in senso orario visti da fuori
		var ordine := [0, 1, 2, 0, 2, 3]
		var test: Vector3 = (v[1] - v[0]).cross(v[2] - v[0])
		if test.dot(nn) > 0:
			ordine = [0, 2, 1, 0, 3, 2]
		for o in ordine:
			sf.set_normal(nn)
			sf.add_vertex(v[o])
	sf.commit(mesh)
	mesh.surface_set_material(0, materiale_immagine(img))
	var lc: Array = f.get("lato", [0.85, 0.8, 0.7])
	mesh.surface_set_material(1, materiale_colore(Color(lc[0], lc[1], lc[2])))
	_mesh[key] = mesh
	return mesh

## un pezzo pronto da mettere nella scena
static func pezzo(nome: String, larg: float, spessore: float, piatto := false, immagine := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = sagoma(nome, larg, spessore, piatto, immagine)
	if piatto:
		mi.rotation.x = -PI / 2.0
		mi.position.y = spessore / 2.0
	return mi

## una tessera di cartone: scatola sottile con l'immagine sopra
static func tessera(immagine: String, larg: float, prof: float, spessore := 0.12) -> Node3D:
	var n := Node3D.new()
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(larg, spessore, prof)
	box.mesh = bm
	box.material_override = materiale_colore(Color(0.86, 0.8, 0.66))
	box.position.y = spessore / 2.0
	n.add_child(box)
	var top := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(larg * 0.98, prof * 0.98)
	top.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(immagine)
	mat.roughness = 0.85
	top.material_override = mat
	top.position.y = spessore + 0.003
	n.add_child(top)
	return n

static func cilindro(r: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 24
	mi.mesh = cm
	mi.material_override = materiale_colore(c, 0.55)
	mi.position.y = h / 2.0
	return mi

static func cubo(l: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(l, l, l)
	mi.mesh = bm
	mi.material_override = materiale_colore(c, 0.55)
	mi.position.y = l / 2.0
	return mi

## Un dado disegnato (niente simboli dei font): faccia avorio o rossa con i punti.
class_name Dado
extends Control

var valore := 1
var colore := Color(0.95, 0.92, 0.84)
var punti := Color(0.12, 0.08, 0.05)

func _init(v := 1, rosso := false, lato := 34.0) -> void:
	valore = v
	custom_minimum_size = Vector2(lato, lato)
	if rosso:
		colore = Color(0.72, 0.1, 0.08)
		punti = Color(0.98, 0.95, 0.9)

func _draw() -> void:
	var l := minf(size.x, size.y)
	var r := Rect2(Vector2.ZERO, Vector2(l, l))
	draw_rect(r.grow(-1), colore, true)
	draw_rect(r.grow(-1), Color(0, 0, 0, 0.6), false, 1.5)
	var p := {1: [Vector2(0.5, 0.5)], 2: [Vector2(0.27, 0.27), Vector2(0.73, 0.73)],
		3: [Vector2(0.25, 0.25), Vector2(0.5, 0.5), Vector2(0.75, 0.75)],
		4: [Vector2(0.27, 0.27), Vector2(0.73, 0.27), Vector2(0.27, 0.73), Vector2(0.73, 0.73)],
		5: [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.5, 0.5), Vector2(0.25, 0.75), Vector2(0.75, 0.75)],
		6: [Vector2(0.27, 0.22), Vector2(0.73, 0.22), Vector2(0.27, 0.5), Vector2(0.73, 0.5), Vector2(0.27, 0.78), Vector2(0.73, 0.78)]}
	for q in p.get(clampi(valore, 1, 6), []):
		draw_circle(q * l, l * 0.09, punti)

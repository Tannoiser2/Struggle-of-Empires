extends SceneTree
func _initialize():
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 6:
		var da := Vector3(-6, 5, 5)
		var a := Vector3(-3, 0, 0)
		var dir := Vector3(a.x - da.x, 0, a.z - da.z)
		var v := dir.normalized() * 24.0 + Vector3(0, 3.5, 0)
		var w := Vector3.UP.cross(dir.normalized()) * rng.randf_range(16, 26) + Vector3(rng.randf_range(-6, 6), rng.randf_range(-4, 4), rng.randf_range(-6, 6))
		var q := Quaternion(Vector3(rng.randf_range(-1,1), rng.randf_range(-1,1), rng.randf_range(-1,1)).normalized(), rng.randf_range(0, TAU))
		var fr: Array = Dadi3D.simula(da, v, w, q)
		var rot := 0.0
		var dist := 0.0
		for i in range(1, fr.size()):
			rot += rad_to_deg((fr[i-1][1].inverse() * fr[i][1]).get_angle())
			dist += Vector2(fr[i][0].x - fr[i-1][0].x, fr[i][0].z - fr[i-1][0].z).length()
		var f = fr[fr.size()-7]
		print("frames %d (%.2fs) rot %.0f gradi, strada %.1f, h fine %.2f" % [fr.size(), fr.size()/60.0/0.55, rot, dist, f[0].y])
	quit()

class_name SealLabContent
extends RefCounted

const SealProgramModel := preload("res://src/sigil_v2/seal_program.gd")


static func fixtures() -> Array[Dictionary]:
	var crescent_white := SealProgramModel.motif(&"crescent", 0, &"white")
	var fang_red := SealProgramModel.motif(&"fang", 0, &"red")
	var branch_blue := SealProgramModel.motif(&"branch", 0, &"blue")

	var orbit_fang_3 := SealProgramModel.orbit(fang_red, 3, 0, &"outward")
	var orbit_fang_4 := SealProgramModel.orbit(fang_red, 4, 0, &"outward")
	var orbit_fang_4_phase := SealProgramModel.orbit(fang_red, 4, 15, &"outward")

	var seal_7 := SealProgramModel.boundary(
		&"circle",
		SealProgramModel.compose(crescent_white, orbit_fang_3)
	)
	var seal_8 := SealProgramModel.boundary(
		&"circle",
		SealProgramModel.compose(crescent_white, orbit_fang_4)
	)
	var seal_9 := SealProgramModel.boundary(
		&"circle",
		SealProgramModel.compose(crescent_white, orbit_fang_4_phase)
	)

	var orbit_branch_6 := SealProgramModel.orbit(branch_blue, 6, 0, &"outward")
	var orbit_branch_group := SealProgramModel.orbit_group_key(branch_blue, 6, 0, &"outward")
	var star_branch_6 := SealProgramModel.circuit(
		orbit_branch_6,
		orbit_branch_group,
		&"star",
		2
	)
	var adjacent_branch_6 := SealProgramModel.circuit(
		orbit_branch_6,
		orbit_branch_group,
		&"adjacent",
		1
	)
	var hero_current := SealProgramModel.boundary(
		&"circle",
		SealProgramModel.compose(
			SealProgramModel.boundary(&"triangle", crescent_white),
			SealProgramModel.concentric(star_branch_6, 3, 2, 3, 10)
		)
	)
	var hero_hypothetical := SealProgramModel.boundary(
		&"circle",
		SealProgramModel.compose(
			SealProgramModel.boundary(&"triangle", crescent_white),
			SealProgramModel.concentric(adjacent_branch_6, 3, 2, 3, 10)
		)
	)

	return [
		_fixture(1, "欠け環", 0, crescent_white, SealProgramModel.motif(&"branch", 0, &"white")),
		_fixture(2, "牙", 0, fang_red, SealProgramModel.motif(&"fang", 0, &"blue")),
		_fixture(3, "枝", 0, branch_blue, SealProgramModel.motif(&"branch", 20, &"blue")),
		_fixture(4, "円境界", 1, SealProgramModel.boundary(&"circle", crescent_white), SealProgramModel.boundary(&"triangle", crescent_white)),
		_fixture(5, "三角境界", 1, SealProgramModel.boundary(&"triangle", crescent_white), SealProgramModel.boundary(&"circle", crescent_white)),
		_fixture(6, "三連環列", 1, orbit_fang_3, orbit_fang_4),
		_fixture(
			7,
			"中心と外周",
			2,
			seal_7,
			SealProgramModel.boundary(&"circle", SealProgramModel.compose(orbit_fang_3, crescent_white))
		),
		_fixture(8, "四連環列", 2, seal_8, seal_7),
		_fixture(9, "半位相", 2, seal_9, seal_8),
		_fixture(10, "星花陣", 3, hero_current, hero_hypothetical, true),
	]


static func _fixture(
	id: int,
	label: String,
	tier: int,
	current,
	hypothetical,
	hero: bool = false
) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"tier": tier,
		"hero": hero,
		"current": current,
		"hypothetical": hypothetical,
	}

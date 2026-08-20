class_name SealLimits
extends RefCounted

const GENERAL := {
	"max_depth": 6,
	"max_nodes": 48,
	"max_repeat_count": 12,
	"max_repeat_nesting": 3,
	"max_commands": 192,
	"max_anchors": 192,
	"max_segments": 2048,
	"max_work": 4096,
	"max_motifs": 48,
}

const MVP_LAB := {
	"max_depth": 4,
	"max_nodes": 24,
	"max_repeat_count": 4,
	"max_repeat_nesting": 1,
	"max_commands": 96,
	"max_anchors": 64,
	"max_segments": 768,
	"max_work": 1024,
	"max_motifs": 7,
}

const HERO_LAB := GENERAL


static func profile(hero: bool = false) -> Dictionary:
	return (HERO_LAB if hero else MVP_LAB).duplicate(true)

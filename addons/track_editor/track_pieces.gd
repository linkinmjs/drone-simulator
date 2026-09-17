@tool
extends RefCounted
## Pieces the toolbar can add to a Track, in the order they appear in the menu.
##
## `offset` is how far ahead of the previous piece a new one is placed, along its -Z (the
## direction a checkpoint is crossed). `gate` marks the pieces that carry a Checkpoint and
## therefore take part in the course; the others are only decoration or the start pad.
## Labels are written in Spanish here on purpose: `tr()` inside the editor resolves against
## the editor translations, not the game ones (see docs/desafios.md).


const PIECES: Array[Dictionary] = [
	{
		"id": &"gate_7x6",
		"label": "Aro 7x6",
		"path": "res://tracks/gates/Gate_7x6_Simple.tscn",
		"offset": 12.0,
		"gate": true,
	},
	{
		"id": &"gate_7x6_double",
		"label": "Aro 7x6 doble",
		"path": "res://tracks/gates/Gate_7x6_Double.tscn",
		"offset": 12.0,
		"gate": true,
	},
	{
		"id": &"gate_5x5",
		"label": "Aro 5x5",
		"path": "res://tracks/gates/Gate_5x5_Simple.tscn",
		"offset": 10.0,
		"gate": true,
	},
	{
		"id": &"gate_5x5_triple",
		"label": "Aro 5x5 triple",
		"path": "res://tracks/gates/Gate_5x5_Triple.tscn",
		"offset": 10.0,
		"gate": true,
	},
	{
		"id": &"gate_dive",
		"label": "Aro con picada 30 grados",
		"path": "res://tracks/gates/Gate_7x6_Dive_30deg.tscn",
		"offset": 14.0,
		"gate": true,
	},
	{
		"id": &"gate_torus_large",
		"label": "Aro circular grande",
		"path": "res://tracks/gates/Gate_Torus_Large.tscn",
		"offset": 25.0,
		"gate": true,
	},
	{
		"id": &"gate_torus",
		"label": "Aro circular chico",
		"path": "res://tracks/gates/Gate_Torus.tscn",
		"offset": 12.0,
		"gate": true,
	},
	{
		"id": &"hurdle",
		"label": "Valla 10x5",
		"path": "res://tracks/gates/Gate_Hurdle_10x5.tscn",
		"offset": 12.0,
		"gate": true,
	},
	{
		"id": &"column",
		"label": "Columna con paso lateral",
		"path": "res://tracks/gates/Gate_Column.tscn",
		"offset": 10.0,
		"gate": true,
	},
	{
		"id": &"launchpad",
		"label": "Plataforma de largada",
		"path": "res://tracks/objects/Launchpad.tscn",
		"offset": 8.0,
		"gate": false,
	},
	{
		"id": &"flag",
		"label": "Banderin",
		"path": "res://tracks/objects/Flag.tscn",
		"offset": 6.0,
		"gate": false,
	},
	{
		"id": &"cones",
		"label": "Conos en flecha",
		"path": "res://tracks/objects/ConePattern_Arrow1.tscn",
		"offset": 6.0,
		"gate": false,
	},
]


static func get_piece(id: StringName) -> Dictionary:
	for piece in PIECES:
		if piece["id"] == id:
			return piece
	return {}

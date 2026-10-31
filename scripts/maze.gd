# Airport, Find our gate: drag your face through the terminal maze to the gate.
extends Node2D


## This part of the airport is finished: on to the next.
func done() -> void:
	Game.goto(Game.MAP)

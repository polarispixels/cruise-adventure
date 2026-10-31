# Airport, Goodbye suitcases: tag the big bags and send them down the belt.
extends Node2D


## This part of the airport is finished: on to the next.
func done() -> void:
	Game.goto(Game.SECURITY)

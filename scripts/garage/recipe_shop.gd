extends "res://scripts/ui/station_screen.gd"
## Test blueprint shop: the station template with the blueprint provider (scripts/garage/blueprint_station.gd).
signal reset_requested
var category:
	get:return tab
	set(value):tab=value;selected=""
func _init():
	provider=preload("res://scripts/garage/blueprint_station.gd").new();provider.screen=self;tab="research"
func refresh():
	if is_inside_tree():build()

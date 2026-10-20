extends Node2D


## One playable wooden dojo stage. Geometry and platform collision are built here;
## art can be replaced without changing fighter physics or blast-zone logic.
func _ready() -> void:
	_build_platform("Main floor", Vector2(0, 48), Vector2(1180, 100))
	_build_platform("Left raised platform", Vector2(-285, -120), Vector2(300, 34))
	_build_platform("Right raised platform", Vector2(285, -120), Vector2(300, 34))
	_add_ledge(Vector2(-590, 8))
	_add_ledge(Vector2(590, 8))
	queue_redraw()


func _build_platform(label: String, center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = label.replace(" ", "")
	body.position = center
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)


func _add_ledge(at: Vector2) -> void:
	var ledge := Marker2D.new()
	ledge.name = "Ledge"
	ledge.position = at
	ledge.add_to_group("ledges")
	add_child(ledge)


func _draw() -> void:
	var view := get_viewport_rect().size
	# Deep charcoal-blue night backdrop, moon and distant rooftops.
	draw_rect(Rect2(-1500, -1100, 3000, 1500), Color("171b29"))
	draw_circle(Vector2(370, -520), 105, Color("d7c7a4", 0.18))
	for i in range(11):
		var x := -960.0 + i * 190.0
		draw_colored_polygon(
			PackedVector2Array([Vector2(x, -85), Vector2(x + 80, -185), Vector2(x + 175, -85)]),
			Color("242636")
		)
		draw_rect(Rect2(x + 14, -88, 145, 115), Color("202333"))
	# Dojo structure and shoji panels.
	draw_rect(Rect2(-790, -390, 1580, 290), Color("2d2630"))
	draw_rect(Rect2(-750, -350, 1500, 205), Color("524034"))
	for i in range(13):
		var x := -700 + i * 116
		draw_rect(Rect2(x, -335, 98, 170), Color("b29b76", 0.18))
		draw_rect(Rect2(x, -335, 6, 170), Color("100f14", 0.65))
		draw_rect(Rect2(x + 46, -335, 4, 170), Color("100f14", 0.45))
	# Structural beams.
	draw_rect(Rect2(-790, -390, 1580, 22), Color("6c4732"))
	draw_rect(Rect2(-765, -165, 1530, 24), Color("754d35"))
	for x in [-750.0, -640.0, 640.0, 750.0]:
		draw_rect(Rect2(x, -385, 28, 230), Color("4b3025"))
	# Floor and visible platforms.
	_draw_plank_platform(Rect2(-590, -2, 1180, 100))
	_draw_plank_platform(Rect2(-435, -137, 300, 34))
	_draw_plank_platform(Rect2(135, -137, 300, 34))
	# Stage edge warning markers / blast-zone ambience.
	for x in [-570.0, 570.0]:
		draw_line(Vector2(x, -20), Vector2(x, 165), Color("d17f49", 0.22), 2)


func _draw_plank_platform(rect: Rect2) -> void:
	draw_rect(rect, Color("603d2c"))
	draw_rect(Rect2(rect.position.x, rect.position.y, rect.size.x, 12), Color("b17a48"))
	var plank_count := int(rect.size.x / 74.0)
	for i in range(plank_count):
		var x := rect.position.x + i * 74.0
		draw_line(
			Vector2(x, rect.position.y + 14), Vector2(x, rect.end.y), Color("2a1c19", 0.45), 2
		)
		draw_circle(Vector2(x + 8, rect.position.y + 6), 2, Color("e0b579", 0.7))

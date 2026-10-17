
extends Node2D

# STAGE SETTINGs
# 1 Godot unit would be 1 metre

@export var stage_length: float = 2000.0
@export var point_spacing: float = 2.0
@export var road_width: float = 5.0

# collision settings to prevent the path from overlapping
@export var prevent_collisions: bool = true
@export var min_road_separation: float = 7.0
@export var max_attempts: int = 50

# NUMBER OF FEATURES

@export var kink_count: int = 4
@export var r0_count: int = 30
@export var r1_count: int = 7
@export var r2_count: int = 15
@export var r3_count: int = 19
@export var r4_count: int = 25
@export var r5_count: int = 31
@export var r6_count: int = 25
@export var hairpin_count: int = 4

# Approximate corner radius ranges in metres
var radius_ranges = {
	1: Vector2(10.0, 20.0),
	2: Vector2(20.0, 35.0),
	3: Vector2(35.0, 55.0),
	4: Vector2(55.0, 80.0),
	5: Vector2(80.0, 120.0),
	6: Vector2(120.0, 200.0)
}

var track_points: PackedVector2Array = []


# STARTUP AND INPUT
func _ready():
	generate_stage()


func _unhandled_input(event):
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_R:
				generate_stage()


# GENERATE STAGE WITH RETRIES
func generate_stage():
	for attempt in range(max_attempts):
		track_points.clear()

		if generate_stage_attempt():
			queue_redraw()
			return

	push_warning(
        "Could not generate a collision-free stage. "
		+ "Try lowering min_road_separation or "
		+ "increasing max_attempts."
	)

	track_points.clear()
	queue_redraw()


func generate_stage_attempt() -> bool:
	track_points.clear()

	if stage_length <= 0.0 or point_spacing <= 0.0:
		push_warning("Stage length and point spacing must be positive.")
		return false

	var events: Array[Dictionary] = []

	# R0: straight sections
	add_events(events, 0, r0_count, 10.0, 25.0)

	# R1-R6: corners
	add_events(events, 1, r1_count, 8.0, 22.0)
	add_events(events, 2, r2_count, 8.0, 22.0)
	add_events(events, 3, r3_count, 8.0, 22.0)
	add_events(events, 4, r4_count, 8.0, 22.0)
	add_events(events, 5, r5_count, 8.0, 22.0)
	add_events(events, 6, r6_count, 8.0, 22.0)

	# Hairpins
	add_events(events, 7, hairpin_count, 30.0, 45.0)

	# Add left-right or right-left kink pairs
	for i in range(kink_count):
		var direction = 1.0

		if randf() < 0.5:
			direction = -1.0

		events.append({
			"type": -1,
			"weight": randf_range(6.0, 10.0),
			"direction": direction,
			"angle": 18.0
		})

		events.append({
			"type": -1,
			"weight": randf_range(6.0, 10.0),
			"direction": -direction,
			"angle": 18.0
		})

	# Randomize feature order
	events.shuffle()

	# Calculate total event weight
	var total_weight = 0.0

	for feature in events:
		total_weight += float(feature["weight"])

	if total_weight <= 0.0:
		return false

	# Start generating the track
	var position = Vector2.ZERO
	var heading = 0.0

	track_points.append(position)

	for feature in events:
		var segment_length = (
			stage_length
			* float(feature["weight"])
			/ total_weight
		)

		var steps = max(
			1,
			int(ceil(segment_length / point_spacing))
		)

		var distance_per_step = segment_length / float(steps)

		var total_angle = get_event_angle(
			feature,
			segment_length
		)

		for step in range(steps):
			heading += deg_to_rad(
				total_angle / float(steps)
			)

			var movement = Vector2.RIGHT.rotated(heading)
			var next_position = (
				position + movement * distance_per_step
			)

			# Check for collision before adding the point
			if prevent_collisions:
				if point_has_collision(next_position):
					return false

			position = next_position
			track_points.append(position)

	return true


# CREATE EVENTS

func add_events(
	events: Array[Dictionary],
	event_type: int,
	count: int,
	min_length: float,
	max_length: float
):
	for i in range(count):
		var direction = 1.0

		if randf() < 0.5:
			direction = -1.0

		events.append({
			"type": event_type,
			"weight": randf_range(min_length, max_length),
			"direction": direction
		})


# --------------------------------------------------
# CALCULATE TURN ANGLES
# --------------------------------------------------

func get_event_angle(
	feature: Dictionary,
	segment_length: float
) -> float:
	var event_type = int(feature["type"])
	var direction = float(feature.get("direction", 1.0))

	# R0: straight
	if event_type == 0:
		return 0.0

	# Kink
	if event_type == -1:
		return direction * float(feature["angle"])

	# Hairpin
	if event_type == 7:
		return direction * randf_range(150.0, 180.0)

	# R1-R6: angle based on distance and radius
	var radius_range: Vector2 = radius_ranges[event_type]

	var radius = randf_range(
		radius_range.x,
		radius_range.y
	)

	var angle_radians = segment_length / radius
	var angle_degrees = rad_to_deg(angle_radians)

	return direction * angle_degrees


# --------------------------------------------------
# SIMPLE COLLISION DETECTION
# --------------------------------------------------

func point_has_collision(point: Vector2) -> bool:
	# Ignore the most recent points because they belong
	# to the road section currently being generated.
	var check_until = track_points.size() - 4

	for i in range(check_until):
		var distance = point.distance_to(track_points[i])

		if distance < min_road_separation:
			return true

	return false


# DRAW THE STAGE
func _draw():
	if track_points.size() < 2:
		return

	# Find track boundaries
	var bounds = Rect2(track_points[0], Vector2.ZERO)

	for point in track_points:
		bounds = bounds.expand(point)

	# Fit the stage inside the window
	var view_size = get_viewport_rect().size
	var available_size = view_size - Vector2(100.0, 100.0)

	var scale_x = available_size.x / max(bounds.size.x, 1.0)
	var scale_y = available_size.y / max(bounds.size.y, 1.0)

	var scale_factor = min(scale_x, scale_y)

	var center = bounds.get_center()
	var offset = view_size / 2.0 - center * scale_factor

	draw_set_transform(
		offset,
		0.0,
		Vector2(scale_factor, scale_factor)
	)

	# Dark outer road
	draw_polyline(
		track_points,
		Color(0.08, 0.08, 0.08),
		road_width + 2.0,
		true
	)

	# Road surface
	draw_polyline(
		track_points,
		Color(0.55, 0.55, 0.55),
		road_width,
		true
	)

	# Centre guide
	draw_polyline(
		track_points,
		Color(0.1, 0.5, 0.0, 0.5),
		0.4,
		false
	)

	# Start and finish markers
	draw_circle(
		track_points[0],
		road_width,
		Color.GREEN
	)

	draw_circle(
		track_points[track_points.size() - 1],
		road_width,
		Color.RED
	)

	# reset transform before drawing screen text
	draw_set_transform(
		Vector2.ZERO,
		0.0,
		Vector2.ONE
	)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(20, 30),
		"Rally Stage Generator | Press R to regenerate",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color.WHITE
	)

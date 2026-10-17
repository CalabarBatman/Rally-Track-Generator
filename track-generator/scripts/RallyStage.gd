
extends Node2D
# Stage settings
@export var stage_length: float = 1200.0
@export var point_spacing: float = 8.0
@export var road_width: float = 24.0

# Number of features to generate
@export var kink_count: int = 4
@export var r1_count: int = 1
@export var r2_count: int = 2
@export var r3_count: int = 2
@export var r4_count: int = 2
@export var r5_count: int = 1
@export var r6_count: int = 1
@export var hairpin_count: int = 2

var track_points: PackedVector2Array = []


func _ready():
	generate_stage()


func _unhandled_input(event):
	# Press R to generate another stage
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_R:
				generate_stage()


func generate_stage():
	track_points.clear()

	var step_count = int(stage_length / point_spacing)
	step_count = max(step_count, 20)

	var events: Array[Dictionary] = []

	# Add the requested turn types
	add_turn_events(events, 1, r1_count, 4, 60, 110)
	add_turn_events(events, 2, r2_count, 6, 50, 90)
	add_turn_events(events, 3, r3_count, 8, 40, 75)
	add_turn_events(events, 4, r4_count, 10, 30, 60)
	add_turn_events(events, 5, r5_count, 12, 25, 50)
	add_turn_events(events, 6, r6_count, 14, 20, 40)

	# Add hairpins
	add_turn_events(
		events, 0, hairpin_count, 8, 150, 180
	)

	# Add kinks as quick left-right or right-left changes
	for i in range(kink_count):
		var direction = 1.0
		if randf() < 0.5:
			direction = -1.0

		events.append({
			"type": -1,
			"start": 0,
			"duration": 2,
			"angle": direction * 18.0
		})

		events.append({
			"type": -1,
			"start": 0,
			"duration": 2,
			"angle": -direction * 18.0
		})

	# Randomize the order of the features
	events.shuffle()

	# Spread events along the stage
	for i in range(events.size()):
		events[i]["start"] = int(
			float(i + 1) * step_count
			/ float(events.size() + 1)
		)

	# Generate the actual path
	var position = Vector2.ZERO
	var heading = 0.0

	track_points.append(position)

	for step in range(step_count):
		# Apply the direction changes active at this step
		for turn in events:
			var start = int(turn["start"])
			var duration = int(turn["duration"])

			if step >= start and step < start + duration:
				heading += deg_to_rad(
					float(turn["angle"]) / float(duration)
				)

		# Move forward along the current heading
		var movement = Vector2.RIGHT.rotated(heading)
		position += movement * point_spacing

		track_points.append(position)

	queue_redraw()


func add_turn_events(
	events: Array[Dictionary],
	turn_type: int,
	count: int,
	duration: int,
	min_angle: float,
	max_angle: float
):
	for i in range(count):
		var direction = 1.0

		if randf() < 0.5:
			direction = -1.0

		var angle = randf_range(min_angle, max_angle)
		angle *= direction

		events.append({
			"type": turn_type,
			"start": 0,
			"duration": duration,
			"angle": angle
		})


func _draw():
	if track_points.size() < 2:
		return

	# Fit the entire track inside the window
	var bounds = Rect2(track_points[0], Vector2.ZERO)

	for point in track_points:
		bounds = bounds.expand(point)

	var view_size = get_viewport_rect().size
	var available_size = view_size - Vector2(100, 100)

	var scale_x = available_size.x / max(bounds.size.x, 1.0)
	var scale_y = available_size.y / max(bounds.size.y, 1.0)
	var scale_factor = min(scale_x, scale_y)

	var center = bounds.get_center()
	var offset = view_size / 2.0 - center * scale_factor

	draw_set_transform(
		offset, 0.0, Vector2(scale_factor, scale_factor)
	)

	# Draw the dark outer road edges first
	draw_polyline(
		track_points, Color(0.08, 0.08, 0.08),
		road_width + 8.0, true
	)

	# Draw the road surface
	draw_polyline(
		track_points, Color(0.55, 0.55, 0.55),
		road_width, true
	)

	# Draw a thin center guide
	draw_polyline(
		track_points, Color(0.85, 0.85, 0.75),
		1.0, true
	)

	# Start and finish markers
	draw_circle(track_points[0], road_width, Color.GREEN)
	draw_circle(
		track_points[track_points.size() - 1],
		road_width, Color.RED
	)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	draw_string(
		ThemeDB.fallback_font,
		Vector2(20, 30),
		"Rally Stage Generator | Press R to regenerate",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1, 18, Color.WHITE
	)

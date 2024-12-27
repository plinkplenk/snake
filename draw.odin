package main

import rl "vendor:raylib"

draw_square :: proc(pos: Vec2, scale: f32, round: f32, color: rl.Color) {
	rec := rl.Rectangle {
		x      = pos.x,
		y      = pos.y,
		width  = 1 * scale,
		height = 1 * scale,
	}
	rl.DrawRectangleRounded(rec, round, 20, color)
}

new_square :: proc(pos: Vec2, width: f32) -> rl.Rectangle {
	return rl.Rectangle{pos.x, pos.y, width, width}
}

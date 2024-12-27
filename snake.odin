package main

import "core:math/linalg"
import rl "vendor:raylib"

SNAKE_COLOR: rl.Color : {0x00, 0x80, 0x00, 0xFF}
SNAKE_HEAD_COLOR: rl.Color : {0x00, 0xFF, 0x00, 0xFF}

Snake :: struct {
	headGridPos:     Vec2,
	headScreenPos:   Vec2,
	tailGridPos:     [dynamic]Vec2,
	tailScreenPos:   [dynamic]Vec2,
	direction:       Vec2,
	speed:           f32,
	shouldGrow:      bool,
	colWidth:        f32,
	move:            proc(snake: ^Snake),
	draw:            proc(snake: Snake),
	calc_screen_pos: proc(snake: ^Snake, delta: f32),
}

@(private = "file")
draw :: proc(snake: Snake) {
	draw_square(snake.headScreenPos, snake.colWidth, 0.6, SNAKE_HEAD_COLOR)
	prevPos := snake.headGridPos
	for pos in snake.tailScreenPos {
		draw_square(pos, snake.colWidth, 0.8, SNAKE_COLOR)
	}
}

@(private = "file")
move :: proc(snake: ^Snake) {
	if snake.direction == {0, 0} {
		return
	}
	lastPos := snake.tailGridPos[len(snake.tailGridPos) - 1]
	if snake.headScreenPos == snake.headGridPos * snake.colWidth {
		#reverse for &pos, idx in snake.tailGridPos {
			if idx - 1 < 0 {
				pos = snake.headGridPos
			} else {
				pos = snake.tailGridPos[idx - 1]
			}
		}
		snake.headGridPos += snake.direction
	}
	if snake.shouldGrow {
		snake.shouldGrow = false
		append(&snake.tailGridPos, lastPos)
		append(&snake.tailScreenPos, lastPos * snake.colWidth)
	}
}

@(private = "file")
calc_next_pos :: proc(currPos: Vec2, targetPos: Vec2, speed, deltaTime: f32) -> Vec2 {
	direction := targetPos - currPos
	distance := linalg.sqrt(direction.x * direction.x + direction.y * direction.y)
	if distance == 0 {
		return targetPos
	}
	if distance < 0 {
		return currPos
	}
	direction /= distance
	pos := currPos + (direction * (deltaTime * speed))
	if abs(targetPos.x - pos.x) < speed * deltaTime {
		pos.x = targetPos.x
	}
	if abs(targetPos.y - pos.y) < speed * deltaTime {
		pos.y = targetPos.y
	}
	return pos
}

@(private = "file")
calc_snake_screen_pos :: proc(snake: ^Snake, deltaTime: f32) {
	if snake.direction == {0, 0} {return}
	snake.headScreenPos = calc_next_pos(
		snake.headScreenPos,
		snake.headGridPos * snake.colWidth,
		snake.speed,
		deltaTime,
	)
	for &pos, i in snake.tailScreenPos {
		pos = calc_next_pos(pos, snake.tailGridPos[i] * snake.colWidth, snake.speed, deltaTime)
	}
}

new_snake :: proc(startingPos: Vec2, speed: f32, colWidth: f32) -> Snake {
	return Snake {
		direction = Vec2{0, 0},
		headGridPos = startingPos,
		headScreenPos = startingPos * colWidth,
		tailGridPos = [dynamic]Vec2 {
			Vec2{startingPos.x, startingPos.y + 1},
			Vec2{startingPos.x, startingPos.y + 2},
		},
		tailScreenPos = [dynamic]Vec2 {
			Vec2{startingPos.x, startingPos.y + 1} * colWidth,
			Vec2{startingPos.x, startingPos.y + 2} * colWidth,
		},
		colWidth = colWidth,
		calc_screen_pos = calc_snake_screen_pos,
		draw = draw,
		speed = speed,
		move = move,
	}
}

free_snake :: proc(snake: ^Snake) {
	delete_dynamic_array(snake.tailScreenPos)
	delete_dynamic_array(snake.tailGridPos)
}

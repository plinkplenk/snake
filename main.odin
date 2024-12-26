package main

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:os"
import "core:time"
import rl "vendor:raylib"

INITIAL_WINDOW_WIDTH :: 800
INITIAL_WINDOW_HEIGHT :: 800
TITLE :: "Snake"

AREA_SIDE_LEN :: 20

COL_WIDTH :: min(INITIAL_WINDOW_HEIGHT, INITIAL_WINDOW_WIDTH) / AREA_SIDE_LEN

FONT_SIZE :: 20

SNAKE_SPEED :: 450

SNAKE_COLOR: rl.Color : {0x00, 0x80, 0x00, 0xFF}
SNAKE_HEAD_COLOR: rl.Color : {0x00, 0xFF, 0x00, 0xFF}
APPLE_COLOR: rl.Color : {0xFF, 0x00, 0x00, 0xFF}
AREA_BG1 :: rl.Color{0x00, 0x00, 0x00, 0xFF}
AREA_BG2 :: rl.Color{0x05, 0x05, 0x05, 0xFF}
FONT_COLOR :: rl.WHITE

Vec2 :: [2]f32

Direction :: enum {
	Up,
	Down,
	Left,
	Right,
}
DirectionVec :: [Direction]Vec2 {
	.Up    = {0, -1},
	.Down  = {0, 1},
	.Left  = {-1, 0},
	.Right = {1, 0},
}


AREA_CELLS := proc() -> [AREA_SIDE_LEN * AREA_SIDE_LEN]Vec2 {
	a := [AREA_SIDE_LEN * AREA_SIDE_LEN]Vec2{}
	idx := 0
	for i in 0 ..< AREA_SIDE_LEN {
		for j in 0 ..< AREA_SIDE_LEN {
			a[idx] = Vec2{cast(f32)j, cast(f32)i}
			idx += 1
		}
	}
	return a
}()

Snake :: struct {
	headGridPos:   Vec2,
	headScreenPos: Vec2,
	tailGridPos:   [dynamic]Vec2,
	tailScreenPos: [dynamic]Vec2,
	direction:     Vec2,
	speed:         f32,
	shouldGrow:    bool,
}

draw_snake :: proc(snake: Snake) {
	draw_square(snake.headScreenPos, COL_WIDTH, 0.6, SNAKE_HEAD_COLOR)
	prevPos := snake.headGridPos
	for pos in snake.tailScreenPos {
		draw_square(pos, COL_WIDTH, 0.8, SNAKE_COLOR)
	}
}

move :: proc(snake: ^Snake) {
	if snake.direction == {0, 0} {
		return
	}
	lastPos := snake.tailGridPos[len(snake.tailGridPos) - 1]
	if snake.headScreenPos == snake.headGridPos * COL_WIDTH {
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
		append(&snake.tailScreenPos, lastPos * COL_WIDTH)
	}
}

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

calc_snake_screen_pos :: proc(snake: ^Snake, deltaTime: f32) {
	if snake.direction == {0, 0} {return}
	snake.headScreenPos = calc_next_pos(
		snake.headScreenPos,
		snake.headGridPos * COL_WIDTH,
		snake.speed,
		deltaTime,
	)
	for &pos, i in snake.tailScreenPos {
		pos = calc_next_pos(pos, snake.tailGridPos[i] * COL_WIDTH, snake.speed, deltaTime)
	}
}

new_snake :: proc(startingPos: Vec2, speed: f32) -> Snake {
	return Snake {
		direction = Vec2{0, 0},
		headGridPos = startingPos,
		headScreenPos = startingPos * COL_WIDTH,
		tailGridPos = [dynamic]Vec2 {
			Vec2{startingPos.x, startingPos.y + 1},
			Vec2{startingPos.x, startingPos.y + 2},
		},
		tailScreenPos = [dynamic]Vec2 {
			Vec2{startingPos.x, startingPos.y + 1} * COL_WIDTH,
			Vec2{startingPos.x, startingPos.y + 2} * COL_WIDTH,
		},
		speed = speed,
	}
}

free_snake :: proc(snake: ^Snake) {
	delete_dynamic_array(snake.tailScreenPos)
	delete_dynamic_array(snake.tailGridPos)
}

State :: enum {
	Neural,
	Paused,
	Playing,
	Lost,
	Won,
}

Game :: struct {
	snake:          Snake,
	applePos:       Vec2,
	state:          State,
	isAppleSpawned: bool,
}

get_coord_idx :: proc(cord: Vec2) -> int {
	return int(cord.x) + int(cord.y) * AREA_SIDE_LEN
}

spawn_apple :: proc(game: ^Game) {
	if game.isAppleSpawned {
		return
	}
	rand.reset(u64(time.now()._nsec))
	areaCopy := make([dynamic]Vec2, 0, AREA_SIDE_LEN * AREA_SIDE_LEN)
	defer delete_dynamic_array(areaCopy)
	snakePositions := map[int]Vec2 {
		get_coord_idx(game.snake.headGridPos) = game.snake.headGridPos,
	}
	defer delete(snakePositions)
	for pos in game.snake.tailGridPos {
		snakePositions[get_coord_idx(pos)] = pos
	}
	for pos in AREA_CELLS {
		if get_coord_idx(pos) not_in snakePositions {
			append(&areaCopy, pos)
		}
	}
	appleCordIdx := int(rand.int31()) % len(areaCopy)
	game.applePos = areaCopy[appleCordIdx]
	game.isAppleSpawned = true
}

draw_game :: proc(game: Game) {
	for row in 0 ..< AREA_SIDE_LEN {
		for col in 0 ..< AREA_SIDE_LEN {
			pos := Vec2{f32(col) * COL_WIDTH, f32(row) * COL_WIDTH}
			draw_square(pos, COL_WIDTH, 0.2, AREA_BG1 if (row + col) % 2 == 0 else AREA_BG2)
		}
	}
	draw_snake(game.snake)
	if game.isAppleSpawned {draw_apple(game.applePos)}
	#partial switch game.state {
	case .Neural:
		neuralMessage :: "PRESS [W], [A], [S], [D] or ↑ ← ↓ → TO START PLAYING"
		textPos := rl.MeasureTextEx(rl.GetFontDefault(), neuralMessage, FONT_SIZE, 1)
		rl.DrawText(
			neuralMessage,
			(rl.GetRenderWidth() - i32(textPos.x)) / 2,
			(rl.GetRenderHeight() - i32(textPos.y)) / 2,
			FONT_SIZE,
			FONT_COLOR,
		)
	case .Paused:
		pausedMessage :: "GAME IS PAUSED"
		textPos := rl.MeasureTextEx(rl.GetFontDefault(), pausedMessage, FONT_SIZE, 1)
		rl.DrawText(
			pausedMessage,
			(rl.GetRenderWidth() - i32(textPos.x)) / 2,
			(rl.GetRenderHeight() - i32(textPos.y)) / 2,
			FONT_SIZE,
			FONT_COLOR,
		)
	case .Lost:
		lostMessage :: "YOU LOST\nPress [R] or [Enter] to restart"
		textPos := rl.MeasureTextEx(rl.GetFontDefault(), lostMessage, FONT_SIZE, 1)
		rl.DrawText(
			lostMessage,
			(rl.GetRenderWidth() - i32(textPos.x)) / 2,
			(rl.GetRenderHeight() - i32(textPos.y)) / 2,
			FONT_SIZE,
			FONT_COLOR,
		)
	}
}
draw_apple :: proc(apple: Vec2) {
	draw_square(apple * COL_WIDTH, COL_WIDTH, 1, APPLE_COLOR)
}

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

check_collisions :: proc(game: ^Game) {
	snakeHeadRec := new_square(game.snake.headScreenPos, COL_WIDTH)
	if rl.CheckCollisionRecs(snakeHeadRec, new_square(game.applePos * COL_WIDTH, COL_WIDTH)) {
		game.snake.shouldGrow = true
		game.isAppleSpawned = false
		return
	}
	if game.snake.headGridPos.x >= AREA_SIDE_LEN ||
	   game.snake.headGridPos.x < 0 ||
	   game.snake.headGridPos.y >= AREA_SIDE_LEN ||
	   game.snake.headGridPos.y < 0 {
		game.state = .Lost
		return
	}
	gridHeadRec := new_square(game.snake.headGridPos * COL_WIDTH, COL_WIDTH)
	for pos in game.snake.tailGridPos {
		tailRec := new_square(pos * COL_WIDTH, COL_WIDTH)
		if rl.CheckCollisionRecs(gridHeadRec, tailRec) {
			game.state = .Lost
		}
	}
}

reinit_game :: proc(game: ^Game) {
	free_snake(&game.snake)
	game.snake = new_snake(Vec2{AREA_SIDE_LEN / 2, AREA_SIDE_LEN / 2}, SNAKE_SPEED)
	game.snake.direction = DirectionVec[.Up]
	game.isAppleSpawned = false
	spawn_apple(game)
	game.state = .Playing
}

need_prevent_unexpected_collision :: proc(pos: Vec2, segments: []Vec2, direction: Vec2) -> bool {
	next_pos := pos + direction
	for segment in segments {
		if segment == next_pos {
			return true
		}
	}
	return false
}

handle_keys :: proc(game: ^Game) {
	switch {
	case game.state == .Lost && (rl.IsKeyPressed(.R) || rl.IsKeyPressed(.ENTER)):
		reinit_game(game)
	case rl.IsKeyPressed(.SPACE):
		game.state = game.state == .Paused ? .Playing : .Paused
	}
	switch {
	case rl.IsKeyPressed(.W), rl.IsKeyPressed(.UP):
		if game.snake.direction == DirectionVec[.Down] ||
		   need_prevent_unexpected_collision(
			   game.snake.headGridPos,
			   game.snake.tailGridPos[:2],
			   DirectionVec[.Up],
		   ) {
			break
		}
		game.snake.direction = DirectionVec[.Up]
		game.state = .Playing
	case rl.IsKeyPressed(.S), rl.IsKeyPressed(.DOWN):
		if game.snake.direction == DirectionVec[.Up] ||
		   need_prevent_unexpected_collision(
			   game.snake.headGridPos,
			   game.snake.tailGridPos[:2],
			   DirectionVec[.Down],
		   ) {
			break
		}
		game.snake.direction = DirectionVec[.Down]
		game.state = .Playing
	case rl.IsKeyPressed(.A), rl.IsKeyPressed(.LEFT):
		if game.snake.direction == DirectionVec[.Right] ||
		   need_prevent_unexpected_collision(
			   game.snake.headGridPos,
			   game.snake.tailGridPos[:2],
			   DirectionVec[.Left],
		   ) {
			break
		}
		game.snake.direction = DirectionVec[.Left]
		game.state = .Playing
	case rl.IsKeyPressed(.D), rl.IsKeyPressed(.RIGHT):
		if game.snake.direction == DirectionVec[.Left] ||
		   need_prevent_unexpected_collision(
			   game.snake.headGridPos,
			   game.snake.tailGridPos[:2],
			   DirectionVec[.Right],
		   ) {
			break
		}
		game.snake.direction = DirectionVec[.Right]
		game.state = .Playing
	}
}

new_game :: proc(startingPos: Vec2) -> Game {
	return Game {
		snake = new_snake(startingPos, SNAKE_SPEED),
		applePos = Vec2{},
		isAppleSpawned = false,
	}
}


main :: proc() {
	rl.SetConfigFlags(rl.ConfigFlags({.MSAA_4X_HINT}))
	rl.InitWindow(INITIAL_WINDOW_WIDTH, INITIAL_WINDOW_HEIGHT, TITLE)
	defer rl.CloseWindow()
	rl.InitAudioDevice()
	rl.SetTargetFPS(144)
	game := new_game(Vec2{AREA_SIDE_LEN / 2, AREA_SIDE_LEN / 2})
	for !rl.WindowShouldClose() {
		check_collisions(&game)
		handle_keys(&game)
		prepare: {
			if game.state == .Paused || game.state == .Lost {
				break prepare
			}
			delta := rl.GetFrameTime()
			move(&game.snake)
			calc_snake_screen_pos(&game.snake, delta)
		}
		rl.BeginDrawing()
		{
			rl.ClearBackground(rl.BLANK)
			draw_game(game)
		}
		rl.EndDrawing()
		spawn_apple(&game)
	}
}

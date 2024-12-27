package main

import "core:fmt"
import "core:math/rand"
import "core:strings"
import "core:time"
import rl "vendor:raylib"

FONT_SIZE :: 20

SNAKE_SPEED :: 450

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

@(private = "file")
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


State :: enum {
	Neural,
	Paused,
	Playing,
	Lost,
	Won,
}

Game :: struct {
	score:            u16,
	snake:            Snake,
	applePos:         Vec2,
	state:            State,
	colWidth:         f32,
	isAppleSpawned:   bool,
	spawn_apple:      proc(_: ^Game),
	check_collisions: proc(_: ^Game),
	draw:             proc(_: Game),
	handle_keys:      proc(_: ^Game),
}

get_coord_idx :: proc(cord: Vec2) -> int {
	return int(cord.x) + int(cord.y) * AREA_SIDE_LEN
}

@(private = "file")
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

@(private = "file")
draw :: proc(game: Game) {
	for row in 0 ..< AREA_SIDE_LEN {
		for col in 0 ..< AREA_SIDE_LEN {
			pos := Vec2{f32(col) * game.colWidth, f32(row) * game.colWidth}
			draw_square(pos, game.colWidth, 0.2, AREA_BG1 if (row + col) % 2 == 0 else AREA_BG2)
		}
	}
	game.snake->draw()
	if game.isAppleSpawned {draw_apple(game.applePos, game.colWidth)}
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
		lostMessage := fmt.tprintf(
			"YOU LOST\nPress [R] or [Enter] to restart\nYOUR SCORE IS %v",
			game.score,
		)
		lostMsgCstr := strings.clone_to_cstring(lostMessage)
		textPos := rl.MeasureTextEx(rl.GetFontDefault(), lostMsgCstr, FONT_SIZE, 1)
		rl.DrawText(
			lostMsgCstr,
			(rl.GetRenderWidth() - i32(textPos.x)) / 2,
			(rl.GetRenderHeight() - i32(textPos.y)) / 2,
			FONT_SIZE,
			FONT_COLOR,
		)
	}
}

@(private = "file")
draw_apple :: proc(apple: Vec2, width: f32) {
	draw_square(apple * width, width, 1, APPLE_COLOR)
}

@(private = "file")
check_collisions :: proc(game: ^Game) {
	snakeHeadRec := new_square(game.snake.headScreenPos, game.colWidth)
	if rl.CheckCollisionRecs(
		snakeHeadRec,
		new_square(game.applePos * game.colWidth, game.colWidth),
	) {
		game.snake.shouldGrow = true
		game.isAppleSpawned = false
		game.score += 1
		return
	}
	if game.snake.headGridPos.x >= AREA_SIDE_LEN ||
	   game.snake.headGridPos.x < 0 ||
	   game.snake.headGridPos.y >= AREA_SIDE_LEN ||
	   game.snake.headGridPos.y < 0 {
		game.state = .Lost
		return
	}
	gridHeadRec := new_square(game.snake.headGridPos * game.colWidth, game.colWidth)
	for pos in game.snake.tailGridPos {
		tailRec := new_square(pos * game.colWidth, game.colWidth)
		if rl.CheckCollisionRecs(gridHeadRec, tailRec) {
			game.state = .Lost
		}
	}
}

@(private = "file")
reinit_game :: proc(game: ^Game) {
	speed := game.snake.speed
	free_snake(&game.snake)
	game.snake = new_snake(Vec2{AREA_SIDE_LEN / 2, AREA_SIDE_LEN / 2}, speed, game.colWidth)
	game.snake.direction = DirectionVec[.Up]
	game.isAppleSpawned = false
	spawn_apple(game)
	game.state = .Playing
	game.score = 0
}

@(private = "file")
need_prevent_unexpected_collision :: proc(pos: Vec2, segments: []Vec2, direction: Vec2) -> bool {
	next_pos := pos + direction
	for segment in segments {
		if segment == next_pos {
			return true
		}
	}
	return false
}

@(private = "file")
handle_keys :: proc(game: ^Game) {
	switch {
	case game.state == .Lost && (rl.IsKeyPressed(.R) || rl.IsKeyPressed(.ENTER)):
		reinit_game(game)
	case game.state == .Lost:
		return
	case rl.IsKeyPressed(.SPACE):
		game.state = game.state == .Paused ? .Playing : .Paused
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

new_game :: proc(startingPos: Vec2, speed, colWidth: f32) -> Game {
	return Game {
		snake = new_snake(startingPos, speed, colWidth),
		applePos = Vec2{},
		colWidth = colWidth,
		isAppleSpawned = false,
		spawn_apple = spawn_apple,
		check_collisions = check_collisions,
		draw = draw,
		handle_keys = handle_keys,
		score = 0,
	}
}

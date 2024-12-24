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

AREA_SIZE :: 20

COL_WIDTH :: INITIAL_WINDOW_HEIGHT / min(AREA_SIZE, AREA_SIZE)

FONT_SIZE :: 20


SNAKE_SPEED :: 500

SNAKE_COLOR: rl.Color : {0x00, 0x80, 0x00, 0xFF}
SNAKE_HEAD_COLOR: rl.Color : {0x00, 0xFF, 0x00, 0xFF}
APPLE_COLOR: rl.Color : {0xFF, 0x00, 0x00, 0xFF}
AREA_BG1 :: rl.Color{0x00, 0x00, 0x00, 0xFF}
AREA_BG2 :: rl.Color{0x05, 0x05, 0x05, 0xFF}
FONT_COLOR :: rl.WHITE

Vec2 :: distinct [2]f32

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
	draw_square(snake.headScreenPos, COL_WIDTH, SNAKE_HEAD_COLOR)
	prevPos := snake.headGridPos
	for pos in snake.tailScreenPos {

		draw_square(pos, COL_WIDTH, SNAKE_COLOR)
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

State :: enum {
	Neural,
	Paused,
	Playing,
	Lost,
	Won,
}

Game :: struct {
	snake:          ^Snake,
	applePos:       Vec2,
	state:          State,
	isAppleSpawned: bool,
}

spawn_apple :: proc(game: ^Game) {
	if game.isAppleSpawned {
		return
	}
	rand.reset(u64(time.now()._nsec))
	x := rand.int31() % AREA_SIZE
	y := rand.int31() % AREA_SIZE
	game.applePos = {f32(x), f32(y)}
	game.isAppleSpawned = true
}

draw_game :: proc(game: Game) {
	for row in 0 ..< AREA_SIZE {
		for col in 0 ..< AREA_SIZE {
			pos := Vec2{f32(col) * COL_WIDTH, f32(row) * COL_WIDTH}
			draw_square(pos, COL_WIDTH, AREA_BG1 if (row + col) % 2 == 0 else AREA_BG2)
		}
	}
	#partial switch game.state {
	case .Playing:
		draw_snake(game.snake^)
		if game.isAppleSpawned {draw_apple(game.applePos)}
	case .Neural:
		neuralMessage :: "PRESS W, A, S, D or ↑ ← ↓ → TO START PLAYING"
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
	}
}
draw_apple :: proc(apple: Vec2) {
	draw_square(apple * COL_WIDTH, COL_WIDTH, APPLE_COLOR)
}

draw_square :: proc(pos: Vec2, scale: f32, color: rl.Color) {
	rec := rl.Rectangle {
		x      = pos.x,
		y      = pos.y,
		width  = 1 * scale,
		height = 1 * scale,
	}
	rl.DrawRectangleRec(rec, color)
}

new_square :: proc(pos: Vec2, width: f32) -> rl.Rectangle {
	return rl.Rectangle{pos.x, pos.y, width, width}
}

check_collisions :: proc(game: ^Game) {
	snakeHeadRec := new_square(game.snake.headScreenPos, COL_WIDTH)
	// apple collision
	if rl.CheckCollisionRecs(snakeHeadRec, new_square(game.applePos * COL_WIDTH, COL_WIDTH)) {
		game.snake.shouldGrow = true
		game.isAppleSpawned = false
	}
}

handle_keys :: proc(game: ^Game) {
	switch {
	case rl.IsKeyPressed(.W), rl.IsKeyPressed(.UP):
		game.snake.direction = Vec2{0, -1}
		game.state = .Playing
	case rl.IsKeyPressed(.S), rl.IsKeyPressed(.DOWN):
		game.snake.direction = Vec2{0, 1}
		game.state = .Playing
	case rl.IsKeyPressed(.A), rl.IsKeyPressed(.LEFT):
		game.snake.direction = Vec2{-1, 0}
		game.state = .Playing
	case rl.IsKeyPressed(.D), rl.IsKeyPressed(.RIGHT):
		game.snake.direction = Vec2{1, 0}
		game.state = .Playing
	case rl.IsKeyPressed(.SPACE):
		game.state = game.state == .Paused ? .Playing : .Paused
	}
}


main :: proc() {
	rl.InitWindow(INITIAL_WINDOW_WIDTH, INITIAL_WINDOW_HEIGHT, TITLE)
	defer rl.CloseWindow()
	rl.InitAudioDevice()
	rl.SetTargetFPS(144)
	startingPos := Vec2{10, 10}
	game := Game {
		snake          = &Snake {
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
			speed = SNAKE_SPEED,
		},
		applePos       = Vec2{},
		isAppleSpawned = false,
	}
	fmt.printfln("game = %v", game)

	for !rl.WindowShouldClose() {
		spawn_apple(&game)
		check_collisions(&game)
		handle_keys(&game)
		fmt.printfln("game = %v", game)
		prepare: {
			#partial switch game.state {
			case .Paused:
				break prepare
			case .Lost:

			}
			delta := rl.GetFrameTime()
			move(game.snake)
			calc_snake_screen_pos(game.snake, delta)
		}
		rl.BeginDrawing()
		{
			rl.ClearBackground(rl.BLANK)
			draw_game(game)

		}
		rl.EndDrawing()
	}
}

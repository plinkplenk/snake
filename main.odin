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

main :: proc() {
	rl.SetConfigFlags(rl.ConfigFlags({.MSAA_4X_HINT, .WINDOW_HIGHDPI}))
	rl.InitWindow(INITIAL_WINDOW_WIDTH, INITIAL_WINDOW_HEIGHT, TITLE)
	defer rl.CloseWindow()
	rl.InitAudioDevice()
	rl.SetTargetFPS(rl.GetMonitorRefreshRate(rl.GetCurrentMonitor()))
	game := new_game(Vec2{AREA_SIDE_LEN / 2, AREA_SIDE_LEN / 2}, SNAKE_SPEED, COL_WIDTH)
	for !rl.WindowShouldClose() {
		game->check_collisions()
		game->handle_keys()
		prepare: {
			if game.state == .Paused || game.state == .Lost {
				break prepare
			}
			delta := rl.GetFrameTime()
			game.snake->move()
			game.snake->calc_screen_pos(delta)
		}
		rl.BeginDrawing()
		{
			rl.ClearBackground(rl.BLANK)
			game->draw()
		}
		rl.EndDrawing()
		game->spawn_apple()
	}
}

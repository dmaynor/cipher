import json
import time
import os
import platform
import sys

from theme import Theme
from mechanics import GameMechanics
from level import Level
from utilities import detect_os, clear_screen, get_terminal_size
from nmap_parser import parse_nmap_xml, generate_seed_from_host, get_level_parameters

class Game:
    def __init__(self):
        self.load_settings()
        self.player = None
        self.levels = []
        self.current_level = None
        self.os_type = detect_os()
        self.theme = Theme(self.os_type)
        self.mechanics = GameMechanics(self.os_type)

    def load_settings(self):
        with open('cipher_game_settings.json', 'r') as f:
            self.settings = json.load(f)

    def generate_levels_from_nmap(self, nmap_file):
        try:
            hosts = parse_nmap_xml(nmap_file)
            if not hosts or len(hosts) == 0:
                print("No hosts found in the nmap scan file. Please check the file and try again.")
                return False

            for host in hosts:
                seed = generate_seed_from_host(host)
                random.seed(seed)
                level_params = get_level_parameters(host)
                level_params['enemies'] = self.settings['enemies']
                level_params['items'] = self.settings['items']
                width, height = get_terminal_size()
                self.levels.append(Level(width, height, level_params, self.theme, self.mechanics))
            
            print(f"Generated {len(self.levels)} levels from the nmap scan.")
            return True
        except Exception as e:
            print(f"Error generating levels from nmap file: {e}")
            return False

    def start_level(self, level_index):
        self.current_level = self.levels[level_index]
        self.refresh_screen()
        print(f"Running on {self.os_type.capitalize()} | Terminal size: {get_terminal_size()}")
        print(f"Entering level: {self.current_level.params['name']}")
        time.sleep(2)

    def get_key(self):
        if self.os_type == 'windows':
            return msvcrt.getch().decode('utf-8')
        else:
            fd = sys.stdin.fileno()
            old_settings = termios.tcgetattr(fd)
            try:
                tty.setraw(sys.stdin.fileno())
                ch = sys.stdin.read(1)
            finally:
                termios.tcsetattr(fd, termios.TCSADRAIN, old_settings)
            return ch

    def move_player(self, direction):
        dx, dy = {'w': (0, -1), 'a': (-1, 0), 's': (0, 1), 'd': (1, 0)}[direction]
        new_x = self.current_level.player.x + dx
        new_y = self.current_level.player.y + dy
        if 0 <= new_x < self.current_level.width and 0 <= new_y < self.current_level.height:
            if self.current_level.map[new_y][new_x] != self.theme.wall:
                self.current_level.player.x = new_x
                self.current_level.player.y = new_y
                self.check_for_interactions()

    def check_for_interactions(self):
        player = self.current_level.player
        for item in self.current_level.items[:]:
            if abs(item.x - player.x) <= 1 and abs(item.y - player.y) <= 1:
                print(f"You picked up {item.name}!")
                player.inventory.append(item.name)
                self.current_level.items.remove(item)
                self.refresh_screen()
                input("Press Enter to continue...")
                return

        for enemy in self.current_level.enemies[:]:
            if abs(enemy.x - player.x) <= 1 and abs(enemy.y - player.y) <= 1:
                print(f"You engaged {enemy.name}!")
                # Simple combat mechanic
                player.health -= 10
                self.current_level.enemies.remove(enemy)
                self.refresh_screen()
                input("Press Enter to continue...")
                return

    def refresh_screen(self):
        clear_screen()
        self.current_level.draw()
        print(f"\nHealth: {self.current_level.player.health} | Inventory: {', '.join(self.current_level.player.inventory)}")
        print("Move: WASD | Interact: I | Quit: Q")

    def game_loop(self):
        while True:
            self.refresh_screen()
            key = self.get_key().lower()
            if key == 'q':
                break
            elif key in ['w', 'a', 's', 'd']:
                self.move_player(key)
            elif key == 'i':
                self.check_for_interactions()

            if self.current_level.player.health <= 0:
                print("Game Over! You have been defeated.")
                break

    def start(self):
        print(f"Welcome to CIPHER - Running on {self.os_type.capitalize()}")
        while True:
            nmap_file = input("Enter the path to the nmap XML file: ")
            if self.generate_levels_from_nmap(nmap_file):
                break
            else:
                print("Failed to generate levels. Please try again with a different file.")

        if self.levels:
            for i, level in enumerate(self.levels):
                self.start_level(i)
                self.game_loop()
                if i < len(self.levels) - 1:
                    input("Press Enter to proceed to the next level...")
        else:
            print("No levels were generated. Exiting the game.")

if __name__ == "__main__":
    game = Game()
    game.start()

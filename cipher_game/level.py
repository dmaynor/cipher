import random

from player import Player
from enemy import Enemy
from item import Item

class Level:
    def __init__(self, width, height, params, theme, mechanics):
        self.width = width
        self.height = height
        self.params = params
        self.theme = theme
        self.mechanics = mechanics
        self.player = Player(width // 2, height // 2, mechanics.player_speed)
        self.map = self.create_map()
        self.enemies = []
        self.items = []
        self.generate_content()

    def create_map(self):
        # Create a basic map with walls around the edges
        map = [[self.theme.empty for _ in range(self.width)] for _ in range(self.height)]
        for y in range(self.height):
            for x in range(self.width):
                if x == 0 or x == self.width - 1 or y == 0 or y == self.height - 1:
                    map[y][x] = self.theme.wall
        map[self.player.y][self.player.x] = self.theme.empty  # Ensure player starts on an empty space
        return map

    def generate_content(self):
        num_enemies = int(self.width * self.height * 0.01 * self.mechanics.enemy_spawn_rate)
        num_items = int(self.width * self.height * 0.005 * self.mechanics.item_spawn_rate)

        for _ in range(num_enemies):
            x, y = self.get_random_empty_position()
            enemy_type = random.choice(self.params['enemies'])
            self.enemies.append(Enemy(x, y, enemy_type['char'], enemy_type['name']))

        for _ in range(num_items):
            x, y = self.get_random_empty_position()
            item_type = random.choice(self.params['items'])
            self.items.append(Item(x, y, item_type['char'], item_type['name']))

    def get_random_empty_position(self):
        while True:
            x = random.randint(1, self.width - 2)
            y = random.randint(1, self.height - 2)
            if self.map[y][x] == self.theme.empty:
                return x, y

    def draw(self):
        for y in range(self.height):
            for x in range(self.width):
                if (x, y) == (self.player.x, self.player.y):
                    print(self.theme.player, end='')
                elif any(e.x == x and e.y == y for e in self.enemies):
                    enemy = next(e for e in self.enemies if e.x == x and e.y == y)
                    print(enemy.char, end='')
                elif any(i.x == x and i.y == y for i in self.items):
                    item = next(i for i in self.items if i.x == x and i.y == y)
                    print(item.char, end='')
                else:
                    print(self.map[y][x], end='')
            print()

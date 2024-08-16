class GameMechanics:
    def __init__(self, os_type):
        self.os_type = os_type
        self.set_mechanics()

    def set_mechanics(self):
        if self.os_type == 'windows':
            self.player_speed = 1
            self.enemy_spawn_rate = 0.8
            self.item_spawn_rate = 1.2
        elif self.os_type == 'linux':
            self.player_speed = 1.2
            self.enemy_spawn_rate = 1
            self.item_spawn_rate = 1
        elif self.os_type == 'macos':
            self.player_speed = 1.1
            self.enemy_spawn_rate = 0.9
            self.item_spawn_rate = 1.1
        else:
            # Default mechanics
            self.player_speed = 1
            self.enemy_spawn_rate = 1
            self.item_spawn_rate = 1

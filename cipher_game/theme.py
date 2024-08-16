class Theme:
    def __init__(self, os_type):
        self.os_type = os_type
        self.set_theme()

    def set_theme(self):
        if self.os_type == 'windows':
            self.wall = '█'
            self.player = '☺'
            self.enemy = '☠'
            self.item = '♦'
            self.empty = '·'
        elif self.os_type == 'linux':
            self.wall = '▒'
            self.player = '@'
            self.enemy = 'E'
            self.item = '*'
            self.empty = '.'
        elif self.os_type == 'macos':
            self.wall = '▓'
            self.player = '◉'
            self.enemy = '◆'
            self.item = '★'
            self.empty = '·'
        else:
            # Default theme
            self.wall = '#'
            self.player = '@'
            self.enemy = 'E'
            self.item = '*'
            self.empty = '.'

#!/bin/bash

# Set the base directory
BASE_DIR="cipher_game"
SCANS_DIR="$BASE_DIR/scans"

# Create the directory structure
mkdir -p $BASE_DIR
mkdir -p $SCANS_DIR

# Create the files
echo "Creating game.py..."
cat <<EOL > $BASE_DIR/game.py
import json
import time
import os
import platform
import sys

from theme import Theme
from mechanics import GameMechanics
from level import Level
from utilities import detect_os, clear_screen, get_terminal_size, find_sample_nmap_file
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

    def generate_levels_from_nmap(self, nmap_file=None):
        try:
            if nmap_file is None:
                nmap_file = find_sample_nmap_file()

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
            nmap_file = find_sample_nmap_file()
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
EOL

echo "Creating theme.py..."
cat <<EOL > $BASE_DIR/theme.py
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
EOL

echo "Creating mechanics.py..."
cat <<EOL > $BASE_DIR/mechanics.py
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
EOL

echo "Creating player.py..."
cat <<EOL > $BASE_DIR/player.py
class Player:
    def __init__(self, x, y, speed):
        self.x = x
        self.y = y
        self.speed = speed
        self.health = 100
        self.inventory = []
EOL

echo "Creating enemy.py..."
cat <<EOL > $BASE_DIR/enemy.py
class Enemy:
    def __init__(self, x, y, char, name):
        self.x = x
        self.y = y
        self.char = char
        self.name = name
EOL

echo "Creating item.py..."
cat <<EOL > $BASE_DIR/item.py
class Item:
    def __init__(self, x, y, char, name):
        self.x = x
        self.y = y
        self.char = char
        self.name = name
EOL

echo "Creating level.py..."
cat <<EOL > $BASE_DIR/level.py
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
EOL

echo "Creating utilities.py..."
cat <<EOL > $BASE_DIR/utilities.py
import os
import platform

def detect_os():
    system = platform.system().lower()
    if system == 'windows':
        return 'windows'
    elif system == 'linux':
        return 'linux'
    elif system == 'darwin':
        return 'macos'
    else:
        return 'unknown'

def clear_screen():
    os.system('cls' if detect_os() == 'windows' else 'clear')

def get_terminal_size():
    return os.get_terminal_size()

def find_sample_nmap_file():
    scans_dir = os.path.join(os.path.dirname(__file__), 'scans')
    for root, dirs, files in os.walk(scans_dir):
        for file in files:
            if file.endswith('.xml'):
                return os.path.join(root, file)
    return None
EOL

# Create a sample nmap scan XML file
echo "Creating sample nmap scan file..."
cat <<EOL > $SCANS_DIR/sample_nmap_scan.xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE nmaprun>
<?xml-stylesheet href="file:///usr/bin/../share/nmap/nmap.xsl" type="text/xsl"?>
<nmaprun scanner="nmap" args="nmap -oX sample_nmap_scan.xml localhost" start="1629868800" startstr="Wed Aug 25 00:00:00 2024" version="7.91" xmloutputversion="1.05">
<scaninfo type="syn" protocol="tcp" numservices="1000" services="1,3-4,6-7,9,13,17,19-26,30,32-33,37,42-43,49,53,70,79-85,88-90,99-100,106,109-111,113,119,125,135,139,143-144,146,161,163,179,199,211-212,222,254-256,259,264,280,301,306,311,340,366,389,406-407,416-417,425,427,443-445,458,464-465,481,497,500,512-515,524,541,543-545,548,554-555,563,587,593,616-617,625,631,636,646,648,666-668,683,687,691,700,705,711,714,720,722,726,749,765,777,783,787,800-801,808,843,873,880,888,898,900-903,911-912,981,987,990,992-993,995,999-1002,1007,1009-1011,1021-1100,1102,1104-1108,1110-1114,1117,1119,1121-1124,1126,1130-1132,1137-1138,1141,1145,1147-1149,1151-1152,1154,1163-1166,1169,1174-1175,1183,1185-1187,1192,1198-1199,1201,1213,1216-1218,1233-1234,1236,1244,1247-1248,1259,1271-1272,1277,1287,1296,1300-1301,1309-1311,1322,1328,1334,1352,1417,1433-1434,1443,1455,1461,1494,1500-1501,1503,1521,1524,1533,1556,1580,1583,1594,1600,1641,1658,1666,1687-1688,1700,1717-1721,1723,1755,1761,1782-1783,1801,1805,1812,1839-1840,1862-1864,1875,1900,1914,1935,1947,1971-1972,1974,1984,1998-2010,2013,2020-2022,2030,2033-2035,2038,2040-2043,2045-2049,2065,2068,2099-2100,2103,2105-2107,2111,2119,2121,2126,2135,2144,2160-2161,2170,2179,2190-2191,2196,2200,2222,2251,2260,2288,2301,2323,2366,2381-2383,2393-2394,2399,2401,2492,2500,2522,2525,2557,2601-2602,2604-2605,2607-2608,2638,2701-2702,2710,2717-2718,2725,2800,2809,2811,2869,2875,2909-2910,2920,2967-2968,2998,3000-3001,3003,3005-3007,3011,3013,3017,3030-3031,3052,3071,3077,3128,3168,3211,3221,3260-3261,3268-3269,3283,3300-3301,3306,3322-3325,3333,3351,3367,3369-3372,3389-3390,3404,3476,3493,3517,3527,3546,3551,3580,3659,3689-3690,3703,3737,3766,3784,3800-3801,3809,3814,3826-3828,3851,3869,3871,3878,3880,3889,3905,3914,3918,3920,3945,3971,3986,3995,3998,4000-4006,4045,4111,4125-4126,4129,4224,4242,4279,4321,4343,4443-4446,4449,4550,4567,4662,4848,4899-4900,4998,5000-5004,5009,5030,5033,5050-5051,5054,5060-5061,5080,5087,5100-5102,5120,5190,5200,5214,5221-5222,5225-5226,5269,5280,5298,5357,5405,5414,5431-5432,5440,5500,5510,5544,5550,5555,5560,5566,5631,5633,5666,5678-5679,5718,5730,5800-5802,5810-5811,5815,5822,5825,5850,5859,5862,5877,5900-5904,5906-5907,5910-5911,5915,5922,5925,5950,5952,5959-5963,5987-5989,5998-6007,6009,6025,6059,6100-6101,6106,6112,6123,6129,6156,6346,6389,6502,6510,6543,6547,6565-6567,6580,6646,6666-6669,6689,6692,6699,6779,6788-6789,6792,6839,6881,6901,6969,7000-7002,7004,7007,7019,7025,7070,7100,7103,7106,7200-7201,7402,7435,7443,7496,7512,7625,7627,7676,7741,7777-7778,7800,7911,7920-7921,7937-7938,7999-8002,8007-8011,8021-8022,8031,8042,8045,8080-8090,8093,8099-8100,8180-8181,8192-8194,8200,8222,8254,8290-8292,8300,8333,8383,8400,8402,8443,8500,8600,8649,8651-8652,8654,8701,8800,8873,8888,8899,8994,9000-9003,9009-9011,9040,9050,9071,9080-9081,9090-9091,9099-9103,9110-9111,9200,9207,9220,9290,9415,9418,9485,9500,9502-9503,9535,9575,9593-9595,9618,9666,9876-9878,9898,9900,9917,9929,9943-9944,9968,9998-10004,10009-10010,10012,10024-10025,10082,10180,10215,10243,10566,10616-10617,10621,10626,10628-10629,10778,11110-11111,11967,12000,12174,12265,12345,13456,13722,13782-13783,14000,14238,14441-14442,15000,15002-15004,15660,15742,16000-16001,16012,16016,16018,16080,16113,16992-16993,17877,17988,18040,18101,18988,19101,19283,19315,19350,19780,19801,19842,20000,20005,20031,20221-20222,20828,21571,22939,23502,24444,24800,25734-25735,26214,27000,27352-27353,27355-27356,27715,28201,30000,30718,30951,31038,31337,32768-32785,33354,33899,34571-34573,35500,38292,40193,40911,41511,42510,44176,44442-44443,44501,45100,48080,49152-49161,49163,49165,49167,49175-49176,49400,49999-50003,50006,50300,50389,50500,50636,50800,51103,51493,52673,52822,52848,52869,54045,54328,55055-55056,55555,55600,56737-56738,57294,57797,58080,60020,60443,61532,61900,62078,63331,64623,64680,65000,65129,65389"/>
<verbose level="0"/>
<debugging level="0"/>
<host starttime="1629868800" endtime="1629868805"><status state="up" reason="localhost-response" reason_ttl="0"/>
<address addr="127.0.0.1" addrtype="ipv4"/>
<hostnames>
<hostname name="localhost" type="user"/>
<hostname name="localhost" type="PTR"/>
</hostnames>
<ports><extraports state="closed" count="997">
<extrareasons reason="resets" count="997"/>
</extraports>
<port protocol="tcp" portid="22"><state state="open" reason="syn-ack" reason_ttl="64"/><service name="ssh" product="OpenSSH" version="8.2p1 Ubuntu 4ubuntu0.3" extrainfo="Ubuntu Linux; protocol 2.0" ostype="Linux" method="probed" conf="10"><cpe>cpe:/a:openbsd:openssh:8.2p1</cpe><cpe>cpe:/o:linux:linux_kernel</cpe></service></port>
<port protocol="tcp" portid="80"><state state="open" reason="syn-ack" reason_ttl="64"/><service name="http" product="Apache httpd" version="2.4.41" extrainfo="(Ubuntu)" method="probed" conf="10"><cpe>cpe:/a:apache:http_server:2.4.41</cpe></service></port>
<port protocol="tcp" portid="3306"><state state="open" reason="syn-ack" reason_ttl="64"/><service name="mysql" product="MySQL" version="8.0.26-0ubuntu0.20.04.2" method="probed" conf="10"><cpe>cpe:/a:mysql:mysql:8.0.26-0ubuntu0.20.04.2</cpe></service></port>
</ports>
<os><portused state="open" proto="tcp" portid="22"/>
<portused state="closed" proto="tcp" portid="1"/>
<portused state="closed" proto="udp" portid="31180"/>
<osmatch name="Linux 4.15 - 5.6" accuracy="95" line="65686">
<osclass type="general purpose" vendor="Linux" osfamily="Linux" osgen="4.X" accuracy="95"><cpe>cpe:/o:linux:linux_kernel:4</cpe></osclass>
<osclass type="general purpose" vendor="Linux" osfamily="Linux" osgen="5.X" accuracy="95"><cpe>cpe:/o:linux:linux_kernel:5</cpe></osclass>
</osmatch>
</os>
<uptime seconds="851194" lastboot="Wed Aug 15 12:00:11 2024"/>
<tcpsequence index="258" difficulty="Good luck!" values="9D8210A1,6645DADA,123A1E4,13F8E940,F13F0FEC,1641AA11"/>
<ipidsequence class="All zeros" values="0,0,0,0,0,0"/>
<tcptssequence class="1000HZ" values="323D1037,323D109B,323D10FF,323D1163,323D11C7,323D122B"/>
<times srtt="76" rttvar="1625" to="100000"/>
</host>
<runstats><finished time="1629868805" timestr="Wed Aug 25 00:00:05 2024" summary="Nmap done: 1 IP address (1 host up) scanned in 5.00 seconds" elapsed="5.00" exit="success"/><hosts up="1" down="0" total="1"/>
</runstats>
</nmaprun>
EOL

echo "All files and directories created successfully!"

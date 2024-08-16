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

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

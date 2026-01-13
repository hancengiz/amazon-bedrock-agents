"""
Sample code with intentional issues for code review testing.
This file demonstrates various problems the AI reviewer should catch.
"""

import os
import pickle
import subprocess

# =============================================================================
# SECURITY ISSUES
# =============================================================================

def get_user_by_id(user_id):
    """SQL Injection vulnerability."""
    query = "SELECT * FROM users WHERE id = " + user_id
    return execute_query(query)


def run_command(user_input):
    """Command injection vulnerability."""
    os.system("echo " + user_input)
    subprocess.call(user_input, shell=True)


def load_user_data(data):
    """Insecure deserialization."""
    return pickle.loads(data)


def authenticate(password):
    """Hardcoded credentials."""
    SECRET_PASSWORD = "admin123"
    return password == SECRET_PASSWORD


API_KEY = "sk-1234567890abcdef"  # Exposed secret


def read_file(filename):
    """Path traversal vulnerability."""
    with open("/var/data/" + filename, "r") as f:
        return f.read()


# =============================================================================
# PERFORMANCE ISSUES
# =============================================================================

def calculate_sum(numbers):
    """Inefficient - should use sum()."""
    total = 0
    for n in numbers:
        total = total + n
    return total


def find_duplicates(items):
    """O(n²) when O(n) is possible with a set."""
    duplicates = []
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            if items[i] == items[j]:
                if items[i] not in duplicates:
                    duplicates.append(items[i])
    return duplicates


def get_all_users():
    """N+1 query problem simulation."""
    users = fetch_users()  # Query 1
    for user in users:
        user['orders'] = fetch_orders(user['id'])  # Query N
    return users


def process_large_file(filepath):
    """Memory issue - loads entire file."""
    with open(filepath) as f:
        data = f.read()  # Could be gigabytes
    return data.split('\n')


def string_concat(items):
    """Inefficient string concatenation."""
    result = ""
    for item in items:
        result = result + str(item) + ", "
    return result


# =============================================================================
# CODE QUALITY ISSUES
# =============================================================================

def x(a, b, c):
    """Bad naming - unclear function and parameter names."""
    return a + b * c


def processData(data):
    """Inconsistent naming (camelCase vs snake_case)."""
    pass


def do_everything(user_id, send_email, update_db, notify_admin, log_action):
    """Function does too many things - violates single responsibility."""
    user = get_user(user_id)
    if send_email:
        send_welcome_email(user)
    if update_db:
        update_user_status(user)
    if notify_admin:
        notify_admin_user_created(user)
    if log_action:
        log_user_action(user)
    return user


def get_status(code):
    """Long if-else chain - should use dict mapping."""
    if code == 1:
        return "pending"
    elif code == 2:
        return "active"
    elif code == 3:
        return "suspended"
    elif code == 4:
        return "deleted"
    elif code == 5:
        return "archived"
    else:
        return "unknown"


def divide(a, b):
    """No error handling for division by zero."""
    return a / b


def parse_config(config_str):
    """No input validation."""
    config = eval(config_str)  # Also a security issue!
    return config['setting']


class user:  # Should be User (PascalCase)
    """Class name should be PascalCase."""

    def __init__(self):
        self.Name = ""  # Inconsistent attribute naming
        self.email_address = ""
        self.isActive = True


# Magic numbers without explanation
def calculate_price(base_price):
    """Magic numbers should be constants."""
    return base_price * 1.0825 * 0.95 + 4.99


# Duplicated code
def validate_email(email):
    if "@" not in email:
        return False
    if "." not in email:
        return False
    if len(email) < 5:
        return False
    return True


def validate_username(username):
    if "@" in username:  # Similar logic, should be refactored
        return False
    if len(username) < 3:
        return False
    return True


# Dead code
def unused_function():
    """This function is never called."""
    print("I'm never used")


UNUSED_CONSTANT = "never used"


# Missing docstrings
def complex_calculation(data, factor, offset, precision):
    result = ((data * factor) + offset) / precision
    return round(result, 2)


# Bare except
def risky_operation():
    try:
        do_something_dangerous()
    except:  # Too broad, catches everything including KeyboardInterrupt
        pass  # Silent failure


# Global state mutation
global_counter = 0

def increment():
    """Mutates global state - hard to test and debug."""
    global global_counter
    global_counter += 1
    return global_counter


# =============================================================================
# STUB FUNCTIONS (for the above to reference)
# =============================================================================

def execute_query(q): pass
def fetch_users(): return []
def fetch_orders(uid): return []
def get_user(uid): return {}
def send_welcome_email(u): pass
def update_user_status(u): pass
def notify_admin_user_created(u): pass
def log_user_action(u): pass
def do_something_dangerous(): pass


if __name__ == "__main__":
    # Test some functions
    print(calculate_sum([1, 2, 3, 4, 5]))
    print(get_status(2))

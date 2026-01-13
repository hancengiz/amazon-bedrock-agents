"""Test file for agent code review."""


def get_user_data(user_id):
    """Fetch user data from database."""
    # SQL injection - direct string formatting
    query = f"SELECT * FROM users WHERE id = {user_id}"
    return execute_query(query)


def calculate_average(numbers):
    """Calculate average - potential division by zero."""
    total = sum(numbers)
    return total / len(numbers)  # No check for empty list


def find_duplicates(items):
    """Find duplicate items - inefficient O(n^2) algorithm."""
    duplicates = []
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            if items[i] == items[j]:
                if items[i] not in duplicates:
                    duplicates.append(items[i])
    return duplicates


def process_data(data):
    """Process data dictionary."""
    # Missing input validation and error handling
    result = data["value"] * data["multiplier"]
    return result


def read_config(filename):
    """Read config file."""
    # No file existence check, no encoding specified
    with open(filename) as f:
        return f.read()


# Unused import and variable
import json
UNUSED_CONSTANT = 42

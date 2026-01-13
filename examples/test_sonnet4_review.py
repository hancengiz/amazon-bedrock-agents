"""Test file for Sonnet 4 agent review."""

import subprocess
import pickle


def get_user_data(user_id):
    """Fetch user data from database."""
    # SQL injection vulnerability
    query = f"SELECT * FROM users WHERE id = {user_id}"
    return execute_query(query)


def process_file(filename):
    """Process uploaded file."""
    # Command injection vulnerability
    result = subprocess.call(f"cat {filename}", shell=True)
    return result


def load_config(data):
    """Load configuration from data."""
    # Insecure deserialization
    return pickle.loads(data)


def find_duplicates(items):
    """Find duplicate items - inefficient O(n^2)."""
    duplicates = []
    for i in range(len(items)):
        for j in range(i + 1, len(items)):
            if items[i] == items[j]:
                if items[i] not in duplicates:
                    duplicates.append(items[i])
    return duplicates


class DataProcessor:
    def process(self, data):
        # No input validation
        result = data["value"] * data["multiplier"]
        return result

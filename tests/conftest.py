#!/usr/bin/env python3
"""
Pytest configuration file for my_tar.sh test suite
"""

import pytest
import sys
import os

# Add project root to Python path if needed
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def pytest_configure(config):
    """Pytest configuration hook"""
    config.addinivalue_line(
        "markers", "slow: marks tests as slow (deselect with '-m \"not slow\"')"
    )
    config.addinivalue_line(
        "markers", "integration: marks tests as integration tests"
    )


@pytest.fixture(scope="session")
def project_root():
    """Get the project root directory"""
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


@pytest.fixture(scope="session")
def script_path(project_root):
    """Get the path to my_tar.sh script"""
    return os.path.join(project_root, "my_tar.sh")

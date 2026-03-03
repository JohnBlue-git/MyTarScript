#!/bin/bash
# Quick test runner script for my_tar.sh

echo "======================================"
echo "My Tar Package Script - Test Runner"
echo "======================================"
echo ""

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo "❌ pytest is not installed"
    echo "📦 Installing test dependencies..."
    pip install -r requirements-test.txt
    echo ""
fi

# Check if script is executable
if [ ! -x "./my_tar.sh" ]; then
    echo "🔧 Making my_tar.sh executable..."
    chmod +x my_tar.sh
    echo ""
fi

echo "🧪 Running tests..."
echo ""

# Run pytest with options
pytest tests/ -v --tb=short --color=yes

# Capture exit code
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed!"
else
    echo "❌ Some tests failed (exit code: $EXIT_CODE)"
fi

exit $EXIT_CODE

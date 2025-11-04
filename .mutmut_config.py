"""
Mutation Testing Configuration for EvidenceOS PRIME
Uses mutmut to test the quality of tests, not just coverage
"""

def pre_mutation(context):
    """
    Called before each mutation
    Can be used to skip certain mutations
    """
    # Skip test files
    if 'test_' in context.filename:
        context.skip = True

    # Skip generated files
    if '__pycache__' in context.filename:
        context.skip = True

    # Skip init files (usually just imports)
    if '__init__.py' in context.filename:
        context.skip = True


def post_mutation(context):
    """
    Called after each mutation
    Can be used for cleanup or logging
    """
    pass


# Paths to mutate
paths_to_mutate = [
    'backend/api/',
    'backend/etl/',
    'backend/cache/',
    'backend/utils/',
    'backend/middleware/',
]

# Paths to exclude
paths_to_exclude = [
    '**/test_*.py',
    '**/__pycache__/**',
    '**/tests/**',
]

# Test command
test_command = 'pytest tests/py/ -x --tb=no -q'

# Coverage command (optional)
coverage_command = 'pytest tests/py/ --cov=backend --cov-report=term-missing'

# Runner (default is pytest)
runner = 'pytest'

# Timeout for each test run (in seconds)
# Increase if you have slow tests
timeout = 300

# Dict of counts for mutation operators
# Can be used to prioritize certain mutation types
mutation_types_to_apply = None  # None = apply all

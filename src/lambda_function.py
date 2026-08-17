"""
lambda_function.py

Minimal AWS Lambda handler for the Shift-Left Security CI/CD lab.
Business logic is kept in a pure function (build_greeting) so it can be
unit-tested with pytest without needing to mock the AWS Lambda runtime.
"""
import json


def build_greeting(name: str) -> str:
    """Pure, easily-testable business logic separated from the handler."""
    if not name:
        name = "world"
    return f"Hello, {name}!"


def lambda_handler(event, context):
    """AWS Lambda entry point. `event` and `context` are provided by AWS at invoke time."""
    name = event.get("name", "world") if isinstance(event, dict) else "world"
    message = build_greeting(name)
    return {
        "statusCode": 200,
        "body": json.dumps({"message": message}),
    }

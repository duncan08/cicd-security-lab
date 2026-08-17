"""
Unit tests for lambda_function.py

Run with: python3 -m pytest -v
"""
from lambda_function import build_greeting, lambda_handler
import json


def test_build_greeting_with_name():
    assert build_greeting("Rafael") == "Hello, Rafael!"


def test_build_greeting_default_when_empty():
    assert build_greeting("") == "Hello, world!"


def test_lambda_handler_returns_200():
    response = lambda_handler({"name": "Rafael"}, None)
    assert response["statusCode"] == 200
    body = json.loads(response["body"])
    assert body["message"] == "Hello, Rafael!"


def test_lambda_handler_defaults_when_no_name():
    response = lambda_handler({}, None)
    body = json.loads(response["body"])
    assert body["message"] == "Hello, world!"

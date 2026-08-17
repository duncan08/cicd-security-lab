"""
NEGATIVE TEST FIXTURE — intentionally insecure code.

This file exists ONLY to prove Bandit's SAST scanner catches real
vulnerability patterns. It is never imported by src/, never deployed,
and is excluded from the mandatory CI SAST gate (which scans src/ only).

Do not "fix" these findings — that would defeat the purpose of this file.
"""
import hashlib
import subprocess


def insecure_hardcoded_password():
    # B105: hardcoded password string
    password = "SuperSecret123!"
    return password


def insecure_eval(user_input):
    # B307: use of eval() on arbitrary/untrusted input
    return eval(user_input)


def insecure_hash(data):
    # B303/B324: MD5 is not a secure hash for security-sensitive use
    return hashlib.md5(data.encode()).hexdigest()


def insecure_shell_command(user_input):
    # B602: subprocess call with shell=True — shell injection risk
    subprocess.call(f"echo {user_input}", shell=True)

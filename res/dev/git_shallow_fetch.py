#!/usr/bin/env python3
"""Limit Cargo's exact-commit dependency fetches to one history level."""
import os
import re
import sys

arguments = sys.argv[1:]
configuration = []
if "fetch" in arguments and any(
    re.fullmatch(r"\+[0-9a-f]{40}:refs/commit/[0-9a-f]{40}", value)
    for value in arguments
):
    arguments.append("--depth=1")
    # A large GitHub transfer through the local proxy was truncated; an
    # HTTP/1.1 retry succeeded. Scope this to Cargo dependency fetches.
    configuration = ["-c", "http.version=HTTP/1.1"]
os.execv("/usr/bin/git", ["git", *configuration, *arguments])

#!/usr/bin/env python3
# vim: set et fenc=utf-8 ff=unix sts=4 sw=4 ts=8 :
# Poll GitHub Actions workflow run status

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
from datetime import datetime

# Colors
RED = "\033[0;31m"
GREEN = "\033[0;32m"
YELLOW = "\033[1;33m"
BLUE = "\033[0;34m"
NC = "\033[0m"

# Constants
TIMESTAMP_PATTERN = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}")
MICROSECOND_PATTERN = re.compile(r"\.\d+Z")
SPACE_SEP_PATTERN = re.compile(r"\s{2,}")
CONCLUSION_TO_STATE = {
    "success": "success",
    "failure": "failed",
    "cancelled": "canceled",
}
STATE_COLORS = {
    "running": BLUE,
    "success": GREEN,
    "failed": RED,
    "canceled": RED,
}
STATE_SYMBOLS = {
    "success": "✓",
    "failed": "✗",
    "canceled": "✗",
}


def error_exit(msg: str, hint: str = "") -> None:
    """Print error and exit."""
    print(f"{RED}Error: {msg}{NC}")
    if hint:
        print(hint)
    sys.exit(1)


def run_cmd(cmd: list[str]) -> tuple[str, int]:
    """Run command and return (output, exit_code)."""
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        return result.stdout.strip(), result.returncode
    except FileNotFoundError:
        return "", 1


def check_dependency(cmd: str, install_hint: str) -> None:
    """Check if command exists, exit if not."""
    try:
        subprocess.run(["which", cmd], check=True, capture_output=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        error_exit(f"{cmd} not found", install_hint)


def get_json(cmd: list[str], key: str | None = None) -> dict | list | None:
    """Run gh command and parse JSON."""
    output, code = run_cmd(cmd)
    if code != 0 or not output:
        return None
    try:
        data = json.loads(output)
        return data.get(key) if key and isinstance(data, dict) else data
    except json.JSONDecodeError:
        return None


def get_git_info(cmd: list[str]) -> str | None:
    """Get git information."""
    output, code = run_cmd(cmd)
    return output if code == 0 and output else None


def find_workflow_run(branch: str, commit: str, workflow: str | None = None, max_wait: int = 300) -> str | None:
    """Find workflow run matching the commit."""
    print(f"{BLUE}Waiting for workflow run matching commit {commit[:7]} to appear...{NC}")
    start_time = time.time()

    while True:
        elapsed = int(time.time() - start_time)
        if elapsed > max_wait:
            return None

        cmd = ["gh", "run", "list", "--json", "headSha,databaseId"]
        if workflow:
            cmd.extend(["--workflow", workflow])
        if branch:
            cmd.extend(["--branch", branch])

        runs = get_json(cmd)
        if runs:
            for run in runs:
                if run.get("headSha") == commit:
                    run_id = str(run.get("databaseId", ""))
                    if run_id and run_id != "null":
                        print(f"{GREEN}Found workflow run matching commit {commit[:7]}: {run_id}{NC}")
                        return run_id

        time.sleep(5)
        print(f"{YELLOW}Waiting for workflow run... ({elapsed}s/{max_wait}s){NC}")


def get_run_state(run_id: str) -> str:
    """Get workflow run state."""
    data = get_json(["gh", "run", "view", run_id, "--json", "status,conclusion"])
    if not data or not isinstance(data, dict):
        return "unknown"

    status = data.get("status")
    conclusion = data.get("conclusion")

    if status == "completed":
        return CONCLUSION_TO_STATE.get(conclusion or "", "failed")
    if status in ("in_progress", "queued"):
        return "running"
    return "unknown"


def format_state(state: str, timestamp: str) -> str:
    """Format state message with color."""
    color = STATE_COLORS.get(state, "")
    symbol = STATE_SYMBOLS.get(state, "")
    symbol_str = f" {symbol}" if symbol else ""
    return f"{color}[{timestamp}] Workflow state: {state}{symbol_str}{NC}"


def display_jobs(jobs: list[dict]) -> None:
    """Display job results."""
    print(f"{BLUE}Job results:{NC}\n")

    for job in jobs:
        name = job.get("name", "")
        status = job.get("status", "")
        conclusion = job.get("conclusion", "")

        if conclusion == "success":
            print(f"  {GREEN}✓ {name}: success{NC}")
        elif conclusion in ("failure", "cancelled"):
            print(f"  {RED}✗ {name}: {conclusion}{NC}")
        elif status in ("in_progress", "queued"):
            print(f"  {YELLOW}⏳ {name}: {status}{NC}")
        else:
            print(f"  {name}: {status} ({conclusion})")
    print()


def parse_log_line(line: str, known_jobs: list[str]) -> tuple[str | None, str | None, str | None]:
    """Parse log line to extract (job_name, step_name, content)."""
    line = line.strip()
    if not line:
        return None, None, None

    # Remove microsecond timestamps (e.g., .2038901Z)
    line = MICROSECOND_PATTERN.sub("", line)

    match = TIMESTAMP_PATTERN.search(line)
    if not match:
        parts = line.split(None, 3)
        if not parts:
            return None, None, None
        return (parts[0], parts[1] if len(parts) > 1 else None, " ".join(parts[3:]) if len(parts) > 3 else "")

    job_step = line[: match.start()].rstrip()
    content = line[match.end() :].strip()

    # Try matching known job names (longest first)
    for job in sorted(known_jobs, key=len, reverse=True):
        if job and job_step.startswith(job):
            remaining = job_step[len(job) :]
            if SPACE_SEP_PATTERN.match(remaining):
                return job, remaining.strip(), content

    # Fallback: split on 2+ spaces
    parts = SPACE_SEP_PATTERN.split(job_step, 1)
    if len(parts) >= 2:
        return parts[0].strip(), parts[1].strip(), content
    if parts:
        words = parts[0].split()
        return (words[0] if words else None, " ".join(words[1:]) if len(words) > 1 else None, content)
    return None, None, None


def display_failed_logs(run_id: str, failed_jobs: list[dict]) -> None:
    """Display failed job logs with formatting."""
    print(f"{BLUE}Fetching failed logs...{NC}")
    output, code = run_cmd(["gh", "run", "view", run_id, "--log-failed"])

    if code != 0 or not output:
        print(f"{YELLOW}Could not fetch logs automatically{NC}")
        print(f"{YELLOW}You can view logs manually using: gh run view {run_id} --log-failed{NC}")
        return

    known_jobs = [j["name"] for j in failed_jobs if j.get("name")]
    print(f"{RED}Failed job logs (last 200 lines):{NC}\n")

    current_job = None
    last_printed_step = None
    for line in output.split("\n")[-200:]:
        job_name, step_name, content = parse_log_line(line, known_jobs)
        if not job_name:
            continue

        if job_name != current_job:
            if current_job:
                print()
            print(f"  {BLUE}[JOB]{NC} {job_name}")
            current_job = job_name
            last_printed_step = None

        # Only print step if it's different from the last printed step
        if step_name and step_name != last_printed_step:
            print(f"    {BLUE}[STEP]{NC} {step_name}")
            last_printed_step = step_name

        if content:
            print(f"    {content}")


def main():
    parser = argparse.ArgumentParser(description="Poll GitHub Actions workflow run status")
    parser.add_argument("-b", "--branch", help="Branch name (default: current branch)")
    parser.add_argument("-w", "--workflow", help="Workflow name or file (e.g., ci.yml)")
    parser.add_argument("-r", "--run-id", help="Specific run ID to poll")
    parser.add_argument("-i", "--interval", type=int, default=10, help="Poll interval in seconds (default: 10)")
    parser.add_argument("-m", "--max-wait", type=int, default=3600, help="Maximum wait time in seconds (default: 3600)")
    parser.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    args = parser.parse_args()

    # Check dependencies
    check_dependency("gh", "Install: https://cli.github.com/")
    _, code = run_cmd(["gh", "auth", "status"])
    if code != 0:
        error_exit("GitHub CLI not authenticated", "Run: gh auth login")

    # Get repository and git info
    repo_data = get_json(["gh", "repo", "view", "--json", "nameWithOwner"])
    repo = repo_data.get("nameWithOwner") if isinstance(repo_data, dict) else None
    if not repo or not isinstance(repo, str):
        error_exit("Not in a GitHub repository or gh CLI not configured")

    branch: str = args.branch or get_git_info(["git", "rev-parse", "--abbrev-ref", "HEAD"]) or ""
    if not branch:
        error_exit("Could not determine current branch")

    commit: str = get_git_info(["git", "rev-parse", "HEAD"]) or ""
    if not commit:
        error_exit("Not in a git repository or no HEAD commit")

    print(f"{BLUE}Repository: {repo}{NC}")
    print(f"{BLUE}Branch: {branch}{NC}")
    print(f"{BLUE}Last commit: {commit[:7]}{NC}")

    # Get or find run ID
    run_id: str = args.run_id or find_workflow_run(branch, commit, args.workflow) or ""
    if not run_id:
        error_exit(f"Could not find workflow run matching commit {commit[:7]}")

    if args.run_id:
        print(f"{BLUE}Using provided run ID: {run_id}{NC}")

    print(f"{BLUE}Polling workflow run: {run_id}{NC}")
    print(f"Poll interval: {args.interval}s, Max wait: {args.max_wait}s\n")

    start_time, last_status = time.time(), None

    while True:
        if int(time.time() - start_time) > args.max_wait:
            error_exit(f"Timeout: Exceeded maximum wait time of {args.max_wait}s")

        state = get_run_state(run_id)
        if state == "unknown":
            print(f"{YELLOW}Warning: Could not fetch run info{NC}")
            time.sleep(args.interval)
            continue

        if state != last_status:
            print(format_state(state, datetime.now().strftime("%H:%M:%S")))
            last_status = state

        if state == "success":
            print(f"{GREEN}Workflow run completed successfully!{NC}")
            sys.exit(0)

        if state in ("failed", "canceled"):
            print(f"{RED}Workflow run failed or was canceled{NC}\n")
            print(f"{YELLOW}Fetching error details...{NC}")

            jobs_data = get_json(["gh", "run", "view", run_id, "--json", "jobs"], "jobs")
            jobs = jobs_data if isinstance(jobs_data, list) else []
            if jobs:
                display_jobs(jobs)
                failed_jobs = [
                    j for j in jobs if isinstance(j, dict) and j.get("conclusion") in ("failure", "cancelled")
                ]

                if failed_jobs:
                    print(f"{RED}Failed jobs:{NC}")
                    for job in failed_jobs:
                        if isinstance(job, dict):
                            print(f"  - {job.get('name', '')} ({job.get('conclusion', '')})")
                    print()
                    display_failed_logs(run_id, failed_jobs)

            url_data = get_json(["gh", "run", "view", run_id, "--json", "url"], "url")
            url = url_data if isinstance(url_data, str) else None
            print(f"{BLUE}View workflow run: {url or f'https://github.com/{repo}/actions/runs/{run_id}'}{NC}")
            sys.exit(1)

        time.sleep(args.interval)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Collect commit metadata from the current git repository.

Current scope:
1. Read all commits that exist in the target local git repository.

The script can optionally refresh remote refs first with ``git fetch --all`` and
can write the collected commit list as JSON either to stdout or to a file.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

FIELD_SEP = "\x1f"
RECORD_SEP = "\x1e"
GIT_LOG_FORMAT = (
    "%H%x1f%P%x1f%an%x1f%ae%x1f%aI%x1f%cn%x1f%ce%x1f%cI%x1f%s%x1f%B%x1f%D%x1e"
)


class GitCommandError(RuntimeError):
    """Raised when a git command fails."""


@dataclass(slots=True)
class CommitInfo:
    """Structured commit metadata exported by this script."""

    sha: str
    parents: list[str]
    author_name: str
    author_email: str
    author_date: str
    committer_name: str
    committer_email: str
    committer_date: str
    subject: str
    message: str
    refs: list[str]


def run_git(cwd: Path, *args: str) -> str:
    """Run a git command and return stdout as text."""
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode != 0:
        stderr = result.stderr.strip()
        stdout = result.stdout.strip()
        details = stderr or stdout or f"git exited with code {result.returncode}"
        raise GitCommandError(f"git {' '.join(args)} failed: {details}")
    return result.stdout


def resolve_repo_root(path: Path) -> Path:
    """Resolve the git repository root for the given path."""
    target = path
    if not target.exists():
        raise ValueError(f"path does not exist: {target}")
    if target.is_file():
        target = target.parent
    repo_root = run_git(target, "rev-parse", "--show-toplevel").strip()
    return Path(repo_root)


def fetch_remotes(repo_root: Path) -> None:
    """Refresh remote refs before reading commit history."""
    run_git(repo_root, "fetch", "--all", "--tags", "--prune")


def get_remotes(repo_root: Path) -> dict[str, str]:
    """Return fetch URLs for configured remotes."""
    remotes: dict[str, str] = {}
    for line in run_git(repo_root, "remote", "-v").splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[2] == "(fetch)":
            remotes[parts[0]] = parts[1]
    return remotes


def get_current_branch(repo_root: Path) -> str | None:
    """Return the checked out branch name, or None in detached HEAD."""
    branch = run_git(repo_root, "branch", "--show-current").strip()
    return branch or None


def get_head_sha(repo_root: Path) -> str:
    """Return the current HEAD commit SHA."""
    return run_git(repo_root, "rev-parse", "HEAD").strip()


def parse_refs(refs_raw: str) -> list[str]:
    """Split git decoration text into individual refs."""
    return [ref.strip() for ref in refs_raw.split(",") if ref.strip()]


def collect_commits(repo_root: Path) -> list[CommitInfo]:
    """Read all commits reachable from any ref in the repository."""
    raw = run_git(repo_root, "log", "--all", f"--format={GIT_LOG_FORMAT}")
    commits: list[CommitInfo] = []

    for record in raw.split(RECORD_SEP):
        if not record.strip():
            continue
        fields = record.split(FIELD_SEP)
        if len(fields) != 11:
            raise ValueError(
                "unexpected git log record format; could not parse commit metadata"
            )

        (
            sha,
            parents_raw,
            author_name,
            author_email,
            author_date,
            committer_name,
            committer_email,
            committer_date,
            subject,
            message,
            refs_raw,
        ) = fields

        commits.append(
            CommitInfo(
                sha=sha,
                parents=parents_raw.split() if parents_raw else [],
                author_name=author_name,
                author_email=author_email,
                author_date=author_date,
                committer_name=committer_name,
                committer_email=committer_email,
                committer_date=committer_date,
                subject=subject,
                message=message.rstrip("\n"),
                refs=parse_refs(refs_raw),
            )
        )

    return commits


def build_payload(repo_root: Path, commits: list[CommitInfo]) -> dict[str, object]:
    """Build the JSON-serializable output payload."""
    return {
        "repository": {
            "root": str(repo_root),
            "head": get_head_sha(repo_root),
            "current_branch": get_current_branch(repo_root),
            "remotes": get_remotes(repo_root),
        },
        "commit_count": len(commits),
        "commits": [asdict(commit) for commit in commits],
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Collect all commits from a local git repository and export them as JSON."
    )
    parser.add_argument(
        "--repo",
        type=Path,
        default=Path.cwd(),
        help="Path inside the target git repository (default: current working directory)",
    )
    parser.add_argument(
        "--fetch",
        action="store_true",
        help="Run 'git fetch --all --tags --prune' before collecting commits",
    )
    parser.add_argument(
        "--reverse",
        action="store_true",
        help="Output commits oldest-first instead of newest-first",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Write JSON output to a file instead of stdout",
    )
    parser.add_argument(
        "--indent",
        type=int,
        default=2,
        help="JSON indentation level (default: 2)",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    args = parse_args(sys.argv[1:] if argv is None else argv)

    try:
        repo_root = resolve_repo_root(args.repo)
        if args.fetch:
            fetch_remotes(repo_root)

        commits = collect_commits(repo_root)
        if args.reverse:
            commits.reverse()

        payload = build_payload(repo_root, commits)
        json_text = json.dumps(payload, ensure_ascii=False, indent=args.indent)

        if args.output is None:
            print(json_text)
        else:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(f"{json_text}\n", encoding="utf-8")
            print(f"Wrote {len(commits)} commits to {args.output}")
    except (GitCommandError, OSError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

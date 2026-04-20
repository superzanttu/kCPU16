#!/usr/bin/env python3
"""Preview and safely rewrite local branch history by keeping only key commits.

Rules implemented by this script:
1. Read all local commits reachable from the selected local branch.
2. Always keep the first commit and the last commit.
3. Keep the first commit of each calendar day and drop the rest.
4. Show every commit and whether it will be kept before any rewrite happens.
5. Refuse risky rewrites unless the user explicitly confirms them.

The script defaults to preview mode. History is rewritten only when ``--apply``
is given, the working tree is clean, and the user confirms the operation.
Before rewriting, the script creates both a backup branch and a backup tag.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path

FIELD_SEP = "\x1f"
RECORD_SEP = "\x1e"
GIT_LOG_FORMAT = "%H%x1f%P%x1f%an%x1f%ae%x1f%aI%x1f%cn%x1f%ce%x1f%cI%x1f%s%x1f%B%x1e"


class GitCommandError(RuntimeError):
    """Raised when a git command fails."""


@dataclass(slots=True)
class CommitInfo:
    """Commit metadata used for selection and history reconstruction."""

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


@dataclass(slots=True)
class CleanupDecision:
    """Keep/drop decision for a single commit."""

    commit: CommitInfo
    keep: bool
    reasons: list[str]


def run_git(
    cwd: Path,
    *args: str,
    input_text: str | None = None,
    env: dict[str, str] | None = None,
) -> str:
    """Run a git command and return stdout as text."""
    full_env = os.environ.copy()
    if env is not None:
        full_env.update(env)

    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        input=input_text,
        encoding="utf-8",
        errors="replace",
        env=full_env,
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


def get_current_branch(repo_root: Path) -> str | None:
    """Return the checked out branch name, or None in detached HEAD."""
    branch = run_git(repo_root, "branch", "--show-current").strip()
    return branch or None


def get_head_sha(repo_root: Path) -> str:
    """Return the current HEAD SHA."""
    return run_git(repo_root, "rev-parse", "HEAD").strip()


def get_local_branches(repo_root: Path) -> list[str]:
    """Return all local branch names."""
    output = run_git(
        repo_root, "for-each-ref", "--format=%(refname:short)", "refs/heads"
    )
    return [line.strip() for line in output.splitlines() if line.strip()]


def ensure_local_branch_exists(repo_root: Path, branch: str) -> None:
    """Fail if the given local branch does not exist."""
    run_git(repo_root, "show-ref", "--verify", f"refs/heads/{branch}")


def ensure_clean_worktree(repo_root: Path) -> None:
    """Require a clean worktree before rewriting history."""
    status = run_git(repo_root, "status", "--porcelain", "--untracked-files=all")
    if status.strip():
        raise ValueError(
            "working tree is not clean; commit or stash changes before using --apply"
        )


def collect_branch_commits(repo_root: Path, branch: str) -> list[CommitInfo]:
    """Read all commits reachable from the selected local branch."""
    raw = run_git(
        repo_root,
        "log",
        branch,
        "--reverse",
        "--topo-order",
        f"--format={GIT_LOG_FORMAT}",
    )
    commits: list[CommitInfo] = []

    for record in raw.split(RECORD_SEP):
        record = record.lstrip("\r\n").rstrip("\r\n")
        if not record.strip():
            continue
        fields = record.split(FIELD_SEP)
        if len(fields) != 10:
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
                message=message.rstrip("\n") or subject,
            )
        )

    if not commits:
        raise ValueError(f"no commits found on branch '{branch}'")
    return commits


def get_root_commits(repo_root: Path, branch: str) -> list[str]:
    """Return root commits for the selected branch."""
    output = run_git(repo_root, "rev-list", "--max-parents=0", branch)
    return [line.strip() for line in output.splitlines() if line.strip()]


def commit_day(commit: CommitInfo) -> str:
    """Return the local calendar date of the commit using committer time."""
    return commit.committer_date.split("T", 1)[0]


def commit_datetime(commit: CommitInfo) -> datetime:
    """Parse the commit's committer timestamp."""
    return datetime.fromisoformat(commit.committer_date)


def build_cleanup_plan(commits: list[CommitInfo]) -> list[CleanupDecision]:
    """Decide which commits to keep according to the requested rules."""
    first_index_for_day: dict[str, int] = {}

    for index, commit in enumerate(commits):
        day = commit_day(commit)
        chosen_index = first_index_for_day.get(day)
        if chosen_index is None:
            first_index_for_day[day] = index
            continue

        chosen_commit = commits[chosen_index]
        if commit_datetime(commit) < commit_datetime(chosen_commit):
            first_index_for_day[day] = index

    keep_indices = {0, len(commits) - 1, *first_index_for_day.values()}
    decisions: list[CleanupDecision] = []

    for index, commit in enumerate(commits):
        reasons: list[str] = []
        if index == 0:
            reasons.append("first-commit")
        if index == len(commits) - 1:
            reasons.append("last-commit")
        if first_index_for_day.get(commit_day(commit)) == index:
            reasons.append(f"first-of-day {commit_day(commit)}")

        decisions.append(
            CleanupDecision(
                commit=commit,
                keep=index in keep_indices,
                reasons=reasons,
            )
        )

    return decisions


def count_merge_commits(commits: list[CommitInfo]) -> int:
    """Return the number of merge commits in the selected history."""
    return sum(1 for commit in commits if len(commit.parents) > 1)


def format_commit_line(decision: CleanupDecision) -> str:
    """Format one preview line for a commit decision."""
    mark = "KEEP" if decision.keep else "DROP"
    reason_text = ", ".join(decision.reasons) if decision.reasons else "removed"
    subject = decision.commit.subject.replace("\n", " ").strip()
    return (
        f"{mark:4} {decision.commit.committer_date} {decision.commit.sha[:12]} "
        f"{subject} [{reason_text}]"
    )


def print_plan(
    repo_root: Path,
    branch: str,
    decisions: list[CleanupDecision],
    merge_count: int,
    other_local_branches: list[str],
) -> None:
    """Print the full keep/drop plan before any rewrite happens."""
    keep_count = sum(1 for decision in decisions if decision.keep)
    drop_count = len(decisions) - keep_count

    print(f"Repository : {repo_root}")
    print(f"Branch     : {branch}")
    print(f"HEAD       : {get_head_sha(repo_root)}")
    print(f"Commits    : {len(decisions)} total, {keep_count} keep, {drop_count} drop")
    print("Rules      : keep first commit, last commit, and first commit of each day")
    if other_local_branches:
        print(
            "Note       : other local branches are not rewritten: "
            + ", ".join(other_local_branches)
        )
    if merge_count:
        print(
            "Warning    : merge commits detected. Applying this cleanup will flatten "
            "the selected branch into a linear snapshot history."
        )
    print()

    for decision in decisions:
        print(format_commit_line(decision))


def clear_worktree(repo_root: Path) -> None:
    """Remove current tracked and untracked contents from a temporary worktree."""
    run_git(repo_root, "rm", "-r", "-f", "--ignore-unmatch", "--", ".")
    run_git(repo_root, "clean", "-fdx")


def populate_snapshot(repo_root: Path, commit_sha: str) -> None:
    """Replace the temporary worktree contents with the exact tree of one commit."""
    clear_worktree(repo_root)
    run_git(repo_root, "checkout", commit_sha, "--", ".")
    run_git(repo_root, "add", "-A")


def commit_snapshot(repo_root: Path, commit: CommitInfo) -> None:
    """Create one reconstructed commit with original metadata and message."""
    env = {
        "GIT_AUTHOR_NAME": commit.author_name,
        "GIT_AUTHOR_EMAIL": commit.author_email,
        "GIT_AUTHOR_DATE": commit.author_date,
        "GIT_COMMITTER_NAME": commit.committer_name,
        "GIT_COMMITTER_EMAIL": commit.committer_email,
        "GIT_COMMITTER_DATE": commit.committer_date,
    }
    run_git(
        repo_root,
        "commit",
        "--allow-empty",
        "--quiet",
        "--file",
        "-",
        input_text=commit.message,
        env=env,
    )


def build_backup_names(branch: str) -> tuple[str, str, str]:
    """Return backup branch, backup tag, and temp branch names."""
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    backup_branch = f"{branch}-backup-before-clean-{stamp}"
    backup_tag = f"backup/clean-repo-{branch}-{stamp}"
    temp_branch = f"clean-repo-rebuild-{branch}-{stamp}"
    return backup_branch, backup_tag, temp_branch


def confirm_rewrite(branch: str, keep_count: int, drop_count: int) -> bool:
    """Ask the user for a strong confirmation before rewriting history."""
    expected = f"rewrite {branch}"
    print()
    print(
        f"About to rewrite branch '{branch}' and drop {drop_count} commits "
        f"while keeping {keep_count}."
    )
    answer = input(f"Type '{expected}' to continue: ").strip()
    return answer == expected


def clone_repo_for_rewrite(repo_root: Path, clone_dir: Path) -> None:
    """Create a temporary local clone used only for history reconstruction.

    A separate clone keeps index writes out of the original repository's
    linked-worktree metadata, which is more robust on Windows/Dropbox setups.
    """
    run_git(
        clone_dir.parent,
        "clone",
        "--quiet",
        "--no-checkout",
        "--shared",
        str(repo_root),
        str(clone_dir),
    )


def rewrite_branch_history(
    repo_root: Path,
    branch: str,
    decisions: list[CleanupDecision],
) -> tuple[str, str, str, str]:
    """Rewrite the selected branch using snapshot commits for kept entries only."""
    backup_branch, backup_tag, temp_branch = build_backup_names(branch)
    original_head = get_head_sha(repo_root)
    kept_commits = [decision.commit for decision in decisions if decision.keep]

    run_git(repo_root, "branch", backup_branch, original_head)
    run_git(repo_root, "tag", backup_tag, original_head)

    with tempfile.TemporaryDirectory(prefix="clean-repo-") as temp_dir_name:
        temp_root = Path(temp_dir_name)
        clone_dir = temp_root / "rewrite-clone"

        clone_repo_for_rewrite(repo_root, clone_dir)
        run_git(clone_dir, "checkout", "--orphan", temp_branch)
        clear_worktree(clone_dir)

        for commit in kept_commits:
            populate_snapshot(clone_dir, commit.sha)
            commit_snapshot(clone_dir, commit)

        run_git(repo_root, "fetch", "--no-tags", str(clone_dir), temp_branch)
        run_git(repo_root, "reset", "--hard", "FETCH_HEAD")

    return backup_branch, backup_tag, original_head, get_head_sha(repo_root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description=(
            "Preview and optionally rewrite one local branch so that only the first "
            "commit, the last commit, and the first commit of each day are kept."
        )
    )
    parser.add_argument(
        "--repo",
        type=Path,
        default=Path.cwd(),
        help="Path inside the target git repository (default: current working directory)",
    )
    parser.add_argument(
        "--branch",
        default=None,
        help="Local branch to inspect and rewrite (default: currently checked out branch)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Actually rewrite history after showing the plan and asking for confirmation",
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="Skip the interactive confirmation prompt after the plan is shown",
    )
    parser.add_argument(
        "--allow-flatten-merges",
        action="store_true",
        help="Allow applying the rewrite even when the branch contains merge commits",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    args = parse_args(sys.argv[1:] if argv is None else argv)

    try:
        repo_root = resolve_repo_root(args.repo)
        current_branch = get_current_branch(repo_root)
        branch = args.branch or current_branch

        if branch is None:
            raise ValueError(
                "detached HEAD: specify a local branch explicitly with --branch"
            )

        ensure_local_branch_exists(repo_root, branch)

        root_commits = get_root_commits(repo_root, branch)
        if len(root_commits) != 1:
            raise ValueError(
                f"branch '{branch}' has {len(root_commits)} root commits; refusing ambiguous cleanup"
            )

        commits = collect_branch_commits(repo_root, branch)
        decisions = build_cleanup_plan(commits)
        merge_count = count_merge_commits(commits)
        other_local_branches = [
            name for name in get_local_branches(repo_root) if name != branch
        ]

        print_plan(repo_root, branch, decisions, merge_count, other_local_branches)

        if not args.apply:
            print()
            print("Preview only. Re-run with --apply to rewrite the selected branch.")
            return 0

        if branch != current_branch:
            raise ValueError(
                "--apply only supports the currently checked out local branch"
            )

        if merge_count and not args.allow_flatten_merges:
            raise ValueError(
                "merge commits detected; re-run with --allow-flatten-merges only if "
                "you accept a linearized replacement history"
            )

        keep_count = sum(1 for decision in decisions if decision.keep)
        drop_count = len(decisions) - keep_count
        if drop_count == 0:
            print()
            print(
                "Nothing to rewrite: every commit is already protected by the keep rules."
            )
            return 0

        ensure_clean_worktree(repo_root)

        if not args.yes and not confirm_rewrite(branch, keep_count, drop_count):
            print("Aborted. No history was rewritten.")
            return 0

        backup_branch, backup_tag, old_head, new_head = rewrite_branch_history(
            repo_root, branch, decisions
        )

        print()
        print("Rewrite complete.")
        print(f"Old HEAD      : {old_head}")
        print(f"New HEAD      : {new_head}")
        print(f"Backup branch : {backup_branch}")
        print(f"Backup tag    : {backup_tag}")
        print(
            "Remote history was not changed. A later push would require force-with-lease."
        )
    except (GitCommandError, OSError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

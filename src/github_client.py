"""GitHub client for fetching PR data and posting review comments."""

import os
from dataclasses import dataclass
from github import Github, PullRequest


@dataclass
class PRData:
    """Data class representing pull request information."""

    title: str
    description: str
    diff: str
    files_changed: list[dict]
    base_branch: str
    head_branch: str
    author: str
    pr_number: int
    repo_name: str


class GitHubClient:
    """Client for interacting with GitHub API."""

    def __init__(self, token: str | None = None):
        """Initialize GitHub client with token.

        Args:
            token: GitHub personal access token. If not provided,
                   reads from GITHUB_TOKEN environment variable.
        """
        self.token = token or os.environ.get("GITHUB_TOKEN")
        if not self.token:
            raise ValueError("GitHub token is required. Set GITHUB_TOKEN environment variable.")
        self.client = Github(self.token)

    def get_pr_data(self, repo_name: str, pr_number: int) -> PRData:
        """Fetch pull request data including diff and file changes.

        Args:
            repo_name: Full repository name (e.g., 'owner/repo')
            pr_number: Pull request number

        Returns:
            PRData object containing PR information
        """
        repo = self.client.get_repo(repo_name)
        pr = repo.get_pull(pr_number)

        # Get the diff
        diff = self._get_pr_diff(pr)

        # Get changed files with their patches
        files_changed = self._get_files_changed(pr)

        return PRData(
            title=pr.title,
            description=pr.body or "",
            diff=diff,
            files_changed=files_changed,
            base_branch=pr.base.ref,
            head_branch=pr.head.ref,
            author=pr.user.login,
            pr_number=pr_number,
            repo_name=repo_name,
        )

    def _get_pr_diff(self, pr: PullRequest.PullRequest) -> str:
        """Get the unified diff for a pull request.

        Args:
            pr: PyGithub PullRequest object

        Returns:
            Unified diff as string
        """
        import requests

        headers = {
            "Authorization": f"token {self.token}",
            "Accept": "application/vnd.github.v3.diff",
        }
        response = requests.get(pr.url, headers=headers, timeout=30)
        response.raise_for_status()
        return response.text

    def _get_files_changed(self, pr: PullRequest.PullRequest) -> list[dict]:
        """Get list of changed files with their patches.

        Args:
            pr: PyGithub PullRequest object

        Returns:
            List of dicts containing file information
        """
        files = []
        for file in pr.get_files():
            files.append({
                "filename": file.filename,
                "status": file.status,  # added, removed, modified, renamed
                "additions": file.additions,
                "deletions": file.deletions,
                "changes": file.changes,
                "patch": file.patch if hasattr(file, "patch") and file.patch else "",
            })
        return files

    def post_review_comment(
        self,
        repo_name: str,
        pr_number: int,
        comment: str,
    ) -> str:
        """Post a review comment on a pull request.

        Args:
            repo_name: Full repository name (e.g., 'owner/repo')
            pr_number: Pull request number
            comment: The review comment text (supports markdown)

        Returns:
            URL of the created comment
        """
        repo = self.client.get_repo(repo_name)
        pr = repo.get_pull(pr_number)

        # Create an issue comment (appears in the PR conversation)
        issue_comment = pr.create_issue_comment(comment)

        return issue_comment.html_url

    def check_existing_review(self, repo_name: str, pr_number: int, bot_marker: str) -> bool:
        """Check if the bot has already reviewed this PR.

        Args:
            repo_name: Full repository name
            pr_number: Pull request number
            bot_marker: Unique marker to identify bot comments

        Returns:
            True if bot has already commented, False otherwise
        """
        repo = self.client.get_repo(repo_name)
        pr = repo.get_pull(pr_number)

        for comment in pr.get_issue_comments():
            if bot_marker in comment.body:
                return True

        return False

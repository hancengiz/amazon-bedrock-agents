"""Main entry point for the PR code reviewer agent."""

import argparse
import os
import sys

from .bedrock_reviewer import BedrockCodeReviewer
from .github_client import GitHubClient


def parse_args() -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Automated PR code reviewer using Amazon Bedrock Agent"
    )
    parser.add_argument(
        "--repo",
        required=True,
        help="GitHub repository in 'owner/repo' format",
    )
    parser.add_argument(
        "--pr",
        type=int,
        required=True,
        help="Pull request number to review",
    )
    parser.add_argument(
        "--skip-if-reviewed",
        action="store_true",
        default=True,
        help="Skip review if bot has already commented (default: True)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Force review even if already commented",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print review without posting to GitHub",
    )

    return parser.parse_args()


def main() -> int:
    """Main entry point for the code reviewer.

    Returns:
        Exit code (0 for success, 1 for error)
    """
    args = parse_args()

    # Validate environment variables
    if not os.environ.get("GITHUB_TOKEN"):
        print("Error: GITHUB_TOKEN environment variable is required", file=sys.stderr)
        return 1

    try:
        # Initialize clients
        print(f"Initializing code reviewer for {args.repo}#{args.pr}...")
        github_client = GitHubClient()
        reviewer = BedrockCodeReviewer()

        # Check if already reviewed (unless forced)
        if args.skip_if_reviewed and not args.force:
            if github_client.check_existing_review(
                args.repo, args.pr, reviewer.bot_marker
            ):
                print("PR has already been reviewed by this bot. Skipping.")
                print("Use --force to review again.")
                return 0

        # Fetch PR data
        print("Fetching PR data...")
        pr_data = github_client.get_pr_data(args.repo, args.pr)
        print(f"  Title: {pr_data.title}")
        print(f"  Author: {pr_data.author}")
        print(f"  Files changed: {len(pr_data.files_changed)}")

        # Generate review
        print("Generating code review...")
        review_comment = reviewer.review_pr(pr_data)

        if args.dry_run:
            print("\n" + "=" * 60)
            print("DRY RUN - Review would be posted:")
            print("=" * 60)
            print(review_comment)
            return 0

        # Post review comment
        print("Posting review comment...")
        comment_url = github_client.post_review_comment(
            args.repo, args.pr, review_comment
        )
        print(f"Review posted successfully: {comment_url}")

        return 0

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())

"""Bedrock-based code reviewer using Claude Sonnet 4.5."""

import json
import os

import boto3

from .github_client import PRData


class BedrockCodeReviewer:
    """Code reviewer powered by Amazon Bedrock and Claude Sonnet 4.5."""

    # Claude Sonnet 4 model ID on Bedrock (requires inference profile)
    # Use us.anthropic.claude-sonnet-4-20250514-v1:0 for cross-region inference
    # Or anthropic.claude-3-5-sonnet-20241022-v2:0 for Claude 3.5 Sonnet (on-demand)
    MODEL_ID = "us.anthropic.claude-sonnet-4-20250514-v1:0"

    # Maximum tokens for the response
    MAX_TOKENS = 4096

    # Bot marker to identify automated reviews
    BOT_MARKER = "<!-- bedrock-code-reviewer-bot -->"

    def __init__(
        self,
        region: str | None = None,
        aws_access_key_id: str | None = None,
        aws_secret_access_key: str | None = None,
    ):
        """Initialize Bedrock client.

        Args:
            region: AWS region. Defaults to AWS_REGION env var or 'us-east-1'
            aws_access_key_id: AWS access key. Defaults to environment/credentials file
            aws_secret_access_key: AWS secret key. Defaults to environment/credentials file
        """
        self.region = region or os.environ.get("AWS_REGION", "us-east-1")

        session_kwargs = {"region_name": self.region}
        if aws_access_key_id and aws_secret_access_key:
            session_kwargs["aws_access_key_id"] = aws_access_key_id
            session_kwargs["aws_secret_access_key"] = aws_secret_access_key

        session = boto3.Session(**session_kwargs)
        self.client = session.client("bedrock-runtime")

    def review_pr(self, pr_data: PRData) -> str:
        """Review a pull request and generate feedback.

        Args:
            pr_data: PRData object containing PR information

        Returns:
            Formatted review comment as markdown string
        """
        prompt = self._build_review_prompt(pr_data)
        review_content = self._invoke_claude(prompt)
        return self._format_review_comment(review_content, pr_data)

    def _build_review_prompt(self, pr_data: PRData) -> str:
        """Build the prompt for code review.

        Args:
            pr_data: PRData object containing PR information

        Returns:
            Formatted prompt string
        """
        # Build file changes summary
        files_summary = []
        for file in pr_data.files_changed:
            files_summary.append(
                f"- `{file['filename']}` ({file['status']}): "
                f"+{file['additions']}/-{file['deletions']} lines"
            )

        files_summary_text = "\n".join(files_summary) if files_summary else "No files changed"

        # Truncate diff if too large (to stay within token limits)
        diff = pr_data.diff
        max_diff_chars = 50000
        if len(diff) > max_diff_chars:
            diff = diff[:max_diff_chars] + "\n\n... [diff truncated due to size]"

        prompt = f"""You are an expert code reviewer. Review the following pull request and provide constructive feedback.

## Pull Request Information

**Title:** {pr_data.title}
**Author:** {pr_data.author}
**Branch:** {pr_data.head_branch} -> {pr_data.base_branch}

**Description:**
{pr_data.description or "No description provided"}

## Files Changed
{files_summary_text}

## Code Diff
```diff
{diff}
```

## Review Instructions

Please review this pull request focusing on:

1. **Code Quality & Best Practices**
   - Code readability and maintainability
   - Naming conventions and code organization
   - DRY principles and code duplication
   - Error handling and edge cases
   - Documentation and comments where needed

2. **Performance Issues**
   - Inefficient algorithms or data structures
   - Unnecessary computations or memory usage
   - N+1 queries or database performance
   - Resource leaks or cleanup issues

3. **Security Vulnerabilities**
   - Input validation and sanitization
   - Authentication/authorization issues
   - Injection vulnerabilities (SQL, XSS, etc.)
   - Sensitive data exposure
   - Insecure dependencies or configurations

## Response Format

Provide your review in the following structured format:

### Summary
A brief overall assessment of the PR (2-3 sentences).

### Code Quality
List specific issues or suggestions related to code quality. If none, state "No issues found."

### Performance
List specific performance concerns or optimizations. If none, state "No issues found."

### Security
List specific security issues or recommendations. If none, state "No issues found."

### Suggestions
Any additional recommendations or improvements not covered above.

Be constructive, specific, and reference line numbers or file names when pointing out issues. If the code looks good, acknowledge the positive aspects."""

        return prompt

    def _invoke_claude(self, prompt: str) -> str:
        """Invoke Claude model via Bedrock.

        Args:
            prompt: The prompt to send to Claude

        Returns:
            Claude's response text
        """
        body = json.dumps({
            "anthropic_version": "bedrock-2023-05-31",
            "max_tokens": self.MAX_TOKENS,
            "messages": [
                {
                    "role": "user",
                    "content": prompt,
                }
            ],
        })

        response = self.client.invoke_model(
            modelId=self.MODEL_ID,
            body=body,
            contentType="application/json",
            accept="application/json",
        )

        response_body = json.loads(response["body"].read())
        return response_body["content"][0]["text"]

    def _format_review_comment(self, review_content: str, pr_data: PRData) -> str:
        """Format the review content as a GitHub comment.

        Args:
            review_content: Raw review content from Claude
            pr_data: PRData object for context

        Returns:
            Formatted markdown comment
        """
        comment = f"""{self.BOT_MARKER}

## Automated Code Review

*Reviewed by Amazon Bedrock (Claude Sonnet 4.5)*

---

{review_content}

---

<details>
<summary>About this review</summary>

This is an automated code review generated by an AI assistant. While it aims to identify potential issues, it may not catch everything and could occasionally flag false positives. Please use your judgment when addressing the feedback.

**PR:** #{pr_data.pr_number} - {pr_data.title}
**Files reviewed:** {len(pr_data.files_changed)}

</details>
"""
        return comment

    @property
    def bot_marker(self) -> str:
        """Get the bot marker for identifying automated reviews."""
        return self.BOT_MARKER

"""Bedrock Agent-based code reviewer."""

import os
import uuid

import boto3

from .github_client import PRData


class BedrockCodeReviewer:
    """Code reviewer powered by Amazon Bedrock Agent."""

    # Bot marker to identify automated reviews
    BOT_MARKER = "<!-- bedrock-code-reviewer-bot -->"

    def __init__(
        self,
        agent_id: str | None = None,
        agent_alias_id: str | None = None,
        region: str | None = None,
        aws_access_key_id: str | None = None,
        aws_secret_access_key: str | None = None,
    ):
        """Initialize Bedrock Agent Runtime client.

        Args:
            agent_id: Bedrock Agent ID. Defaults to BEDROCK_AGENT_ID env var
            agent_alias_id: Agent Alias ID. Defaults to BEDROCK_AGENT_ALIAS_ID env var
            region: AWS region. Defaults to AWS_REGION env var or 'us-east-1'
            aws_access_key_id: AWS access key. Defaults to environment/credentials file
            aws_secret_access_key: AWS secret key. Defaults to environment/credentials file
        """
        self.agent_id = agent_id or os.environ.get("BEDROCK_AGENT_ID")
        self.agent_alias_id = agent_alias_id or os.environ.get("BEDROCK_AGENT_ALIAS_ID")
        self.region = region or os.environ.get("AWS_REGION", "us-east-1")

        if not self.agent_id:
            raise ValueError("BEDROCK_AGENT_ID environment variable or agent_id parameter required")
        if not self.agent_alias_id:
            raise ValueError("BEDROCK_AGENT_ALIAS_ID environment variable or agent_alias_id parameter required")

        session_kwargs = {"region_name": self.region}
        if aws_access_key_id and aws_secret_access_key:
            session_kwargs["aws_access_key_id"] = aws_access_key_id
            session_kwargs["aws_secret_access_key"] = aws_secret_access_key

        session = boto3.Session(**session_kwargs)
        self.client = session.client("bedrock-agent-runtime")

    def review_pr(self, pr_data: PRData) -> str:
        """Review a pull request and generate feedback.

        Args:
            pr_data: PRData object containing PR information

        Returns:
            Formatted review comment as markdown string
        """
        prompt = self._build_review_prompt(pr_data)
        review_content = self._invoke_agent(prompt)
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

        prompt = f"""Review this pull request:

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

Please provide your code review following your instructions."""

        return prompt

    def _invoke_agent(self, prompt: str) -> str:
        """Invoke Bedrock Agent.

        Args:
            prompt: The prompt to send to the agent

        Returns:
            Agent's response text
        """
        # Generate a unique session ID for this invocation
        session_id = str(uuid.uuid4())

        response = self.client.invoke_agent(
            agentId=self.agent_id,
            agentAliasId=self.agent_alias_id,
            sessionId=session_id,
            inputText=prompt,
        )

        # Collect the streamed response
        completion = ""
        for event in response.get("completion", []):
            if "chunk" in event:
                chunk_data = event["chunk"]
                if "bytes" in chunk_data:
                    completion += chunk_data["bytes"].decode("utf-8")

        return completion

    def _format_review_comment(self, review_content: str, pr_data: PRData) -> str:
        """Format the review content as a GitHub comment.

        Args:
            review_content: Raw review content from the agent
            pr_data: PRData object for context

        Returns:
            Formatted markdown comment
        """
        comment = f"""{self.BOT_MARKER}

## Automated Code Review

*Reviewed by Amazon Bedrock Agent*

---

{review_content}

---

<details>
<summary>About this review</summary>

This is an automated code review generated by a Bedrock Agent. While it aims to identify potential issues, it may not catch everything and could occasionally flag false positives. Please use your judgment when addressing the feedback.

**PR:** #{pr_data.pr_number} - {pr_data.title}
**Files reviewed:** {len(pr_data.files_changed)}

</details>
"""
        return comment

    @property
    def bot_marker(self) -> str:
        """Get the bot marker for identifying automated reviews."""
        return self.BOT_MARKER

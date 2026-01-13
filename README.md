# Amazon Bedrock PR Code Reviewer

Automated pull request code reviewer powered by Amazon Bedrock and Claude Sonnet 4.5.

## Features

- Automated code review on PR creation/update via GitHub Actions
- Reviews focus on:
  - Code quality and best practices
  - Performance issues
  - Security vulnerabilities
- Posts a single summary comment on the PR
- Skips duplicate reviews (won't comment twice on the same PR)

---

## Architecture Overview

### High-Level Architecture

```mermaid
flowchart TB
    subgraph GHCloud["☁️ GitHub Cloud"]
        PR[("Pull Request")]
        API["GitHub API"]

        subgraph Runner["🖥️ GitHub Actions Runner<br/>(Ubuntu VM - Ephemeral)"]
            GHA["Workflow Engine"]

            subgraph Agent["Python Runtime"]
                Main["main.py<br/>Orchestrator"]
                GHClient["github_client.py<br/>GitHub Client"]
                Reviewer["bedrock_reviewer.py<br/>AI Reviewer"]
            end
        end
    end

    subgraph AWSCloud["☁️ AWS Cloud (us-east-1)"]
        subgraph BedrockService["Amazon Bedrock Service"]
            Bedrock["Bedrock Runtime API"]
            Claude["Claude Sonnet 4.5<br/>(Foundation Model)"]
        end
    end

    PR -->|"1. triggers"| GHA
    GHA -->|"2. executes"| Main
    Main --> GHClient
    Main --> Reviewer
    GHClient <-->|"3. HTTPS"| API
    Reviewer <-->|"4. HTTPS<br/>(AWS SDK)"| Bedrock
    Bedrock --> Claude
    GHClient -->|"5. post comment"| API
    API --> PR
```

### Runtime Environments

| Component | Hosted On | Lifecycle |
|-----------|-----------|-----------|
| Pull Request & API | GitHub Cloud | Persistent |
| GitHub Actions Runner | GitHub-hosted Ubuntu VM | Ephemeral (per workflow run) |
| Code Reviewer Agent | Inside Actions Runner | Ephemeral (per workflow run) |
| Amazon Bedrock | AWS Cloud (your region) | Managed service (always available) |
| Claude Sonnet 4.5 | AWS Bedrock | Foundation model (serverless) |

### Component Architecture

```mermaid
flowchart LR
    subgraph Components["Agent Components"]
        direction TB

        subgraph Main["main.py"]
            CLI["CLI Parser"]
            Orch["Orchestrator"]
        end

        subgraph GH["github_client.py"]
            Fetch["PR Fetcher"]
            Post["Comment Poster"]
            Check["Duplicate Checker"]
        end

        subgraph BR["bedrock_reviewer.py"]
            Prompt["Prompt Builder"]
            Invoke["Model Invoker"]
            Format["Response Formatter"]
        end
    end

    CLI --> Orch
    Orch --> Fetch
    Orch --> Check
    Orch --> Prompt
    Fetch --> Prompt
    Prompt --> Invoke
    Invoke --> Format
    Format --> Post
```

---

## Workflow

### GitHub Action Trigger Flow

```mermaid
sequenceDiagram
    autonumber
    participant Dev as Developer
    participant GH as GitHub
    participant GHA as GitHub Actions
    participant Agent as Code Reviewer
    participant Bedrock as Amazon Bedrock

    Dev->>GH: Open/Update PR
    GH->>GHA: Trigger workflow<br/>(pull_request event)

    GHA->>GHA: Checkout repository
    GHA->>GHA: Setup Python environment
    GHA->>GHA: Install dependencies

    GHA->>Agent: Run code reviewer

    Agent->>GH: Check for existing review

    alt Already reviewed
        Agent->>GHA: Skip (already reviewed)
    else Not reviewed
        Agent->>GH: Fetch PR data (title, diff, files)
        GH-->>Agent: PR metadata + diff

        Agent->>Agent: Build review prompt
        Agent->>Bedrock: Invoke Claude Sonnet 4.5
        Bedrock-->>Agent: AI review response

        Agent->>Agent: Format review comment
        Agent->>GH: Post review comment
        GH-->>Dev: Notification
    end

    Agent->>GHA: Exit (success)
```

### Data Flow

```mermaid
flowchart TD
    subgraph Input["Input Data"]
        PRNum["PR Number"]
        Repo["Repository Name"]
    end

    subgraph Fetch["Data Fetching"]
        Title["PR Title"]
        Desc["PR Description"]
        Diff["Code Diff"]
        Files["Changed Files"]
    end

    subgraph Process["AI Processing"]
        Prompt["Review Prompt"]
        Analysis["Code Analysis"]
    end

    subgraph Output["Output"]
        Quality["Code Quality<br/>Findings"]
        Perf["Performance<br/>Issues"]
        Security["Security<br/>Vulnerabilities"]
        Comment["Formatted<br/>PR Comment"]
    end

    PRNum --> Fetch
    Repo --> Fetch

    Fetch --> Title
    Fetch --> Desc
    Fetch --> Diff
    Fetch --> Files

    Title --> Prompt
    Desc --> Prompt
    Diff --> Prompt
    Files --> Prompt

    Prompt --> Analysis

    Analysis --> Quality
    Analysis --> Perf
    Analysis --> Security

    Quality --> Comment
    Perf --> Comment
    Security --> Comment
```

### Review Categories

```mermaid
mindmap
    root((Code Review))
        Code Quality
            Readability
            Naming Conventions
            DRY Principles
            Error Handling
            Documentation
        Performance
            Algorithm Efficiency
            Memory Usage
            Database Queries
            Resource Management
        Security
            Input Validation
            Auth Issues
            Injection Vulnerabilities
            Data Exposure
            Insecure Config
```

---

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── code-review.yml    # GitHub Action workflow
├── scripts/
│   ├── deploy.sh              # One-command deployment
│   ├── setup-aws.sh           # AWS IAM setup
│   ├── setup-github.sh        # GitHub secrets setup
│   ├── run-local.sh           # Local code review runner
│   └── cleanup.sh             # Remove all resources
├── src/
│   ├── __init__.py
│   ├── github_client.py       # GitHub API interactions
│   ├── bedrock_reviewer.py    # Bedrock/Claude integration
│   └── main.py                # Main entry point
├── requirements.txt
├── README.md                  # This file (architecture & overview)
└── DEPLOYMENT.md              # Step-by-step deployment guide
```

### Module Responsibilities

| Module | Responsibility |
|--------|----------------|
| `main.py` | CLI parsing, orchestration, error handling |
| `github_client.py` | Fetch PR data, post comments, check duplicates |
| `bedrock_reviewer.py` | Build prompts, invoke Claude, format responses |

---

## Quick Start

### Automated Deployment (Recommended)

```bash
# One-command deploy (requires AWS CLI + GitHub CLI)
./scripts/deploy.sh
```

### Manual Deployment

For detailed step-by-step deployment instructions, see **[DEPLOYMENT.md](./DEPLOYMENT.md)**.

### Local Testing

```bash
# Run a code review locally
./scripts/run-local.sh --pr 123 --dry-run
```

### Prerequisites

- AWS account with Bedrock access
- GitHub repository with admin access

### Required Secrets

Add these to your GitHub repository (**Settings → Secrets → Actions**):

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |

> `GITHUB_TOKEN` is automatically provided by GitHub Actions.

---

## Deployment Flow

```mermaid
flowchart LR
    subgraph Setup["One-Time Setup"]
        A1["Enable Bedrock<br/>Model Access"] --> A2["Create IAM User"]
        A2 --> A3["Add GitHub<br/>Secrets"]
        A3 --> A4["Push Code<br/>to Repo"]
    end

    subgraph Runtime["Per-PR Runtime"]
        B1["PR Created"] --> B2["Action Triggered"]
        B2 --> B3["Review Generated"]
        B3 --> B4["Comment Posted"]
    end

    Setup --> Runtime
```

---

## Local Usage

You can also run the reviewer locally:

```bash
# Install dependencies
pip install -r requirements.txt

# Set environment variables
export GITHUB_TOKEN="your-github-pat"
export AWS_ACCESS_KEY_ID="your-aws-key"
export AWS_SECRET_ACCESS_KEY="your-aws-secret"
export AWS_REGION="us-east-1"

# Run review (dry run)
python -m src.main --repo "owner/repo" --pr 123 --dry-run

# Run review and post comment
python -m src.main --repo "owner/repo" --pr 123

# Force re-review (even if already commented)
python -m src.main --repo "owner/repo" --pr 123 --force
```

### CLI Options

| Option | Description |
|--------|-------------|
| `--repo` | Repository in `owner/repo` format (required) |
| `--pr` | Pull request number (required) |
| `--skip-if-reviewed` | Skip if bot already commented (default: true) |
| `--force` | Force review even if already commented |
| `--dry-run` | Print review without posting to GitHub |

---

## Security Architecture

```mermaid
flowchart TB
    subgraph Secrets["Secret Management"]
        GHS["GitHub Secrets<br/>(encrypted)"]
        ENV["Environment Variables<br/>(runtime only)"]
    end

    subgraph Protection["Protection Mechanisms"]
        Fork["Fork PR Check<br/>(blocks external PRs)"]
        Marker["Bot Marker<br/>(prevents duplicates)"]
        Perms["Minimal Permissions<br/>(read + PR write)"]
    end

    subgraph Flow["Secure Data Flow"]
        GHS -->|"injected at runtime"| ENV
        ENV -->|"used by"| Agent["Agent"]
        Agent -->|"authenticated"| AWS["AWS Bedrock"]
        Agent -->|"authenticated"| GitHub["GitHub API"]
    end

    Fork --> Agent
    Marker --> Agent
    Perms --> Agent
```

### Security Notes

- The workflow only runs on PRs from the same repository (not forks) to protect secrets
- AWS credentials are stored as GitHub secrets and never exposed in logs
- The bot marker prevents duplicate reviews
- Minimal permissions: only `contents: read` and `pull-requests: write`

---

## Customization

### Modify Review Focus

Edit the prompt in `src/bedrock_reviewer.py:_build_review_prompt()` to customize what the reviewer looks for.

### Change the Model

Update `MODEL_ID` in `src/bedrock_reviewer.py` to use a different Claude model:

```python
MODEL_ID = "anthropic.claude-3-opus-20240229-v1:0"  # For Claude 3 Opus
```

### Add Inline Comments

To add line-by-line comments instead of a summary, modify `github_client.py` to use the GitHub Reviews API:

```python
pr.create_review(body="Review body", event="COMMENT", comments=[...])
```

---

## Troubleshooting

> For detailed troubleshooting steps, see [DEPLOYMENT.md](./DEPLOYMENT.md#troubleshooting).

### Error Resolution Flow

```mermaid
flowchart TD
    Error["Error Occurred"]

    Error --> Q1{"Bedrock<br/>Access Denied?"}
    Q1 -->|Yes| A1["Check IAM permissions<br/>& model access"]
    Q1 -->|No| Q2{"GitHub<br/>Not Found?"}

    Q2 -->|Yes| A2["Verify repo format<br/>& token permissions"]
    Q2 -->|No| Q3{"Review Not<br/>Triggering?"}

    Q3 -->|Yes| A3["Check Actions enabled<br/>& workflow path"]
    Q3 -->|No| A4["Check logs for<br/>specific error"]

    A1 --> Fixed["Issue Resolved"]
    A2 --> Fixed
    A3 --> Fixed
    A4 --> Fixed
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Access Denied from Bedrock | Verify IAM `bedrock:InvokeModel` permission and model access |
| Resource not found from GitHub | Check repo format (`owner/repo`) and token permissions |
| Review not triggering | Ensure Actions enabled and workflow in `.github/workflows/` |
| Duplicate reviews | Bot marker should prevent this; use `--force` to override |

---

## License

MIT

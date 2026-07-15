#!/usr/bin/env bash
set -euo pipefail

PUSH=0
KEEP_TEMP=1
LIMIT=""

usage() {
    cat <<'USAGE'
Usage: script/add_julia_tag.sh [--push] [--cleanup] [--limit N]

Find GitHub repositories the authenticated user has contributed to, filter those
whose GitHub language metadata includes Julia, and append official Julia links to
README.md when missing.

Options:
  --push       Push the generated commit back to each repository.
  --cleanup    Remove the temporary clone directory when finished.
  --limit N    Process only the first N matching repositories.
  -h, --help   Show this help.

By default the script commits only inside a temporary directory and does not push.
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --push)
            PUSH=1
            shift
            ;;
        --cleanup)
            KEEP_TEMP=0
            shift
            ;;
        --limit)
            if [ "$#" -lt 2 ] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo "ERROR: --limit requires a non-negative integer." >&2
                exit 2
            fi
            LIMIT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: Please install GitHub CLI and run 'gh auth login' first." >&2
    exit 1
fi

if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is required." >&2
    exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "ERROR: GitHub CLI is not authenticated. Run 'gh auth login' first." >&2
    exit 1
fi

USERNAME=$(gh api user --jq ".login" | tr -d '\r\n')
echo "Searching @$USERNAME contributed repositories whose GitHub language metadata includes Julia..."

GRAPHQL_QUERY='
query($endCursor: String) {
  viewer {
    repositoriesContributedTo(
      first: 100
      after: $endCursor
      includeUserRepositories: true
      contributionTypes: [COMMIT, PULL_REQUEST, REPOSITORY, PULL_REQUEST_REVIEW]
    ) {
      nodes {
        nameWithOwner
        defaultBranchRef {
          name
        }
        languages(first: 50, orderBy: {field: SIZE, direction: DESC}) {
          nodes {
            name
          }
        }
      }
      pageInfo {
        hasNextPage
        endCursor
      }
    }
  }
}'

REPOS=$(gh api graphql --paginate -f query="$GRAPHQL_QUERY" \
    --jq '.data.viewer.repositoriesContributedTo.nodes[]
          | select(.defaultBranchRef != null)
          | select([.languages.nodes[].name] | index("Julia"))
          | .nameWithOwner' | sort -u)

if [ -z "$REPOS" ]; then
    echo "No contributed repositories with Julia language metadata were found."
    echo "Check each repository's GitHub language statistics if you expected matches."
    exit 0
fi

if [ -n "$LIMIT" ]; then
    REPOS=$(printf '%s\n' "$REPOS" | head -n "$LIMIT")
fi

echo "Matching repositories:"
printf '  - %s\n' $REPOS

TEMP_DIR=$(mktemp -d)
echo "Temporary clone directory: $TEMP_DIR"

cleanup() {
    if [ "$KEEP_TEMP" -eq 0 ]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

TAG_BLOCK='

---
Julia language: [#JuliaLang](https://julialang.org/) | [JuliaLang GitHub](https://github.com/JuliaLang/julia)
'

processed=0
changed=0
skipped=0
failed=0

printf '%s\n' "$REPOS" | while IFS= read -r REPO; do
    [ -n "$REPO" ] || continue

    processed=$((processed + 1))
    REPO_DIR="$TEMP_DIR/${REPO//\//__}"

    echo "========================================"
    echo "Processing: $REPO"

    if ! gh repo clone "$REPO" "$REPO_DIR" -- --depth 1; then
        echo "WARN: clone failed for $REPO; skipping." >&2
        failed=$((failed + 1))
        continue
    fi

    cd "$REPO_DIR"

    README_FILE=$(find . -maxdepth 1 -type f -iname 'readme.md' -print -quit)
    if [ -z "$README_FILE" ]; then
        echo "Skipped: README.md was not found at repository root."
        skipped=$((skipped + 1))
        continue
    fi
    README_FILE=${README_FILE#./}

    if grep -qi '#JuliaLang' "$README_FILE" \
        && grep -qi 'https://julialang.org/' "$README_FILE" \
        && grep -qi 'https://github.com/JuliaLang/julia' "$README_FILE"; then
        echo "Skipped: README already contains #JuliaLang and both official links."
        skipped=$((skipped + 1))
        continue
    fi

    printf '%s' "$TAG_BLOCK" >> "$README_FILE"

    git add "$README_FILE"
    if git diff --cached --quiet; then
        echo "Skipped: no staged README changes."
        skipped=$((skipped + 1))
        continue
    fi

    git commit -m "docs: add JuliaLang official links to README"
    changed=$((changed + 1))

    if [ "$PUSH" -eq 1 ]; then
        git push
        echo "Pushed: $REPO"
    else
        echo "Committed locally only. Re-run with --push to update GitHub."
    fi
done

echo "========================================"
echo "Done."
echo "Processed: $processed"
echo "Changed:   $changed"
echo "Skipped:   $skipped"
echo "Failed:    $failed"

if [ "$KEEP_TEMP" -eq 1 ]; then
    echo "Review temporary clones at: $TEMP_DIR"
fi

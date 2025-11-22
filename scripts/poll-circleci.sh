#!/bin/bash
# vim: set et fenc=utf-8 ff=unix sts=4 sw=4 ts=8 :
# Poll CircleCI pipeline status

set -euo pipefail

# Load direnv if available and .envrc exists
if command -v direnv &>/dev/null; then
    # Get script directory and repo root
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

    # Check for .envrc in repo root
    if [[ -f "$REPO_ROOT/.envrc" ]]; then
        # Change to repo root to allow direnv to work
        cd "$REPO_ROOT" || {
            echo "Error: Failed to change to repo root: $REPO_ROOT" >&2
            exit 1
        }
        # Allow direnv to load (if not already allowed)
        direnv allow &>/dev/null || true
        # Load environment variables from .envrc
        eval "$(direnv export bash)" || {
            echo "Warning: Failed to load direnv environment" >&2
        }
        # Stay in repo root for git operations
        # Don't change back to script directory to avoid losing env vars
    fi
fi

# Configuration
CIRCLECI_API_URL="https://circleci.com/api/v2"
POLL_INTERVAL=${POLL_INTERVAL:-10} # seconds
MAX_WAIT=${MAX_WAIT:-3600}         # 1 hour default
TIMEOUT=${TIMEOUT:-3600}           # 1 hour default

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [PIPELINE_ID|BRANCH]

Poll CircleCI pipeline status until completion or timeout.

Options:
    -t, --token TOKEN       CircleCI API token (or set CIRCLECI_TOKEN env var)
    -o, --org ORG           Organization/username (e.g., github/jcppkkk)
    -p, --project PROJECT   Project name (e.g., dotfiles)
    -b, --branch BRANCH     Branch name (default: main)
    -i, --interval SECONDS  Poll interval in seconds (default: 10)
    -w, --max-wait SECONDS  Maximum wait time in seconds (default: 3600)
    -v, --verbose           Verbose output
    -h, --help              Show this help message

Environment variables:
    CIRCLECI_TOKEN          CircleCI API token
    CIRCLECI_ORG            Organization/username
    CIRCLECI_PROJECT        Project name

Examples:
    # Poll latest pipeline on main branch
    $0 -t \$CIRCLECI_TOKEN -o jcppkkk -p dotfiles

    # Poll specific pipeline
    $0 -t \$CIRCLECI_TOKEN <pipeline-id>

    # Poll specific branch
    $0 -t \$CIRCLECI_TOKEN -o jcppkkk -p dotfiles -b feature-branch
EOF
    exit 1
}

# Parse arguments
VERBOSE=false
BRANCH="main"
PIPELINE_ID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -t | --token)
            CIRCLECI_TOKEN="$2"
            shift 2
            ;;
        -o | --org)
            CIRCLECI_ORG="$2"
            shift 2
            ;;
        -p | --project)
            CIRCLECI_PROJECT="$2"
            shift 2
            ;;
        -b | --branch)
            BRANCH="$2"
            shift 2
            ;;
        -i | --interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        -w | --max-wait)
            MAX_WAIT="$2"
            shift 2
            ;;
        -v | --verbose)
            VERBOSE=true
            shift
            ;;
        -h | --help)
            usage
            ;;
        *)
            if [[ -z "$PIPELINE_ID" ]]; then
                PIPELINE_ID="$1"
            else
                echo "Error: Unknown argument $1"
                usage
            fi
            shift
            ;;
    esac
done

# Check required variables
if [[ -z "${CIRCLECI_TOKEN:-}" ]]; then
    echo -e "${RED}Error: CircleCI token is required${NC}"
    echo "Set CIRCLECI_TOKEN environment variable or use -t option"
    exit 1
fi

# Get pipeline ID if not provided
if [[ -z "$PIPELINE_ID" ]]; then
    if [[ -z "${CIRCLECI_ORG:-}" ]]; then
        echo -e "${RED}Error: CIRCLECI_ORG is required when polling by branch${NC}"
        echo "Current value: '${CIRCLECI_ORG:-<empty>}'"
        echo "Use -o option or set CIRCLECI_ORG environment variable"
        echo "Example: CIRCLECI_ORG=github/jcppkkk or CIRCLECI_ORG=jcppkkk"
        exit 1
    fi

    if [[ -z "${CIRCLECI_PROJECT:-}" ]]; then
        echo -e "${RED}Error: CIRCLECI_PROJECT is required when polling by branch${NC}"
        echo "Current value: '${CIRCLECI_PROJECT:-<empty>}'"
        echo "Use -p option or set CIRCLECI_PROJECT environment variable"
        echo "Example: CIRCLECI_PROJECT=dotfiles"
        exit 1
    fi

    # Get last pushed commit SHA
    LAST_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "")
    if [[ -n "$LAST_COMMIT" ]]; then
        echo -e "${BLUE}Last commit: ${LAST_COMMIT:0:7}${NC}"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}Fetching latest pipeline for ${CIRCLECI_ORG}/${CIRCLECI_PROJECT} on branch ${BRANCH}...${NC}"
    fi

    # Get latest pipeline for branch
    echo -e "${BLUE}Fetching pipelines for ${CIRCLECI_ORG}/${CIRCLECI_PROJECT} on branch ${BRANCH}...${NC}"
    PIPELINE_RESPONSE=$(curl -s -w "\n%{http_code}" -X GET \
        "${CIRCLECI_API_URL}/project/${CIRCLECI_ORG}/${CIRCLECI_PROJECT}/pipeline?branch=${BRANCH}" \
        -H "Circle-Token: ${CIRCLECI_TOKEN}" \
        -H "Accept: application/json")

    HTTP_CODE=$(echo "$PIPELINE_RESPONSE" | tail -1)
    PIPELINE_RESPONSE=$(echo "$PIPELINE_RESPONSE" | sed '$d')

    if [[ "$HTTP_CODE" != "200" ]]; then
        echo -e "${RED}Error: Failed to fetch pipelines (HTTP $HTTP_CODE)${NC}"
        echo "Response: $PIPELINE_RESPONSE"
        if echo "$PIPELINE_RESPONSE" | grep -q "Unauthorized"; then
            echo -e "${RED}Authentication failed. Please check your CIRCLECI_TOKEN.${NC}"
        elif echo "$PIPELINE_RESPONSE" | grep -q "Not Found"; then
            echo -e "${RED}Project not found. Please check CIRCLECI_ORG and CIRCLECI_PROJECT.${NC}"
            echo "Expected format: org=github/jcppkkk, project=dotfiles"
        fi
        exit 1
    fi

    # Check if response contains error
    if echo "$PIPELINE_RESPONSE" | grep -q '"message"'; then
        ERROR_MSG=$(echo "$PIPELINE_RESPONSE" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
        echo -e "${RED}Error from CircleCI API: ${ERROR_MSG}${NC}"
        exit 1
    fi

    # Try to find pipeline matching last commit if available
    if [[ -n "$LAST_COMMIT" ]]; then
        PIPELINE_ID=$(echo "$PIPELINE_RESPONSE" | grep -B 5 -A 5 "\"vcs\":{\"revision\":\"$LAST_COMMIT\"" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [[ -n "$PIPELINE_ID" ]]; then
            echo -e "${GREEN}Found pipeline matching commit ${LAST_COMMIT:0:7}: ${PIPELINE_ID}${NC}"
        fi
    fi

    # Fallback to latest pipeline if commit match not found
    if [[ -z "$PIPELINE_ID" ]]; then
        PIPELINE_ID=$(echo "$PIPELINE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        if [[ -n "$PIPELINE_ID" ]]; then
            echo -e "${YELLOW}Using latest pipeline (commit match not found): ${PIPELINE_ID}${NC}"
        fi
    fi

    if [[ -z "$PIPELINE_ID" ]]; then
        echo -e "${RED}Error: Could not find any pipeline for ${CIRCLECI_ORG}/${CIRCLECI_PROJECT} on branch ${BRANCH}${NC}"
        echo "This might mean:"
        echo "  1. No pipeline has been triggered for this branch yet"
        echo "  2. The branch name is incorrect"
        echo "  3. The project is not set up in CircleCI"
        if [[ "$VERBOSE" == "true" ]]; then
            echo "Full API response:"
            echo "$PIPELINE_RESPONSE" | head -50
        fi
        exit 1
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${GREEN}Found pipeline: ${PIPELINE_ID}${NC}"
    fi
fi

echo -e "${BLUE}Polling pipeline: ${PIPELINE_ID}${NC}"
echo -e "Poll interval: ${POLL_INTERVAL}s, Max wait: ${MAX_WAIT}s"
echo ""

START_TIME=$(date +%s)
LAST_STATUS=""

while true; do
    ELAPSED=$(($(date +%s) - START_TIME))

    if [[ $ELAPSED -gt $MAX_WAIT ]]; then
        echo -e "${RED}Timeout: Exceeded maximum wait time of ${MAX_WAIT}s${NC}"
        exit 1
    fi

    # Get pipeline status
    PIPELINE_STATUS=$(curl -s -X GET \
        "${CIRCLECI_API_URL}/pipeline/${PIPELINE_ID}" \
        -H "Circle-Token: ${CIRCLECI_TOKEN}" \
        -H "Accept: application/json")

    STATE=$(echo "$PIPELINE_STATUS" | grep -o '"state":"[^"]*"' | head -1 | cut -d'"' -f4 || echo "unknown")

    if [[ "$STATE" != "$LAST_STATUS" ]]; then
        case "$STATE" in
            "created" | "errored" | "setup-pending" | "setup" | "pending")
                echo -e "${YELLOW}[$(date +%H:%M:%S)] Pipeline state: ${STATE}${NC}"
                ;;
            "running")
                echo -e "${BLUE}[$(date +%H:%M:%S)] Pipeline state: ${STATE}${NC}"
                ;;
            "success")
                echo -e "${GREEN}[$(date +%H:%M:%S)] Pipeline state: ${STATE} ✓${NC}"
                ;;
            "failed" | "canceled")
                echo -e "${RED}[$(date +%H:%M:%S)] Pipeline state: ${STATE} ✗${NC}"
                ;;
            *)
                echo -e "[$(date +%H:%M:%S)] Pipeline state: ${STATE}"
                ;;
        esac
        LAST_STATUS="$STATE"
    fi

    # Check if pipeline is complete
    case "$STATE" in
        "success")
            echo -e "${GREEN}Pipeline completed successfully!${NC}"
            exit 0
            ;;
        "failed" | "canceled" | "error" | "errored")
            echo -e "${RED}Pipeline failed or was canceled${NC}"
            echo ""
            echo -e "${YELLOW}Fetching error details...${NC}"

            # Get workflow details to show which jobs failed
            WORKFLOWS=$(curl -s -X GET \
                "${CIRCLECI_API_URL}/pipeline/${PIPELINE_ID}/workflow" \
                -H "Circle-Token: ${CIRCLECI_TOKEN}" \
                -H "Accept: application/json")

            # Extract failed workflows
            FAILED_WORKFLOWS=$(echo "$WORKFLOWS" | grep -o '"id":"[^"]*".*"status":"failed"' | head -5)

            if [[ -n "$FAILED_WORKFLOWS" ]]; then
                echo -e "${RED}Failed workflows:${NC}"
                echo "$WORKFLOWS" | grep -E '"id"|"name"|"status"' | grep -A 2 -B 2 "failed" | head -20
            fi

            # Get job details for failed jobs
            WORKFLOW_IDS=$(echo "$WORKFLOWS" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
            for WORKFLOW_ID in $WORKFLOW_IDS; do
                JOBS=$(curl -s -X GET \
                    "${CIRCLECI_API_URL}/workflow/${WORKFLOW_ID}/job" \
                    -H "Circle-Token: ${CIRCLECI_TOKEN}" \
                    -H "Accept: application/json")

                FAILED_JOBS=$(echo "$JOBS" | grep -E '"name".*"status":"failed"|"status":"failed"' | head -10)
                if [[ -n "$FAILED_JOBS" ]]; then
                    echo -e "${RED}Failed jobs:${NC}"
                    echo "$JOBS" | grep -E '"name"|"status"' | grep -B 1 "failed" | head -20
                fi
            done

            # Show pipeline URL if available
            PIPELINE_VCS=$(echo "$PIPELINE_STATUS" | grep -o '"vcs":{[^}]*}' | head -1)
            if [[ -n "$PIPELINE_VCS" ]]; then
                REPO_SLUG=$(echo "$PIPELINE_VCS" | grep -o '"repository_url":"[^"]*"' | cut -d'"' -f4 | sed 's|https://github.com/||' | sed 's|\.git$||')
                if [[ -n "$REPO_SLUG" ]]; then
                    echo ""
                    echo -e "${BLUE}View pipeline: https://app.circleci.com/pipelines/${CIRCLECI_ORG}/${CIRCLECI_PROJECT}/${PIPELINE_ID}${NC}"
                fi
            fi

            exit 1
            ;;
    esac

    # Get workflow status for more details
    if [[ "$VERBOSE" == "true" ]]; then
        WORKFLOWS=$(curl -s -X GET \
            "${CIRCLECI_API_URL}/pipeline/${PIPELINE_ID}/workflow" \
            -H "Circle-Token: ${CIRCLECI_TOKEN}" \
            -H "Accept: application/json")

        echo "$WORKFLOWS" | grep -o '"status":"[^"]*"' | while read -r status_line; do
            STATUS=$(echo "$status_line" | cut -d'"' -f4)
            echo "  Workflow status: $STATUS"
        done
    fi

    sleep "$POLL_INTERVAL"
done

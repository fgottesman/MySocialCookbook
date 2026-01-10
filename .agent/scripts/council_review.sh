#!/bin/bash
# Council Review Script
# Runs all 4 persona sub-agents against a git diff and aggregates results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_CONFIG="$SCRIPT_DIR/council_agents.json"
DIFF_FILE="/tmp/council_review_diff.txt"
OUTPUT_DIR="/tmp/council_review_output"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🏛️  COUNCIL REVIEW${NC}"
echo "=================================="

# Determine what to review
if [ -n "$1" ]; then
    # Review a specific commit
    COMMIT="$1"
    echo -e "Reviewing commit: ${YELLOW}$COMMIT${NC}"
    git diff "$COMMIT^..$COMMIT" > "$DIFF_FILE"
else
    # Review staged changes, or if none, unstaged changes
    if git diff --cached --quiet; then
        echo -e "Reviewing: ${YELLOW}unstaged changes${NC}"
        git diff > "$DIFF_FILE"
    else
        echo -e "Reviewing: ${YELLOW}staged changes${NC}"
        git diff --cached > "$DIFF_FILE"
    fi
fi

# Check if there's anything to review
if [ ! -s "$DIFF_FILE" ]; then
    echo -e "${RED}No changes to review!${NC}"
    exit 1
fi

LINES=$(wc -l < "$DIFF_FILE" | tr -d ' ')
echo -e "Diff size: ${YELLOW}$LINES lines${NC}"
echo ""

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Run all 4 agents in parallel
echo -e "${BLUE}Spawning sub-agents...${NC}"

run_agent() {
    local PERSONA=$1
    local OUTPUT_FILE="$OUTPUT_DIR/$PERSONA.txt"
    
    case $PERSONA in
        architect)
            PROMPT="You are the ARCHITECT reviewer. Analyze if this code change aligns with the overall project structure, architecture patterns, and long-term maintainability. Be specific about concerns. Start your response with APPROVED, CONCERNS, or BLOCKED."
            ;;
        risk)
            PROMPT="You are the RISK-TEAM reviewer. Identify security vulnerabilities, performance regressions, breaking changes, or production risks. Pay special attention to Node.js/dependency version compatibility, ESM vs CommonJS issues, API breaking changes. Be paranoid. Start your response with APPROVED, CONCERNS, or BLOCKED."
            ;;
        testing)
            PROMPT="You are the TESTING reviewer. Evaluate test coverage, identify missing edge cases, and flag untested code paths. Look for missing error handling and validation gaps. Start your response with APPROVED, CONCERNS, or BLOCKED."
            ;;
        perfectionist)
            PROMPT="You are THE-PERFECTIONIST reviewer. Check code cleanliness, formatting, naming conventions, typos, orphan words in UI text, and code smells. Be meticulous. Start your response with APPROVED, CONCERNS, or BLOCKED."
            ;;
    esac
    
    claude -p --append-system-prompt "$PROMPT" "Review this diff:

$(cat $DIFF_FILE)" > "$OUTPUT_FILE" 2>&1
}

# Run agents in parallel
echo -e "  🏗️  Architect..."
run_agent "architect" &
PID1=$!

echo -e "  ⚠️  Risk-team..."
run_agent "risk" &
PID2=$!

echo -e "  🧪 Testing..."
run_agent "testing" &
PID3=$!

echo -e "  ✨ The-perfectionist..."
run_agent "perfectionist" &
PID4=$!

echo ""
echo -e "${BLUE}Waiting for sub-agents to complete...${NC}"

# Wait for all to complete
wait $PID1 $PID2 $PID3 $PID4

echo ""
echo -e "${BLUE}=================================="
echo -e "📋 AGGREGATED RESULTS"
echo -e "==================================${NC}"
echo ""

# Function to extract verdict
get_verdict() {
    local FILE=$1
    local FIRST_LINE=$(head -1 "$FILE" | tr '[:lower:]' '[:upper:]')
    
    if echo "$FIRST_LINE" | grep -q "BLOCKED"; then
        echo "BLOCKED"
    elif echo "$FIRST_LINE" | grep -q "CONCERNS"; then
        echo "CONCERNS"
    elif echo "$FIRST_LINE" | grep -q "APPROVED"; then
        echo "APPROVED"
    else
        # Try to find verdict in first few lines
        local CONTENT=$(head -10 "$FILE" | tr '[:lower:]' '[:upper:]')
        if echo "$CONTENT" | grep -q "BLOCKED"; then
            echo "BLOCKED"
        elif echo "$CONTENT" | grep -q "CONCERNS"; then
            echo "CONCERNS"
        elif echo "$CONTENT" | grep -q "APPROVED"; then
            echo "APPROVED"
        else
            echo "UNKNOWN"
        fi
    fi
}

# Display summary table
echo "| Persona         | Verdict   |"
echo "|-----------------|-----------|"

BLOCKED=0
CONCERNS=0

for PERSONA in architect risk testing perfectionist; do
    VERDICT=$(get_verdict "$OUTPUT_DIR/$PERSONA.txt")
    
    case $VERDICT in
        BLOCKED)
            echo -e "| ${PERSONA^} | ${RED}⛔ BLOCKED${NC} |"
            BLOCKED=$((BLOCKED + 1))
            ;;
        CONCERNS)
            echo -e "| ${PERSONA^} | ${YELLOW}⚠️  CONCERNS${NC} |"
            CONCERNS=$((CONCERNS + 1))
            ;;
        APPROVED)
            echo -e "| ${PERSONA^} | ${GREEN}✅ APPROVED${NC} |"
            ;;
        *)
            echo -e "| ${PERSONA^} | ❓ UNKNOWN |"
            ;;
    esac
done

echo ""

# Final verdict
if [ $BLOCKED -gt 0 ]; then
    echo -e "${RED}🚫 FINAL VERDICT: BLOCKED${NC}"
    echo -e "${RED}$BLOCKED persona(s) blocked this change. Address their concerns before pushing.${NC}"
elif [ $CONCERNS -gt 0 ]; then
    echo -e "${YELLOW}⚠️  FINAL VERDICT: REVIEW CONCERNS${NC}"
    echo -e "${YELLOW}$CONCERNS persona(s) raised concerns. Consider addressing before pushing.${NC}"
else
    echo -e "${GREEN}✅ FINAL VERDICT: APPROVED${NC}"
    echo -e "${GREEN}All personas approved. Safe to push!${NC}"
fi

echo ""
echo -e "${BLUE}Detailed reports saved to: $OUTPUT_DIR/${NC}"
echo ""

# Show detailed output if requested
if [ "$2" == "--verbose" ] || [ "$2" == "-v" ]; then
    for PERSONA in architect risk testing perfectionist; do
        echo -e "${BLUE}=== ${PERSONA^^} DETAILED REVIEW ===${NC}"
        cat "$OUTPUT_DIR/$PERSONA.txt"
        echo ""
    done
fi

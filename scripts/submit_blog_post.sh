#!/bin/bash

# Blog Post Submission Script
# Usage: ./scripts/submit_blog_post.sh <markdown_file> [options]

set -e

# Configuration
API_ENDPOINT="https://stephenloggedon.com:8443/api/posts"
CERT_PATH="priv/cert/clients/client-cert.pem"
KEY_PATH="priv/cert/clients/client-key.pem"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print usage
usage() {
    echo "Usage: $0 <markdown_file> [options]"
    echo ""
    echo "Options:"
    echo "  --title <title>       Override title (defaults to first # heading)"
    echo "  --slug <slug>         Override slug (defaults to filename-based slug)"
    echo "  --tags <tags>         Comma-separated tags"
    echo "  --subtitle <subtitle> Post subtitle"
    echo "  --unpublished         Create as draft (default: published)"
    echo "  --dry-run             Show what would be sent without submitting"
    echo "  --help                Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 my_post.md --tags 'Tech,Blog' --subtitle 'A great post'"
    echo "  $0 /path/to/post.md --unpublished --dry-run"
}

# Function to extract title from markdown
extract_title() {
    local file="$1"
    # Get first line that starts with # and remove the #
    grep -m 1 '^#[^#]' "$file" 2>/dev/null | sed 's/^#[[:space:]]*//' || echo ""
}

# Function to generate slug from filename or title
generate_slug() {
    local input="$1"
    echo "$input" | \
        tr '[:upper:]' '[:lower:]' | \
        sed 's/[^a-z0-9]/-/g' | \
        sed 's/--*/-/g' | \
        sed 's/^-\|-$//g'
}

# Function to remove title from content
remove_title_from_content() {
    local file="$1"
    # Remove first line if it starts with # (title)
    if head -n 1 "$file" | grep -q '^#[^#]'; then
        tail -n +2 "$file"
    else
        cat "$file"
    fi
}

# Function to escape JSON (using jq for proper escaping)
escape_json() {
    # Use jq to properly escape content for JSON
    jq -Rs .
}

# Function to make the API request
submit_post() {
    local json_payload="$1"
    local dry_run="$2"
    
    if [ "$dry_run" = "true" ]; then
        echo -e "${YELLOW}DRY RUN - Would submit:${NC}"
        echo "$json_payload" | jq '.' 2>/dev/null || echo "$json_payload"
        return 0
    fi
    
    echo -e "${BLUE}Submitting blog post...${NC}"
    
    # Make the curl request
    local response
    response=$(curl -s -X POST "$API_ENDPOINT" \
        --cert "$CERT_PATH" \
        --key "$KEY_PATH" \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        -k)
    
    # Check if request was successful
    if echo "$response" | jq -e '.data' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Blog post submitted successfully!${NC}"
        echo "$response" | jq '.data | {id, title, slug, published, tags}'
    else
        echo -e "${RED}❌ Error submitting blog post:${NC}"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        exit 1
    fi
}

# Parse command line arguments
MARKDOWN_FILE=""
TITLE=""
SLUG=""
TAGS=""
SUBTITLE=""
PUBLISHED="true"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --title)
            TITLE="$2"
            shift 2
            ;;
        --slug)
            SLUG="$2"
            shift 2
            ;;
        --tags)
            TAGS="$2"
            shift 2
            ;;
        --subtitle)
            SUBTITLE="$2"
            shift 2
            ;;
        --unpublished)
            PUBLISHED="false"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        -*)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
        *)
            if [ -z "$MARKDOWN_FILE" ]; then
                MARKDOWN_FILE="$1"
            else
                echo -e "${RED}Multiple files specified. Only one file allowed.${NC}"
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$MARKDOWN_FILE" ]; then
    echo -e "${RED}Error: Markdown file is required${NC}"
    usage
    exit 1
fi

if [ ! -f "$MARKDOWN_FILE" ]; then
    echo -e "${RED}Error: File '$MARKDOWN_FILE' not found${NC}"
    exit 1
fi

# Check for required certificate files
if [ ! -f "$CERT_PATH" ] || [ ! -f "$KEY_PATH" ]; then
    echo -e "${RED}Error: Certificate files not found${NC}"
    echo "Expected: $CERT_PATH and $KEY_PATH"
    exit 1
fi

# Extract or use provided values
if [ -z "$TITLE" ]; then
    TITLE=$(extract_title "$MARKDOWN_FILE")
    if [ -z "$TITLE" ]; then
        echo -e "${RED}Error: Could not extract title from file and none provided${NC}"
        exit 1
    fi
fi

if [ -z "$SLUG" ]; then
    # Generate slug from filename (remove extension)
    FILENAME=$(basename "$MARKDOWN_FILE")
    SLUG=$(generate_slug "${FILENAME%.*}")
fi

# Get content without title (already JSON-escaped)
CONTENT=$(remove_title_from_content "$MARKDOWN_FILE" | escape_json)

# Build JSON payload
JSON_PAYLOAD=$(jq -n \
    --arg title "$TITLE" \
    --argjson content "$CONTENT" \
    --arg slug "$SLUG" \
    --arg tags "$TAGS" \
    --arg subtitle "$SUBTITLE" \
    --argjson published "$PUBLISHED" \
    '{
        title: $title,
        content: $content,
        slug: $slug,
        tags: $tags,
        subtitle: $subtitle,
        published: $published
    }' | jq 'with_entries(select(.value != ""))')

echo -e "${BLUE}Preparing to submit:${NC}"
echo "  📄 File: $MARKDOWN_FILE"
echo "  📝 Title: $TITLE"
echo "  🔗 Slug: $SLUG"
echo "  🏷️  Tags: ${TAGS:-"(none)"}"
echo "  📋 Subtitle: ${SUBTITLE:-"(none)"}"
echo "  📊 Published: $PUBLISHED"
echo "  📏 Content size: $(remove_title_from_content "$MARKDOWN_FILE" | wc -c | tr -d ' ') characters"

# Submit the post
submit_post "$JSON_PAYLOAD" "$DRY_RUN"
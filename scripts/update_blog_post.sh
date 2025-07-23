#!/bin/bash

# Blog Post Update Script
# Usage: ./scripts/update_blog_post.sh <post_id> <markdown_file> [options]

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
    echo "Usage: $0 <post_id> <markdown_file> [options]"
    echo ""
    echo "Options:"
    echo "  --content-only        Update only content (from file)"
    echo "  --title <title>       Update title"
    echo "  --tags <tags>         Update tags"
    echo "  --subtitle <subtitle> Update subtitle"
    echo "  --publish             Set published to true"
    echo "  --unpublish           Set published to false"
    echo "  --dry-run             Show what would be sent without updating"
    echo "  --help                Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 26 updated_post.md --content-only"
    echo "  $0 26 post.md --title 'New Title' --tags 'Updated,Tags'"
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
update_post() {
    local post_id="$1"
    local json_payload="$2"
    local dry_run="$3"
    
    if [ "$dry_run" = "true" ]; then
        echo -e "${YELLOW}DRY RUN - Would update post $post_id with:${NC}"
        echo "$json_payload" | jq '.' 2>/dev/null || echo "$json_payload"
        return 0
    fi
    
    echo -e "${BLUE}Updating blog post $post_id...${NC}"
    
    # Make the curl request
    local response
    response=$(curl -s -X PATCH "$API_ENDPOINT/$post_id" \
        --cert "$CERT_PATH" \
        --key "$KEY_PATH" \
        -H "Content-Type: application/json" \
        -d "$json_payload" \
        -k)
    
    # Check if request was successful
    if echo "$response" | jq -e '.data' > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Blog post updated successfully!${NC}"
        echo "$response" | jq '.data | {id, title, slug, published, tags}'
    else
        echo -e "${RED}❌ Error updating blog post:${NC}"
        echo "$response" | jq '.' 2>/dev/null || echo "$response"
        exit 1
    fi
}

# Parse command line arguments
POST_ID=""
MARKDOWN_FILE=""
CONTENT_ONLY="false"
TITLE=""
TAGS=""
SUBTITLE=""
PUBLISHED=""
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --content-only)
            CONTENT_ONLY="true"
            shift
            ;;
        --title)
            TITLE="$2"
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
        --publish)
            PUBLISHED="true"
            shift
            ;;
        --unpublish)
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
            if [ -z "$POST_ID" ]; then
                POST_ID="$1"
            elif [ -z "$MARKDOWN_FILE" ]; then
                MARKDOWN_FILE="$1"
            else
                echo -e "${RED}Too many arguments${NC}"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$POST_ID" ]; then
    echo -e "${RED}Error: Post ID is required${NC}"
    usage
    exit 1
fi

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

# Build update payload
if [ "$CONTENT_ONLY" = "true" ]; then
    # Only update content
    CONTENT=$(remove_title_from_content "$MARKDOWN_FILE" | escape_json)
    JSON_PAYLOAD=$(jq -n --argjson content "$CONTENT" '{content: $content}')
    echo -e "${BLUE}Updating content only from: $MARKDOWN_FILE${NC}"
else
    # Build full update payload
    CONTENT=$(remove_title_from_content "$MARKDOWN_FILE" | escape_json)
    
    # Start with content
    JSON_PAYLOAD=$(jq -n --argjson content "$CONTENT" '{content: $content}')
    
    # Add other fields if provided
    if [ -n "$TITLE" ]; then
        JSON_PAYLOAD=$(echo "$JSON_PAYLOAD" | jq --arg title "$TITLE" '. + {title: $title}')
    fi
    
    if [ -n "$TAGS" ]; then
        JSON_PAYLOAD=$(echo "$JSON_PAYLOAD" | jq --arg tags "$TAGS" '. + {tags: $tags}')
    fi
    
    if [ -n "$SUBTITLE" ]; then
        JSON_PAYLOAD=$(echo "$JSON_PAYLOAD" | jq --arg subtitle "$SUBTITLE" '. + {subtitle: $subtitle}')
    fi
    
    if [ -n "$PUBLISHED" ]; then
        JSON_PAYLOAD=$(echo "$JSON_PAYLOAD" | jq --argjson published "$PUBLISHED" '. + {published: $published}')
    fi
    
    echo -e "${BLUE}Updating post $POST_ID with:${NC}"
    [ -n "$TITLE" ] && echo "  📝 Title: $TITLE"
    [ -n "$TAGS" ] && echo "  🏷️  Tags: $TAGS"
    [ -n "$SUBTITLE" ] && echo "  📋 Subtitle: $SUBTITLE"
    [ -n "$PUBLISHED" ] && echo "  📊 Published: $PUBLISHED"
fi

echo "  📄 Content from: $MARKDOWN_FILE"
echo "  📏 Content size: $(remove_title_from_content "$MARKDOWN_FILE" | wc -c | tr -d ' ') characters"

# Update the post
update_post "$POST_ID" "$JSON_PAYLOAD" "$DRY_RUN"
# Blog Post Submission Scripts

These scripts make it easy to submit and update blog posts using the chunked upload API.

## Prerequisites

- mTLS certificates must be present at:
  - `priv/cert/clients/client-cert.pem`
  - `priv/cert/clients/client-key.pem`
- `jq` command-line JSON processor must be installed
- The blog API must be running at `https://stephenloggedon.com:8443`

## Scripts

### `submit_blog_post.sh` - Create New Posts

Creates a new blog post from a markdown file.

**Basic Usage:**
```bash
./scripts/submit_blog_post.sh my_post.md
```

**With Options:**
```bash
./scripts/submit_blog_post.sh my_post.md \
  --tags "Phoenix,Elixir,Tutorial" \
  --subtitle "A comprehensive guide" \
  --unpublished
```

**Available Options:**
- `--title <title>` - Override title (defaults to first # heading in file)
- `--slug <slug>` - Override slug (defaults to filename-based slug)
- `--tags <tags>` - Comma-separated tags
- `--subtitle <subtitle>` - Post subtitle
- `--unpublished` - Create as draft (default: published)
- `--dry-run` - Show what would be sent without submitting
- `--help` - Show help

**Features:**
- Automatically extracts title from first `# heading` in markdown
- Removes duplicate title from content to avoid title repetition
- Generates slug from filename if not provided
- Uses chunked upload for large content automatically
- Validates certificates before submission

### `update_blog_post.sh` - Update Existing Posts

Updates an existing blog post.

**Basic Usage (content only):**
```bash
./scripts/update_blog_post.sh 26 updated_content.md --content-only
```

**Update multiple fields:**
```bash
./scripts/update_blog_post.sh 26 my_post.md \
  --title "New Title" \
  --tags "Updated,Tags" \
  --publish
```

**Available Options:**
- `--content-only` - Update only content from file
- `--title <title>` - Update title
- `--tags <tags>` - Update tags  
- `--subtitle <subtitle>` - Update subtitle
- `--publish` - Set published to true
- `--unpublish` - Set published to false
- `--dry-run` - Show what would be sent without updating
- `--help` - Show help

## Examples

### Submit a new blog post:
```bash
# Simple submission
./scripts/submit_blog_post.sh /Users/stephen/devlog/my_new_post.md

# With custom options
./scripts/submit_blog_post.sh my_post.md \
  --title "Custom Title" \
  --tags "Tech,Tutorial,Phoenix" \
  --subtitle "Learn advanced techniques" \
  --dry-run
```

### Update existing post content:
```bash
# Update only content from file (most common)
./scripts/update_blog_post.sh 26 /Users/stephen/devlog/updated_post.md --content-only

# Update content and metadata
./scripts/update_blog_post.sh 26 my_post.md \
  --title "Updated Title" \
  --tags "New,Tags"
```

### Test before submitting:
```bash
# Always test with --dry-run first
./scripts/submit_blog_post.sh my_post.md --dry-run
./scripts/update_blog_post.sh 26 my_post.md --content-only --dry-run
```

## How It Works

1. **Title Extraction**: Automatically finds first `# heading` in markdown file
2. **Content Processing**: Removes the title line to prevent duplication
3. **JSON Escaping**: Properly escapes quotes and newlines for JSON payload
4. **Chunked Upload**: Uses the API's automatic chunked upload for large content
5. **Validation**: Checks for required files and certificates before submission
6. **Feedback**: Provides clear success/error messages with response details

## Script Output

The scripts provide colored output showing:
- 📄 Source file information
- 📝 Title and metadata being used  
- 📏 Content size
- ✅ Success confirmation with post details
- ❌ Error messages with API response

## Troubleshooting

**Certificate not found:**
- Ensure mTLS certificates are in `priv/cert/clients/`
- Check certificate file permissions

**jq command not found:**
```bash
# Install jq
brew install jq  # macOS
sudo apt install jq  # Ubuntu
```

**Large content fails:**
- The chunked upload should handle large files automatically
- Check server logs if issues persist

**Invalid JSON:**
- Ensure markdown file is valid UTF-8
- Check for special characters that might break JSON escaping
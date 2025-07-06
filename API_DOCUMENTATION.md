# Blog API Documentation

## Overview

The Blog API provides RESTful endpoints for managing blog posts with API key authentication for write operations. Read operations are public, while create, update, and delete operations require authentication.

## Authentication

### API Key Authentication

Write operations (POST, PUT, DELETE) require an API key to be included in the `X-API-Key` header.

**Header Format:**
```
X-API-Key: your-api-key-here
```

**Current Test API Key:**
```
blog-api-test-key-2024
```

> **Note:** In production, API keys should be securely generated and distributed to authorized clients.

## Blog Post Endpoints

### Public Endpoints (No Authentication Required)

#### List Posts
```http
GET /api/posts?page=1&per_page=20
```

**Query Parameters:**
- `page` (optional): Page number for pagination (default: 1)
- `per_page` (optional): Number of posts per page (default: 20, max: 100)

**Response:**
```json
{
  "data": [
    {
      "id": 123,
      "title": "My Blog Post",
      "slug": "my-blog-post", 
      "content": "Post content here...",
      "excerpt": "Auto-generated excerpt...",
      "tags": "elixir, phoenix",
      "published": true,
      "published_at": "2024-01-01T00:00:00Z",
      "inserted_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

#### Get Single Post
```http
GET /api/posts/:id
```

**Response:**
```json
{
  "data": {
    "id": 123,
    "title": "My Blog Post",
    "slug": "my-blog-post",
    "content": "Full post content...",
    "excerpt": "Post excerpt...",
    "tags": "elixir, phoenix",
    "published": true,
    "published_at": "2024-01-01T00:00:00Z",
    "inserted_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

### Authenticated Endpoints (API Key Required)

#### Create Post
```http
POST /api/posts
X-API-Key: your-api-key
Content-Type: application/json

{
  "metadata": "{\"title\":\"My New Post\",\"content\":\"Post content\",\"tags\":\"elixir, phoenix\",\"published\":true}"
}
```

**With Images:**
```http
POST /api/posts
X-API-Key: your-api-key
Content-Type: multipart/form-data

metadata: {"title":"My Post","content":"Content with {{image_0}} placeholder","published":true}
images: [file1.jpg, file2.png]
```

**Response:**
```json
{
  "data": {
    "id": 124,
    "title": "My New Post",
    "slug": "my-new-post",
    "content": "Post content",
    "excerpt": "Post content",
    "tags": "elixir, phoenix",
    "published": true,
    "published_at": "2024-01-01T00:00:00Z",
    "inserted_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
}
```

#### Update Post
```http
PUT /api/posts/:id
X-API-Key: your-api-key
Content-Type: application/json

{
  "metadata": "{\"title\":\"Updated Title\",\"content\":\"Updated content\"}"
}
```

#### Delete Post
```http
DELETE /api/posts/:id
X-API-Key: your-api-key
```

**Response:** 204 No Content

## Image Upload

### Supported Formats
- JPEG (.jpg, .jpeg)
- PNG (.png)
- GIF (.gif)
- WebP (.webp)

### Size Limits
- Maximum file size: 10MB per image
- Maximum request size: 10MB total

### Image Processing
- Images are uploaded to cloud storage (AWS S3 or compatible)
- Public URLs are generated and inserted into post content
- Image placeholders in content ({{image_0}}, {{image_1}}) are replaced with markdown image syntax

## Metadata Format

Post metadata must be provided as a JSON string in the `metadata` field:

```json
{
  "title": "Required - Post title",
  "content": "Required - Post content (markdown supported)",
  "tags": "Optional - Comma-separated tags",
  "published": "Optional - Boolean (default: false)",
  "subtitle": "Optional - Post subtitle",
  "excerpt": "Optional - Auto-generated if not provided",
  "slug": "Optional - Auto-generated from title if not provided"
}
```

## Error Responses

### Authentication Error
```json
{
  "error": "API key required in X-API-Key header"
}
```

```json
{
  "error": "Invalid API key"
}
```

### Validation Errors
```json
{
  "errors": {
    "title": ["can't be blank"],
    "content": ["can't be blank"]
  }
}
```

### Not Found
```json
{
  "message": "Post not found"
}
```

## Example Usage

### Using cURL

#### List Posts (Public)
```bash
curl -X GET http://localhost:4000/api/posts
```

#### Create Post (Authenticated)
```bash
curl -X POST http://localhost:4000/api/posts \
  -H "X-API-Key: blog-api-test-key-2024" \
  -H "Content-Type: application/json" \
  -d '{"metadata": "{\"title\":\"Hello World\",\"content\":\"My first post via API\"}"}'
```

#### Update Post (Authenticated)
```bash
curl -X PUT http://localhost:4000/api/posts/123 \
  -H "X-API-Key: blog-api-test-key-2024" \
  -H "Content-Type: application/json" \
  -d '{"metadata": "{\"title\":\"Updated Title\"}"}'
```

#### Delete Post (Authenticated)
```bash
curl -X DELETE http://localhost:4000/api/posts/123 \
  -H "X-API-Key: blog-api-test-key-2024"
```

### With Images
```bash
curl -X POST http://localhost:4000/api/posts \
  -H "X-API-Key: blog-api-test-key-2024" \
  -F 'metadata={"title":"Post with Image","content":"Check out this image: {{image_0}}"}' \
  -F 'images=@/path/to/image.jpg'
```

## Security Features

- **API Key Authentication**: Write operations require valid API key
- **Public Read Access**: Read operations remain publicly accessible
- **Input Validation**: All inputs validated and sanitized
- **Image Upload Security**: File type and size validation
- **SSL Support**: HTTPS configuration available for production

## Future Authentication Enhancements

The current implementation uses simple API key authentication. Future versions may include:

- **mTLS Client Certificates**: Mutual TLS authentication using client certificates
- **JWT Tokens**: Stateless token-based authentication
- **HMAC Signatures**: Request signing with replay protection
- **OAuth 2.0**: Third-party authentication integration

The certificate infrastructure has been prepared for mTLS implementation:
- Certificate Authority (CA) setup in `priv/cert/ca/`
- Server certificates in `priv/cert/server/`
- Client certificate templates in `priv/cert/clients/`

## Environment Variables

### Required for Production
```bash
SECRET_KEY_BASE=your-phoenix-secret-key
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
AWS_REGION=us-east-1
S3_BUCKET=your-bucket-name
```

### Optional
```bash
S3_ENDPOINT=https://your-custom-s3-endpoint.com  # For S3-compatible services
```

This API provides a simple yet secure solution for blog post management with clear separation between public read access and authenticated write operations.
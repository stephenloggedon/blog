# Blog API Documentation

## Overview

The Blog API provides RESTful endpoints for managing blog posts with mTLS (mutual TLS) client certificate authentication for write operations. Read operations are public, while create, update, and delete operations require valid client certificates.

## Authentication

### mTLS Client Certificate Authentication

Write operations (POST, PUT, DELETE) require a valid client certificate signed by the Blog API Certificate Authority (CA).

**Requirements:**
- Client certificate signed by the Blog API CA
- Private key corresponding to the client certificate
- HTTPS connection to port 8443

**Certificate Generation:**
Client certificates must be issued by the Blog API Certificate Authority. Contact your administrator for certificate issuance.

> **Note:** Read operations (GET) do not require client certificates and can be accessed via HTTP or HTTPS.

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

### Using cURL with mTLS

#### List Posts (Public - No Certificate Required)
```bash
# Via HTTP
curl -X GET http://localhost:4000/api/posts

# Via HTTPS without client certificate
curl -X GET --cacert priv/cert/ca/ca.pem https://localhost:8443/api/posts
```

#### Create Post (mTLS Authentication Required)
```bash
curl -X POST https://localhost:8443/api/posts \
  --cacert priv/cert/ca/ca.pem \
  --cert client-cert.pem \
  --key client-key.pem \
  -H "Content-Type: application/json" \
  -d '{"metadata": "{\"title\":\"Hello World\",\"content\":\"My first post via mTLS API\"}"}'
```

#### Update Post (mTLS Authentication Required)
```bash
curl -X PUT https://localhost:8443/api/posts/123 \
  --cacert priv/cert/ca/ca.pem \
  --cert client-cert.pem \
  --key client-key.pem \
  -H "Content-Type: application/json" \
  -d '{"metadata": "{\"title\":\"Updated Title\"}"}'
```

#### Delete Post (mTLS Authentication Required)
```bash
curl -X DELETE https://localhost:8443/api/posts/123 \
  --cacert priv/cert/ca/ca.pem \
  --cert client-cert.pem \
  --key client-key.pem
```

### With Images
```bash
curl -X POST https://localhost:8443/api/posts \
  --cacert priv/cert/ca/ca.pem \
  --cert client-cert.pem \
  --key client-key.pem \
  -F 'metadata={"title":"Post with Image","content":"Check out this image: {{image_0}}"}' \
  -F 'images=@/path/to/image.jpg'
```

## Security Features

- **mTLS Client Certificate Authentication**: Enterprise-grade mutual TLS authentication
- **Certificate Authority Validation**: All client certificates verified against trusted CA
- **Public Read Access**: Read operations remain publicly accessible
- **Encrypted Communication**: All authenticated requests use HTTPS with strong cipher suites
- **Input Validation**: All inputs validated and sanitized
- **Image Upload Security**: File type and size validation
- **Certificate-based Identity**: No shared secrets, each client has unique certificate identity

## Certificate Management

### Certificate Authority (CA)
- Self-signed root CA certificate: `priv/cert/ca/ca.pem`
- CA private key: `priv/cert/ca/ca-key.pem` (secure storage required)

### Server Certificates
- Server certificate: `priv/cert/server/server-cert.pem`
- Server private key: `priv/cert/server/server-key.pem`

### Client Certificates
- Template client certificate: `priv/cert/clients/client-cert.pem`
- Template client private key: `priv/cert/clients/client-key.pem`

### Certificate Issuance Process
1. Generate client private key: `openssl genrsa -out client-key.pem 4096`
2. Create certificate signing request: `openssl req -new -key client-key.pem -out client.csr`
3. Sign with CA: `openssl x509 -req -in client.csr -CA ca.pem -CAkey ca-key.pem -out client-cert.pem`

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
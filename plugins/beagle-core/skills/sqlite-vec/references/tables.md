# vec0 Virtual Tables

## Table of Contents
- [Basic Table Creation](#basic-table-creation)
- [Vector Column Types](#vector-column-types)
- [Metadata Columns](#metadata-columns)
- [Partition Key Columns](#partition-key-columns)
- [Auxiliary Columns](#auxiliary-columns)
- [Performance Tuning](#performance-tuning)

## Basic Table Creation

### Simple vec0 Table
```sql
CREATE VIRTUAL TABLE vec_items USING vec0(
  embedding float[4]
);
```

### With Primary Key
```sql
CREATE VIRTUAL TABLE vec_documents USING vec0(
  document_id integer primary key,
  contents_embedding float[768]
);
```

### With Distance Metric
```sql
CREATE VIRTUAL TABLE vec_documents USING vec0(
  document_id integer primary key,
  contents_embedding float[768] distance_metric=cosine
);
```

Distance metrics: `l2` (default), `cosine`, `hamming` (for bit vectors)

## Vector Column Types

### float[N] - Float32 Vectors
4 bytes per element, most common for embeddings:

```sql
CREATE VIRTUAL TABLE vec_embeddings USING vec0(
  embedding float[1536]  -- OpenAI text-embedding-3-small
);
```

### int8[N] - 8-bit Integer Vectors
1 byte per element, for quantized embeddings:

```sql
CREATE VIRTUAL TABLE vec_quantized USING vec0(
  embedding int8[768]
);
```

### bit[N] - Binary Vectors
1 bit per element (packed into bytes), for binary quantization:

```sql
CREATE VIRTUAL TABLE vec_binary USING vec0(
  embedding bit[768]  -- 96 bytes storage
);
```

## Metadata Columns

Metadata columns are indexed alongside vectors and can be filtered in KNN queries.

### Supported Types
- `TEXT` - strings
- `INTEGER` - 8-byte integers
- `FLOAT` - 8-byte floating point
- `BOOLEAN` - 1-bit (0 or 1)

Maximum: 16 metadata columns per table

### Declaration
```sql
CREATE VIRTUAL TABLE vec_movies USING vec0(
  movie_id integer primary key,
  synopsis_embedding float[1024],
  genre text,
  num_reviews integer,
  mean_rating float,
  contains_violence boolean
);
```

### Inserting with Metadata
```python
db.execute("""
    INSERT INTO vec_movies(movie_id, synopsis_embedding, genre, num_reviews, mean_rating, contains_violence)
    VALUES (?, ?, ?, ?, ?, ?)
""", [
    1,
    serialize_float32(embedding),
    'scifi',
    250,
    4.2,
    False
])
```

### Filtering in KNN Queries
```sql
SELECT *
FROM vec_movies
WHERE synopsis_embedding MATCH ?
  AND k = 5
  AND genre = 'scifi'
  AND num_reviews BETWEEN 100 AND 500
  AND mean_rating > 3.5
  AND contains_violence = false
ORDER BY distance;
```

### Supported Operators
- `=` - Equals
- `!=` - Not equals
- `>` - Greater than
- `>=` - Greater than or equal
- `<` - Less than
- `<=` - Less than or equal

BOOLEAN columns only support `=` and `!=`

Unsupported: `IS NULL`, `LIKE`, `GLOB`, `REGEXP`, scalar functions

## Partition Key Columns

Partition keys internally shard the vector index for faster filtered queries.

Maximum: 4 partition key columns per table

### Use Cases
1. Multi-tenant data (user_id, organization_id)
2. Temporal data (published_date, created_month)
3. Category-based filtering (document_type, region)

### Single Partition Key
```sql
CREATE VIRTUAL TABLE vec_documents USING vec0(
  document_id integer primary key,
  user_id integer partition key,
  contents_embedding float[1024]
);
```

Query with partition filtering:
```sql
SELECT document_id, distance
FROM vec_documents
WHERE contents_embedding MATCH :query
  AND k = 20
  AND user_id = 123;
```

### Multiple Partition Keys
```sql
CREATE VIRTUAL TABLE vec_articles USING vec0(
  article_id integer primary key,
  organization_id integer partition key,
  published_date text partition key,
  headline_embedding float[1024]
);
```

Query with multiple partition filters:
```sql
SELECT article_id, distance
FROM vec_articles
WHERE headline_embedding MATCH :query
  AND k = 10
  AND organization_id = 456
  AND published_date BETWEEN '2024-01-01' AND '2024-12-31';
```

### Best Practices
- Each unique partition key value should have 100+ vectors
- Avoid over-sharding (too many unique partition values)
- Consider broader keys if queries are slow (e.g., month instead of day)
- Use 1-2 partition keys maximum in most cases

### Supported Operators
- `=` - Equals
- `BETWEEN` - Range (inclusive)

## Auxiliary Columns

Auxiliary columns store unindexed data separately, avoiding JOIN operations.

Maximum: 16 auxiliary columns per table

### Use Cases
- Large text content
- Raw image/document BLOBs
- URLs, metadata not used in WHERE clauses
- Data appearing in SELECT but not WHERE

### Declaration
Prefix column name with `+`:

```sql
CREATE VIRTUAL TABLE vec_chunks USING vec0(
  contents_embedding float[1024],
  +contents text
);
```

### Multiple Auxiliary Columns
```sql
CREATE VIRTUAL TABLE vec_documents USING vec0(
  document_id integer primary key,
  embedding float[768],
  +title text,
  +url text,
  +full_text text,
  +metadata_json text
);
```

### Querying
Auxiliary columns can appear in SELECT but not in WHERE:

```sql
-- ✓ Valid: auxiliary column in SELECT
SELECT rowid, contents, distance
FROM vec_chunks
WHERE contents_embedding MATCH ?
  AND k = 10;

-- ✗ Invalid: auxiliary column in WHERE
SELECT rowid, distance
FROM vec_chunks
WHERE contents_embedding MATCH ?
  AND contents LIKE '%search%';  -- ERROR
```

### Image Storage Example
```sql
CREATE VIRTUAL TABLE vec_images USING vec0(
  image_id integer primary key,
  image_embedding float[512],
  +image blob,
  +image_url text
);

SELECT image_id, image, image_url, distance
FROM vec_images
WHERE image_embedding MATCH ?
  AND k = 5
ORDER BY distance;
```

## Performance Tuning

### chunk_size Parameter
Controls internal chunking for better performance:

```sql
CREATE VIRTUAL TABLE vec_large USING vec0(
  embedding float[1536],
  chunk_size=512
);
```

Default chunk_size is appropriate for most use cases. Tune for:
- Very large tables (millions of vectors)
- Specific memory constraints
- Bulk insert performance

### Column Type Comparison

| Column Type   | Use Case                          | In WHERE? | In SELECT? | Max Count |
|---------------|-----------------------------------|-----------|------------|-----------|
| Vector        | Embeddings                        | MATCH     | ✓          | Multiple  |
| Metadata      | Filtered searches                 | ✓         | ✓          | 16        |
| Partition Key | Multi-tenant/temporal sharding    | ✓         | ✓          | 4         |
| Auxiliary     | Large content, no filtering       | ✗         | ✓          | 16        |

### Complete Example

```sql
CREATE VIRTUAL TABLE vec_knowledge_base USING vec0(
  -- Primary key
  document_id integer primary key,

  -- Partition keys (multi-tenant + temporal)
  organization_id integer partition key,
  created_month text partition key,

  -- Vector column
  content_embedding float[768] distance_metric=cosine,

  -- Metadata columns (filterable)
  document_type text,
  language text,
  word_count integer,
  is_public boolean,

  -- Auxiliary columns (not filterable)
  +title text,
  +full_content text,
  +url text,
  +metadata_json text,

  chunk_size=256
);
```

Query example:
```sql
SELECT
  document_id,
  title,
  full_content,
  distance
FROM vec_knowledge_base
WHERE content_embedding MATCH ?
  AND k = 10
  AND organization_id = 123
  AND created_month = '2024-12'
  AND document_type = 'article'
  AND is_public = true
  AND language = 'en'
  AND word_count > 500
ORDER BY distance;
```

# sqlite-vec Query Patterns

## Table of Contents
- [KNN Query Basics](#knn-query-basics)
- [Distance Functions](#distance-functions)
- [Metadata Filtering](#metadata-filtering)
- [Partition Key Filtering](#partition-key-filtering)
- [Point Queries](#point-queries)
- [Full Table Scan](#full-table-scan)
- [Query Optimization](#query-optimization)

## KNN Query Basics

### Standard KNN Syntax
```sql
SELECT rowid, distance
FROM vec_items
WHERE embedding MATCH ?
  AND k = 10
ORDER BY distance;
```

Key components:
- `WHERE embedding MATCH ?` - Triggers KNN query on the embedding column
- `AND k = 10` - Limit to 10 nearest neighbors
- `ORDER BY distance` - Sort by proximity (distance column auto-generated)

### Using LIMIT (SQLite 3.41+)
```sql
SELECT rowid, distance
FROM vec_items
WHERE embedding MATCH ?
LIMIT 10;
```

LIMIT only works correctly on SQLite 3.41+. Use `k =` for older versions.

### Python Example
```python
from sqlite_vec import serialize_float32

query = [0.3, 0.3, 0.3, 0.3]

results = db.execute(
    """
    SELECT rowid, distance
    FROM vec_items
    WHERE embedding MATCH ?
      AND k = 5
    ORDER BY distance
    """,
    [serialize_float32(query)]
).fetchall()

for rowid, distance in results:
    print(f"rowid={rowid}, distance={distance}")
```

### Joining with Source Tables
```sql
WITH knn_matches AS (
  SELECT document_id, distance
  FROM vec_documents
  WHERE contents_embedding MATCH ?
    AND k = 10
)
SELECT
  documents.id,
  documents.title,
  documents.contents,
  knn_matches.distance
FROM knn_matches
LEFT JOIN documents ON documents.id = knn_matches.document_id
ORDER BY knn_matches.distance;
```

## Distance Functions

### Distance Metric in Table Definition
```sql
CREATE VIRTUAL TABLE vec_cosine USING vec0(
  embedding float[768] distance_metric=cosine
);

-- KNN query uses cosine distance automatically
SELECT rowid, distance
FROM vec_cosine
WHERE embedding MATCH ?
  AND k = 10;
```

Supported metrics:
- `l2` - Euclidean distance (default)
- `cosine` - Cosine distance
- `hamming` - Hamming distance (for bit vectors)

### Manual Distance Calculation

For regular tables (not vec0):

```sql
-- L2 distance
SELECT
  id,
  contents,
  vec_distance_l2(contents_embedding, ?) as distance
FROM documents
ORDER BY distance
LIMIT 10;

-- Cosine distance
SELECT
  id,
  vec_distance_cosine(contents_embedding, ?) as distance
FROM documents
ORDER BY distance
LIMIT 10;

-- Hamming distance (bit vectors)
SELECT
  id,
  vec_distance_hamming(signature, ?) as distance
FROM documents
ORDER BY distance
LIMIT 10;
```

## Metadata Filtering

### Single Metadata Filter
```sql
SELECT rowid, genre, distance
FROM vec_movies
WHERE synopsis_embedding MATCH ?
  AND k = 10
  AND genre = 'scifi'
ORDER BY distance;
```

### Multiple Metadata Filters
```sql
SELECT rowid, distance
FROM vec_movies
WHERE synopsis_embedding MATCH ?
  AND k = 5
  AND genre = 'scifi'
  AND num_reviews BETWEEN 100 AND 500
  AND mean_rating > 3.5
  AND contains_violence = false
ORDER BY distance;
```

### Range Queries
```sql
-- Numeric ranges
WHERE rating BETWEEN 3.0 AND 5.0
WHERE year >= 2020
WHERE budget < 1000000

-- Text equality (no LIKE in KNN)
WHERE category = 'technology'
WHERE language = 'en'
```

### Boolean Filters
```sql
WHERE is_published = true
WHERE has_images = false
WHERE is_archived != true
```

## Partition Key Filtering

### Single Partition Key
```sql
SELECT document_id, distance
FROM vec_documents
WHERE contents_embedding MATCH ?
  AND k = 20
  AND user_id = 123  -- Partition key filter
ORDER BY distance;
```

This query only searches vectors belonging to user 123, making it much faster.

### Date Range Partition
```sql
SELECT article_id, distance
FROM vec_articles
WHERE headline_embedding MATCH ?
  AND k = 10
  AND published_date BETWEEN '2024-01-01' AND '2024-12-31'
ORDER BY distance;
```

### Multiple Partition Keys
```sql
SELECT document_id, distance
FROM vec_multi_tenant
WHERE embedding MATCH ?
  AND k = 10
  AND organization_id = 456
  AND region = 'us-west'
  AND created_month = '2024-12'
ORDER BY distance;
```

### IN Constraint (Advanced)
```sql
-- Partition key with IN clause
SELECT document_id, distance
FROM vec_documents
WHERE contents_embedding MATCH ?
  AND k = 10
  AND user_id IN (123, 456, 789)
ORDER BY distance;
```

## Point Queries

Retrieve a single vector by rowid or primary key:

### By rowid
```sql
SELECT rowid, embedding
FROM vec_items
WHERE rowid = 42;
```

### By Primary Key
```sql
SELECT document_id, contents_embedding
FROM vec_documents
WHERE document_id = 123;
```

### With Auxiliary Data
```sql
SELECT document_id, embedding, title, contents
FROM vec_documents
WHERE document_id = 123;
```

## Full Table Scan

Query all vectors without KNN:

```sql
-- All vectors
SELECT rowid, embedding
FROM vec_items;

-- With metadata filter (no vector MATCH)
SELECT rowid, genre
FROM vec_movies
WHERE genre = 'scifi';

-- Count vectors
SELECT COUNT(*) FROM vec_items;
```

## Query Optimization

### Selecting Specific Columns
```sql
-- Only what you need
SELECT document_id, distance
FROM vec_documents
WHERE embedding MATCH ?
  AND k = 10;

-- With auxiliary data
SELECT document_id, title, url, distance
FROM vec_documents
WHERE embedding MATCH ?
  AND k = 10;
```

### Using Indexes on Metadata
Metadata columns in vec0 are automatically indexed for KNN queries.

### Batch Queries
```python
# Query multiple vectors efficiently
queries = [
    [0.1, 0.2, 0.3, 0.4],
    [0.5, 0.6, 0.7, 0.8],
    [0.9, 1.0, 1.1, 1.2]
]

results = []
for query in queries:
    rows = db.execute(
        """
        SELECT rowid, distance
        FROM vec_items
        WHERE embedding MATCH ?
          AND k = 5
        """,
        [serialize_float32(query)]
    ).fetchall()
    results.append(rows)
```

### Result Pagination
```sql
-- Not directly supported, use k parameter
SELECT rowid, distance
FROM vec_items
WHERE embedding MATCH ?
  AND k = 50  -- Get top 50, handle pagination in application
ORDER BY distance;
```

### Query Performance Tips

1. Use partition keys for multi-tenant/filtered queries
2. Keep k value reasonable (10-100 for most use cases)
3. Filter with metadata columns when possible
4. Use appropriate distance metric for your embeddings
5. Ensure partition keys have 100+ vectors per unique value
6. Batch similar queries together
7. Use auxiliary columns for large data not needed in filtering

### Complex Query Example
```python
from sqlite_vec import serialize_float32

# Multi-condition filtered KNN query
query_embedding = get_embedding("semantic search query")

results = db.execute(
    """
    SELECT
      document_id,
      title,
      url,
      distance
    FROM vec_knowledge_base
    WHERE content_embedding MATCH ?
      AND k = 20
      AND organization_id = ?
      AND created_month = ?
      AND document_type IN ('article', 'blog')
      AND is_public = true
      AND language = 'en'
      AND word_count > 500
    ORDER BY distance
    """,
    [
        serialize_float32(query_embedding),
        123,  # organization_id
        '2024-12'  # created_month
    ]
).fetchall()

for doc_id, title, url, dist in results:
    print(f"{title}: {dist:.4f}")
```

### Combining with Regular SQL
```sql
-- Subquery with KNN
SELECT
  d.id,
  d.title,
  COUNT(c.id) as comment_count,
  v.distance
FROM (
  SELECT document_id, distance
  FROM vec_documents
  WHERE embedding MATCH ?
    AND k = 10
) v
JOIN documents d ON d.id = v.document_id
LEFT JOIN comments c ON c.document_id = d.id
GROUP BY d.id, d.title, v.distance
ORDER BY v.distance;
```

### Similarity Search with Threshold
```sql
-- Find all items within distance threshold
SELECT rowid, distance
FROM vec_items
WHERE embedding MATCH ?
  AND k = 1000  -- Large k to get more candidates
  AND distance < 0.5  -- Filter by distance threshold
ORDER BY distance;
```

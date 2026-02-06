# Docling Batch Processing Reference

This reference covers batch document processing using `convert_all()`, including error handling, concurrency patterns, and resource management.

## Table of Contents

- [Basic Batch Conversion](#basic-batch-conversion)
- [ConversionStatus Handling](#conversionstatus-handling)
- [Error Handling and Recovery](#error-handling-and-recovery)
- [Concurrency Control](#concurrency-control)
- [Resource Limits](#resource-limits)
- [Export Patterns](#export-patterns)
- [Progress Tracking](#progress-tracking)

## Basic Batch Conversion

### Convert Multiple Files

```python
from docling.document_converter import DocumentConverter
from pathlib import Path

converter = DocumentConverter()

# List of file paths
input_paths = [
    "doc1.pdf",
    "doc2.docx",
    "doc3.html"
]

# Returns an iterator of ConversionResult objects
results = converter.convert_all(input_paths)

for result in results:
    print(f"Converted: {result.input.file}")
    result.document.save_as_markdown(f"{result.input.file.stem}.md")
```

### Using Path Objects

```python
from pathlib import Path

data_folder = Path("documents/")
input_paths = list(data_folder.glob("*.pdf"))

results = converter.convert_all(input_paths)
```

### Mixed Sources

```python
from io import BytesIO
from docling.datamodel.base_models import DocumentStream

# Mix of paths, URLs, and streams
sources = [
    Path("local.pdf"),
    "https://example.com/remote.pdf",
    DocumentStream(name="stream.pdf", stream=BytesIO(binary_data))
]

results = converter.convert_all(sources)
```

## ConversionStatus Handling

### Status Values

```python
from docling.datamodel.base_models import ConversionStatus

# SUCCESS: Document fully converted
# PARTIAL_SUCCESS: Converted with some errors
# FAILURE: Conversion failed
# SKIPPED: Document format not allowed
```

### Checking Status

```python
from docling.datamodel.base_models import ConversionStatus

results = converter.convert_all(input_paths, raises_on_error=False)

success_count = 0
partial_count = 0
failure_count = 0

for result in results:
    if result.status == ConversionStatus.SUCCESS:
        success_count += 1
        result.document.save_as_markdown(f"output/{result.input.file.stem}.md")
    elif result.status == ConversionStatus.PARTIAL_SUCCESS:
        partial_count += 1
        print(f"Partial success for {result.input.file}:")
        for error in result.errors:
            print(f"  - {error.error_message}")
        # Still save the partial result
        result.document.save_as_markdown(f"output/{result.input.file.stem}.md")
    else:  # FAILURE or SKIPPED
        failure_count += 1
        print(f"Failed: {result.input.file}")

print(f"Success: {success_count}, Partial: {partial_count}, Failed: {failure_count}")
```

## Error Handling and Recovery

### raises_on_error Parameter

```python
# Default: raises_on_error=True
# Raises ConversionError on first failure
try:
    results = converter.convert_all(input_paths, raises_on_error=True)
    for result in results:
        result.document.save_as_markdown(f"{result.input.file.stem}.md")
except ConversionError as e:
    print(f"Conversion failed: {e}")
```

### Continue on Error

```python
# raises_on_error=False
# Process all documents, collect failures
results = converter.convert_all(input_paths, raises_on_error=False)

failed_docs = []

for result in results:
    if result.status == ConversionStatus.SUCCESS:
        result.document.save_as_markdown(f"{result.input.file.stem}.md")
    else:
        failed_docs.append(result.input.file)
        if result.errors:
            print(f"Errors in {result.input.file}:")
            for error in result.errors:
                print(f"  {error.component_type}: {error.error_message}")

# Retry failed documents
if failed_docs:
    print(f"Retrying {len(failed_docs)} failed documents...")
    retry_results = converter.convert_all(failed_docs, raises_on_error=False)
```

### Error Details

```python
from docling.datamodel.base_models import ConversionStatus

for result in results:
    if result.status != ConversionStatus.SUCCESS:
        print(f"\nDocument: {result.input.file}")
        print(f"Status: {result.status}")

        if result.errors:
            print("Errors:")
            for error in result.errors:
                print(f"  Component: {error.component_type}")
                print(f"  Module: {error.module_name}")
                print(f"  Message: {error.error_message}")
```

## Concurrency Control

Docling uses `ThreadPoolExecutor` internally for concurrent batch processing.

### Default Concurrency

Controlled by settings (default: 4 threads, batch size: 10):

```python
from docling.datamodel.settings import settings

# View current settings
print(f"Batch size: {settings.perf.doc_batch_size}")
print(f"Concurrency: {settings.perf.doc_batch_concurrency}")
```

### Custom Concurrency

Adjust via environment variables or settings:

```python
# Via environment (before import)
import os
os.environ["DOCLING_DOC_BATCH_SIZE"] = "20"
os.environ["DOCLING_DOC_BATCH_CONCURRENCY"] = "8"

from docling.document_converter import DocumentConverter
```

### CPU Thread Control

Limit CPU threads used by models:

```bash
# Environment variable
export OMP_NUM_THREADS=4

# Or in Python
import os
os.environ["OMP_NUM_THREADS"] = "4"
```

### Sequential Processing

For debugging or controlled execution:

```python
from docling.datamodel.settings import settings

# Force sequential processing
settings.perf.doc_batch_concurrency = 1
settings.perf.doc_batch_size = 1

converter = DocumentConverter()
results = converter.convert_all(input_paths)
```

## Resource Limits

### Per-Document Limits

```python
# Apply limits to all documents in batch
results = converter.convert_all(
    input_paths,
    max_file_size=20_971_520,    # 20 MB per file
    max_num_pages=100,            # 100 pages per document
    raises_on_error=False
)

for result in results:
    if result.status == ConversionStatus.SKIPPED:
        print(f"Skipped (too large): {result.input.file}")
```

### Page Range

```python
# Convert only first 50 pages of each document
results = converter.convert_all(
    input_paths,
    page_range=[1, 50]
)
```

### Memory Management

```python
from pathlib import Path

# Process in smaller batches for memory control
def batch_files(files, batch_size=10):
    for i in range(0, len(files), batch_size):
        yield files[i:i + batch_size]

all_files = list(Path("documents/").glob("*.pdf"))

for file_batch in batch_files(all_files, batch_size=10):
    results = converter.convert_all(file_batch, raises_on_error=False)

    for result in results:
        if result.status == ConversionStatus.SUCCESS:
            result.document.save_as_markdown(f"output/{result.input.file.stem}.md")

    # Results iterator consumed, memory can be freed
```

## Export Patterns

### Save All to Directory

```python
from pathlib import Path
from docling.datamodel.base_models import ConversionStatus

output_dir = Path("output")
output_dir.mkdir(parents=True, exist_ok=True)

results = converter.convert_all(input_paths, raises_on_error=False)

for result in results:
    if result.status == ConversionStatus.SUCCESS:
        doc_name = result.input.file.stem

        # Multiple formats
        result.document.save_as_markdown(output_dir / f"{doc_name}.md")
        result.document.save_as_json(output_dir / f"{doc_name}.json")
        result.document.save_as_html(output_dir / f"{doc_name}.html")
```

### Conditional Export

```python
from docling.datamodel.base_models import ConversionStatus

for result in results:
    doc_name = result.input.file.stem

    if result.status == ConversionStatus.SUCCESS:
        # Full export for successful conversions
        result.document.save_as_markdown(f"output/success/{doc_name}.md")
        result.document.save_as_json(f"output/success/{doc_name}.json")
    elif result.status == ConversionStatus.PARTIAL_SUCCESS:
        # Markdown only for partial conversions
        result.document.save_as_markdown(f"output/partial/{doc_name}.md")
        # Log errors
        with open(f"output/partial/{doc_name}.errors.txt", "w") as f:
            for error in result.errors:
                f.write(f"{error.error_message}\n")
```

### Custom Export Function

```python
import json
from pathlib import Path
from docling.datamodel.base_models import ConversionStatus
from docling_core.types.doc import ImageRefMode

def export_document(result, output_dir):
    """Export successful conversions to multiple formats."""
    if result.status != ConversionStatus.SUCCESS:
        return False

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    doc_filename = result.input.file.stem

    # JSON with placeholders
    result.document.save_as_json(
        output_dir / f"{doc_filename}.json",
        image_mode=ImageRefMode.PLACEHOLDER
    )

    # HTML with embedded images
    result.document.save_as_html(
        output_dir / f"{doc_filename}.html",
        image_mode=ImageRefMode.EMBEDDED
    )

    # Markdown
    result.document.save_as_markdown(output_dir / f"{doc_filename}.md")

    # Plain text
    result.document.save_as_markdown(
        output_dir / f"{doc_filename}.txt",
        strict_text=True
    )

    return True

# Process batch
results = converter.convert_all(input_paths, raises_on_error=False)
success_count = sum(export_document(r, "output") for r in results)
print(f"Exported {success_count} documents")
```

## Progress Tracking

### Simple Counter

```python
import logging

logging.basicConfig(level=logging.INFO)

results = converter.convert_all(input_paths, raises_on_error=False)

total = len(input_paths)
for i, result in enumerate(results, 1):
    status_str = "✓" if result.status == ConversionStatus.SUCCESS else "✗"
    print(f"[{i}/{total}] {status_str} {result.input.file.name}")
```

### Progress Bar (tqdm)

```python
from tqdm import tqdm

results = converter.convert_all(input_paths, raises_on_error=False)

for result in tqdm(results, total=len(input_paths), desc="Converting"):
    if result.status == ConversionStatus.SUCCESS:
        result.document.save_as_markdown(f"{result.input.file.stem}.md")
```

### Detailed Logging

```python
import logging
import time

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

start_time = time.time()
results = converter.convert_all(input_paths, raises_on_error=False)

for i, result in enumerate(results, 1):
    elapsed = time.time() - start_time

    if result.status == ConversionStatus.SUCCESS:
        logger.info(
            f"[{i}/{len(input_paths)}] SUCCESS: {result.input.file.name} "
            f"({elapsed:.1f}s elapsed)"
        )
    else:
        logger.error(
            f"[{i}/{len(input_paths)}] FAILED: {result.input.file.name} "
            f"- {result.status}"
        )
```

## Advanced Patterns

### Filter Before Processing

```python
from pathlib import Path

# Get all PDFs, filter by size
data_folder = Path("documents/")
pdf_files = [
    f for f in data_folder.glob("*.pdf")
    if f.stat().st_size < 10_000_000  # < 10 MB
]

results = converter.convert_all(pdf_files)
```

### Batch with Custom Headers

```python
# For URL-based sources requiring authentication
sources = [
    "https://api.example.com/doc1.pdf",
    "https://api.example.com/doc2.pdf"
]

results = converter.convert_all(
    sources,
    headers={"Authorization": "Bearer token123"}
)
```

### Retry Failed Documents

```python
from docling.datamodel.base_models import ConversionStatus

# First attempt
results = converter.convert_all(input_paths, raises_on_error=False)

failed_paths = []
for result in results:
    if result.status == ConversionStatus.FAILURE:
        failed_paths.append(result.input.file)

# Retry with different options (e.g., OCR disabled)
if failed_paths:
    from docling.datamodel.base_models import InputFormat
    from docling.datamodel.pipeline_options import PdfPipelineOptions
    from docling.document_converter import PdfFormatOption

    # Simpler pipeline for retry
    retry_options = PdfPipelineOptions()
    retry_options.do_ocr = False

    retry_converter = DocumentConverter(
        format_options={
            InputFormat.PDF: PdfFormatOption(pipeline_options=retry_options)
        }
    )

    retry_results = retry_converter.convert_all(failed_paths, raises_on_error=False)
    for result in retry_results:
        if result.status == ConversionStatus.SUCCESS:
            print(f"Retry succeeded: {result.input.file}")
```

### Parallel Batches with multiprocessing

```python
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

def process_batch(file_batch):
    """Process a batch of files in a separate process."""
    from docling.document_converter import DocumentConverter

    converter = DocumentConverter()
    results = list(converter.convert_all(file_batch, raises_on_error=False))

    success = sum(1 for r in results if r.status == ConversionStatus.SUCCESS)
    return success, len(results)

# Split files into batches
all_files = list(Path("documents/").glob("*.pdf"))
batch_size = 10
batches = [all_files[i:i+batch_size] for i in range(0, len(all_files), batch_size)]

# Process batches in parallel processes
with ProcessPoolExecutor(max_workers=4) as executor:
    batch_results = executor.map(process_batch, batches)

total_success = 0
total_processed = 0
for success, processed in batch_results:
    total_success += success
    total_processed += processed

print(f"Processed {total_processed} documents, {total_success} successful")
```

### Summary Statistics

```python
from collections import Counter
from docling.datamodel.base_models import ConversionStatus

results = converter.convert_all(input_paths, raises_on_error=False)

status_counts = Counter()
error_types = Counter()

for result in results:
    status_counts[result.status] += 1

    if result.errors:
        for error in result.errors:
            error_types[error.component_type] += 1

print("\nConversion Summary:")
print(f"  SUCCESS: {status_counts[ConversionStatus.SUCCESS]}")
print(f"  PARTIAL_SUCCESS: {status_counts[ConversionStatus.PARTIAL_SUCCESS]}")
print(f"  FAILURE: {status_counts[ConversionStatus.FAILURE]}")
print(f"  SKIPPED: {status_counts[ConversionStatus.SKIPPED]}")

if error_types:
    print("\nError Types:")
    for error_type, count in error_types.most_common():
        print(f"  {error_type}: {count}")
```

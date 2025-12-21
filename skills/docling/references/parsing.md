# Docling Parsing Reference

This reference covers document parsing operations, including converter initialization, format-specific options, and OCR configuration.

## Table of Contents

- [DocumentConverter Initialization](#documentconverter-initialization)
- [Single File Conversion](#single-file-conversion)
- [URL Conversion](#url-conversion)
- [Binary Stream Conversion](#binary-stream-conversion)
- [Format-Specific Options](#format-specific-options)
- [PDF Pipeline Options](#pdf-pipeline-options)
- [OCR Configuration](#ocr-configuration)
- [Advanced Options](#advanced-options)

## DocumentConverter Initialization

### Basic Initialization

```python
from docling.document_converter import DocumentConverter

# All formats enabled by default
converter = DocumentConverter()
```

### Restricted Formats

```python
from docling.datamodel.base_models import InputFormat
from docling.document_converter import DocumentConverter

# Only allow specific formats
converter = DocumentConverter(
    allowed_formats=[
        InputFormat.PDF,
        InputFormat.DOCX,
        InputFormat.HTML
    ]
)
```

### Custom Format Options

```python
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption

# Configure PDF-specific pipeline
pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True
pipeline_options.do_table_structure = True

converter = DocumentConverter(
    format_options={
        InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options)
    }
)
```

## Single File Conversion

### Basic Conversion

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()

# From file path (str or Path)
result = converter.convert("document.pdf")
result = converter.convert(Path("document.pdf"))
```

### With Options

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()

result = converter.convert(
    "document.pdf",
    max_num_pages=100,           # Limit to 100 pages
    max_file_size=20_971_520,    # 20 MB limit
    page_range=[5, 15],           # Only pages 5-15
    raises_on_error=True          # Raise on conversion failure
)
```

### Result Handling

```python
from docling.datamodel.base_models import ConversionStatus

result = converter.convert("document.pdf")

# Check status
if result.status == ConversionStatus.SUCCESS:
    doc = result.document
    markdown = doc.export_to_markdown()
elif result.status == ConversionStatus.PARTIAL_SUCCESS:
    print(f"Partial success with {len(result.errors)} errors")
    for error in result.errors:
        print(f"  {error.error_message}")
else:  # FAILURE
    print("Conversion failed")
```

## URL Conversion

### HTTP/HTTPS URLs

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()

# Convert from URL
result = converter.convert("https://arxiv.org/pdf/2408.09869")
result = converter.convert("http://example.com/document.docx")
```

### With Headers

```python
converter = DocumentConverter()

result = converter.convert(
    "https://example.com/protected.pdf",
    headers={"Authorization": "Bearer token123"}
)
```

## Binary Stream Conversion

### From BytesIO

```python
from io import BytesIO
from docling.datamodel.base_models import DocumentStream
from docling.document_converter import DocumentConverter

# Read file into memory
with open("document.pdf", "rb") as f:
    buf = BytesIO(f.read())

# Create DocumentStream
source = DocumentStream(name="document.pdf", stream=buf)

converter = DocumentConverter()
result = converter.convert(source)
```

### From Binary Data

```python
from io import BytesIO
from docling.datamodel.base_models import DocumentStream

# Binary data from any source
binary_data = get_pdf_bytes()  # Your function
buf = BytesIO(binary_data)

source = DocumentStream(name="my_doc.pdf", stream=buf)
result = converter.convert(source)
```

### String Content

For Markdown and HTML, you can convert string content directly:

```python
converter = DocumentConverter()

# Markdown string
result = converter.convert_string(
    content="# Title\n\nParagraph text",
    format=InputFormat.MD,
    name="my_markdown"  # Optional
)

# HTML string
result = converter.convert_string(
    content="<h1>Title</h1><p>Paragraph</p>",
    format=InputFormat.HTML,
    name="my_html"
)
```

## Format-Specific Options

### PDF Options

```python
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption

pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True
pipeline_options.do_table_structure = True
pipeline_options.generate_page_images = True

converter = DocumentConverter(
    format_options={
        InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options)
    }
)
```

### Image Options

```python
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions
from docling.document_converter import DocumentConverter, ImageFormatOption

# Images use same pipeline as PDFs
pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True

converter = DocumentConverter(
    format_options={
        InputFormat.IMAGE: ImageFormatOption(pipeline_options=pipeline_options)
    }
)
```

### Markdown Options

```python
from docling.datamodel.base_models import InputFormat
from docling.datamodel.backend_options import MarkdownBackendOptions
from docling.document_converter import DocumentConverter, MarkdownFormatOption

backend_options = MarkdownBackendOptions()

converter = DocumentConverter(
    format_options={
        InputFormat.MD: MarkdownFormatOption(backend_options=backend_options)
    }
)
```

### HTML Options

```python
from docling.datamodel.base_models import InputFormat
from docling.datamodel.backend_options import HTMLBackendOptions
from docling.document_converter import DocumentConverter, HTMLFormatOption

backend_options = HTMLBackendOptions()

converter = DocumentConverter(
    format_options={
        InputFormat.HTML: HTMLFormatOption(backend_options=backend_options)
    }
)
```

## PDF Pipeline Options

### Layout and Structure

```python
from docling.datamodel.pipeline_options import PdfPipelineOptions

pipeline_options = PdfPipelineOptions()

# Enable/disable features
pipeline_options.do_ocr = True                    # OCR for scanned PDFs
pipeline_options.do_table_structure = True        # Table structure recognition
pipeline_options.do_picture_classification = True # Classify images
pipeline_options.do_code_enrichment = True        # Code block detection
pipeline_options.do_formula_enrichment = True     # Formula detection

# Page image generation (needed for HTML export with images)
pipeline_options.generate_page_images = True
```

### Table Structure Options

```python
from docling.datamodel.pipeline_options import (
    PdfPipelineOptions,
    TableFormerMode
)

pipeline_options = PdfPipelineOptions()
pipeline_options.do_table_structure = True

# Cell matching: map structure to PDF cells (default: True)
pipeline_options.table_structure_options.do_cell_matching = True

# Accuracy mode
pipeline_options.table_structure_options.mode = TableFormerMode.ACCURATE  # or FAST
```

### Model Artifacts Path

For offline/air-gapped environments:

```python
from docling.datamodel.pipeline_options import PdfPipelineOptions

pipeline_options = PdfPipelineOptions(
    artifacts_path="/local/path/to/models"
)
```

## OCR Configuration

### EasyOCR (Default)

```python
from docling.datamodel.pipeline_options import (
    PdfPipelineOptions,
    EasyOcrOptions
)

pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True

# Configure language(s)
pipeline_options.ocr_options = EasyOcrOptions(
    lang=["en"],              # Single language
    # lang=["en", "es", "de"],  # Multiple languages
)
```

### Tesseract

```python
from docling.datamodel.pipeline_options import (
    PdfPipelineOptions,
    TesseractOcrOptions
)

pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True
pipeline_options.ocr_options = TesseractOcrOptions()
```

### Tesseract CLI

```python
from docling.datamodel.pipeline_options import (
    PdfPipelineOptions,
    TesseractCliOcrOptions
)

pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True
pipeline_options.ocr_options = TesseractCliOcrOptions()
```

### macOS System OCR

```python
from docling.datamodel.pipeline_options import (
    PdfPipelineOptions,
    OcrMacOptions
)

pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True
pipeline_options.ocr_options = OcrMacOptions()
```

### RapidOCR

```python
from docling.datamodel.pipeline_options import (
    PdfPipelineOptions,
    RapidOcrOptions
)

pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True
pipeline_options.ocr_options = RapidOcrOptions()
```


### GPU Acceleration

```python
from docling.datamodel.accelerator_options import (
    AcceleratorDevice,
    AcceleratorOptions
)
from docling.datamodel.pipeline_options import PdfPipelineOptions

pipeline_options = PdfPipelineOptions()

# Auto-detect best device
pipeline_options.accelerator_options = AcceleratorOptions(
    device=AcceleratorDevice.AUTO,
    num_threads=4
)

# Force CPU
pipeline_options.accelerator_options = AcceleratorOptions(
    device=AcceleratorDevice.CPU,
    num_threads=8
)

# Force GPU
pipeline_options.accelerator_options = AcceleratorOptions(
    device=AcceleratorDevice.CUDA  # or MPS for Apple Silicon
)
```

## Advanced Options

### Pipeline Initialization

Pre-initialize pipelines to avoid lazy loading during first conversion:

```python
from docling.datamodel.base_models import InputFormat
from docling.document_converter import DocumentConverter

converter = DocumentConverter()

# Initialize pipeline for specific format
converter.initialize_pipeline(InputFormat.PDF)
```

### Remote Services

For cloud-based OCR or models:

```python
from docling.datamodel.pipeline_options import PdfPipelineOptions

pipeline_options = PdfPipelineOptions()
pipeline_options.enable_remote_services = True  # Required for API-based models
```

### Model Download

Prefetch models for offline use:

```python
from docling.utils.model_downloader import download_models

# Download all default models
download_models(target_dir="/local/path/to/models")
```

Or via CLI:

```bash
docling-tools models download
docling-tools models download-hf-repo ds4sd/SmolDocling-256M-preview
```

### Environment Variables

```bash
# Set artifacts path via environment
export DOCLING_ARTIFACTS_PATH="/local/path/to/models"

# Limit CPU threads
export OMP_NUM_THREADS=4

# Run your script
python convert_docs.py
```

### Resource Limits

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()

result = converter.convert(
    "large_doc.pdf",
    max_file_size=52_428_800,   # 50 MB max
    max_num_pages=500,          # 500 pages max
    page_range=[1, 100]         # Only first 100 pages
)
```

### Error Control

```python
# Raise on first error (default)
result = converter.convert("doc.pdf", raises_on_error=True)

# Continue on error
result = converter.convert("doc.pdf", raises_on_error=False)
if result.status != ConversionStatus.SUCCESS:
    print(f"Failed with errors: {result.errors}")
```

## Common Patterns

### Multi-Format Converter

```python
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption

# Configure different options per format
pdf_options = PdfPipelineOptions()
pdf_options.do_ocr = True
pdf_options.do_table_structure = True

converter = DocumentConverter(
    format_options={
        InputFormat.PDF: PdfFormatOption(pipeline_options=pdf_options)
    }
)

# Handles PDFs with custom options, other formats with defaults
result1 = converter.convert("document.pdf")
result2 = converter.convert("document.docx")
result3 = converter.convert("document.html")
```

### OCR-Only PDF Processing

```python
from docling.datamodel.pipeline_options import PdfPipelineOptions

pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = True
pipeline_options.do_table_structure = False
pipeline_options.do_picture_classification = False
pipeline_options.do_code_enrichment = False
pipeline_options.do_formula_enrichment = False

converter = DocumentConverter(
    format_options={
        InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options)
    }
)
```

### Fast Table Extraction

```python
from docling.datamodel.pipeline_options import (
    PdfPipelineOptions,
    TableFormerMode
)

pipeline_options = PdfPipelineOptions()
pipeline_options.do_ocr = False  # Disable OCR for speed
pipeline_options.do_table_structure = True
pipeline_options.table_structure_options.mode = TableFormerMode.FAST

converter = DocumentConverter(
    format_options={
        InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options)
    }
)
```

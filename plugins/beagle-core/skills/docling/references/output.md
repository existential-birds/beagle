# Docling Output Formats Reference

This reference covers document export methods, output formats, and accessing document structure.

## Table of Contents

- [DoclingDocument Structure](#doclingdocument-structure)
- [Markdown Export](#markdown-export)
- [HTML Export](#html-export)
- [JSON Export](#json-export)
- [Plain Text Export](#plain-text-export)
- [DocTags Export](#doctags-export)
- [Save Methods](#save-methods)
- [Document Iteration](#document-iteration)
- [Image Handling](#image-handling)

## DoclingDocument Structure

The `DoclingDocument` is a Pydantic model with the following top-level fields:

```python
from docling.document_converter import DocumentConverter

converter = DocumentConverter()
result = converter.convert("document.pdf")
doc = result.document

# Content items (lists of DocItem instances)
doc.texts              # TextItem: paragraphs, headings, equations
doc.tables             # TableItem: tables with structure
doc.pictures           # PictureItem: images, figures
doc.key_value_items    # Key-value pairs

# Structure (tree of NodeItem instances)
doc.body               # Main content hierarchy
doc.furniture          # Headers, footers, page numbers
doc.groups             # Lists, chapters, sections

# Metadata
doc.name               # Document name
doc.origin             # Document source information
```

### Content Items

```python
# Access text items
for text_item in doc.texts:
    print(f"Label: {text_item.label}")        # paragraph, section_header, etc.
    print(f"Text: {text_item.text}")
    if text_item.prov:
        print(f"Page: {text_item.prov[0].page}")

# Access tables
for table_item in doc.tables:
    print(f"Table data: {table_item.data}")
    # Export table to HTML
    html = table_item.export_to_html()

# Access pictures
for pic_item in doc.pictures:
    print(f"Image: {pic_item.image}")
    if pic_item.prov:
        print(f"BBox: {pic_item.prov[0].bbox}")
```

## Markdown Export

### Basic Markdown Export

```python
# Export to Markdown string
markdown = result.document.export_to_markdown()
print(markdown)

# Write to file manually
with open("output.md", "w") as f:
    f.write(markdown)
```

### Image Modes

```python
from docling_core.types.doc import ImageRefMode

# Placeholder (default) - no actual image data
markdown = result.document.export_to_markdown(
    image_mode=ImageRefMode.PLACEHOLDER
)

# Referenced - link to image files
markdown = result.document.export_to_markdown(
    image_mode=ImageRefMode.REFERENCED
)

# Embedded - base64-encoded images (not typical for Markdown)
markdown = result.document.export_to_markdown(
    image_mode=ImageRefMode.EMBEDDED
)
```

### Plain Text Mode

```python
# Export as plain text (no Markdown formatting)
plain_text = result.document.export_to_markdown(strict_text=True)

# Just the text content, no markers
with open("output.txt", "w") as f:
    f.write(plain_text)
```

### Partial Export

```python
# Export specific range of items
markdown = result.document.export_to_markdown(
    main_text_start=0,
    main_text_stop=10
)
```

## HTML Export

### Basic HTML Export

```python
# Export to HTML string
html = result.document.export_to_html()

with open("output.html", "w") as f:
    f.write(html)
```

### Image Modes

```python
from docling_core.types.doc import ImageRefMode

# Embedded images (base64-encoded)
html = result.document.export_to_html(
    image_mode=ImageRefMode.EMBEDDED
)

# Referenced images (external files)
html = result.document.export_to_html(
    image_mode=ImageRefMode.REFERENCED
)

# Placeholders only
html = result.document.export_to_html(
    image_mode=ImageRefMode.PLACEHOLDER
)
```

### Page Images

To include page images, enable during conversion:

```python
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption

# Enable page image generation
pipeline_options = PdfPipelineOptions()
pipeline_options.generate_page_images = True

converter = DocumentConverter(
    format_options={
        InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options)
    }
)

result = converter.convert("document.pdf")

# Export with embedded page images
html = result.document.export_to_html(image_mode=ImageRefMode.EMBEDDED)
```

## JSON Export

### Dictionary Export

```python
# Export to Python dict
doc_dict = result.document.export_to_dict()

# Access fields
print(doc_dict["name"])
print(len(doc_dict["texts"]))
print(len(doc_dict["tables"]))
```

### JSON String Export

```python
import json

# Export to dict, then convert to JSON string
doc_dict = result.document.export_to_dict()
json_str = json.dumps(doc_dict, indent=2)

# Note: There is no export_to_json() method
# Use export_to_dict() and then json.dumps() for JSON strings
```

### Pretty Print

```python
import json

doc_dict = result.document.export_to_dict()

# Pretty-printed JSON
with open("output.json", "w") as f:
    json.dump(doc_dict, f, indent=2)
```

### Lossless Serialization

JSON export is lossless - you can reconstruct the DoclingDocument:

```python
from docling_core.types.doc import DoclingDocument
import json

# Export to dict, then to JSON string
doc_dict = result.document.export_to_dict()
json_str = json.dumps(doc_dict)

# Reconstruct
doc_dict_loaded = json.loads(json_str)
reconstructed = DoclingDocument(**doc_dict_loaded)

# Identical to original
assert reconstructed.export_to_markdown() == result.document.export_to_markdown()
```

## Plain Text Export

### Using Markdown Export

```python
# Most common: use export_to_markdown with strict_text=True
plain_text = result.document.export_to_markdown(strict_text=True)

with open("output.txt", "w") as f:
    f.write(plain_text)
```

### Manual Text Extraction

```python
# Extract all text content manually
all_text = []

for item, level in result.document.iterate_items():
    if hasattr(item, 'text') and item.text:
        all_text.append(item.text)

plain_text = "\n".join(all_text)
```

## DocTags Export

DocTags is a markup format for representing full content and layout characteristics.

### Basic DocTags Export

```python
# Export to DocTags format
doctags = result.document.export_to_doctags()

with open("output.doctags.txt", "w") as f:
    f.write(doctags)
```

### DocTags with Options

```python
# Export specific range
doctags = result.document.export_to_document_tokens(
    main_text_start=0,
    main_text_stop=10,
    add_page_index=True
)
```

## Save Methods

Convenience methods that combine export and file writing:

### save_as_markdown()

```python
from pathlib import Path
from docling_core.types.doc import ImageRefMode

# Basic save
result.document.save_as_markdown("output.md")

# With options
result.document.save_as_markdown(
    Path("output.md"),
    image_mode=ImageRefMode.PLACEHOLDER
)

# Plain text mode
result.document.save_as_markdown(
    "output.txt",
    strict_text=True
)
```

### save_as_html()

```python
from docling_core.types.doc import ImageRefMode

# Save with embedded images
result.document.save_as_html(
    "output.html",
    image_mode=ImageRefMode.EMBEDDED
)

# Save with referenced images
result.document.save_as_html(
    "output.html",
    image_mode=ImageRefMode.REFERENCED
)
```

### save_as_json()

```python
from docling_core.types.doc import ImageRefMode

# Save JSON
result.document.save_as_json("output.json")

# With image mode
result.document.save_as_json(
    "output.json",
    image_mode=ImageRefMode.PLACEHOLDER
)
```

### save_as_doctags()

```python
# Save DocTags format
result.document.save_as_doctags("output.doctags.txt")
```

## Document Iteration

### iterate_items()

Iterate document elements in reading order:

```python
# Basic iteration
for item, level in result.document.iterate_items():
    indent = "  " * level
    if hasattr(item, 'text'):
        print(f"{indent}{item.label}: {item.text[:50]}")
```

### With Filtering

```python
# Only specific item types
for item, level in result.document.iterate_items():
    if item.label == "section_header":
        print(f"Header (level {level}): {item.text}")
    elif item.label == "table":
        print(f"Table (level {level})")
```

### Extract Tables

```python
# Find all tables
tables = []
for item, level in result.document.iterate_items():
    if item.label == "table":
        tables.append(item)

# Export tables
for i, table in enumerate(tables):
    html = table.export_to_html()
    with open(f"table_{i}.html", "w") as f:
        f.write(html)
```

### Extract Images

```python
# Find all pictures/figures
pictures = []
for item, level in result.document.iterate_items():
    if item.label in ["picture", "figure"]:
        pictures.append(item)

print(f"Found {len(pictures)} images")

# Access image data
for i, pic in enumerate(pictures):
    if pic.image:
        # Save image
        pic.image.pil_image.save(f"image_{i}.png")
```

### Build Outline

```python
# Extract document outline
outline = []

for item, level in result.document.iterate_items():
    if item.label in ["section_header", "title", "subtitle_level_1"]:
        outline.append({
            "level": level,
            "text": item.text,
            "page": item.prov[0].page if item.prov else None
        })

# Print outline
for entry in outline:
    indent = "  " * entry["level"]
    page_str = f" (p. {entry['page']})" if entry['page'] else ""
    print(f"{indent}{entry['text']}{page_str}")
```

## Image Handling

### Image Reference Modes

```python
from docling_core.types.doc import ImageRefMode

# PLACEHOLDER: No image data, just placeholders
# REFERENCED: Links to external image files
# EMBEDDED: Base64-encoded images in output
```

### Extract Images from Document

```python
# Get all picture items
for i, pic_item in enumerate(result.document.pictures):
    if pic_item.image and pic_item.image.pil_image:
        # Save as PNG
        pic_item.image.pil_image.save(f"figure_{i}.png")

        # Or get bytes
        from io import BytesIO
        buf = BytesIO()
        pic_item.image.pil_image.save(buf, format="PNG")
        image_bytes = buf.getvalue()
```

### Generate Page Images

```python
from docling.datamodel.base_models import InputFormat
from docling.datamodel.pipeline_options import PdfPipelineOptions
from docling.document_converter import DocumentConverter, PdfFormatOption

# Enable page image generation
pipeline_options = PdfPipelineOptions()
pipeline_options.generate_page_images = True

converter = DocumentConverter(
    format_options={
        InputFormat.PDF: PdfFormatOption(pipeline_options=pipeline_options)
    }
)

result = converter.convert("document.pdf")

# Access page images
for i, page in enumerate(result.pages):
    if page.image:
        page.image.pil_image.save(f"page_{i}.png")
```

## Advanced Export Patterns

### Multi-Format Export

```python
from pathlib import Path
from docling_core.types.doc import ImageRefMode

def export_all_formats(result, output_dir):
    """Export conversion result to all formats."""
    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    doc_name = result.input.file.stem

    # Markdown
    result.document.save_as_markdown(
        output_dir / f"{doc_name}.md",
        image_mode=ImageRefMode.PLACEHOLDER
    )

    # HTML with embedded images
    result.document.save_as_html(
        output_dir / f"{doc_name}.html",
        image_mode=ImageRefMode.EMBEDDED
    )

    # JSON
    result.document.save_as_json(output_dir / f"{doc_name}.json")

    # Plain text
    result.document.save_as_markdown(
        output_dir / f"{doc_name}.txt",
        strict_text=True
    )

    # DocTags
    result.document.save_as_doctags(output_dir / f"{doc_name}.doctags.txt")

# Use
export_all_formats(result, "output")
```

### Custom JSON Serialization

```python
import json

def export_custom_json(doc, output_path):
    """Export custom JSON with selected fields."""
    custom_data = {
        "name": doc.name,
        "text_count": len(doc.texts),
        "table_count": len(doc.tables),
        "picture_count": len(doc.pictures),
        "content": []
    }

    # Extract structured content
    for item, level in doc.iterate_items():
        if hasattr(item, 'text'):
            custom_data["content"].append({
                "level": level,
                "label": item.label,
                "text": item.text,
                "page": item.prov[0].page if item.prov else None
            })

    with open(output_path, "w") as f:
        json.dump(custom_data, f, indent=2)

# Use
export_custom_json(result.document, "custom.json")
```

### Extract Tables to CSV

```python
import csv
from bs4 import BeautifulSoup

def table_to_csv(table_item, output_path):
    """Convert table HTML to CSV."""
    html = table_item.export_to_html()
    soup = BeautifulSoup(html, "html.parser")

    rows = []
    for tr in soup.find_all("tr"):
        row = [td.get_text(strip=True) for td in tr.find_all(["td", "th"])]
        rows.append(row)

    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerows(rows)

# Extract all tables to CSV
for i, table in enumerate(result.document.tables):
    table_to_csv(table, f"table_{i}.csv")
```

### Metadata Extraction

```python
def extract_metadata(result):
    """Extract document metadata."""
    doc = result.document

    metadata = {
        "filename": result.input.file.name,
        "format": result.input.format.value,
        "status": result.status.value,
        "page_count": len(result.pages) if hasattr(result, 'pages') else 0,
        "text_items": len(doc.texts),
        "tables": len(doc.tables),
        "pictures": len(doc.pictures),
        "headings": []
    }

    # Extract headings
    for item, level in doc.iterate_items():
        if item.label in ["section_header", "title"]:
            metadata["headings"].append({
                "level": level,
                "text": item.text
            })

    return metadata

# Use
import json
metadata = extract_metadata(result)
with open("metadata.json", "w") as f:
    json.dump(metadata, f, indent=2)
```

### Page-Level Export

```python
def export_pages_separately(result, output_dir):
    """Export each page to a separate Markdown file."""
    from pathlib import Path

    output_dir = Path(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Group items by page
    pages = {}
    for item, _ in result.document.iterate_items():
        if hasattr(item, 'prov') and item.prov:
            page_num = item.prov[0].page
            if page_num not in pages:
                pages[page_num] = []
            if hasattr(item, 'text'):
                pages[page_num].append(item.text)

    # Export each page
    for page_num, texts in sorted(pages.items()):
        page_content = "\n\n".join(texts)
        output_file = output_dir / f"page_{page_num:03d}.md"
        with open(output_file, "w") as f:
            f.write(f"# Page {page_num}\n\n{page_content}")

# Use
export_pages_separately(result, "pages")
```

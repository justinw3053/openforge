import json
import os
import re

def parse_notebook(filepath):
    """
    Parses a Jupyter Notebook (.ipynb) and extracts markdown instructions,
    starter code, and hidden assertions.
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        notebook = json.load(f)

    result = {
        "title": "Unknown Lesson",
        "markdown": "",
        "exercises": []
    }

    markdown_blocks = []

    for cell in notebook.get("cells", []):
        cell_type = cell.get("cell_type")
        source_lines = cell.get("source", [])
        
        if not source_lines:
            continue
            
        source_text = "".join(source_lines)

        if cell_type == "markdown":
            markdown_blocks.append(source_text)
            # Try to extract a title from the first heading of any level (e.g. ##)
            match = re.match(r'^#+\s+(.*)', source_text)
            if match and result["title"] == "Unknown Lesson":
                title_text = match.group(1).strip()
                # Cleanse "Playroom" dynamically from the phase naming convention
                title_text = re.sub(r'\s+Playroom\b', '', title_text, flags=re.IGNORECASE)
                result["title"] = title_text

        elif cell_type == "code":
            # Split the code cell at the automated check marker
            separator = "# === AUTOMATED CHECK ==="
            if separator in source_text:
                parts = source_text.split(separator)
                starter_code = parts[0].strip()
                assertions = parts[1].strip() if len(parts) > 1 else ""
            else:
                # Universal smart-splitting fallback: split at the first 'assert' statement!
                lines = source_text.splitlines()
                first_assert_index = -1
                for idx, line in enumerate(lines):
                    if line.strip().startswith("assert") or "assert " in line:
                        first_assert_index = idx
                        break
                
                if first_assert_index != -1:
                    starter_code = "\n".join(lines[:first_assert_index]).strip()
                    assertions = "\n".join(lines[first_assert_index:]).strip()
                else:
                    starter_code = source_text.strip()
                    assertions = ""

            result["exercises"].append({
                "starter_code": starter_code,
                "assertions": assertions
            })

    result["markdown"] = "\n\n".join(markdown_blocks)
    return result

def get_lesson_content(lesson_id):
    if not lesson_id.endswith('.ipynb'):
        lesson_id += '.ipynb'
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    content_dir = os.path.join(base_dir, 'content')
    filepath = os.path.join(content_dir, lesson_id)
    if os.path.exists(filepath):
        return parse_notebook(filepath)
    return None

def get_sort_key(rel_path):
    """
    Generates a sort key for hierarchical, numerical sorting of lesson notebooks.
    Handles 'phase_10_syndicate' sorting after 'phase_9_local', and sub-phase 
    sorting (e.g., 'playroom_p1_5_linalg' between 'playroom_p1' and 'playroom_p2').
    """
    dir_name, filename = os.path.split(rel_path)
    
    # 1. Parse directory float
    dir_float = 999.0
    if dir_name:
        match = re.search(r'phase_(\d+)(?:_(\d+))?', dir_name)
        if match:
            major = match.group(1)
            minor = match.group(2)
            dir_float = float(major) + (float(minor) / 10.0 if minor else 0.0)
            
    # 2. Parse filename float
    file_float = 0.0
    match = re.search(r'p(\d+)(?:_(\d+))?', filename)
    if match:
        major = match.group(1)
        minor = match.group(2)
        file_float = float(major) + (float(minor) / 10.0 if minor else 0.0)
    elif filename == 'playroom.ipynb':
        file_float = 0.0
        
    return (dir_float, file_float, rel_path)

def list_lessons():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    content_dir = os.path.join(base_dir, 'content')
    if not os.path.exists(content_dir):
        return []
    
    lessons = []
    # Walk the directory recursively to find all notebooks
    for root, dirs, files in os.walk(content_dir):
        # Skip hidden files or folders (like .ipynb_checkpoints)
        if any(part.startswith('.') for part in root.split(os.sep)):
            continue
        for filename in files:
            if filename.endswith('.ipynb') and not filename.endswith('_eng.ipynb'):
                filepath = os.path.join(root, filename)
                rel_path = os.path.relpath(filepath, content_dir)
                try:
                    parsed = parse_notebook(filepath)
                    lessons.append({
                        "id": rel_path,
                        "title": parsed["title"],
                        "sort_key": get_sort_key(rel_path)
                    })
                except Exception:
                    pass
                    
    # Sort lessons chronologically by curriculum path metrics
    lessons.sort(key=lambda x: x["sort_key"])
    
    # Strip sort_key before outputting
    for lesson in lessons:
        lesson.pop("sort_key", None)
        
    return lessons

"""
Packaging utility to generate a clean, self-contained ZIP archive
for team members and judges. Excludes repository metadata and bytecode.
"""

import os
import zipfile
import time


def make_portable_zip(
    source_dir: str = ".",
    output_zip: str = "SIH2026_DR_Screening_Pipeline.zip",
):
    print(f"Creating portable zip archive: {output_zip}...")
    start_time = time.time()
    
    # Exclude patterns
    exclude_dirs = {".git", "__pycache__", ".pytest_cache", ".idea", ".vscode", "venv", ".venv"}
    exclude_exts = {".pyc", ".pyo", ".pyd"}
    
    abs_source = os.path.abspath(source_dir)
    abs_output = os.path.abspath(output_zip)

    file_count = 0
    with zipfile.ZipFile(output_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for root, dirs, files in os.walk(source_dir):
            # Prune excluded directories
            dirs[:] = [d for d in dirs if d not in exclude_dirs]
            
            for f in sorted(files):
                file_path = os.path.join(root, f)
                abs_file_path = os.path.abspath(file_path)
                
                # Do not include the zip file inside itself
                if abs_file_path == abs_output:
                    continue
                    
                _, ext = os.path.splitext(f)
                if ext.lower() in exclude_exts or ext.lower() == ".zip":
                    continue
                    
                # Relative archive path
                arcname = os.path.relpath(file_path, source_dir)
                zf.write(file_path, arcname)
                file_count += 1

    elapsed = time.time() - start_time
    zip_size_mb = os.path.getsize(output_zip) / (1024 * 1024)
    print(f"Successfully packaged {file_count} files into {output_zip}")
    print(f"Compressed Archive Size: {zip_size_mb:.2f} MB")
    print(f"Elapsed Time: {elapsed:.2f}s")


if __name__ == "__main__":
    import sys
    out_name = sys.argv[1] if len(sys.argv) > 1 else "SIH2026_DR_Screening_Pipeline_LATEST.zip"
    make_portable_zip(output_zip=out_name)

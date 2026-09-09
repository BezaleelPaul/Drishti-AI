"""
Package Sinduri's UI/UX Design Kit into a clean, standalone ZIP archive.
"""
import os
import zipfile
import shutil
import time

def package_kit():
    source_dir = os.path.abspath("sinduri_uiux_kit")
    zip_name = "SIH2026_UIUX_Design_Kit_Sinduri.zip"
    dest_downloads = os.path.join(os.path.expanduser("~/Downloads"), zip_name)
    local_zip = os.path.abspath(zip_name)
    
    print(f"Packaging {source_dir} into {zip_name}...")
    t0 = time.time()
    
    with zipfile.ZipFile(local_zip, 'w', zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk(source_dir):
            for file in files:
                file_path = os.path.join(root, file)
                rel_path = os.path.relpath(file_path, source_dir)
                zipf.write(file_path, arcname=os.path.join("NetraAI_UIUX_Design_Kit_Sinduri", rel_path))
                print(f"  + Added: {rel_path}")

    # Copy to Downloads
    shutil.copy2(local_zip, dest_downloads)
    
    size_mb = os.path.getsize(local_zip) / (1024 * 1024)
    elapsed = time.time() - t0
    print(f"\n[SUCCESS] Packaged Sinduri's Design Kit successfully!")
    print(f"Archive Size: {size_mb:.2f} MB")
    print(f"Time Taken: {elapsed:.2f}s")
    print(f"Saved locally to: {local_zip}")
    print(f"Copied to Downloads: {dest_downloads}")

if __name__ == "__main__":
    package_kit()

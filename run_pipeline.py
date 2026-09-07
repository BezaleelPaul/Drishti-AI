"""
CLI runner for the AI-Assisted Diabetic Retinopathy Screening Pipeline.
Processes single images or directories, applying the full 11-node decision flow.
"""

import argparse
import os
import sys
from PIL import Image

from src.pipeline.router import ScreeningPipelineRouter
from src.pipeline.schema import QualityGrade


def main():
    parser = argparse.ArgumentParser(
        description="SIH 2026: AI-Assisted Diabetic Retinopathy Screening Pipeline"
    )
    parser.add_argument(
        "--image",
        type=str,
        help="Path to a single retinal fundus image file.",
    )
    parser.add_argument(
        "--input_dir",
        type=str,
        help="Path to directory containing retinal fundus images.",
    )
    parser.add_argument(
        "--output_dir",
        type=str,
        default="results",
        help="Directory to save screening reports and Grad-CAM overlays.",
    )
    parser.add_argument(
        "--recaptures",
        type=int,
        default=0,
        help="Current count of previous recapture attempts for this session.",
    )

    args = parser.parse_args()

    if not args.image and not args.input_dir:
        # Default to running sample images if neither is passed
        sample_dir = os.path.join("demo", "sample_images")
        if os.path.exists(sample_dir):
            args.input_dir = sample_dir
        else:
            parser.print_help()
            sys.exit(1)

    os.makedirs(args.output_dir, exist_ok=True)
    router = ScreeningPipelineRouter()

    image_paths = []
    if args.image:
        image_paths.append(args.image)
    elif args.input_dir:
        valid_exts = (".jpg", ".jpeg", ".png", ".bmp", ".tif")
        for f in sorted(os.listdir(args.input_dir)):
            if f.lower().endswith(valid_exts):
                image_paths.append(os.path.join(args.input_dir, f))

    print(f"\n{'='*70}")
    print(f"SIH 2026: AI-Assisted DR Screening Pipeline Execution")
    print(f"Processing {len(image_paths)} image(s)...")
    print(f"{'='*70}\n")

    for idx, path in enumerate(image_paths, 1):
        filename = os.path.basename(path)
        img_out_dir = os.path.join(args.output_dir, os.path.splitext(filename)[0])

        record = router.process_image(
            image_input=path,
            recapture_attempt_count=args.recaptures,
            output_dir=img_out_dir,
        )

        print(f"[{idx}/{len(image_paths)}] File: {filename}")
        print("-" * 50)
        print(record.format_report_text())
        print("-" * 50)
        print(f"Result files saved to: {img_out_dir}\n")


if __name__ == "__main__":
    main()

# ELYTRIVA Brand Assets

Concept logo package for ELYTRIVA — AI-powered retinal screening.

## Included
- `svg/`: scalable vector logo files (editable in Figma, Illustrator, Inkscape)
- `png/`: high-resolution raster exports
- `flutter_assets/`: app icon sizes and a Flutter pubspec snippet
- `colors.txt`: brand palette

## Palette
- Navy: #0B132B
- Cyan: #00B4D8
- Teal: #18D6C7
- Orange accent: #FF9F6E
- White: #FFFFFF

## Flutter
1. Copy `flutter_assets/elytriva_icon_512.png` to `your_project/assets/branding/`.
2. Add the asset under `flutter.assets` in `pubspec.yaml` (see `flutter_assets/pubspec_snippet.yaml`).
3. For launcher icons, configure `flutter_launcher_icons` as shown in the snippet and run:
   `dart run flutter_launcher_icons`

The PNG icons use a navy background. The logo PNGs have transparent backgrounds where appropriate; light/dark variants use matching text colours.

Note: This is a starter brand asset pack generated from a concept logo, not trademark clearance. Review the assets at small sizes and adjust the vector geometry/typography to your final brand guidelines before production.

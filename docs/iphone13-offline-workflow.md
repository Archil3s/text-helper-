# iPhone 13 offline visual workflow

This project uses GitHub Actions to generate an offline visual preview for the Text Helper UI.

## Preview target

- Device viewport: iPhone 13
- Logical size: 390 x 844
- Output: PNG artifact from GitHub Actions

## How to view the preview

1. Open the repository on GitHub.
2. Go to Actions.
3. Open iPhone 13 Visual Workflow.
4. Open the latest workflow run.
5. Download the artifact named iphone13-home-screen-visual.
6. Open the PNG locally.

## Local command

```bash
bash scripts/update_iphone13_visuals.sh
```

This updates the golden visual locally using the same iPhone 13 viewport test.

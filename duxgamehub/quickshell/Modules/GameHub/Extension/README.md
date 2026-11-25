# Game Hub Extension System

This folder enables Playnite-like metadata and asset enrichment extensions for Fullscreen Game Hub.

## How it works

The python library scanner in `GameHubWidget.qml` checks the `Extension/` folder for any custom Python extension modules (`.py`).
Each extension module can provide:
1. Custom game detection rules (e.g. sideloaded, emulators, custom paths, Wine prefixes).
2. Metadata enrichment hooks:
   - Extra metadata tags (genres, release year, developers, tags).
   - High-resolution custom cover art URLs or local paths.
   - Gameplay trailer URLs (YouTube / WebM / MP4).
   - Custom backdrop / banner assets.

## Example Extension Structure
```
Extension/
├── README.md
└── custom_metadata_enricher.py
```

### Implementing `enrich_game(game_dict)`:
```python
def enrich_game(game):
    """
    Called for each scanned game entry.
    game contains:
      - title: Game title
      - launcher: Platform launcher tag (Steam, Epic, GOG, etc.)
      - cmd: Launch executable/command
      - coverUrl: Existing cover art URL or file path
      - uninstalled: Boolean
    """
    # Example: attach custom trailer or override cover
    if game["title"].lower() == "my custom game":
        game["coverUrl"] = "file:///path/to/custom_cover.jpg"
        game["trailerUrl"] = "https://www.youtube.com/watch?v=..."
    return game
```

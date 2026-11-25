"""
Metadata Manager for DMS Fullscreen Game Hub
---------------------------------------------
Orchestrates metadata fetching + local disk caching with per-phase progress.

Phases (run independently via separate QML Process, each can be cancelled):
  1. metadata    - fetch descriptions/genres/artwork URLs from APIs, write to cache
  2. covers      - download vertical cover images (600x900)
  3. backgrounds - download full-resolution background/hero images (1920x1080)
  4. media       - download gallery screenshots
  5. trailers    - download trailer video files (.mp4)

Progress protocol (stdout -> GameHubWidget.qml):
  PROGRESS:<phase>:<done>:<total>:<current_title>
  RELOAD                              <- tells QML to reload game list mid-run
  METADATA_DONE                       <- phase fully finished

Cache / storage:
  Extension Data/metadata.json        - keyed by normalised title string
  Extension Data/covers/              - cover images  (600x900 vertical JPEGs)
  Extension Data/backgrounds/         - background images (landscape 1920x1080)
  Extension Data/media/               - gallery screenshots
  Extension Data/trailers/            - trailer videos (.mp4) and thumbnails
"""

import glob
import json
import os
import re
import subprocess
import sys
import time
import urllib.request


# ---------------------------------------------------------------------------
#  Paths
# ---------------------------------------------------------------------------

def _plugin_dir_from_self():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _ext_data_dir(plugin_dir=None):
    base = plugin_dir or _plugin_dir_from_self()
    return os.path.join(base, "Extension Data")


def _cache_path(plugin_dir=None):
    return os.path.join(_ext_data_dir(plugin_dir), "metadata.json")


def _media_dir(sub, plugin_dir=None):
    p = os.path.join(_ext_data_dir(plugin_dir), sub)
    os.makedirs(p, exist_ok=True)
    return p


def _covers_dir(plugin_dir=None):      return _media_dir("covers", plugin_dir)
def _backgrounds_dir(plugin_dir=None): return _media_dir("backgrounds", plugin_dir)
def _screenshots_dir(plugin_dir=None): return _media_dir("media", plugin_dir)
def _trailers_dir(plugin_dir=None):    return _media_dir("trailers", plugin_dir)


# ---------------------------------------------------------------------------
#  Cache helpers
# ---------------------------------------------------------------------------

def _load_cache(plugin_dir=None):
    path = _cache_path(plugin_dir)
    if not os.path.exists(path):
        return {}
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _save_cache(cache, plugin_dir=None):
    path = _cache_path(plugin_dir)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(cache, f, ensure_ascii=False, indent=2)
    except Exception:
        pass


def _cache_key(title):
    t = re.sub(r"[^a-z0-9 ]", "", title.lower().strip())
    return t.strip()


def _find_existing_local_file(dest_dir, slug):
    """Check if a file with given slug already exists in dest_dir with any common extension."""
    safe_slug = re.sub(r"[^a-z0-9_-]", "_", slug.lower())[:80]
    pattern = os.path.join(dest_dir, safe_slug + ".*")
    matches = glob.glob(pattern)
    for m in matches:
        if os.path.exists(m) and os.path.getsize(m) > 1000:
            return "file://" + os.path.abspath(m)
    return ""


# ---------------------------------------------------------------------------
#  Media Checksum & Integrity Verification
# ---------------------------------------------------------------------------

def _calculate_file_checksum(file_path):
    """Calculate SHA256 checksum of a file to verify completeness and integrity."""
    import hashlib
    try:
        h = hashlib.sha256()
        with open(file_path, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                h.update(chunk)
        return h.hexdigest()
    except Exception:
        return ""


def _verify_media_integrity(file_path, is_video=False, min_width=0, min_height=0):
    """
    Verify downloaded media file integrity (checksum/header & decoder test).
    Returns (is_valid: bool, width: int, height: int)
    """
    if not os.path.exists(file_path):
        return False, 0, 0

    size = os.path.getsize(file_path)
    if is_video:
        if size < 50000:
            return False, 0, 0
        # Probe video using ffprobe to confirm it plays cleanly and has valid video frames
        try:
            cmd = [
                "ffprobe", "-v", "error",
                "-select_streams", "v:0",
                "-show_entries", "stream=width,height",
                "-of", "default=noprint_wrappers=1",
                file_path
            ]
            ret = subprocess.run(cmd, capture_output=True, text=True, timeout=8)
            if ret.returncode != 0:
                return False, 0, 0
            w = h = 0
            for line in ret.stdout.splitlines():
                if line.startswith("width="):
                    w = int(line.split("=")[1])
                elif line.startswith("height="):
                    h = int(line.split("=")[1])
            return (w > 0 and h > 0), w, h
        except Exception:
            return False, 0, 0
    else:
        # Image verification
        if size < 1500:
            return False, 0, 0
        try:
            from PIL import Image
            with Image.open(file_path) as img:
                img.verify()
            with Image.open(file_path) as img:
                w, h = img.size
                if min_width > 0 and w < min_width:
                    return False, w, h
                if min_height > 0 and h < min_height:
                    return False, w, h
                return True, w, h
        except Exception:
            # Fallback signature check if PIL not available
            try:
                with open(file_path, "rb") as f:
                    head = f.read(16)
                is_valid_header = head.startswith(b"\xff\xd8") or head.startswith(b"\x89PNG") or head.startswith(b"RIFF")
                return is_valid_header, 0, 0
            except Exception:
                return False, 0, 0


# ---------------------------------------------------------------------------
#  Generic download helper with integrity check & checksum
# ---------------------------------------------------------------------------

def _download_file(url, dest_dir, slug, hint_ext=".jpg", min_width=0, min_height=0):
    """Download url to dest_dir/<slug><ext> with integrity validation."""
    if not url or not url.startswith("http"):
        return url

    # Skip if valid file already exists locally
    existing = _find_existing_local_file(dest_dir, slug)
    if existing:
        raw_p = existing.replace("file://", "")
        valid, w, h = _verify_media_integrity(raw_p, is_video=False, min_width=min_width, min_height=min_height)
        if valid:
            return existing
        else:
            # Corrupt or too low-res existing file, remove and re-download
            try:
                os.remove(raw_p)
            except Exception:
                pass

    ext = hint_ext
    clean_url = url.split("?")[0]
    for e in (".png", ".webp", ".jpeg", ".jpg", ".mp4", ".mkv", ".webm"):
        if clean_url.lower().endswith(e):
            ext = e
            break

    safe_slug = re.sub(r"[^a-z0-9_-]", "_", slug.lower())[:80]
    dest = os.path.join(dest_dir, safe_slug + ext)

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
        "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://store.steampowered.com/"
    }

    data = None
    # 1. Direct fetch
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=12) as resp:
            data = resp.read()
    except Exception:
        data = None

    # 2. Weserv image CDN proxy fallback (bypasses ISP/regional CDN blocks on Epic & Steam CDNs)
    if not data or len(data) < 1500:
        try:
            proxy_url = f"https://images.weserv.nl/?url={urllib.parse.quote(url)}"
            req = urllib.request.Request(proxy_url, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(req, timeout=12) as resp:
                data = resp.read()
        except Exception:
            data = None

    if not data or len(data) < 1500:
        return url

    try:
        with open(dest, "wb") as f:
            f.write(data)

        # Integrity check
        valid, w, h = _verify_media_integrity(dest, is_video=False, min_width=min_width, min_height=min_height)
        if not valid:
            try:
                os.remove(dest)
            except Exception:
                pass
            return url

        return "file://" + os.path.abspath(dest)
    except Exception:
        return url


# ---------------------------------------------------------------------------
#  Apply metadata to game entry  (no file I/O)
# ---------------------------------------------------------------------------

def _apply_meta(game, meta):
    """Merge metadata dict fields into game entry (non-destructive)."""
    for field, src_key in [
        ("description",  "description"),
        ("genres",       "genres"),
        ("releaseDate",  "releaseDate"),
        ("publisher",    "publisher"),
        ("developer",    "developer"),
        ("rating",       "rating"),
        ("screenshots",  "screenshots"),
        ("trailers",     "trailers"),
        ("metascore",    "metascore"),
        ("metaSource",   "source"),
    ]:
        val = meta.get(src_key)
        if val is not None and not game.get(field):
            game[field] = val

    # High-resolution background preference:
    # Always prefer full 1920x1080 artwork (page_bg_raw, screenshots) over small 460x215 headers
    bg = meta.get("background", "")
    screenshots = meta.get("screenshots") or []
    if screenshots and isinstance(screenshots, list) and len(screenshots) > 0:
        first_ss = screenshots[0]
        if isinstance(first_ss, str) and first_ss.startswith("http"):
            bg = first_ss

    if bg:
        cur_bg = game.get("backgroundUrl", "")
        if not cur_bg or "header.jpg" in cur_bg:
            game["backgroundUrl"] = bg

    cov = meta.get("cover", "")
    cur_cov = game.get("coverUrl", "")
    # Upgrade cover to high-res vertical Steam/RAWG poster if missing or currently an un-downloadable/landscape Epic URL
    if cov and (not cur_cov or "epicgames.com" in cur_cov or cur_cov == "fallback"):
        game["coverUrl"] = cov

    # Always prefer local downloaded covers and backgrounds if present on disk
    title = game.get("title", "")
    if title:
        slug = _cache_key(title)
        local_cov = _find_existing_local_file(_covers_dir(), slug)
        if local_cov:
            game["coverUrl"] = local_cov
        local_bg = _find_existing_local_file(_backgrounds_dir(), slug)
        if local_bg:
            raw_bg = local_bg.replace("file://", "")
            is_valid_bg, w, h = _verify_media_integrity(raw_bg, is_video=False, min_width=1280, min_height=720)
            if is_valid_bg:
                game["backgroundUrl"] = local_bg


# ---------------------------------------------------------------------------
#  Shared progress/reload helpers
# ---------------------------------------------------------------------------

def _report(phase, done, total, title=""):
    safe = title.replace("\n", " ").replace(":", "-")[:60]
    print(f"PROGRESS:{phase}:{done}:{total}:{safe}", flush=True)


def _reload(games_file, games):
    """Write current game state + signal QML to reload grid."""
    try:
        with open(games_file, "w", encoding="utf-8") as f:
            json.dump(games, f, ensure_ascii=False)
        print("RELOAD", flush=True)
    except Exception:
        pass


# ---------------------------------------------------------------------------
#  PHASE 1 - Fetch metadata from APIs (Steam/PSN/RAWG)
# ---------------------------------------------------------------------------

def phase_metadata(games, games_file, plugin_dir, rawg_key, report_progress=True):
    ext_dir = os.path.join(plugin_dir, "Extension")
    if ext_dir not in sys.path:
        sys.path.insert(0, ext_dir)
    try:
        from psn_metadata import fetch_metadata
    except Exception as e:
        sys.stderr.write(f"Cannot import psn_metadata: {e}\n")
        return games

    cache = _load_cache(plugin_dir)
    cache_dirty = False

    needs = []
    for game in games:
        title = game.get("title", "").strip()
        if not title:
            continue
        key = _cache_key(title)
        if key in cache:
            _apply_meta(game, cache[key])
            entry = cache[key]
            if entry.get("description") and (entry.get("cover") or game.get("coverUrl")):
                continue
        needs.append((game, key))

    total = len(needs)
    if report_progress:
        if total == 0:
            _report("metadata", 0, 0, "Complete")
        else:
            _report("metadata", 0, total, needs[0][0].get("title", "Starting..."))

    for idx, (game, key) in enumerate(needs):
        title = game.get("title", "")
        if report_progress and idx > 0:
            _report("metadata", idx, total, title)

        try:
            meta = fetch_metadata(title, rawg_key=rawg_key)
        except Exception:
            meta = None

        if meta:
            cache[key] = meta
            cache_dirty = True
            _apply_meta(game, meta)

        # Batch reload after every 20 games (or at end) so newly fetched data shows up in grid
        if report_progress and ((idx + 1) % 20 == 0 or idx == total - 1):
            _reload(games_file, games)

        time.sleep(0.04)

    if report_progress and total > 0:
        _report("metadata", total, total, "Done")

    if cache_dirty:
        _save_cache(cache, plugin_dir)
        _reload(games_file, games)

    return games


# ---------------------------------------------------------------------------
#  PHASE 2 - Download covers (vertical 600x900 JPEGs)
# ---------------------------------------------------------------------------

def phase_covers(games, games_file, plugin_dir, report_progress=True):
    covers = _covers_dir(plugin_dir)
    targets = []
    for g in games:
        title = g.get("title", "")
        slug = _cache_key(title)
        existing = _find_existing_local_file(covers, slug)
        if existing:
            raw_p = existing.replace("file://", "")
            is_valid, _, _ = _verify_media_integrity(raw_p, is_video=False, min_width=300, min_height=400)
            if is_valid:
                g["coverUrl"] = existing
                continue
            else:
                try: os.remove(raw_p)
                except: pass

        c_url = g.get("coverUrl", "")
        if c_url.startswith("http"):
            targets.append((g, slug))

    total = len(targets)
    if report_progress:
        if total == 0:
            _report("covers", 0, 0, "Complete")
        else:
            _report("covers", 0, total, targets[0][0].get("title", "Starting..."))

    for idx, (game, slug) in enumerate(targets):
        if report_progress and idx > 0:
            _report("covers", idx, total, game.get("title", ""))

        local = _download_file(game["coverUrl"], covers, slug, min_width=300, min_height=400)
        if local.startswith("file://"):
            game["coverUrl"] = local

        # Batch reload after every 20 games
        if report_progress and ((idx + 1) % 20 == 0 or idx == total - 1):
            _reload(games_file, games)

        time.sleep(0.02)

    if report_progress and total > 0:
        _report("covers", total, total, "Done")
        _reload(games_file, games)

    return games


# ---------------------------------------------------------------------------
#  PHASE 3 - Download background/hero images (1920x1080)
# ---------------------------------------------------------------------------

def phase_backgrounds(games, games_file, plugin_dir, report_progress=True):
    bg_dir = _backgrounds_dir(plugin_dir)
    targets = []
    for g in games:
        title = g.get("title", "")
        slug = _cache_key(title)
        existing = _find_existing_local_file(bg_dir, slug)
        if existing:
            raw_p = existing.replace("file://", "")
            is_valid, w, h = _verify_media_integrity(raw_p, is_video=False, min_width=1280, min_height=720)
            if is_valid:
                g["backgroundUrl"] = existing
                continue
            else:
                try: os.remove(raw_p)
                except: pass

        b_url = g.get("backgroundUrl", "")
        # If screenshots exist, upgrade to screenshot 1920x1080 over small header
        screens = g.get("screenshots") or []
        if screens and isinstance(screens, list) and len(screens) > 0:
            for s in screens:
                if isinstance(s, str) and s.startswith("http"):
                    b_url = s
                    g["backgroundUrl"] = b_url
                    break

        if b_url.startswith("http"):
            targets.append((g, slug))

    total = len(targets)
    if report_progress:
        if total == 0:
            _report("backgrounds", 0, 0, "Complete")
        else:
            _report("backgrounds", 0, total, targets[0][0].get("title", "Starting..."))

    for idx, (game, slug) in enumerate(targets):
        if report_progress and idx > 0:
            _report("backgrounds", idx, total, game.get("title", ""))

        local = _download_file(game["backgroundUrl"], bg_dir, slug, min_width=1280, min_height=720)
        if local.startswith("file://"):
            game["backgroundUrl"] = local

        # Batch reload after every 20 games
        if report_progress and ((idx + 1) % 20 == 0 or idx == total - 1):
            _reload(games_file, games)

        time.sleep(0.02)

    if report_progress and total > 0:
        _report("backgrounds", total, total, "Done")
        _reload(games_file, games)

    return games


# ---------------------------------------------------------------------------
#  PHASE 4 - Download media & gallery screenshots
# ---------------------------------------------------------------------------

def phase_media(games, games_file, plugin_dir, report_progress=True):
    media_dir = _screenshots_dir(plugin_dir)
    targets = []
    for g in games:
        slug = _cache_key(g.get("title", ""))
        screens = g.get("screenshots") or []
        has_http = any(isinstance(s, str) and s.startswith("http") for s in screens)
        if has_http:
            targets.append((g, slug))

    total = len(targets)

    for idx, (game, slug) in enumerate(targets):
        if report_progress:
            _report("media", idx, total, game.get("title", ""))

        screens = game.get("screenshots") or []
        new_screens = []
        for i, s_url in enumerate(screens):
            if isinstance(s_url, str) and s_url.startswith("http"):
                local = _download_file(s_url, media_dir, f"{slug}_ss{i}", ".jpg")
                new_screens.append(local)
            else:
                new_screens.append(s_url)
        game["screenshots"] = new_screens

        # Batch reload after every 20 games
        if report_progress and ((idx + 1) % 20 == 0 or idx == total - 1):
            _reload(games_file, games)

        time.sleep(0.02)

    if report_progress and total > 0:
        _report("media", total, total, "Done")
        _reload(games_file, games)

    return games


# ---------------------------------------------------------------------------
#  PHASE 5 - Download trailers (Actual Video Files)
# ---------------------------------------------------------------------------

def _download_video_stream(video_url, dest_path):
    """Download video stream (m3u8, mp4, etc.) to a local mp4 file with full integrity validation."""
    if not video_url or not video_url.startswith("http"):
        return ""

    if os.path.exists(dest_path):
        is_valid, _, _ = _verify_media_integrity(dest_path, is_video=True)
        if is_valid:
            return "file://" + os.path.abspath(dest_path)
        else:
            try: os.remove(dest_path)
            except: pass

    # 1. Try ffmpeg directly (best for HLS m3u8 streams and mp4 urls)
    try:
        cmd = [
            "ffmpeg", "-y",
            "-headers", "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64)\r\n",
            "-i", video_url,
            "-c", "copy",
            "-bsf:a", "aac_adtstoasc",
            "-t", "90",  # limit trailer to max 90 seconds
            dest_path
        ]
        ret = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=45)
        if ret.returncode == 0 and os.path.exists(dest_path):
            is_valid, _, _ = _verify_media_integrity(dest_path, is_video=True)
            if is_valid:
                return "file://" + os.path.abspath(dest_path)
            else:
                try: os.remove(dest_path)
                except: pass
    except Exception:
        pass

    # 2. Try yt-dlp fallback
    try:
        cmd = [
            "yt-dlp",
            "--no-playlist",
            "--quiet",
            "--no-warnings",
            "-o", dest_path,
            video_url
        ]
        ret = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=45)
        if ret.returncode == 0 and os.path.exists(dest_path):
            is_valid, _, _ = _verify_media_integrity(dest_path, is_video=True)
            if is_valid:
                return "file://" + os.path.abspath(dest_path)
            else:
                try: os.remove(dest_path)
                except: pass
    except Exception:
        pass

    # 3. Direct HTTP download fallback if standard direct video file
    try:
        req = urllib.request.Request(video_url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
        with urllib.request.urlopen(req, timeout=18) as resp:
            data = resp.read()
        if len(data) > 50000:
            with open(dest_path, "wb") as f:
                f.write(data)
            is_valid, _, _ = _verify_media_integrity(dest_path, is_video=True)
            if is_valid:
                return "file://" + os.path.abspath(dest_path)
            else:
                try: os.remove(dest_path)
                except: pass
    except Exception:
        pass

    return ""


def phase_trailers(games, games_file, plugin_dir, report_progress=True):
    trailers_dir = _trailers_dir(plugin_dir)
    targets = []
    for g in games:
        title = g.get("title", "")
        slug = re.sub(r"[^a-z0-9_-]+", "_", _cache_key(title)).strip("_")[:80]
        trailers = g.get("trailers") or []
        if not trailers:
            continue
        first_t = trailers[0]
        if not isinstance(first_t, dict):
            continue
        dest_file = os.path.join(trailers_dir, f"{slug}.mp4")
        if os.path.exists(dest_file):
            is_valid, _, _ = _verify_media_integrity(dest_file, is_video=True)
            if is_valid:
                first_t["localVideo"] = "file://" + os.path.abspath(dest_file)
                first_t["url"] = "file://" + os.path.abspath(dest_file)
            else:
                try: os.remove(dest_file)
                except: pass
                targets.append((g, slug, first_t))
        elif first_t.get("url", "").startswith("http"):
            targets.append((g, slug, first_t))

    total = len(targets)
    if report_progress:
        if total == 0:
            _report("trailers", 0, 0, "Complete")
        else:
            _report("trailers", 0, total, targets[0][0].get("title", "Starting..."))

    for idx, (game, slug, trailer) in enumerate(targets):
        if report_progress and idx > 0:
            _report("trailers", idx, total, game.get("title", ""))

        v_url = trailer.get("url", "")
        if v_url.startswith("http"):
            dest = os.path.join(trailers_dir, f"{slug}.mp4")
            local_path = _download_video_stream(v_url, dest)
            if local_path:
                trailer["localVideo"] = local_path
                trailer["url"] = local_path  # Point directly to downloaded video file

        # Batch reload after every 20 games
        if report_progress and ((idx + 1) % 20 == 0 or idx == total - 1):
            _reload(games_file, games)

        time.sleep(0.05)

    if report_progress and total > 0:
        _report("trailers", total, total, "Done")
        _reload(games_file, games)

    return games


# ---------------------------------------------------------------------------
#  Legacy enrich_games  (kept for compatibility with old callers)
# ---------------------------------------------------------------------------

def enrich_games(games, plugin_dir=None, settings=None, report_progress=False):
    s = settings or {}
    if not s.get("metadataEnabled", True):
        return games
    if not s.get("metadataAutoFetch", True):
        return games

    rawg_key = s.get("rawgKey", "") or s.get("metadataRawgKey", "")
    tmp = "/tmp/dms_gamehub_games.json"
    pd = plugin_dir or _plugin_dir_from_self()

    games = phase_metadata(games, tmp, pd, rawg_key, report_progress)

    if s.get("metadataDownloadCovers", False):
        games = phase_covers(games, tmp, pd, report_progress)

    return games


# ---------------------------------------------------------------------------
#  Standalone mode
#   python3 metadata_enricher.py <games_file> <plugin_dir> [rawg_key] [phase]
#   phase = metadata | covers | backgrounds | media | trailers
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.stderr.write(
            "Usage: metadata_enricher.py <games_file> <plugin_dir> [rawg_key] [phase]\n"
        )
        sys.exit(1)

    games_file = sys.argv[1]
    plugin_dir = sys.argv[2]
    rawg_key   = sys.argv[3] if len(sys.argv) > 3 else ""
    phase      = sys.argv[4].lower() if len(sys.argv) > 4 else "metadata"

    try:
        with open(games_file, "r", encoding="utf-8") as f:
            games = json.load(f)
    except Exception as e:
        sys.stderr.write(f"Failed to read games file: {e}\n")
        sys.exit(1)

    if phase == "metadata":
        games = phase_metadata(games, games_file, plugin_dir, rawg_key)
    elif phase == "covers":
        games = phase_covers(games, games_file, plugin_dir)
    elif phase == "backgrounds":
        games = phase_backgrounds(games, games_file, plugin_dir)
    elif phase == "media":
        games = phase_media(games, games_file, plugin_dir)
    elif phase == "trailers":
        games = phase_trailers(games, games_file, plugin_dir)
    else:
        sys.stderr.write(f"Unknown phase: {phase}\n")
        sys.exit(1)

    # Final authoritative save
    try:
        with open(games_file, "w", encoding="utf-8") as f:
            json.dump(games, f, ensure_ascii=False)
    except Exception as e:
        sys.stderr.write(f"Failed to save: {e}\n")

    print("METADATA_DONE", flush=True)

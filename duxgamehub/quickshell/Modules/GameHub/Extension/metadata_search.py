#!/usr/bin/env python3
"""
Metadata Search & Editor Backend
---------------------------------
Supports:
  1. Searching for metadata across Steam, PSN, and Wikipedia
     Usage: python3 metadata_search.py search "<search_query>" [provider]
     Output: JSON array of search result objects with rich media (covers, backgrounds, screenshots, trailers)
             and resolution tags (width, height, is_high_res).

  2. Saving / updating metadata permanently
     Usage: python3 metadata_search.py save "<game_title>" '<json_payload>' <plugin_dir> <games_file>
     Updates Extension Data/metadata.json permanently AND updates /tmp/dms_gamehub_games.json
"""

import sys
import os
import json
import re
import urllib.request
import urllib.parse

def _safe_get(url, headers=None, timeout=8):
    try:
        h = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}
        if headers:
            h.update(headers)
        req = urllib.request.Request(url, headers=h)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode("utf-8", errors="ignore")
    except Exception:
        return ""

def _safe_json(url, headers=None, timeout=8):
    raw = _safe_get(url, headers, timeout)
    if not raw:
        return None
    try:
        return json.loads(raw)
    except Exception:
        return None

def search_steam(query):
    """Search Steam store and return candidate game matches with high-resolution media."""
    encoded = urllib.parse.quote(query)
    url = f"https://store.steampowered.com/api/storesearch/?term={encoded}&l=english&cc=US"
    data = _safe_json(url)
    if not data or not data.get("items"):
        return []

    results = []
    for item in data.get("items", [])[:6]:
        app_id = item.get("id")
        if not app_id:
            continue
        name = item.get("name", "")

        # Fetch detailed appinfo
        det_url = f"https://store.steampowered.com/api/appdetails?appids={app_id}&l=english"
        det_data = _safe_json(det_url)
        app_info = (det_data or {}).get(str(app_id), {}).get("data", {})
        if not app_info:
            continue

        desc = app_info.get("short_description") or ""
        genres = [g.get("description") for g in app_info.get("genres", []) if isinstance(g, dict) and g.get("description")]
        categories = [c.get("description") for c in app_info.get("categories", []) if isinstance(c, dict) and c.get("description")]
        for cat in categories:
            if cat and cat not in genres:
                genres.append(cat)
        release_date = (app_info.get("release_date") or {}).get("date") or ""
        developers = app_info.get("developers") or []
        publishers = app_info.get("publishers") or []
        metascore = (app_info.get("metacritic") or {}).get("score")

        # Media arrays
        cover_vertical = f"https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{app_id}/library_600x900_2x.jpg"
        header = app_info.get("header_image") or f"https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{app_id}/header.jpg"

        covers = [
            {
                "title": "Steam Vertical Boxart",
                "url": cover_vertical,
                "width": 600,
                "height": 900,
                "isHighRes": True
            },
            {
                "title": "Steam Store Header",
                "url": header,
                "width": 460,
                "height": 215,
                "isHighRes": False
            }
        ]

        backgrounds = []
        bg_raw = app_info.get("background_raw")
        if bg_raw:
            backgrounds.append({
                "title": "Steam Raw Hero Art",
                "url": bg_raw,
                "width": 1920,
                "height": 1080,
                "isHighRes": True
            })

        bg_store = app_info.get("background")
        if bg_store and bg_store != bg_raw:
            backgrounds.append({
                "title": "Steam Store Background",
                "url": bg_store,
                "width": 1920,
                "height": 1080,
                "isHighRes": True
            })

        screenshots = []
        for s in app_info.get("screenshots", []):
            if isinstance(s, dict) and s.get("path_full"):
                ss_url = s["path_full"]
                screenshots.append(ss_url)
                backgrounds.append({
                    "title": f"Screenshot {s.get('id', '')}",
                    "url": ss_url,
                    "width": 1920,
                    "height": 1080,
                    "isHighRes": True
                })

        trailers = []
        for m in app_info.get("movies", []):
            if not isinstance(m, dict):
                continue
            t_url = (
                m.get("hls_h264")
                or m.get("dash_h264")
                or (m.get("mp4", {}) or {}).get("max")
                or (m.get("webm", {}) or {}).get("max")
                or ""
            )
            if t_url:
                trailers.append({
                    "id": m.get("id"),
                    "name": m.get("name", "Trailer"),
                    "thumbnail": m.get("thumbnail", ""),
                    "url": t_url
                })

        primary_bg = (backgrounds[0]["url"] if backgrounds else header)

        results.append({
            "source": "Steam",
            "sourceId": str(app_id),
            "title": name,
            "description": desc,
            "genres": genres,
            "releaseDate": release_date,
            "developer": developers[0] if developers else "",
            "publisher": publishers[0] if publishers else "",
            "metascore": metascore,
            "coverUrl": cover_vertical,
            "backgroundUrl": primary_bg,
            "covers": covers,
            "backgrounds": backgrounds,
            "screenshots": screenshots[:10],
            "trailers": trailers
        })

    return results

def search_wikipedia(query):
    """Wikipedia OpenSearch & summary for game information."""
    encoded = urllib.parse.quote(query)
    url = f"https://en.wikipedia.org/w/api.php?action=opensearch&search={encoded}&limit=4&namespace=0&format=json"
    data = _safe_json(url, headers={"User-Agent": "DMSGameHub/1.0 (Linux)"})
    if not data or len(data) < 2 or not data[1]:
        return []

    results = []
    for title in data[1]:
        sum_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{urllib.parse.quote(title)}"
        sdata = _safe_json(sum_url, headers={"User-Agent": "DMSGameHub/1.0 (Linux)"})
        if not sdata:
            continue
        extract = sdata.get("extract") or ""
        img_info = sdata.get("originalimage") or sdata.get("thumbnail") or {}
        img_url = img_info.get("source") or ""
        w = img_info.get("width") or 0
        h = img_info.get("height") or 0

        covers = []
        if img_url:
            covers.append({
                "title": "Wikipedia Poster",
                "url": img_url,
                "width": w,
                "height": h,
                "isHighRes": (w >= 300 and h >= 400)
            })

        results.append({
            "source": "Wikipedia",
            "sourceId": title,
            "title": title,
            "description": extract,
            "genres": ["Wikipedia"],
            "releaseDate": "",
            "developer": "",
            "publisher": "",
            "metascore": None,
            "coverUrl": img_url,
            "backgroundUrl": "",
            "covers": covers,
            "backgrounds": [],
            "screenshots": [],
            "trailers": []
        })

    return results

def search_all(query):
    """Search all metadata providers and return consolidated results."""
    combined = []
    # 1. Steam (richest media, full 1080p backgrounds, vertical 600x900 covers, trailers)
    try:
        steam_res = search_steam(query)
        combined.extend(steam_res)
    except Exception as e:
        sys.stderr.write(f"Steam search error: {e}\n")

    # 2. Wikipedia (encyclopedic summaries & alternative covers)
    try:
        wiki_res = search_wikipedia(query)
        combined.extend(wiki_res)
    except Exception as e:
        sys.stderr.write(f"Wiki search error: {e}\n")

    return combined

def save_permanent_metadata(original_title, payload_json, plugin_dir, games_file):
    """Permanently write updated metadata to metadata.json and /tmp/dms_gamehub_games.json."""
    data = json.loads(payload_json)
    ext_data = os.path.join(plugin_dir, "Extension Data")
    os.makedirs(ext_data, exist_ok=True)
    cache_path = os.path.join(ext_data, "metadata.json")

    cache = {}
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r", encoding="utf-8") as f:
                cache = json.load(f) or {}
        except Exception:
            cache = {}

    def _cache_key(t):
        return re.sub(r"[^a-z0-9 ]", "", t.lower().strip()).strip()

    orig_key = _cache_key(original_title)
    new_title = data.get("title") or original_title
    new_key = _cache_key(new_title)

    meta_entry = {
        "title": new_title,
        "description": data.get("description", ""),
        "genres": data.get("genres", []),
        "releaseDate": data.get("releaseDate", ""),
        "publisher": data.get("publisher", ""),
        "developer": data.get("developer", ""),
        "rating": data.get("rating", ""),
        "cover": data.get("coverUrl", ""),
        "background": data.get("backgroundUrl", ""),
        "screenshots": data.get("screenshots", []),
        "trailers": data.get("trailers", []),
        "metascore": data.get("metascore"),
        "source": data.get("source", "Manual Editor")
    }

    cache[orig_key] = meta_entry
    if new_key != orig_key:
        cache[new_key] = meta_entry

    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)

    # Now update games_file (/tmp/dms_gamehub_games.json)
    if os.path.exists(games_file):
        try:
            with open(games_file, "r", encoding="utf-8") as gf:
                games = json.load(gf)
            updated = False
            for g in games:
                if g.get("title") == original_title or _cache_key(g.get("title", "")) == orig_key:
                    g["title"] = new_title
                    for k in ["description", "genres", "releaseDate", "publisher", "developer", "rating", "metascore", "screenshots", "trailers"]:
                        if k in data:
                            g[k] = data[k]
                    if data.get("coverUrl"):
                        g["coverUrl"] = data["coverUrl"]
                    if data.get("backgroundUrl"):
                        g["backgroundUrl"] = data["backgroundUrl"]
                    updated = True
                    break
            if updated:
                with open(games_file, "w", encoding="utf-8") as gf:
                    json.dump(games, gf, ensure_ascii=False)
        except Exception as e:
            sys.stderr.write(f"Error updating games file: {e}\n")

    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No action specified"}))
        sys.exit(1)

    action = sys.argv[1].lower()

    if action == "search":
        q = sys.argv[2] if len(sys.argv) > 2 else ""
        results = search_all(q)
        print(json.dumps(results, ensure_ascii=False))

    elif action == "save":
        orig_title = sys.argv[2] if len(sys.argv) > 2 else ""
        payload = sys.argv[3] if len(sys.argv) > 3 else "{}"
        pd = sys.argv[4] if len(sys.argv) > 4 else os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        gf = sys.argv[5] if len(sys.argv) > 5 else "/tmp/dms_gamehub_games.json"
        ok = save_permanent_metadata(orig_title, payload, pd, gf)
        print(json.dumps({"status": "SUCCESS" if ok else "FAILED"}))

    else:
        print(json.dumps({"error": f"Unknown action {action}"}))

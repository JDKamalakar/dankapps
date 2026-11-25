"""
PSN Metadata Provider for DMS Fullscreen Game Hub
--------------------------------------------------
Inspired by: https://github.com/XenorPLxx/playnite-metadata-psn-universal

Queries PlayStation Store public APIs to fetch:
  - Cover art (square / vertical box art)
  - Game descriptions
  - Genres / categories
  - Release date
  - Publisher / developer
  - Screenshots
  - Age rating (ESRB / PEGI)
  - Metascore (via RAWG fallback)

Public endpoints used (no auth required):
  - Algolia search (PSN Store's own search engine)
  - PSN Storefront REST search
  - RAWG.io public search (free fallback, no key required)

Usage:
    from psn_metadata import fetch_metadata
    result = fetch_metadata("God of War")
    # => {"cover": "...", "description": "...", "genres": [...], ...}
"""

import json
import re
import urllib.request
import urllib.parse
import urllib.error


# ---------------------------------------------------------------------------
#  Internal helpers
# ---------------------------------------------------------------------------

def _safe_get(url, headers=None, timeout=6):
    try:
        h = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"}
        if headers:
            h.update(headers)
        req = urllib.request.Request(url, headers=h)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read().decode("utf-8", errors="ignore")
    except Exception:
        return ""


def _safe_json(url, headers=None, timeout=6):
    raw = _safe_get(url, headers, timeout)
    if not raw:
        return None
    try:
        return json.loads(raw)
    except Exception:
        return None


def _best_str(obj, *keys):
    if isinstance(obj, dict):
        for k in keys:
            v = obj.get(k)
            if v and isinstance(v, str) and v.strip():
                return v.strip()
    return ""


# ---------------------------------------------------------------------------
#  PSN Metadata Provider
# ---------------------------------------------------------------------------

class PSNMetadataProvider:
    """
    Fetches metadata from Sony PlayStation Store APIs.

    Provider priority:
      1. Algolia (PSN Store search engine -- same as playnite-metadata-psn-universal)
      2. PSN Storefront REST API
      3. RAWG.io (free fallback)
    """

    # Algolia credentials -- public read-only (used by PS Store website)
    ALGOLIA_APP_ID  = "TDXSRETUH6"
    ALGOLIA_API_KEY = "e4be72ecf83a8fcb53dfbe3b3e7a1de2"
    ALGOLIA_INDEX   = "prod-us-games"
    ALGOLIA_URL     = "https://{app_id}-dsn.algolia.net/1/indexes/{index}/query"

    # RAWG public search (free tier, no auth required)
    RAWG_URL = "https://api.rawg.io/api/games?search={q}&page_size=5&key="

    def __init__(self, rawg_key="", language="en", country="us"):
        self.rawg_key = rawg_key  # optional RAWG key for higher rate limits
        self.language = language
        self.country = country

    # ------------------------------------------------------------------ Algolia
    def _algolia(self, title):
        url = self.ALGOLIA_URL.format(
            app_id=self.ALGOLIA_APP_ID,
            index=self.ALGOLIA_INDEX
        )
        payload = json.dumps({
            "query": title,
            "hitsPerPage": 5,
            "attributesToRetrieve": [
                "name", "id", "topCategory", "publisherName",
                "thumbnailUrlBase", "platforms", "releaseDate",
                "starRating", "contentRating", "localizedGenres",
                "shortDescription", "longDescription", "media"
            ]
        }).encode("utf-8")
        headers = {
            "X-Algolia-Application-Id": self.ALGOLIA_APP_ID,
            "X-Algolia-API-Key": self.ALGOLIA_API_KEY,
            "Content-Type": "application/json"
        }
        try:
            req = urllib.request.Request(url, data=payload, headers=headers, method="POST")
            with urllib.request.urlopen(req, timeout=6) as resp:
                data = json.loads(resp.read().decode("utf-8", errors="ignore"))
        except Exception:
            return None

        hits = data.get("hits", [])
        if not hits:
            return None
        hit = hits[0]

        thumb_base = hit.get("thumbnailUrlBase", "")
        cover = (thumb_base + "?w=400&h=600") if thumb_base else ""

        # Parse media list for background / screenshots
        background = (thumb_base + "?w=1920&h=1080") if thumb_base else ""
        screenshots = []
        for m in (hit.get("media") or []):
            if not isinstance(m, dict):
                continue
            role = (m.get("role") or "").lower()
            u = m.get("url") or m.get("asset") or ""
            if not u:
                continue
            if role in ("background", "hero", "preview") and background == (thumb_base + "?w=1920&h=1080"):
                background = u
            elif role in ("screenshot", "screen"):
                screenshots.append(u)

        genres = []
        for k in ("localizedGenres", "genres", "topCategory"):
            v = hit.get(k)
            if isinstance(v, list) and v:
                genres = [str(g) for g in v if g]
                break
            elif isinstance(v, str) and v:
                genres = [v]
                break

        cr = hit.get("contentRating")
        rating = ""
        if isinstance(cr, dict):
            rating = cr.get("name") or cr.get("value") or ""
        elif isinstance(cr, str):
            rating = cr

        return {
            "cover":       cover,
            "background":  background,
            "description": hit.get("shortDescription") or hit.get("longDescription") or "",
            "genres":      genres,
            "releaseDate": hit.get("releaseDate", ""),
            "publisher":   hit.get("publisherName", ""),
            "developer":   hit.get("publisherName", ""),
            "rating":      rating,
            "screenshots": screenshots[:6],
            "metascore":   None,
            "source":      "psn-algolia"
        }

    # ---------------------------------------------------------------- PSN REST
    def _psn_rest(self, title):
        encoded = urllib.parse.quote(title)
        url = (
            f"https://store.playstation.com/store/api/11/19/{self.language}"
            f"/{self.country}/tumbler-search/{encoded}?suggested_size=5&mode=game"
        )
        data = _safe_json(url)
        if not data:
            return None

        links = (data.get("links") or
                 data.get("data", {}).get("search", {}).get("edges", []))
        if not links:
            return None

        first = links[0]
        if isinstance(first, dict) and "node" in first:
            first = first["node"]

        images = first.get("images") or []
        cover = background = ""
        for img in (images if isinstance(images, list) else []):
            if isinstance(img, dict):
                t = (img.get("type") or "").lower()
                u = img.get("url") or img.get("src") or ""
                if not cover and "cover" in t:
                    cover = u
                if not background and "background" in t:
                    background = u
        if not cover:
            cover = _best_str(first, "image", "thumbnail", "poster")

        return {
            "cover":       cover,
            "background":  background,
            "description": first.get("description") or first.get("shortDescription") or "",
            "genres":      first.get("genres") or [],
            "releaseDate": first.get("releaseDate") or "",
            "publisher":   first.get("publisherName") or "",
            "developer":   first.get("developerName") or first.get("publisherName") or "",
            "rating":      first.get("contentRating") or "",
            "screenshots": [],
            "metascore":   None,
            "source":      "psn-rest"
        }

    # -------------------------------------------------------------------- RAWG
    def _rawg(self, title):
        encoded = urllib.parse.quote(title)
        url = self.RAWG_URL.format(q=encoded) + self.rawg_key
        data = _safe_json(url)
        if not data:
            return None
        results = data.get("results", [])
        if not results:
            return None
        g = results[0]
        cover = g.get("background_image") or ""
        genres = [x.get("name", "") for x in (g.get("genres") or []) if isinstance(x, dict)]
        rawg_tags = [t.get("name", "") for t in (g.get("tags") or []) if isinstance(t, dict) and t.get("name")]
        for tag_item in rawg_tags:
            if tag_item and tag_item not in genres:
                genres.append(tag_item)
        esrb = g.get("esrb_rating")
        rating = esrb.get("name") if isinstance(esrb, dict) else ""
        return {
            "cover":       cover,
            "background":  cover,
            "description": "",
            "genres":      genres,
            "releaseDate": g.get("released") or "",
            "publisher":   "",
            "developer":   "",
            "rating":      rating,
            "screenshots": [],
            "metascore":   g.get("metacritic"),
            "source":      "rawg"
        }

    # ------------------------------------------------------------------- Steam
    def _steam(self, title):
        encoded = urllib.parse.quote(title)
        url = f"https://store.steampowered.com/api/storesearch/?term={encoded}&l=english&cc=US"
        data = _safe_json(url)
        if not data or not data.get("items"):
            return None

        # Pick best matching item
        item = data["items"][0]
        app_id = item.get("id")
        if not app_id:
            return None

        # Standard vertical library cover art
        cover = f"https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{app_id}/library_600x900_2x.jpg"
        header = f"https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/{app_id}/header.jpg"

        # Query appdetails for rich metadata
        det_url = f"https://store.steampowered.com/api/appdetails?appids={app_id}&l=english"
        det_data = _safe_json(det_url)
        app_info = (det_data or {}).get(str(app_id), {}).get("data", {})

        description = app_info.get("short_description") or ""
        genres = [g.get("description") for g in app_info.get("genres", []) if isinstance(g, dict) and g.get("description")]
        # Also include Steam categories as tags
        categories = [c.get("description") for c in app_info.get("categories", []) if isinstance(c, dict) and c.get("description")]
        for cat in categories:
            if cat and cat not in genres:
                genres.append(cat)
        release_date = (app_info.get("release_date") or {}).get("date") or ""
        developers = app_info.get("developers") or []
        publishers = app_info.get("publishers") or []
        metascore = (app_info.get("metacritic") or {}).get("score")
        screenshots = [s.get("path_full") for s in app_info.get("screenshots", []) if isinstance(s, dict) and s.get("path_full")]

        # High-Resolution Background Selection:
        # Prefer page_bg_raw (1920x1080) -> first 1920x1080 screenshot -> background -> header
        bg_candidate = app_info.get("background_raw") or ""
        if not bg_candidate and screenshots:
            bg_candidate = screenshots[0]
        if not bg_candidate:
            bg_candidate = app_info.get("background") or header

        trailers = []
        for m in app_info.get("movies", []):
            if not isinstance(m, dict):
                continue
            # Prefer HLS for broad compatibility, then DASH, then MP4
            t_url = (
                m.get("hls_h264")
                or m.get("dash_h264")
                or m.get("dash_av1")
                or (m.get("mp4", {}) or {}).get("max")
                or (m.get("webm", {}) or {}).get("max")
                or ""
            )
            if t_url:
                trailers.append({
                    "id": m.get("id"),
                    "name": m.get("name", ""),
                    "thumbnail": m.get("thumbnail", ""),
                    "url": t_url
                })

        return {
            "cover":       cover or header,
            "background":  bg_candidate,
            "description": description,
            "genres":      genres,
            "releaseDate": release_date,
            "publisher":   publishers[0] if publishers else "",
            "developer":   developers[0] if developers else "",
            "rating":      "",
            "screenshots": screenshots[:8],
            "trailers":    trailers,
            "metascore":   metascore,
            "source":      "steam"
        }

    # ----------------------------------------------------------- PSN GraphQL
    # Playnite Universal PSN Metadata provider implementation:
    # https://github.com/XenorPLxx/playnite-metadata-psn-universal
    def _psn_graphql(self, title):
        import uuid
        search_hash = "4df6284f982e57bec70f23c77e2c219dc792eb19af7fb3d3a81767aa3f1958aa"
        search_url = "https://web.np.playstation.com/api/graphql/v1//op"

        variables = json.dumps({
            "countryCode": self.country.upper(),
            "languageCode": self.language.lower(),
            "nextCursor": "",
            "pageOffset": 0,
            "pageSize": 5,
            "searchTerm": title
        })
        extensions = json.dumps({
            "persistedQuery": {
                "version": 1,
                "sha256Hash": search_hash
            }
        })

        url = f"{search_url}?operationName=getSearchResults&variables={urllib.parse.quote(variables)}&extensions={urllib.parse.quote(extensions)}"
        headers = {
            "Accept": "application/json",
            "Content-Type": "application/json",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36",
            "Origin": "https://store.playstation.com",
            "Referer": "https://store.playstation.com/",
            "apollographql-client-name": "@sie-ppr-web-store/app",
            "apollographql-client-version": "0.113.0",
            "X-PSN-App-Ver": "@sie-ppr-web-store/app/0.113.0-",
            "X-PSN-Correlation-ID": str(uuid.uuid4()),
            "X-PSN-Request-ID": str(uuid.uuid4()),
            "X-PSN-Store-Locale-Override": f"{self.language.lower()}-{self.country.upper()}"
        }

        data = _safe_json(url, headers=headers)
        if not data:
            return None

        results = data.get("data", {}).get("universalSearch", {}).get("results", [])
        if not results:
            return None

        first = results[0]
        media_list = first.get("media") or []

        cover = ""
        background = ""
        screenshots = []

        # Roles match UniversalPSNMetadataProvider.cs:
        # MASTER, PORTRAIT_BANNER, EDITION_KEY_ART, GAMEHUB_COVER_ART
        for role in ["MASTER", "PORTRAIT_BANNER", "EDITION_KEY_ART", "GAMEHUB_COVER_ART"]:
            for m in media_list:
                if str(m.get("role", "")).upper() == role and m.get("url"):
                    cover = m["url"]
                    break
            if cover:
                break

        if not cover:
            for m in media_list:
                if m.get("url"):
                    cover = m["url"]
                    break

        for role in ["BACKGROUND", "SIXTEEN_BY_NINE_BANNER", "HERO"]:
            for m in media_list:
                if str(m.get("role", "")).upper() == role and m.get("url"):
                    background = m["url"]
                    break
            if background:
                break

        for m in media_list:
            if str(m.get("role", "")).upper() in ["SCREENSHOT", "SCREEN"] and m.get("url"):
                screenshots.append(m["url"])

        # Fetch product page if concept/product id exists for full description, publisher, genres
        description = ""
        publisher = ""
        release_date = ""
        genres = []

        item_id = first.get("id")
        item_type = str(first.get("type", "")).lower()
        route = "concept" if item_type == "concept" else "product"
        if item_id:
            page_url = f"https://store.playstation.com/{self.language.lower()}-{self.country.upper()}/{route}/{item_id}"
            page_html = _safe_get(page_url, headers=headers)
            if page_html:
                desc_m = re.search(r'data-qa="mfe-game-overview#description"[^>]*>(.*?)</div>', page_html, re.DOTALL)
                if desc_m:
                    description = re.sub(r'<[^>]+>', ' ', desc_m.group(1)).strip()
                date_m = re.search(r'"releaseDate"\s*:\s*"(\d{4}-\d{2}-\d{2})', page_html)
                if date_m:
                    release_date = date_m.group(1)
                pub_m = re.search(r'data-qa="gameInfo#releaseInformation#publisher-value"[^>]*>([^<]+)<', page_html)
                if pub_m:
                    publisher = pub_m.group(1).strip()
                genre_m = re.search(r'data-qa="gameInfo#releaseInformation#genre-value"[^>]*>([^<]+)<', page_html)
                if genre_m:
                    genres = [g.strip() for g in genre_m.group(1).split(",") if g.strip()]

        return {
            "cover":       cover,
            "background":  background or cover,
            "description": description,
            "genres":      genres,
            "releaseDate": release_date,
            "publisher":   publisher,
            "developer":   publisher,
            "rating":      "",
            "screenshots": screenshots[:6],
            "trailers":    [],
            "metascore":   None,
            "source":      "psn-store"
        }

    # ---------------------------------------------------------- public API
    def fetch(self, title):
        """Fetch metadata for a game title. Returns dict or None."""
        if not title or not title.strip():
            return None

        # Build search variations: exact title, cleaned title, base title
        variations = [title.strip()]

        # Clean common edition / DLC suffixes
        cleaned = re.sub(r'[\(（\[].*?[\)）\]]', '', title)
        cleaned = re.sub(r'(?i)\b(definitive edition|director\'s cut|directors cut|game of the year|goty|deluxe edition|digital deluxe|complete edition|enhanced edition|remastered|remaster|anniversary edition|collector\'s edition|collectors edition|\bce\b|\bdlc\b|\+.*$)\b', '', cleaned).strip()
        if cleaned and cleaned != variations[0]:
            variations.append(cleaned)

        # Before colon / dash (main title only)
        if ":" in title or " - " in title:
            base = re.split(r'[:\-–—]', title)[0].strip()
            if base and base not in variations:
                variations.append(base)

        for query in variations:
            # Priority: Steam first (most reliable, gives vertical covers + full metadata),
            # then PSN GraphQL, then Algolia, then PSN REST, then RAWG as last resort
            for strategy in (self._steam, self._psn_graphql, self._algolia, self._psn_rest, self._rawg):
                try:
                    result = strategy(query)
                    if result and (result.get("cover") or result.get("description")):
                        return result
                except Exception:
                    continue
        return None


# ---------------------------------------------------------------------------
#  Module-level helpers
# ---------------------------------------------------------------------------

_provider = None


def _get_provider(rawg_key=""):
    global _provider
    if _provider is None or rawg_key:
        _provider = PSNMetadataProvider(rawg_key=rawg_key)
    return _provider


def fetch_metadata(title, rawg_key=""):
    """Convenience: fetch metadata for a single title string."""
    return _get_provider(rawg_key).fetch(title)


if __name__ == "__main__":
    import sys
    t = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else "God of War"
    res = fetch_metadata(t)
    print(json.dumps(res, indent=2, ensure_ascii=False))

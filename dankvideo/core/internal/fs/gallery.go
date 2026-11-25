package fs

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"syscall"
	"time"
)

// fileID represents a unique device and inode identifier on POSIX systems.
type fileID struct {
	dev uint64
	ino uint64
}

// getFileID extracts device and inode numbers from os.FileInfo.
func getFileID(fi os.FileInfo) (fileID, bool) {
	if stat, ok := fi.Sys().(*syscall.Stat_t); ok {
		return fileID{dev: uint64(stat.Dev), ino: uint64(stat.Ino)}, true
	}
	return fileID{}, false
}

// VideoItem represents a single video with metadata for the video gallery.
type VideoItem struct {
	Path      string `json:"path"`
	Thumbnail string `json:"thumbnail"`
	Name      string `json:"name"`
	ModTime   int64  `json:"modTime"`
	SortTime  int64  `json:"sortTime"`
	DateGroup string `json:"dateGroup"`
	Category  string `json:"category"`
	IsVideo   bool   `json:"isVideo"`
}

// VideoGroup groups videos under a specific date header (e.g. "Today", "Yesterday").
type VideoGroup struct {
	DateGroup string      `json:"dateGroup"`
	Videos    []VideoItem `json:"videos"`
}

// VideoAlbum represents a category/folder of videos with preview thumbnails.
type VideoAlbum struct {
	Name       string   `json:"name"`
	Path       string   `json:"path"`
	IsPinned   bool     `json:"isPinned"`
	Previews   []string `json:"previews"`
	TotalCount int      `json:"totalCount"`
}

// VideoGalleryData is the payload returned to QML.
type VideoGalleryData struct {
	AllVideos  []VideoItem  `json:"allVideos"`
	Groups     []VideoGroup `json:"groups"`
	Albums     []VideoAlbum `json:"albums"`
	Categories []string     `json:"categories"`
}

// GetVideosDir returns the user's Videos directory via xdg-user-dir or fallback ~/Videos.
func GetVideosDir() string {
	if out, err := exec.Command("xdg-user-dir", "VIDEOS").Output(); err == nil {
		dir := strings.TrimSpace(string(out))
		if dir != "" && dir != "/" {
			return dir
		}
	}
	if home, err := os.UserHomeDir(); err == nil {
		return filepath.Join(home, "Videos")
	}
	return ""
}

// resolveXdgThumbnail finds the Freedesktop cached thumbnail if available.
func resolveXdgThumbnail(filePath string, thumbDir string) string {
	if thumbDir == "" {
		return ""
	}
	abs, err := filepath.Abs(filePath)
	if err != nil {
		return ""
	}
	// XDG format: "file://" + url.PathEscape(abs)
	uri := "file://" + (&url.URL{Path: abs}).EscapedPath()
	h := md5.Sum([]byte(uri))
	hashStr := hex.EncodeToString(h[:])
	fileName := hashStr + ".png"

	for _, size := range []string{"large", "normal", "x-large"} {
		cand := filepath.Join(thumbDir, size, fileName)
		if fi, err := os.Stat(cand); err == nil && !fi.IsDir() && fi.Size() > 0 {
			return cand
		}
	}
	return ""
}

func computeDateGroup(t time.Time, today, yesterday time.Time) string {
	fileDate := time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, t.Location())
	if !fileDate.Before(today) {
		return "Today"
	}
	if fileDate.Equal(yesterday) {
		return "Yesterday"
	}
	if fileDate.Year() == today.Year() {
		return t.Format("January 2")
	}
	return t.Format("January 2, 2006")
}

// canonicalPath resolves symbolic links and cleans the given path.
func canonicalPath(p string) string {
	clean := filepath.Clean(p)
	if realP, err := filepath.EvalSymlinks(clean); err == nil {
		return filepath.Clean(realP)
	}
	return clean
}

type dsearchHit struct {
	ID string `json:"id"`
}

type dsearchResult struct {
	Hits []dsearchHit `json:"hits"`
}

func tryScanWithDsearch(
	absRoot string,
	thumbDir string,
	today, yesterday time.Time,
	isExcluded func(string) bool,
	seenCanonical map[string]bool,
	seenInodes map[fileID]bool,
) ([]VideoItem, map[string]*VideoAlbum, map[string]bool, bool) {
	dsearchBin, err := exec.LookPath("dsearch")
	if err != nil {
		return nil, nil, nil, false
	}

	cmd := exec.Command(dsearchBin, "search", "", "--folder", absRoot, "--limit", "10000", "--json")
	out, err := cmd.Output()
	if err != nil {
		return nil, nil, nil, false
	}

	var res dsearchResult
	if err := json.Unmarshal(out, &res); err != nil || len(res.Hits) == 0 {
		return nil, nil, nil, false
	}

	var allVideos []VideoItem
	albumMap := make(map[string]*VideoAlbum)
	categorySet := make(map[string]bool)

	for _, hit := range res.Hits {
		p := filepath.Clean(hit.ID)
		if isExcluded(p) || !IsVideoFile(p) {
			continue
		}
		canon := canonicalPath(p)
		if seenCanonical[canon] {
			continue
		}
		fi, err := os.Stat(p)
		if err != nil || fi.IsDir() {
			continue
		}
		if id, ok := getFileID(fi); ok {
			if seenInodes[id] {
				continue
			}
			seenInodes[id] = true
		}
		if strings.HasPrefix(fi.Name(), ".") {
			continue
		}

		seenCanonical[canon] = true
		parentDir := filepath.Dir(p)
		category := "Videos"
		albumDir := absRoot
		if parentDir != absRoot {
			rel, err := filepath.Rel(absRoot, parentDir)
			if err == nil && rel != "." {
				topFolder := strings.Split(rel, string(os.PathSeparator))[0]
				category = topFolder
				albumDir = filepath.Join(absRoot, topFolder)
			} else {
				category = filepath.Base(parentDir)
				albumDir = parentDir
			}
		}

		if _, exists := albumMap[albumDir]; !exists {
			albumMap[albumDir] = &VideoAlbum{
				Name:     category,
				Path:     albumDir,
				IsPinned: false,
				Previews: []string{},
			}
		}

		thumbPath := resolveXdgThumbnail(p, thumbDir)
		modTime := fi.ModTime()
		item := VideoItem{
			Path:      p,
			Thumbnail: thumbPath,
			Name:      fi.Name(),
			ModTime:   modTime.Unix(),
			SortTime:  modTime.Unix(),
			DateGroup: computeDateGroup(modTime, today, yesterday),
			Category:  category,
			IsVideo:   true,
		}

		categorySet[category] = true
		if alb, ok := albumMap[albumDir]; ok {
			alb.TotalCount++
			if len(alb.Previews) < 4 {
				alb.Previews = append(alb.Previews, p)
			}
		}

		allVideos = append(allVideos, item)
	}

	if len(allVideos) == 0 {
		return nil, nil, nil, false
	}

	return allVideos, albumMap, categorySet, true
}

// ScanVideoGallery scans rootDir and its subdirectories (plus any extraDirs) for videos,
// ignoring any directories in excludedDirs, and organizes them into VideoGalleryData.
func ScanVideoGallery(rootDir string, excludedDirs []string, extraDirs ...string) (*VideoGalleryData, error) {
	if rootDir == "" {
		rootDir = GetVideosDir()
	}

	absRoot, err := filepath.Abs(rootDir)
	if err != nil {
		return nil, err
	}
	absRoot = filepath.Clean(absRoot)

	var canonicalExcludes []string
	for _, ex := range excludedDirs {
		trimmed := strings.TrimSpace(ex)
		if trimmed != "" {
			if abs, err := filepath.Abs(trimmed); err == nil {
				canonicalExcludes = append(canonicalExcludes, canonicalPath(abs))
			}
		}
	}

	isExcluded := func(p string) bool {
		if len(canonicalExcludes) == 0 {
			return false
		}
		canon := canonicalPath(p)
		for _, ex := range canonicalExcludes {
			if canon == ex || strings.HasPrefix(canon, ex+string(os.PathSeparator)) {
				return true
			}
		}
		return false
	}

	now := time.Now()
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	yesterday := today.AddDate(0, 0, -1)

	var allVideos []VideoItem
	albumMap := make(map[string]*VideoAlbum)
	categorySet := make(map[string]bool)
	explicitAlbums := make(map[string]bool)
	seenCanonical := make(map[string]bool)
	seenInodes := make(map[fileID]bool)

	thumbDir := ""
	if cacheDir, err := os.UserCacheDir(); err == nil {
		thumbDir = filepath.Join(cacheDir, "thumbnails")
	}

	if !isExcluded(absRoot) {
		if dsearchVideos, dsearchAlbums, dsearchCats, ok := tryScanWithDsearch(absRoot, thumbDir, today, yesterday, isExcluded, seenCanonical, seenInodes); ok {
			allVideos = dsearchVideos
			albumMap = dsearchAlbums
			categorySet = dsearchCats
		} else {
			// Walk directory tree
			_ = filepath.Walk(absRoot, func(path string, info os.FileInfo, err error) error {
				if err != nil || info == nil {
					return nil
				}
				if isExcluded(path) {
					if info.IsDir() {
						return filepath.SkipDir
					}
					return nil
				}

				name := info.Name()
				if strings.HasPrefix(name, ".") && path != absRoot {
					if info.IsDir() {
						return filepath.SkipDir
					}
					return nil
				}

				rel, relErr := filepath.Rel(absRoot, path)
				if relErr == nil {
					depth := len(strings.Split(rel, string(os.PathSeparator)))
					if info.IsDir() && depth > 5 && rel != "." {
						return filepath.SkipDir
					}
				}

				if info.IsDir() {
					if id, ok := getFileID(info); ok {
						if seenInodes[id] {
							return filepath.SkipDir
						}
						seenInodes[id] = true
					}

					if path != absRoot && filepath.Dir(path) == absRoot {
						albumName := info.Name()
						if _, exists := albumMap[path]; !exists {
							albumMap[path] = &VideoAlbum{
								Name:     albumName,
								Path:     path,
								IsPinned: false,
								Previews: []string{},
							}
						}
					}
					return nil
				}

				if !IsVideoFile(path) {
					return nil
				}

				canon := canonicalPath(path)
				if seenCanonical[canon] {
					return nil
				}
				if id, ok := getFileID(info); ok {
					if seenInodes[id] {
						return nil
					}
					seenInodes[id] = true
				}
				seenCanonical[canon] = true

				parentDir := filepath.Dir(path)
				category := "Videos"
				albumDir := absRoot
				if parentDir != absRoot {
					rel, err := filepath.Rel(absRoot, parentDir)
					if err == nil && rel != "." {
						topFolder := strings.Split(rel, string(os.PathSeparator))[0]
						category = topFolder
						albumDir = filepath.Join(absRoot, topFolder)
					} else {
						category = filepath.Base(parentDir)
						albumDir = parentDir
					}
				}

				if _, exists := albumMap[albumDir]; !exists {
					albumMap[albumDir] = &VideoAlbum{
						Name:     category,
						Path:     albumDir,
						IsPinned: false,
						Previews: []string{},
					}
				}

				thumbPath := resolveXdgThumbnail(path, thumbDir)
				modTime := info.ModTime()
				item := VideoItem{
					Path:      path,
					Thumbnail: thumbPath,
					Name:      info.Name(),
					ModTime:   modTime.Unix(),
					SortTime:  modTime.Unix(),
					DateGroup: computeDateGroup(modTime, today, yesterday),
					Category:  category,
					IsVideo:   true,
				}
				categorySet[category] = true
				if alb, ok := albumMap[albumDir]; ok {
					alb.TotalCount++
					if len(alb.Previews) < 4 {
						alb.Previews = append(alb.Previews, path)
					}
				}
				allVideos = append(allVideos, item)
				return nil
			})
		}
	}

	// Scan extra folders (user-added watched directories)
	for _, extra := range extraDirs {
		if strings.TrimSpace(extra) == "" {
			continue
		}
		absExtra, err := filepath.Abs(extra)
		if err != nil {
			continue
		}
		absExtra = filepath.Clean(absExtra)
		if isExcluded(absExtra) {
			continue
		}
		fi, err := os.Stat(absExtra)
		if err != nil || !fi.IsDir() {
			continue
		}

		explicitAlbums[absExtra] = true
		albumName := filepath.Base(absExtra)
		alb, exists := albumMap[absExtra]
		if !exists {
			alb = &VideoAlbum{
				Name:     albumName,
				Path:     absExtra,
				IsPinned: false,
				Previews: []string{},
			}
			albumMap[absExtra] = alb
		}

		seenExtraDirs := make(map[fileID]bool)

		_ = filepath.Walk(absExtra, func(path string, info os.FileInfo, err error) error {
			if err != nil || info == nil {
				return nil
			}
			if isExcluded(path) {
				if info.IsDir() {
					return filepath.SkipDir
				}
				return nil
			}

			name := info.Name()
			if strings.HasPrefix(name, ".") && path != absExtra {
				if info.IsDir() {
					return filepath.SkipDir
				}
				return nil
			}

			rel, relErr := filepath.Rel(absExtra, path)
			if relErr == nil {
				depth := len(strings.Split(rel, string(os.PathSeparator)))
				if info.IsDir() && depth > 5 && rel != "." {
					return filepath.SkipDir
				}
			}

			if info.IsDir() {
				if id, ok := getFileID(info); ok {
					if seenExtraDirs[id] {
						return filepath.SkipDir
					}
					seenExtraDirs[id] = true
				}
				return nil
			}

			if !IsVideoFile(path) {
				return nil
			}

			canon := canonicalPath(path)
			if seenCanonical[canon] {
				return nil
			}
			if id, ok := getFileID(info); ok {
				if seenInodes[id] {
					return nil
				}
				seenInodes[id] = true
			}
			seenCanonical[canon] = true

			thumbPath := resolveXdgThumbnail(path, thumbDir)
			modTime := info.ModTime()
			item := VideoItem{
				Path:      path,
				Thumbnail: thumbPath,
				Name:      info.Name(),
				ModTime:   modTime.Unix(),
				SortTime:  modTime.Unix(),
				DateGroup: computeDateGroup(modTime, today, yesterday),
				Category:  albumName,
				IsVideo:   true,
			}
			allVideos = append(allVideos, item)
			return nil
		})
	}

	// For any video that belongs to an extraDir, update its category
	for _, extra := range extraDirs {
		trimmed := strings.TrimSpace(extra)
		if trimmed == "" {
			continue
		}
		if absExtra, err := filepath.Abs(trimmed); err == nil {
			canonExtra := canonicalPath(absExtra)
			albumName := filepath.Base(absExtra)
			for i := range allVideos {
				canonImg := canonicalPath(allVideos[i].Path)
				if canonImg == canonExtra || strings.HasPrefix(canonImg, canonExtra+string(os.PathSeparator)) {
					allVideos[i].Category = albumName
				}
			}
		}
	}

	// Reconcile album counts, previews, categories
	categorySet = make(map[string]bool)
	categorySet["All"] = true
	for _, alb := range albumMap {
		alb.TotalCount = 0
		alb.Previews = []string{}
	}

	for _, vid := range allVideos {
		if vid.Category != "" {
			categorySet[vid.Category] = true
		}
		for _, alb := range albumMap {
			if alb.Name == vid.Category {
				alb.TotalCount++
				if len(alb.Previews) < 4 {
					alb.Previews = append(alb.Previews, vid.Path)
				}
				break
			}
		}
	}

	// Sort videos newest first
	sort.Slice(allVideos, func(i, j int) bool {
		if allVideos[i].SortTime != allVideos[j].SortTime {
			return allVideos[i].SortTime > allVideos[j].SortTime
		}
		return allVideos[i].ModTime > allVideos[j].ModTime
	})

	// Group by date
	groupMap := make(map[string][]VideoItem)
	var dateOrder []string
	for _, vid := range allVideos {
		grp := vid.DateGroup
		if _, exists := groupMap[grp]; !exists {
			dateOrder = append(dateOrder, grp)
		}
		groupMap[grp] = append(groupMap[grp], vid)
	}

	var groups []VideoGroup
	for _, grpName := range dateOrder {
		groups = append(groups, VideoGroup{
			DateGroup: grpName,
			Videos:    groupMap[grpName],
		})
	}

	// Build albums list
	var albums []VideoAlbum
	for pathKey, alb := range albumMap {
		if alb.TotalCount > 0 || alb.IsPinned || explicitAlbums[pathKey] {
			albums = append(albums, *alb)
		}
	}

	sort.Slice(albums, func(i, j int) bool {
		return albums[i].Name < albums[j].Name
	})

	// Categories
	var categories []string
	categories = append(categories, "All")
	var otherCats []string
	for cat := range categorySet {
		if cat != "All" {
			otherCats = append(otherCats, cat)
		}
	}
	sort.Strings(otherCats)
	categories = append(categories, otherCats...)

	return &VideoGalleryData{
		AllVideos:  allVideos,
		Groups:     groups,
		Albums:     albums,
		Categories: categories,
	}, nil
}

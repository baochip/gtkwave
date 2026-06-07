#!/usr/bin/env sh

set -e

gtkver="$(basename "$(realpath "$(pwd)")")"
tmpdir="gtkwave_${gtkver}"

bits="$(echo "$MSYSTEM" | tail -c 3)"
mingw="/mingw${bits}"

if [ -d "$tmpdir" ]; then
  rm -rf "$tmpdir"
fi

mkdir "$tmpdir"

# --- executables (curated list of which tools to ship) -----------------------
mkdir "$tmpdir"/bin
for item in $(cat ../exe.inc); do
  cp "$mingw"/bin/"$item" "$tmpdir"/bin/
done

# --- runtime libs (gdk-pixbuf loaders, gio modules, etc.) and shared data ----
mkdir "$tmpdir"/lib
for item in $(cat ../lib.inc); do
  cp -r "$mingw"/lib/"$item" "$tmpdir"/lib/
done

sharedir="gtkwave"
if [ "$gtkver" = "gtk3" ]; then
  sharedir="gtkwave-gtk3"
fi

mkdir "$tmpdir"/share
for item in applications icons "$sharedir"; do
  cp -r "$mingw"/share/"$item" "$tmpdir"/share/
done

# --- drop pixbuf loaders that crash GTK on Windows ---------------------------
# The legacy XPM loader re-enters GdkPixbuf type registration at startup and
# brings down GTK ("cannot register existing type 'GdkPixbuf'"); the Rust-based
# SVG loader is a known troublemaker for the same class of failure. gtkwave
# needs neither to view waveforms, and its icons render fine without them.
# Remove the loader DLLs and strip their entries from loaders.cache. Done BEFORE
# the ldd step below so the SVG loader's heavy dependency (librsvg) isn't pulled
# into bin. If you ever want SVG icon rendering back, delete the svg lines here.
for d in "$tmpdir"/lib/gdk-pixbuf-2.0/*/; do
  [ -d "$d/loaders" ] || continue
  rm -f "$d/loaders/libpixbufloader-xpm.dll" "$d/loaders/pixbufloader_svg.dll"
  if [ -f "$d/loaders.cache" ]; then
    awk 'BEGIN{RS="";ORS="\n\n"} !/libpixbufloader-xpm\.dll|pixbufloader_svg\.dll/' \
      "$d/loaders.cache" > "$d/loaders.cache.tmp" && mv "$d/loaders.cache.tmp" "$d/loaders.cache"
  fi
done

# --- best-effort: still honor the legacy .inc DLL lists, but skip any entry
#     that no longer exists (e.g. a bumped soname) instead of aborting. This
#     preserves any intentionally-bundled DLL that isn't in the import graph. --
for item in $(cat ../dll.inc 2>/dev/null) \
            $(cat ../"$gtkver"dll.inc 2>/dev/null) \
            $(cat ../"$bits"dll.inc 2>/dev/null); do
  if [ -e "$mingw"/bin/"$item" ]; then
    cp "$mingw"/bin/"$item" "$tmpdir"/bin/
  fi
done

# --- DLLs: discover the rest automatically with ldd -------------------------
# Walk the real dependency graph of every shipped .exe and every runtime-loaded
# plugin .dll, copying each mingw DLL it needs (transitively). Matching on
# "does this name exist under $mingw/bin" avoids depending on how ldd formats
# paths, and naturally skips Windows system DLLs (KERNEL32, etc.).
collect_dlls() {
  to_scan="$*"
  while [ -n "$to_scan" ]; do
    next=""
    for f in $to_scan; do
      names="$(ldd "$f" 2>/dev/null | awk '{print $1}' || true)"
      for base in $names; do
        if [ -e "$mingw"/bin/"$base" ] && [ ! -e "$tmpdir"/bin/"$base" ]; then
          cp "$mingw"/bin/"$base" "$tmpdir"/bin/
          next="$next $tmpdir/bin/$base"
        fi
      done
    done
    to_scan="$next"
  done
}

collect_dlls "$tmpdir"/bin/*.exe $(find "$tmpdir"/lib -name '*.dll' 2>/dev/null)

# librsvg is only used by the SVG loader we removed above; drop it if anything
# (e.g. the legacy .inc lists) pulled it into bin so it isn't dead weight.
rm -f "$tmpdir"/bin/librsvg-2-2.dll

# --- package ----------------------------------------------------------------
# Ship a .zip rather than a .tgz: Windows Explorer extracts .zip with a
# double-click ("Extract All") with no extra tooling, whereas .tgz needs a
# separate archiver most Windows users don't have. Contents sit at the archive
# root (the cd into "$tmpdir"), so extraction yields one clean folder.
( cd "$tmpdir" && zip -r -q "../../../${tmpdir}_mingw${bits}_standalone.zip" . )
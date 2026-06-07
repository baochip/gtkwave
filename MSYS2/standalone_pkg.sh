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

tar czf ../../"$tmpdir"_mingw"$bits"_standalone.tgz -C "$tmpdir" .
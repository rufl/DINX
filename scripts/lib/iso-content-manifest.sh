# Match the path column in unsquashfs -lls output, not the metadata prefix.
iso_manifest_contains_path() {
  local wanted_path=$1
  awk -v wanted="squashfs-root/$wanted_path" '
    {
      start = index($0, "squashfs-root/")
      if (start == 0) next
      actual = substr($0, start)
      link = index(actual, " -> ")
      if (link > 0) actual = substr(actual, 1, link - 1)
      if (actual == wanted || actual == wanted "/") found = 1
    }
    END { exit !found }
  '
}
# Match a package's metadata directory without matching packages that share its prefix.
iso_manifest_contains_package() {
  local wanted_package=$1
  awk -v wanted="$wanted_package" '
    {
      start = index($0, "squashfs-root/")
      if (start == 0) next
      actual = substr($0, start)
      base = "squashfs-root/var/lib/pacman/local/"
      if (index(actual, base) != 1) next
      entry = substr(actual, length(base) + 1)
      slash = index(entry, "/")
      if (slash == 0) next
      package_dir = substr(entry, 1, slash - 1)
      prefix = wanted "-"
      if (index(package_dir, prefix) != 1) next
      version = substr(package_dir, length(prefix) + 1)
      if (version ~ /^[0-9]/) found = 1
    }
    END { exit !found }
  '
}

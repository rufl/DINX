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

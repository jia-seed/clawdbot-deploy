#!/bin/bash

for md in *.md; do
  name=$(basename "$md" .md)
  echo "<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<title>$name</title>
<style>
body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 700px; margin: 40px auto; padding: 20px; line-height: 1.6; }
h1 { border-bottom: 2px solid #000; padding-bottom: 10px; }
h2 { margin-top: 40px; color: #333; }
h3 { color: #555; }
code { background: #f4f4f4; padding: 2px 6px; border-radius: 3px; }
pre { background: #f4f4f4; padding: 15px; border-radius: 5px; overflow-x: auto; }
pre code { background: none; padding: 0; }
blockquote { border-left: 4px solid #ddd; margin: 0; padding-left: 20px; color: #666; }
hr { border: none; border-top: 1px solid #eee; margin: 40px 0; }
</style>
</head>
<body>" > "${name}.html"
  # Simple markdown to html conversion
  sed 's/^# \(.*\)$/<h1>\1<\/h1>/g; s/^## \(.*\)$/<h2>\1<\/h2>/g; s/^### \(.*\)$/<h3>\1<\/h3>/g; s/^---$/<hr>/g; s/^\*\*\(.*\)\*\*$/<strong>\1<\/strong>/g; s/^- \(.*\)$/<li>\1<\/li>/g; s/^```.*/<pre><code>/g; s/^```/<\/code><\/pre>/g; s/^$/<p><\/p>/g' "$md" >> "${name}.html"
  echo "</body></html>" >> "${name}.html"
done

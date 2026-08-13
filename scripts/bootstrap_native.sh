#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$repo_root/third_party"
if [ ! -d "$repo_root/third_party/whisper.cpp/.git" ]; then
  git clone --depth 1 https://github.com/ggerganov/whisper.cpp.git "$repo_root/third_party/whisper.cpp"
fi
echo "whisper.cpp 준비 완료: $repo_root/third_party/whisper.cpp"

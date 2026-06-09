#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RENDERER="$ROOT_DIR/Sources/LightMDReader/MarkdownRenderer.swift"
MUYA_BUNDLE="$ROOT_DIR/Assets/Muya/lightmd-muya.bundle.js"

if grep -q '<script src=' "$RENDERER"; then
  echo "FAIL: MarkdownRenderer still emits an external editor script."
  exit 1
fi

if ! grep -q 'window.LightMDMuya' "$MUYA_BUNDLE"; then
  echo "FAIL: bundled Muya editor does not expose window.LightMDMuya."
  exit 1
fi

echo "PASS: editor script is embedded for unsaved documents."

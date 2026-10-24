.pragma library

// IconDatabase.js — Portable Freedesktop icon resolver for NerveCenter Launchpad.
// Dynamic theme indexing is performed at runtime by icon_scanner.py.

var FALLBACK_THEMES = [
    "System Default", "Tela", "Tela-circle", "Fluent", "Win11-black",
    "kora", "Deepin2022-Dark", "breeze", "breeze-dark", "Adwaita"
];

function getThemesList() {
    return FALLBACK_THEMES;
}

function resolveIcon(themeName, iconName) {
    if (!iconName) return "";
    if (iconName.charAt(0) === "/") return "file://" + iconName;
    return iconName;
}

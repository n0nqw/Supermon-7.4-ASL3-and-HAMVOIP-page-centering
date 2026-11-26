#!/bin/bash
# Supermon 7.4 page-centering script for HamVoIP / ASL
# Auto-detects Supermon location, centers content including footer,
# full backup/rollback support.

set -euo pipefail

MARKER="/* BEGIN Supermon page-centering (managed by center-supermon.sh) */"
END_MARKER="/* END Supermon page-centering (managed by center-supermon.sh) */"

usage() {
    cat <<'EOF'
Usage:
  sudo ./center-supermon.sh apply
  sudo ./center-supermon.sh rollback /path/to/supermon.css.backup

The apply command creates a timestamped backup before changing the CSS.
The rollback command restores a backup you specify.
EOF
}

if [[ "${EUID}" -ne 0 ]]; then
    echo "Please run this script as root (for example: sudo $0 apply)." >&2
    exit 1
fi

# Auto-detect Supermon directory
if [[ -d /srv/http/supermon ]]; then
    SUPERMON_DIR="/srv/http/supermon"
elif [[ -d /var/www/html/supermon ]]; then
    SUPERMON_DIR="/var/www/html/supermon"
else
    echo "ERROR: Could not find Supermon directory." >&2
    echo "Looked in /srv/http/supermon and /var/www/html/supermon" >&2
    exit 1
fi

CSS="$SUPERMON_DIR/supermon.css"

if [[ ! -f "$CSS" ]]; then
    echo "ERROR: CSS file not found: $CSS" >&2
    exit 1
fi

ACTION="${1:-apply}"

case "$ACTION" in
    apply)
        BACKUP="${CSS}.before_centering_$(date +%Y%m%d_%H%M%S)"
        cp -a "$CSS" "$BACKUP"
        TMP="$(mktemp)"
        trap 'rm -f "$TMP"' EXIT

        # Remove a previously managed block if present
        awk -v start="$MARKER" -v finish="$END_MARKER" '
            $0 == start { skip=1; next }
            $0 == finish { skip=0; next }
            !skip { print }
        ' "$CSS" > "$TMP"

        cat >> "$TMP" <<'CSSRULES'

/* BEGIN Supermon page-centering (managed by center-supermon.sh) */
/* Center main content containers */
body {
    text-align: center;
}

#connect_form,
.connect_form,
form[name="connect"] {
    width: 100%;
    max-width: 900px;
    margin: 0 auto 15px auto;
    text-align: center;
    box-sizing: border-box;
}

/* Center node tables and grids */
table.gridtable,
table.nodeTable,
.gridtable {
    margin: 10px auto !important;
    text-align: center;
}

/* Center status / utility blocks */
#cpustats,
#aststatus,
.aststatus,
#weather,
.weather,
p.status,
div.status {
    text-align: center;
    margin-left: auto;
    margin-right: auto;
}

/* Center login header */
#login-header,
.login-header {
    position: relative;
    left: auto !important;
    right: auto !important;
    width: 100%;
    max-width: 900px;
    margin: 0 auto;
    text-align: center;
    box-sizing: border-box;
}

/* Center common button groups */
.button-group,
div.buttons,
input[type="submit"],
button {
    margin-left: auto;
    margin-right: auto;
}

/* Center the footer ("System maintained by...") */
#footer,
#footer p,
.footer {
    text-align: center !important;
    width: 100%;
    margin: 15px auto 5px auto;
    box-sizing: border-box;
}

/* Keep menus left-aligned if desired (uncomment to force) */
/*
ul.menu, #menu, .menu {
    text-align: left;
}
*/
/* END Supermon page-centering (managed by center-supermon.sh) */
CSSRULES

        # Verify the managed block exists and the file is nonempty
        grep -Fq "$MARKER" "$TMP"
        grep -Fq "$END_MARKER" "$TMP"
        [[ -s "$TMP" ]]

        cat "$TMP" > "$CSS"
        chmod --reference="$BACKUP" "$CSS"
        chown --reference="$BACKUP" "$CSS"

        echo "Supermon centering CSS applied."
        echo "Supermon directory: $SUPERMON_DIR"
        echo "Backup: $BACKUP"
        echo "Refresh Supermon with Ctrl+F5."
        ;;
    rollback)
        if [[ -z "${2:-}" || ! -f "${2:-}" ]]; then
            echo "ERROR: provide an existing backup file to restore." >&2
            usage
            exit 1
        fi
        cp -a "$2" "$CSS"
        echo "Restored $CSS from $2"
        echo "Refresh Supermon with Ctrl+F5."
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage >&2
        exit 1
        ;;
esac

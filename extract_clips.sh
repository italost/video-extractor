set -euo pipefail

FFMPEG="${FFMPEG:-/opt/homebrew/bin/ffmpeg}"

declare -A COUNTERS

make_unique_name() {
  local name="$1"

  local base ext
  if [[ "$name" == *.* ]]; then
    base="${name%.*}"
    ext=".${name##*.}"
  else
    base="$name"
    ext=""
  fi

  COUNTERS["$name"]=$(( ${COUNTERS["$name"]:-0} + 1 ))
  local n="${COUNTERS["$name"]}"

  # Set a global variable instead of echoing
  printf -v UNIQUE_NAME "%s_%02d%s" "$base" "$n" "$ext"
}

to_hhmm() {
  local t="$1"
  echo "${t:0:2}:${t:2:2}"
}

# Converts a 4-digit time like 0130 to a number that can be compared (01:30 -> 90)
to_seconds() {
  local t="$1"
  echo $(( 10#${t:0:2} * 60 + 10#${t:2:2} ))
}


## Input
dirname=$1
csv_input=$2
## ---

done_count=0
skipped_count=0
error_count=0
row=2   # the two header lines are read below, so the first data row is row 3

# Prints one error line and counts it. Row numbers match the spreadsheet/CSV line.
row_error() {
  echo "ERROR row $row: $*" >&2
  error_count=$(( error_count + 1 ))
}

{
  read
  read
  while IFS=',' read -r check link video game camera start end vr code quality private jersey; do
    row=$(( row + 1 ))

    start_hhmm=$(to_hhmm "$start")
    end_hhmm=$(to_hhmm "$end")
    code_prefix="${code%% -*}"
    quality_prefix="${quality%% -*}"

    if [[ "$private" != "-" ]]; then
      private_suffix="_${private}"
    else
      private_suffix=""
    fi

    jersey=$(printf '%s' "$jersey" | tr -d '\r\n')
    if [[ "$jersey" != "-" ]]; then
      jersey_suffix="_jersey${jersey}"
    else
      jersey_suffix=""
    fi

    out_name=${vr}_${code_prefix}_${quality_prefix}${private_suffix}${jersey_suffix}

    make_unique_name "$out_name"
    out_name="$UNIQUE_NAME.mp4"

    if [[ "$check" != "FALSE" ]]; then
      skipped_count=$(( skipped_count + 1 ))
      continue
    fi

    video_input="${dirname}/${video}"

    # --- Validation: report the problem and move on to the next row ---
    if [[ ! -f "$video_input" ]]; then
      row_error "input file not found: $video_input"
      continue
    fi

    if [[ ! "$start" =~ ^[0-9]{4}$ || ! "$end" =~ ^[0-9]{4}$ ]]; then
      row_error "start/end must be 4 digits (got start='$start', end='$end')"
      continue
    fi

    if (( $(to_seconds "$start") >= $(to_seconds "$end") )); then
      row_error "start ($start_hhmm) is not before end ($end_hhmm) for $video"
      continue
    fi

    # --- Extract ---
    echo "Extracting row $row: $game - $camera [$start_hhmm -> $end_hhmm] -> $out_name"
    # -nostdin stops ffmpeg from swallowing the rest of the CSV;
    # -loglevel error prints only real problems.
    if ! ffmpeg_err=$("$FFMPEG" -nostdin -hide_banner -loglevel error -nostats \
          -ss "$start_hhmm" -to "$end_hhmm" -i "$video_input" -c copy \
          "${dirname}/${out_name}" 2>&1); then
      row_error "ffmpeg failed for $out_name: ${ffmpeg_err##*$'\n'}"
      continue
    fi
    done_count=$(( done_count + 1 ))
  done
} < "$csv_input"

echo
echo "Done: $done_count extracted, $skipped_count skipped (check != FALSE), $error_count errors"
if (( error_count > 0 )); then
  exit 1
fi

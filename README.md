# video-extractor

Bash script (written for a macOS Automator "Run Shell Script" action) that cuts video clips with ffmpeg based on rows in a CSV spreadsheet.

## Usage

```
extract_clips.sh <video_folder> <csv_file>
```

- Rows with `check` set to `FALSE` are extracted; other rows are skipped.
- Start and end times are 4 digits (`0130`), converted to `01:30` for ffmpeg.
- Requires ffmpeg (default `/opt/homebrew/bin/ffmpeg`; override with the `FFMPEG` environment variable).

## Error reporting

Each problem prints one line and the run continues with the next row:

- `ERROR row N: input file not found: <path>`
- `ERROR row N: start (02:00) is not before end (01:30) for <file>`
- `ERROR row N: start/end must be 4 digits ...`
- `ERROR row N: ffmpeg failed ...`

A summary line is printed at the end, and the script exits non-zero if any row failed.

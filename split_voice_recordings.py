import subprocess
import os
import re
import sys
import zipfile

def get_duration(input_file):
    result = subprocess.run(
        ["ffprobe", "-v", "quiet", "-print_format", "json", "-show_streams", input_file],
        capture_output=True, text=True
    )
    for line in result.stdout.split("\n"):
        if '"duration"' in line:
            return float(line.split(":")[1].strip().strip('",'))
    return None

def detect_silences(input_file, noise="-30dB", duration=0.1):
    result = subprocess.run(
        ["ffmpeg", "-i", input_file,
         "-af", f"silencedetect=noise={noise}:d={duration}",
         "-f", "null", "-"],
        capture_output=True, text=True
    )
    output = result.stderr
    starts = [float(x) for x in re.findall(r"silence_start: (\S+)", output)]
    ends   = [float(x) for x in re.findall(r"silence_end: (\S+)", output)]
    return list(zip(starts, ends[:len(starts)]))

def merge_silences(silences):
    silences = sorted(silences)
    merged = []
    for s, e in silences:
        if merged and s <= merged[-1][1]:
            merged[-1] = (merged[-1][0], max(merged[-1][1], e))
        else:
            merged.append([s, e])
    return merged

def get_speech_segments(merged_silences, total_duration, min_duration=0.1):
    segments = []
    prev_end = 0.0
    for s, e in merged_silences:
        if s > prev_end + 0.05:
            segments.append((prev_end, s))
        prev_end = e
    if prev_end < total_duration - 0.05:
        segments.append((prev_end, total_duration))
    return [(s, e) for s, e in segments if (e - s) >= min_duration]

def cut_segments(input_file, segments, output_dir, total_duration, padding=0.05):
    os.makedirs(output_dir, exist_ok=True)
    for idx, (start, end) in enumerate(segments):
        ps = max(0, start - padding)
        pe = min(total_duration, end + padding)
        out_file = os.path.join(output_dir, f"word_{idx+1:03d}.mp4")
        subprocess.run(
            ["ffmpeg", "-y", "-i", input_file,
             "-ss", str(ps), "-t", str(pe - ps),
             "-acodec", "copy", "-vn", out_file],
            capture_output=True
        )
        print(f"  Created: word_{idx+1:03d}.mp4  ({start:.3f}s – {end:.3f}s)")

def zip_clips(output_dir, zip_path):
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for fname in sorted(os.listdir(output_dir)):
            if fname.endswith(".mp4"):
                zf.write(os.path.join(output_dir, fname), fname)
    print(f"  Zipped: {zip_path}")

def split_audio(input_file, output_dir=None, noise="-30dB", silence_duration=0.1):
    if not os.path.exists(input_file):
        print(f"File not found: {input_file}")
        return

    base = os.path.splitext(os.path.basename(input_file))[0]
    if output_dir is None:
        output_dir = f"{base}_clips"

    zip_path = f"{base}_word_clips.zip"

    print(f"\nProcessing: {input_file}")
    total_duration = get_duration(input_file)
    print(f"  Duration: {total_duration:.2f}s")

    silences = detect_silences(input_file, noise, silence_duration)
    merged   = merge_silences(silences)
    segments = get_speech_segments(merged, total_duration)

    print(f"  Found {len(segments)} speech segments")
    cut_segments(input_file, segments, output_dir, total_duration)

    print(f"\nZipping clips...")
    zip_clips(output_dir, zip_path)
    print(f"\nDone! ZIP saved to: {zip_path}")

# ── Entry point ──────────────────────────────────────────────────────────────
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python split_audio.py <audio_file> [output_folder]")
        print("Example: python split_audio.py recording.mp3")
        print("Example: python split_audio.py recording.mp3 my_clips")
    else:
        input_file = sys.argv[1]
        output_dir = sys.argv[2] if len(sys.argv) > 2 else None
        split_audio(input_file, output_dir)
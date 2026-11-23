import argparse
import csv
import os
import subprocess
import tempfile
import time
import unicodedata
import wave
from pathlib import Path

os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
os.environ.setdefault("HF_HUB_OFFLINE", "1")

import numpy as np
import torch
from peft import PeftModel
from transformers import WhisperForConditionalGeneration, WhisperProcessor


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATASET = Path.home() / "Desktop" / "dataset words"
DEFAULT_OUTPUT = Path(__file__).resolve().parent / "results.csv"
ADAPTER_PATH = ROOT / "whisper-kids-speech-model" / "whisper-kids-speech"
BASE_MODEL = "openai/whisper-medium"
SUPPORTED_AUDIO = {".mp3", ".mp4", ".mpeg", ".wav", ".m4a", ".webm", ".ogg"}
SAMPLE_RATE = 16000
CHUNK_SECONDS = 15
OVERLAP_SECONDS = 1


def normalize_text(text):
    normalized = unicodedata.normalize("NFKC", text).casefold()
    return "".join(character for character in normalized if character.isalnum())


def convert_to_wav(input_path, output_path):
    command = [
        "ffmpeg", "-y", "-i", str(input_path),
        "-ar", str(SAMPLE_RATE), "-ac", "1", "-acodec", "pcm_s16le",
        "-af", "aresample=resampler=soxr", str(output_path),
    ]
    result = subprocess.run(
        command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True
    )
    if result.returncode == 0:
        return

    fallback_command = command.copy()
    fallback_command[fallback_command.index("-af"):fallback_command.index("-af") + 2] = []
    fallback = subprocess.run(
        fallback_command, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True
    )
    if fallback.returncode != 0:
        raise RuntimeError(fallback.stderr.strip() or result.stderr.strip())


class DatasetTranscriber:
    def __init__(self):
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        dtype = torch.float16 if self.device == "cuda" else torch.float32
        print(f"Loading {BASE_MODEL} and the project kids-speech adapter on {self.device}...")
        self.processor = WhisperProcessor.from_pretrained(
            BASE_MODEL, local_files_only=True
        )
        base_model = WhisperForConditionalGeneration.from_pretrained(
            BASE_MODEL, torch_dtype=dtype, local_files_only=True
        )
        self.model = PeftModel.from_pretrained(
            base_model, str(ADAPTER_PATH), local_files_only=True
        ).to(self.device)
        self.model.eval()
        self.decoder_ids = self.processor.get_decoder_prompt_ids(
            language="en", task="transcribe"
        )
        print("Model ready.")

    def transcribe(self, audio_path):
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temporary:
            wav_path = Path(temporary.name)
        try:
            convert_to_wav(audio_path, wav_path)
            with wave.open(str(wav_path), "rb") as audio:
                if (
                    audio.getnchannels() != 1
                    or audio.getframerate() != SAMPLE_RATE
                    or audio.getsampwidth() != 2
                ):
                    raise ValueError("Converted audio is not 16 kHz mono 16-bit PCM")
                waveform = np.frombuffer(
                    audio.readframes(audio.getnframes()), dtype="<i2"
                ).astype(np.float32) / 32768.0
        finally:
            wav_path.unlink(missing_ok=True)

        chunk_size = CHUNK_SECONDS * SAMPLE_RATE
        step_size = (CHUNK_SECONDS - OVERLAP_SECONDS) * SAMPLE_RATE
        chunks = (
            [waveform]
            if len(waveform) <= chunk_size
            else (waveform[start:start + chunk_size] for start in range(0, len(waveform), step_size))
        )

        transcripts = []
        for chunk in chunks:
            inputs = self.processor(
                chunk, sampling_rate=SAMPLE_RATE, return_tensors="pt"
            )
            input_features = inputs.input_features.to(self.device)
            with torch.no_grad():
                predicted_ids = self.model.generate(
                    input_features, forced_decoder_ids=self.decoder_ids
                )
            transcript = self.processor.batch_decode(
                predicted_ids, skip_special_tokens=True
            )[0].strip()
            if transcript:
                transcripts.append(transcript)
        return " ".join(transcripts).strip()


def collect_audio_files(dataset_path):
    return [
        (label_dir.name, audio_path)
        for label_dir in sorted(dataset_path.iterdir())
        if label_dir.is_dir()
        for audio_path in sorted(label_dir.rglob("*"))
        if audio_path.is_file() and audio_path.suffix.casefold() in SUPPORTED_AUDIO
    ]


def evaluate(dataset_path, output_path, limit=None, resume=False):
    if not dataset_path.is_dir():
        raise FileNotFoundError(f"Dataset folder not found: {dataset_path}")
    if not ADAPTER_PATH.is_dir():
        raise FileNotFoundError(f"Whisper kids-speech adapter not found: {ADAPTER_PATH}")

    files = collect_audio_files(dataset_path)
    if limit is not None:
        files = files[:limit]
    if not files:
        raise ValueError(f"No supported audio files found under {dataset_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    completed = {}
    if resume and output_path.exists():
        with output_path.open("r", newline="", encoding="utf-8-sig") as results_file:
            for row in csv.DictReader(results_file):
                if row.get("status") != "ok":
                    continue
                relative_path = row.get("audio_file", "")
                expected_label = row.get("expected_label", "")
                if relative_path and expected_label:
                    completed[(expected_label, relative_path)] = row

    pending_files = [
        (expected, audio_path)
        for expected, audio_path in files
        if (expected, str(audio_path.relative_to(dataset_path))) not in completed
    ]
    transcriber = DatasetTranscriber()
    correct_count = sum(
        row.get("exact_match", "").casefold() == "true"
        for row in completed.values()
    )
    error_count = 0
    started_at = time.monotonic()
    columns = [
        "expected_label", "audio_file", "transcript", "exact_match", "status", "error"
    ]
    print(
        f"Evaluating {len(pending_files)} of {len(files)} audio files "
        f"from {dataset_path} ({len(completed)} already complete)"
    )

    output_exists = resume and output_path.exists()
    with output_path.open(
        "a" if output_exists else "w", newline="", encoding="utf-8-sig"
    ) as results_file:
        writer = csv.DictWriter(results_file, fieldnames=columns)
        if not output_exists:
            writer.writeheader()
        results_file.flush()

        for index, (expected, audio_path) in enumerate(pending_files, start=1):
            transcript = ""
            error = ""
            try:
                transcript = transcriber.transcribe(audio_path)
                is_correct = bool(
                    normalize_text(expected)
                    and normalize_text(expected) == normalize_text(transcript)
                )
                status = "ok"
            except Exception as exc:
                is_correct = False
                status = "error"
                error = f"{type(exc).__name__}: {exc}"
                error_count += 1

            correct_count += int(is_correct)
            writer.writerow({
                "expected_label": expected,
                "audio_file": str(audio_path.relative_to(dataset_path)),
                "transcript": transcript,
                "exact_match": is_correct,
                "status": status,
                "error": error,
            })
            results_file.flush()

            if not is_correct:
                detail = f" ERROR: {error}" if error else ""
                print(
                    f"[{index}/{len(pending_files)}] WRONG | {expected} -> "
                    f"{transcript or '<empty>'}{detail}"
                )
            elif index % 25 == 0 or index == len(pending_files):
                print(f"[{index}/{len(pending_files)}] processed")

    wrong_count = len(files) - correct_count
    accuracy = 100 * correct_count / len(files)
    elapsed = time.monotonic() - started_at
    print("\n=== Dataset transcription results ===")
    print(f"Total files: {len(files)}")
    print(f"Correct: {correct_count}")
    print(f"Wrong: {wrong_count}")
    print(f"Processing errors (included in wrong): {error_count}")
    print(f"Exact-match accuracy: {accuracy:.2f}%")
    print(f"Elapsed: {elapsed / 60:.1f} minutes")
    print(f"Per-file results: {output_path}")


def main():
    parser = argparse.ArgumentParser(
        description="Evaluate the project Whisper kids-speech model on labeled audio folders."
    )
    parser.add_argument("--dataset", type=Path, default=DEFAULT_DATASET)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--limit", type=int, help="Evaluate only the first N files (useful for a quick check)."
    )
    parser.add_argument(
        "--resume", action="store_true",
        help="Reuse successful results already in the output CSV and retry unfinished files.",
    )
    args = parser.parse_args()
    if args.limit is not None and args.limit < 1:
        parser.error("--limit must be greater than zero")
    evaluate(args.dataset.resolve(), args.output.resolve(), args.limit, args.resume)


if __name__ == "__main__":
    main()

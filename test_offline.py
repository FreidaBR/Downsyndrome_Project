# =========================================
# test_whisper.py
# Tests Whisper STT with chunking for long audio
# Run: python test_whisper.py
#   or: python test_whisper.py path/to/your_audio.wav
# =========================================

import sys
import os
import time
import torch
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample
from transformers import WhisperProcessor, WhisperForConditionalGeneration

# -----------------------------------------
# CONFIG
# -----------------------------------------

WHISPER_MODEL_PATH = "models/FINAL_WHISPER_MODEL_APRIL/FINAL_WHISPER_MODEL_APRIL"
DEFAULT_TEST_AUDIO  = "test_audio/ivan.wav"
CHUNK_SECONDS       = 30        # Whisper's max input size
OVERLAP_SECONDS     = 1         # Small overlap to avoid cutting words mid-sentence

# -----------------------------------------
# LOAD MODEL
# -----------------------------------------

print("\n" + "="*50)
print("  WHISPER MODEL TEST")
print("="*50)

print(f"\n[1/2] Loading Whisper from:\n      {WHISPER_MODEL_PATH}")
t0 = time.time()

processor    = WhisperProcessor.from_pretrained(WHISPER_MODEL_PATH)
speech_model = WhisperForConditionalGeneration.from_pretrained(WHISPER_MODEL_PATH)
speech_model.eval()

print(f"      ✅ Loaded in {time.time() - t0:.1f}s")

# -----------------------------------------
# TRANSCRIBE WITH CHUNKING
# -----------------------------------------

def transcribe(audio_file):
    print(f"\n[2/2] Transcribing: {audio_file}")

    # Load WAV
    sr_original, waveform = wavfile.read(audio_file)
    print(f"      Sample rate : {sr_original} Hz")
    print(f"      Duration    : {len(waveform) / sr_original:.2f}s")
    print(f"      dtype       : {waveform.dtype}")

    # Normalize to float32
    if waveform.dtype != np.float32:
        waveform = waveform.astype(np.float32) / np.iinfo(waveform.dtype).max

    # Mono
    if len(waveform.shape) > 1:
        waveform = waveform.mean(axis=1)
        print("      Converted stereo → mono")

    # Resample to 16kHz
    if sr_original != 16000:
        num_samples = int(len(waveform) * 16000 / sr_original)
        waveform = resample(waveform, num_samples)
        print(f"      Resampled {sr_original}Hz → 16000Hz")

    sr            = 16000
    chunk_size    = CHUNK_SECONDS * sr
    overlap_size  = OVERLAP_SECONDS * sr
    total_samples = len(waveform)
    duration      = total_samples / sr

    # Short audio — no chunking needed
    if duration <= CHUNK_SECONDS:
        print("      Audio is short — transcribing directly (no chunking needed)")
        chunks = [waveform]
    else:
        print(f"      Audio is {duration:.1f}s — splitting into {CHUNK_SECONDS}s chunks (overlap: {OVERLAP_SECONDS}s)")
        chunks = []
        start = 0
        while start < total_samples:
            end = min(start + chunk_size, total_samples)
            chunks.append(waveform[start:end])
            if end == total_samples:
                break
            start += chunk_size - overlap_size  # step back slightly to avoid cutting words

    print(f"      Total chunks : {len(chunks)}")
    print()

    # Transcribe each chunk
    full_transcript = []
    t1 = time.time()

    for i, chunk in enumerate(chunks):
        chunk_start_sec = i * (CHUNK_SECONDS - OVERLAP_SECONDS)
        chunk_end_sec   = chunk_start_sec + len(chunk) / sr
        print(f"      Chunk {i+1}/{len(chunks)}  [{chunk_start_sec:.0f}s → {chunk_end_sec:.0f}s] ...", end=" ", flush=True)

        inputs = processor(chunk, sampling_rate=sr, return_tensors="pt")

        with torch.no_grad():
            predicted_ids = speech_model.generate(
                inputs.input_features,
                language="en"
            )

        chunk_text = processor.batch_decode(predicted_ids, skip_special_tokens=True)[0].strip()
        print(f'"{chunk_text}"')

        if chunk_text:  # skip empty chunks (silence)
            full_transcript.append(chunk_text)

    total_time = time.time() - t1
    print(f"\n      ✅ Total inference time: {total_time:.2f}s")

    return " ".join(full_transcript).strip()

# -----------------------------------------
# MAIN
# -----------------------------------------

audio_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_TEST_AUDIO

if not os.path.exists(audio_path):
    print(f"\n❌ Audio file not found: {audio_path}")
    print("   Usage: python test_whisper.py path/to/audio.wav")
    sys.exit(1)

result = transcribe(audio_path)

print("\n" + "="*50)
print("  FULL TRANSCRIPT")
print("="*50)
print(f"\n  {result}\n")
print("="*50 + "\n")
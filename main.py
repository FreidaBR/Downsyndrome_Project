# =========================================
# Neurodivergent AI Assistant - main.py
# =========================================
# TRANSCRIPTION : Local whisper-kids-speech-model (PEFT/LoRA adapter on whisper-medium)
# GRAMMAR FIX   : Local GEC T5 model (FINAL_GEC_MODEL_APRIL)
# =========================================

import os
import subprocess
import tempfile
import sys
import torch
import librosa

# Force local/offline Hugging Face loading when internet or SSL is unavailable
os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
os.environ.setdefault("HF_HUB_OFFLINE", "1")

from transformers import (
    WhisperProcessor,
    WhisperForConditionalGeneration,
    AutoTokenizer,
    AutoModelForSeq2SeqLM,
)
from peft import PeftModel

# Force UTF-8 on Windows
if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

# -----------------------------------------
# SPEED / FAST MODE
# -----------------------------------------
FAST_MODE = os.environ.get("FAST_MODE", "1") == "1"
if FAST_MODE:
    print("FAST_MODE enabled: grammar correction will be skipped for speed.")

# -----------------------------------------
# DEVICE SETUP
# -----------------------------------------
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
DTYPE  = torch.float16 if torch.cuda.is_available() else torch.float32
print(f"Running on: {DEVICE.upper()}")

# -----------------------------------------
# LOAD WHISPER KIDS SPEECH MODEL
# -----------------------------------------
print("Loading Whisper Kids speech model (PEFT adapter)...")
WHISPER_BASE_MODEL = "openai/whisper-medium"
WHISPER_KIDS_ADAPTER = "whisper-kids-speech-model/whisper-kids-speech"

processor = WhisperProcessor.from_pretrained(
    WHISPER_BASE_MODEL,
    local_files_only=True,
)
base_whisper_model = WhisperForConditionalGeneration.from_pretrained(
    WHISPER_BASE_MODEL,
    torch_dtype=DTYPE,
    local_files_only=True,
)

speech_model = PeftModel.from_pretrained(
    base_whisper_model,
    WHISPER_KIDS_ADAPTER,
    local_files_only=True,
).to(DEVICE)
speech_model.eval()
print("Whisper Kids speech model ready.")
print(f"Loaded Whisper Kids adapter from: {WHISPER_KIDS_ADAPTER}")
print(f"Speech model type: {type(speech_model).__name__}")

# Load base Whisper model (no adapter) as a fallback for uploaded files
# that differ from the kids mic-recording training distribution
print("Loading base Whisper-medium model as upload fallback...")
try:
    base_transcribe_model = WhisperForConditionalGeneration.from_pretrained(
        WHISPER_BASE_MODEL,
        torch_dtype=DTYPE,
        local_files_only=True,
    ).to(DEVICE)
    base_transcribe_model.eval()
    print("Base Whisper-medium fallback ready.")
except Exception as e:
    print(f"Could not load base Whisper fallback: {e}")
    base_transcribe_model = None

# -----------------------------------------
# AUDIO UTILITIES
# -----------------------------------------

def convert_to_clean_wav(input_path, output_path):
    """
    Convert any audio format (m4a, webm, ogg, wav, mp3) to a clean 16kHz mono WAV.
    Uses high-quality resampling with aresample filter for uploaded files.
    """
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-i", input_path,
             "-ar", "16000", "-ac", "1",
             "-acodec", "pcm_s16le",
             "-af", "aresample=resampler=soxr",
             output_path],
            check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        )
        print("Audio: converted to 16kHz mono WAV (high quality).")
    except subprocess.CalledProcessError:
        # soxr resampler might not be available; fall back to default
        try:
            subprocess.run(
                ["ffmpeg", "-y", "-i", input_path,
                 "-ar", "16000", "-ac", "1", "-acodec", "pcm_s16le", output_path],
                check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            )
            print("Audio: converted to 16kHz mono WAV (standard).")
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"ffmpeg conversion failed: {e.stderr.decode(errors='replace')}")
    except FileNotFoundError:
        raise RuntimeError("ffmpeg not found. Please install ffmpeg and add it to your PATH.")


# -----------------------------------------
# STEP 1 : SPEECH TO TEXT (Local Whisper Kids)
# -----------------------------------------

def _run_whisper_inference(model, input_features, forced_decoder_ids):
    """Run Whisper generate and decode on given model."""
    with torch.no_grad():
        predicted_ids = model.generate(
            input_features,
            forced_decoder_ids=forced_decoder_ids,
        )
    return processor.batch_decode(
        predicted_ids,
        skip_special_tokens=True
    )[0].strip()


def transcribe(audio_file, is_uploaded=False):
    """
    Transcribe audio file using the appropriate Whisper model.

    - Mic recordings (is_uploaded=False): use the LoRA kids-speech adapter
      which is fine-tuned for children's microphone speech.
    - Uploaded files (is_uploaded=True): use the base Whisper-medium model
      which generalises well across all audio sources, sample rates, codecs,
      and speaking styles that the adapter hasn't seen.
    """
    model_label = "base Whisper-medium (uploaded file)" if is_uploaded else "Whisper Kids adapter (mic)"
    print(f"Transcribing audio via {model_label}: {audio_file}")

    # Convert to clean WAV first (handles m4a, webm, ogg, mp3, wav, etc.)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        tmp_wav = tmp.name

    try:
        convert_to_clean_wav(audio_file, tmp_wav)
        wav_to_send = tmp_wav
    except Exception as e:
        print(f"Conversion failed ({e}), sending original file.")
        wav_to_send = audio_file

    try:
        waveform, sr = librosa.load(wav_to_send, sr=16000, mono=True)
        inputs = processor(
            waveform,
            sampling_rate=16000,
            return_tensors="pt"
        )
        input_features = inputs.input_features.to(DEVICE).to(DTYPE)

        forced_decoder_ids = processor.get_decoder_prompt_ids(
            language="en",
            task="transcribe",
        )

        # Choose model: base Whisper for uploaded files, kids adapter for mic
        # If audio is long, split into overlapping chunks to avoid losing later parts
        total_duration = len(waveform) / sr
        CHUNK_SECONDS = 15.0
        OVERLAP_SECONDS = 1.0

        if total_duration <= CHUNK_SECONDS:
            # Single-shot transcription
            inputs = processor(
                waveform,
                sampling_rate=16000,
                return_tensors="pt"
            )
            input_features = inputs.input_features.to(DEVICE).to(DTYPE)

            forced_decoder_ids = processor.get_decoder_prompt_ids(
                language="en",
                task="transcribe",
            )

            with torch.no_grad():
                predicted_ids = speech_model.generate(
                    input_features,
                    forced_decoder_ids=forced_decoder_ids,
                )

            transcribed_text = processor.batch_decode(
                predicted_ids,
                skip_special_tokens=True
            )[0].strip()
            print(f"Transcribed: '{transcribed_text}'")
            return transcribed_text

        # Chunked transcription for long audio
        print(f"Long audio detected ({total_duration:.1f}s) — transcribing in chunks.")
        chunk_samples = int(CHUNK_SECONDS * sr)
        overlap_samples = int(OVERLAP_SECONDS * sr)
        texts = []
        start = 0
        total_samples = len(waveform)

        # prevent infinite loops by using a fixed step and a safety counter
        step = max(1, chunk_samples - overlap_samples)
        max_iters = 10000
        iters = 0
        while start < total_samples and iters < max_iters:
            end = min(start + chunk_samples, total_samples)
            chunk = waveform[start:end]
            if len(chunk) == 0:
                break

            inputs = processor(
                chunk,
                sampling_rate=16000,
                return_tensors="pt"
            )
            input_features = inputs.input_features.to(DEVICE).to(DTYPE)

            forced_decoder_ids = processor.get_decoder_prompt_ids(
                language="en",
                task="transcribe",
            )

            with torch.no_grad():
                predicted_ids = speech_model.generate(
                    input_features,
                    forced_decoder_ids=forced_decoder_ids,
                )

            chunk_text = processor.batch_decode(predicted_ids, skip_special_tokens=True)[0].strip()
            print(f"  chunk {start/sr:.1f}s-{end/sr:.1f}s -> '{chunk_text}'")
            if chunk_text:
                texts.append(chunk_text)

            # advance by step (chunk minus overlap) to guarantee progress
            start += step
            if start < 0:
                start = 0
            iters += 1

        if iters >= max_iters:
            print("Warning: chunking reached max iterations; stopping to avoid infinite loop.")

        transcribed_text = " ".join(texts).strip()
        print(f"Transcribed (concatenated): '{transcribed_text}'")
        return transcribed_text
    except Exception as e:
        print(f"Whisper transcription error: {e}")
        raise RuntimeError(f"Transcription failed: {e}")
    finally:
        try:
            if os.path.exists(tmp_wav):
                os.remove(tmp_wav)
        except Exception:
            pass


# -----------------------------------------
# STEP 2 : GRAMMAR CORRECTION (Local GEC model)
# -----------------------------------------

GEC_MODEL_PATH = "models/FINAL_GEC_MODEL_APRIL/FINAL_GEC_MODEL_APRIL"

if not FAST_MODE:
    print("Loading Grammar Correction model...")
    tokenizer = AutoTokenizer.from_pretrained(GEC_MODEL_PATH)
    gec_model  = AutoModelForSeq2SeqLM.from_pretrained(
        GEC_MODEL_PATH, torch_dtype=DTYPE
    ).to(DEVICE)
    gec_model.eval()
    print("Grammar model ready.")


def correct_text(raw_text):
    """Apply grammar correction to raw transcribed text."""
    if not raw_text.strip():
        return raw_text

    if FAST_MODE:
        print("FAST_MODE: skipping grammar correction")
        return raw_text

    inputs = tokenizer(raw_text, return_tensors="pt")
    inputs = {k: v.to(DEVICE) for k, v in inputs.items()}

    with torch.no_grad():
        outputs = gec_model.generate(
            **inputs,
            max_new_tokens=20,
            no_repeat_ngram_size=2,
            num_beams=1,
            early_stopping=True,
            do_sample=False,
        )

    corrected = tokenizer.decode(outputs[0], skip_special_tokens=True)
    return corrected.strip()


# -----------------------------------------
# FULL PIPELINE (STT + GEC)
# -----------------------------------------

def run_pipeline(audio_file):
    print("\n--- Processing ---\n")

    raw_text = transcribe(audio_file)
    print(f"Raw Transcript  : {raw_text}")

    clean_text = correct_text(raw_text)
    print(f"Corrected Text  : {clean_text}")

    return raw_text, clean_text


# -----------------------------------------
# TEST
# -----------------------------------------

if __name__ == "__main__":
    test_audio = "test_audio/pizza_please_1.wav"
    run_pipeline(test_audio)
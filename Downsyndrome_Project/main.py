# =========================================
# Neurodivergent AI Assistant - main.py
# =========================================

import torch
import librosa
import os

from transformers import (
    WhisperProcessor,
    WhisperForConditionalGeneration,
    AutoTokenizer,
    AutoModelForSeq2SeqLM
)

# -----------------------------------------
# MODEL PATHS
# Change folder names to match yours exactly
# -----------------------------------------

WHISPER_MODEL_PATH = "models/FINAL_WHISPER_MODEL_APRIL/FINAL_WHISPER_MODEL_APRIL"
GEC_MODEL_PATH = "models/FINAL_GEC_MODEL_APRIL/FINAL_GEC_MODEL_APRIL"


# -----------------------------------------
# LOAD PERSONALIZED WHISPER MODEL
# -----------------------------------------

print("Loading Whisper model...")

processor = WhisperProcessor.from_pretrained(
    WHISPER_MODEL_PATH
)
speech_model = WhisperForConditionalGeneration.from_pretrained(
    WHISPER_MODEL_PATH
)

speech_model.eval()



# -----------------------------------------
# LOAD GRAMMAR CORRECTION MODEL
# -----------------------------------------

print("Loading Grammar model...")

tokenizer = AutoTokenizer.from_pretrained(
    GEC_MODEL_PATH
)

gec_model = AutoModelForSeq2SeqLM.from_pretrained(
    GEC_MODEL_PATH
)

gec_model.eval()






# -----------------------------------------
# STEP 1 : SPEECH TO TEXT
# -----------------------------------------

def transcribe(audio_file):

    # Use librosa to load, automatically resample to 16kHz, and convert to Mono
    waveform, sr = librosa.load(audio_file, sr=16000, mono=True)


    inputs = processor(
        waveform,
        sampling_rate=16000,
        return_tensors="pt"
    )


    with torch.no_grad():

        predicted_ids = speech_model.generate(
            inputs.input_features,
            language="en"
        )


    text = processor.batch_decode(
        predicted_ids,
        skip_special_tokens=True
    )[0]


    return text.strip()



# -----------------------------------------
# STEP 2 : GRAMMAR CORRECTION
# -----------------------------------------

def correct_text(raw_text):

    inputs = tokenizer(
        raw_text,
        return_tensors="pt"
    )


    with torch.no_grad():

        outputs = gec_model.generate(
            **inputs,
            max_length=60
        )


    corrected = tokenizer.decode(
        outputs[0],
        skip_special_tokens=True
    )


    return corrected.strip()






# -----------------------------------------
# OPTIONAL STEP 4 : TEXT TO SPEECH
# Uncomment if using Coqui TTS
# -----------------------------------------

"""
from TTS.api import TTS

tts = TTS(
model_name="tts_models/en/ljspeech/tacotron2-DDC"
)

def speak(text):
    tts.tts_to_file(
        text=text,
        file_path="reply.wav"
    )
"""



# -----------------------------------------
# FULL PIPELINE (STT + GEC only)
# -----------------------------------------

def run_pipeline(audio_file):

    print("\n--- Processing ---\n")


    # Listen
    raw_text = transcribe(audio_file)
    print("Raw Transcript:")
    print(raw_text)


    # Clean
    clean_text = correct_text(raw_text)
    print("\nCorrected Text:")
    print(clean_text)


    return raw_text, clean_text



# -----------------------------------------
# TEST
# -----------------------------------------

if __name__ == "__main__":

    test_audio = "test_audio/pizza_please_1.wav"

    run_pipeline(test_audio)
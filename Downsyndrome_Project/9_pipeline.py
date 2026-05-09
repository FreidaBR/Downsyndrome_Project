# =========================================
# Phase 3: The Interaction Loop (Pipeline)
# =========================================

import os
import main
import assistant

print("Loading TTS Engine...")
try:
    # Try loading Coqui TTS (fully offline and high quality)
    from TTS.api import TTS
    # Using the fast_pitch model or tacotron2-DDC
    tts_engine = TTS(model_name="tts_models/en/ljspeech/tacotron2-DDC", progress_bar=False)
    tts_type = "coqui"
    print("Coqui TTS loaded successfully!")
except ImportError:
    print("Coqui TTS not installed. Falling back to gTTS (requires internet connection).")
    from gtts import gTTS
    tts_engine = None
    tts_type = "gtts"
except Exception as e:
    print(f"Error loading Coqui TTS: {e}. Falling back to gTTS.")
    from gtts import gTTS
    tts_engine = None
    tts_type = "gtts"

def run_full_interaction_loop(audio_file_path=None, input_text=None, output_audio_path="reply.wav", name="", age="", mood="", c_name="Astra", c_trait="companion"):
    """
    Executes the 4-step real-time flow:
    1. Listen (Whisper)
    2. Clean (T5 GEC)
    3. Think (Phi-3 Assistant)
    4. Speak (TTS)
    """
    print("STARTING REAL-TIME INTERACTION LOOP")
    print("="*40)

    # STEP 1 & 2: Listen and Clean (or bypass if Text is provided)
    if input_text:
        print("\n[STEP 1 & 2] Bypassed! Processing direct text input...")
        raw_text = input_text
        clean_text = input_text
    else:
        print("\n[STEP 1 & 2] Listening & Cleaning...")
        raw_text, clean_text = main.run_pipeline(audio_file_path)
    
    # STEP 3: Think
    print("\n[STEP 3] Thinking (Phi-3 Assistant)...")
    reply = assistant.get_assistant_response(clean_text, name=name, age=age, mood=mood, c_name=c_name, c_trait=c_trait)
    print(f"Assistant Response: {reply}")

    # STEP 4: Speak
    print("\n[STEP 4] Speaking (Generating Audio)...")
    if tts_type == "coqui" and tts_engine is not None:
        tts_engine.tts_to_file(text=reply, file_path=output_audio_path)
    else:
        # Fallback to gTTS (with character-specific accents)
        tld = "com" # default US for Astra
        if c_name == "Lumi":
            tld = "co.uk" # UK accent for Lumi
        elif c_name == "Blaze":
            tld = "com.au" # Australian accent for Blaze
            
        tts = gTTS(text=reply, lang="en", tld=tld, slow=False)
        tts.save(output_audio_path)
    
    print(f"✅ Audio response saved to: {output_audio_path}")
    print("="*40 + "\n")

    return raw_text, clean_text, reply, output_audio_path

if __name__ == "__main__":
    # Test file
    test_audio = "test_audio/pizza_please_1.wav"
    if os.path.exists(test_audio):
        run_full_interaction_loop(test_audio, name="Test", age="10", mood="Happy", c_name="Lumi", c_trait="Dreamer")
    else:
        print(f"Test audio {test_audio} not found. Please provide a valid file.")

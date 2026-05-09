#!/usr/bin/env python3
"""
Test script to process audio files through the pipeline
"""

import os
import sys
import importlib

# Import the pipeline module
pipeline = importlib.import_module("9_pipeline")

# Test audio file
TEST_AUDIO = "test_audio/painting_1.wav"
OUTPUT_AUDIO = "test_output.mp3"

print("=" * 60)
print("AUDIO PROCESSING TEST")
print("=" * 60)
print(f"\nTest Audio: {TEST_AUDIO}")
print(f"Output Audio: {OUTPUT_AUDIO}")

if not os.path.exists(TEST_AUDIO):
    print(f"\n❌ ERROR: Test audio file not found: {TEST_AUDIO}")
    sys.exit(1)

try:
    print("\n[Processing...]\n")
    
    raw_text, clean_text, assistant_reply, saved_audio_path = pipeline.run_full_interaction_loop(
        audio_file_path=TEST_AUDIO,
        input_text=None,
        output_audio_path=OUTPUT_AUDIO,
        name="Freida",
        age="25",
        mood="happy",
        c_name="Astra",
        c_trait="companion"
    )
    
    print("\n" + "=" * 60)
    print("RESULTS")
    print("=" * 60)
    print(f"\n📝 Raw Transcript:\n{raw_text}")
    print(f"\n✨ Cleaned Text:\n{clean_text}")
    print(f"\n🤖 Assistant Reply:\n{assistant_reply}")
    print(f"\n🔊 Audio Saved To: {saved_audio_path}")
    print("\n✅ Test completed successfully!\n")
    
except Exception as e:
    import traceback
    print("\n" + "=" * 60)
    print("ERROR")
    print("=" * 60)
    print(f"\n❌ {str(e)}\n")
    print("Full Traceback:")
    print(traceback.format_exc())
    sys.exit(1)

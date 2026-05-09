import main

print("Loading test audio...")
raw_text, clean_text = main.run_pipeline("test_audio/pizza_please_1.wav")

with open("scratch_output.txt", "w", encoding="utf-8") as f:
    f.write(f"RAW: {raw_text}\n")
    f.write(f"CLEAN: {clean_text}\n")

print("Finished!")

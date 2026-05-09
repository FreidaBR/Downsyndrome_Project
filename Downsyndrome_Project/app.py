from flask import Flask, render_template, request, jsonify
from flask_cors import CORS
import importlib
pipeline = importlib.import_module("9_pipeline")
import os
import time
import uuid

app = Flask(__name__, static_folder="frontend", static_url_path="", template_folder="frontend")
CORS(app)

UPLOAD_DIR = "uploads"
VOICE_FILE = os.path.join("frontend", "assistant_voice.mp3")

os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/process", methods=["POST"])
def api_process():
    try:
        # Determine if it's text or audio
        input_text = request.form.get("text", "")
        audio_path = None
        
        if not input_text:
            if "audio" not in request.files:
                return jsonify({"error": "No audio file or text provided."}), 400

            audio_file = request.files["audio"]
            if audio_file.filename == "":
                return jsonify({"error": "Empty audio file."}), 400

            temp_name = f"{uuid.uuid4().hex}.wav"
            audio_path = os.path.join(UPLOAD_DIR, temp_name)
            audio_file.save(audio_path)
            print(f"Processing Audio: {audio_path}")
        else:
            print(f"Processing Text: {input_text}")
        
        # Extract personalization variables
        name = request.form.get("name", "")
        age = request.form.get("age", "")
        mood = request.form.get("mood", "")
        c_name = request.form.get("companion_name", "Astra")
        c_trait = request.form.get("companion_trait", "companion")
        
        # Step 1 -> 4
        # We need to save the Voice File exactly where app.py expects it for the frontend
        raw_text, clean_text, assistant_reply, saved_audio_path = pipeline.run_full_interaction_loop(
            audio_file_path=audio_path,
            input_text=input_text if input_text else None, 
            output_audio_path=VOICE_FILE,
            name=name,
            age=age,
            mood=mood,
            c_name=c_name,
            c_trait=c_trait
        )

        response = {
            "raw_text": raw_text,
            "clean_text": clean_text,
            "assistant_reply": assistant_reply,
            "audio_url": f"http://127.0.0.1:5000/assistant_voice.mp3?ts={int(time.time())}"
        }

        return jsonify(response)
        
    except Exception as e:
        import traceback
        error_msg = traceback.format_exc()
        print(f"ERROR: {error_msg}")
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
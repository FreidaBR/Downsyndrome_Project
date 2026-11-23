from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
import importlib
import sys
import os
import time
import uuid
import base64
import io
import shutil

# Force UTF-8 output on Windows to prevent charmap errors with emoji in logs
if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

pipeline = importlib.import_module("9_pipeline")

app = Flask(__name__)
CORS(app)

UPLOAD_DIR = "uploads"
VOICE_FILE = os.path.join(UPLOAD_DIR, "assistant_voice.mp3")

os.makedirs(UPLOAD_DIR, exist_ok=True)


@app.route("/")
def index():
    # Serve a simple frontend recorder page when available
    frontend_path = os.path.join(os.path.dirname(__file__), "frontend.html")
    if os.path.exists(frontend_path):
        return send_file(frontend_path)
    return "<html><head><title>Server Running</title></head><body><h1>Server is running</h1><p>Use POST <strong>/api/process</strong> to access the API.</p></body></html>"


@app.route('/health')
def health():
    """Health check: ffmpeg, ffprobe, model folders, and TTS available."""
    checks = {}
    checks['ffmpeg'] = bool(shutil.which('ffmpeg'))
    checks['ffprobe'] = bool(shutil.which('ffprobe'))

    # Check for known model folders in the repo
    whisper_adapter = os.path.join(os.getcwd(), 'whisper-kids-speech-model', 'whisper-kids-speech')
    gec_path = os.path.join(os.getcwd(), 'models', 'FINAL_GEC_MODEL_APRIL', 'FINAL_GEC_MODEL_APRIL')
    checks['whisper_kids_adapter_exists'] = os.path.exists(whisper_adapter)
    checks['gec_model_exists'] = os.path.exists(gec_path)

    # Check Coqui TTS availability
    try:
        from TTS.api import TTS  # type: ignore
        checks['coqui_tts'] = True
    except Exception:
        checks['coqui_tts'] = False

    return jsonify(checks)


@app.route("/api/process", methods=["POST"])
def api_process():
    try:
        # Determine if it's text or audio
        input_text = request.form.get("text", "")
        audio_path = None
        
        if not input_text:
            # Multipart file upload (common)
            if 'audio' in request.files and request.files['audio'].filename:
                audio_file = request.files['audio']
                file_ext = os.path.splitext(audio_file.filename)[1].lower() or '.wav'
                temp_name = f"{uuid.uuid4().hex}{file_ext}"
                audio_path = os.path.join(UPLOAD_DIR, temp_name)
                audio_file.save(audio_path)
                print(f"Received audio file: {audio_file.filename} -> saved as {audio_path}")
                print(f"Uploaded file content type: {audio_file.content_type}")
            else:
                # Accept base64 payload in form or JSON (use key 'audio_base64')
                audio_b64 = request.form.get('audio_base64') or (request.json.get('audio_base64') if request.is_json else None)
                if audio_b64:
                    try:
                        header, encoded = (audio_b64.split(',', 1) + [audio_b64])[:2]
                        data = base64.b64decode(encoded)
                        temp_name = f"{uuid.uuid4().hex}.wav"
                        audio_path = os.path.join(UPLOAD_DIR, temp_name)
                        with open(audio_path, 'wb') as f:
                            f.write(data)
                        print(f"Saved base64 audio to {audio_path}")
                    except Exception as e:
                        return jsonify({"error": f"Invalid base64 audio payload: {e}"}), 400
                else:
                    return jsonify({"error": "No audio file, base64 audio, or text provided."}), 400

            print("Processing audio with Whisper transcription and noise reduction.")
        else:
            print(f"Processing direct text input: {input_text}")
        
        # Extract personalization variables
        name = request.form.get("name", "")
        age = request.form.get("age", "")
        mood = request.form.get("mood", "")
        c_name = request.form.get("companion_name", "Astra")
        c_trait = request.form.get("companion_trait", "companion")
        history = request.form.get("history", "")
        
        # Step 1 -> 4
        # We save the assistant voice file into uploads and return the audio URL only if generated.
        raw_text, clean_text, assistant_reply, saved_audio_path = pipeline.run_full_interaction_loop(
            audio_file_path=audio_path,
            input_text=input_text if input_text else None,
            output_audio_path=VOICE_FILE,
            history=history if history else None,
            name=name,
            age=age,
            mood=mood,
            c_name=c_name,
            c_trait=c_trait
        )
        # Debug logging: print pipeline outputs so frontend vs backend behavior is clear
        print("[PIPELINE OUTPUT] raw_text=", repr(raw_text))
        print("[PIPELINE OUTPUT] clean_text=", repr(clean_text))
        print("[PIPELINE OUTPUT] assistant_reply=", repr(assistant_reply))

        audio_url = None
        if saved_audio_path:
            audio_url = f"/assistant_voice.mp3?ts={int(time.time())}"

        response = {
            "raw_text": raw_text,
            "transcribed_text": raw_text,
            "clean_text": clean_text,
            "assistant_reply": assistant_reply,
            "audio_url": audio_url
        }

        return jsonify(response)
        
    except Exception as e:
        import traceback
        error_msg = traceback.format_exc()
        print(f"ERROR: {error_msg}")
        error_str = str(e) if str(e) else error_msg.split('\n')[-2]
        return jsonify({"error": error_str}), 500


@app.route("/assistant_voice.mp3")
def get_assistant_voice():
    if not os.path.exists(VOICE_FILE):
        return "Audio not found", 404
    return send_file(VOICE_FILE, mimetype="audio/mpeg")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)
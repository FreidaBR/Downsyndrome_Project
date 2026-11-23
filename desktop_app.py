import threading
import time
import webview
from app import app


def start_flask():
    app.run(host="127.0.0.1", port=5000, debug=False, use_reloader=False)


if __name__ == "__main__":
    flask_thread = threading.Thread(target=start_flask, daemon=True)
    flask_thread.start()

    # Give the local server a moment to start before opening the window.
    time.sleep(1)

    webview.create_window(
        title="Lumina Desktop",
        url="http://127.0.0.1:5000",
        width=1280,
        height=820,
        resizable=True,
        fullscreen=False,
    )

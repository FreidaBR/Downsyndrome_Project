const recordButton = document.getElementById("recordButton");
const uploadButton = document.getElementById("uploadButton");
const statusText = document.getElementById("status");
const previewAudio = document.getElementById("preview");
const assistantAudio = document.getElementById("assistantAudio");
const rawText = document.getElementById("rawText");
const cleanText = document.getElementById("cleanText");
const assistantReply = document.getElementById("assistantReply");

let mediaRecorder;
let recordedChunks = [];
let currentBlob = null;
let isRecording = false;

async function setupRecorder() {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    mediaRecorder = new MediaRecorder(stream);

    mediaRecorder.addEventListener("dataavailable", (event) => {
      if (event.data.size > 0) {
        recordedChunks.push(event.data);
      }
    });

    mediaRecorder.addEventListener("stop", () => {
      currentBlob = new Blob(recordedChunks, { type: "audio/wav" });
      recordedChunks = [];
      previewAudio.src = URL.createObjectURL(currentBlob);
      previewAudio.hidden = false;
      uploadButton.disabled = false;
      statusText.textContent = "Recording complete. Ready to send.";
    });
  } catch (error) {
    statusText.textContent = "Microphone access blocked or unavailable.";
    recordButton.disabled = true;
    console.error(error);
  }
}

recordButton.addEventListener("click", () => {
  if (!mediaRecorder) {
    return;
  }

  if (!isRecording) {
    recordedChunks = [];
    mediaRecorder.start();
    isRecording = true;
    recordButton.textContent = "Stop Recording";
    uploadButton.disabled = true;
    statusText.textContent = "Recording... Speak now.";
  } else {
    mediaRecorder.stop();
    isRecording = false;
    recordButton.textContent = "Start Recording";
  }
});

uploadButton.addEventListener("click", async () => {
  if (!currentBlob) {
    return;
  }

  statusText.textContent = "Sending audio to the assistant...";
  uploadButton.disabled = true;

  const formData = new FormData();
  formData.append("audio", currentBlob, "speech.wav");

  try {
    const response = await fetch("/api/process", {
      method: "POST",
      body: formData,
    });

    const data = await response.json();

    if (!response.ok) {
      statusText.textContent = data.error || "Unable to process audio.";
      uploadButton.disabled = false;
      return;
    }

    rawText.textContent = data.raw_text || "—";
    cleanText.textContent = data.clean_text || "—";
    assistantReply.textContent = data.assistant_reply || "—";
    assistantAudio.src = data.audio_url;
    assistantAudio.hidden = false;
    assistantAudio.load();
    statusText.textContent = "Assistant response received.";
  } catch (error) {
    statusText.textContent = "Server error while processing audio.";
    console.error(error);
  } finally {
    uploadButton.disabled = false;
  }
});

setupRecorder();
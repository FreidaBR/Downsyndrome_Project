import torch
import sys
import requests
from transformers import AutoTokenizer, AutoModelForSeq2SeqLM

# Force UTF-8 output on Windows to prevent charmap errors with emoji in logs
if sys.stdout and hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if sys.stderr and hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

# Check for GPU, otherwise use CPU
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

print("Loading Assistant Brain (flan-t5-small)...")
assistant_tokenizer = AutoTokenizer.from_pretrained("google/flan-t5-small", local_files_only=True)
assistant_model = AutoModelForSeq2SeqLM.from_pretrained(
    "google/flan-t5-small",
    torch_dtype=torch.float16 if torch.cuda.is_available() else torch.float32,
    local_files_only=True,
).to(device)
assistant_model.eval()

def generate_with_llama32(cleaned_sentence, history_text="", name="", age="", mood="", c_name="Lumina", c_trait="companion"):
    """
    Attempt response generation using local Llama 3.2 3B via Ollama.
    """
    system_prompt = (
        f"You are {c_name}, a friendly, warm, and gentle AI {c_trait} for a child. "
        f"The child is feeling {mood or 'happy'}. "
        f"Respond directly, warmly, and encouragingly in 1-2 short sentences using very simple words. "
        f"No bullet points, no markdown formatting, no robotic jargon."
    )

    clean_hist = []
    if history_text:
        for line in history_text.splitlines():
            line_str = line.strip()
            if line_str and '(voice message)' not in line_str:
                clean_hist.append(line_str)

    recent_dialogue = "\n".join(clean_hist[-4:]) if clean_hist else ""
    
    if recent_dialogue:
        user_msg = f"Recent chat history:\n{recent_dialogue}\n\nThe child now says: \"{cleaned_sentence}\""
    else:
        user_msg = f"The child says: \"{cleaned_sentence}\""
    
    prompt = f"{system_prompt}\n\n{user_msg}\n\n{c_name}:"

    try:
        payload = {
            "model": "llama3.2",
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.7,
                "max_tokens": 60,
                "stop": ["Child:", "\n\n", "User:"]
            }
        }
        res = requests.post("http://localhost:11434/api/generate", json=payload, timeout=30)
        if res.status_code == 200:
            text = res.json().get("response", "").strip()
            if text and len(text) > 2:
                if text.startswith('"') and text.endswith('"'):
                    text = text[1:-1].strip()
                return text
    except Exception as e:
        print(f"[OLLAMA LLAMA 3.2 NOTICE] {e}")

    return None

def get_assistant_response(cleaned_sentence, history_text="", name="", age="", mood="", c_name="Lumina", c_trait="companion"):
    """
    Generates a supportive, child-friendly response, fully personalized to the child and character chosen.
    Uses Llama 3.2 3B via Ollama if available, falling back to FLAN-T5-small.
    """
    cleaned = (cleaned_sentence or "").strip()
    if not cleaned:
        return f"Hi! I'm {c_name}, your {c_trait}. What would you like to talk about today?"

    lower_c = cleaned.lower().strip("?!. ")

    # Direct conversational handlers for common child questions & phrases
    if lower_c in ["what is your name", "what's your name", "who are you"]:
        return f"My name is {c_name}! I'm your friendly {c_trait} companion."
    
    if lower_c in ["hello", "hi", "hey", "hello!", "hi!", "hey!"]:
        return f"Hello there! I'm {c_name}, your {c_trait}. I'm so happy to talk with you!"

    # 1. Try Llama 3.2 3B first
    print(f"Assistant is thinking (Llama 3.2 3B) about: {cleaned}")
    llama_reply = generate_with_llama32(cleaned, history_text=history_text, name=name, age=age, mood=mood, c_name=c_name, c_trait=c_trait)
    if llama_reply:
        print(f"[LLAMA 3.2 3B REPLIED]: {llama_reply}")
        return llama_reply

    # 2. Fallback to FLAN-T5-small if Llama 3.2 is not ready yet
    print(f"[FALLBACK FLAN-T5] thinking about: {cleaned}")
    prompt = f'Answer this question or message warmly for a child: "{cleaned}"'

    print("[ASSISTANT PROMPT]", prompt)
    inputs = assistant_tokenizer(prompt, return_tensors="pt", truncation=True, max_length=512).to(device)
    with torch.no_grad():
        output_ids = assistant_model.generate(
            **inputs,
            max_new_tokens=32,
            num_beams=4,
            no_repeat_ngram_size=2,
            early_stopping=True,
            do_sample=False,
        )
    try:
        response_text = assistant_tokenizer.decode(output_ids[0], skip_special_tokens=True).strip()
    except Exception as e:
        print(f"[ASSISTANT DECODE ERROR] {e}")
        response_text = ""

    print("[ASSISTANT RAW RESPONSE]", repr(response_text))

    # Filter out echoes of prompt or repetitive default fallback phrases
    bad_phrases = ["Hello, how can I help you", "User:", "Assistant:", "a child who says", "I'm not sure if", "don't know what to say", "t-shirt", "if i don't"]
    if not response_text or any(bp.lower() in response_text.lower() for bp in bad_phrases):
        response_text = f"That sounds wonderful! Tell me more about {cleaned}."

    print(f"Assistant replied: {response_text}")
    return response_text



from transformers import pipeline
import torch

# Check for GPU, otherwise use CPU
device = 0 if torch.cuda.is_available() else -1

print("Loading Assistant Brain (Phi-3)...")
# We use the 'instruct' model because it's tuned to follow directions
assistant_pipe = pipeline(
    "text-generation", 
    model="microsoft/Phi-3-mini-4k-instruct", 
    device=device,
    torch_dtype="auto"
)

def get_assistant_response(cleaned_sentence, name="", age="", mood="", c_name="Lumina", c_trait="companion"):
    """
    Takes the corrected sentence and generates a supportive, 
    child-friendly response, fully personalized to the child and character chosen.
    """
    
    # Format the dynamic variables
    age_str = f"{age}-year-old" if age else "young"
    name_str = f" named {name}" if name else ""
    mood_str = f", who is currently feeling {mood}" if mood else ""
    
    # This prompt sets the "personality" of your AI
    system_prompt = f"You are {c_name}, a {c_trait}. You are talking to a {age_str} child{name_str}{mood_str}. Treat them with kindness, use simple words, stay very positive, and give short, 1-sentence responses matching your {c_trait} personality."
    
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": f"The child says: '{cleaned_sentence}'"}
    ]
    
    # Generate response
    print(f"Assistant is thinking about: {cleaned_sentence}")
    generation_args = {
        "max_new_tokens": 50,
        "return_full_text": False,
        "temperature": 0.7,
        "do_sample": True,
    }

    start_time = torch.cuda.Event(enable_timing=True) if torch.cuda.is_available() else None
    if start_time: start_time.record()

    output = assistant_pipe(messages, **generation_args)
    response_text = output[0]['generated_text'].strip()
    
    print(f"Thinking finished in a few seconds.")
    return response_text
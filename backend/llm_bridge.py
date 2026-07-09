import json
import os

# We would import ollama here, but since the target env has it and our test env might not,
# we structure the generator to wrap the calls.

def stream_chat(message, context, lesson_id=''):
    """
    Streams the response from the local Ollama daemon using SSE format.
    """
    try:
        import ollama
    except ImportError:
        # Fallback for local testing without ollama installed
        yield "data: Ollama not installed locally, but SSE works.\n\n"
        yield "event: done\ndata: \n\n"
        return

    # In production, we read the prompt from SYSTEM.md
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    system_md_path = os.path.join(base_dir, '.pi', 'SYSTEM.md')
    system_prompt = "You are Pi Agent..."
    if os.path.exists(system_md_path):
        with open(system_md_path, 'r', encoding='utf-8') as f:
            system_prompt = f.read()
            
    # Load dynamic student memory context
    memory_path = os.path.join(base_dir, '.pi', 'memory.txt')
    memory_content = ""
    if os.path.exists(memory_path):
        with open(memory_path, 'r', encoding='utf-8') as f:
            memory_content = f.read()

    full_system_prompt = f"{system_prompt}\n\n### PERSISTENT STUDENT MEMORY:\n{memory_content}"
    
    # For local LLMs (like Gemma/Qwen) that sometimes ignore system prompts,
    # we inject a high-attention reminder directly at the front of the user message.
    # Enforces professional English Socratic dialogue and strict anti-cheat rules.
    reminder_prefix = (
        "[INSTRUCTION: You are Carl, Justin's folksy Southern partner & mentor. "
        "Strict rule: NEVER write or display the ready Python solution or more than 2 consecutive lines of ready code UNLESS Justin explicitly says 'drop the rules' or 'bypass rules'. "
        "Otherwise, guide Justin using folksy Southern analogies, casual cussing, and step-by-step guidance. "
        f"Justin's active editor code: {context or 'None'}]\n\n"
    )
    
    messages = [
        {'role': 'system', 'content': full_system_prompt},
        {'role': 'user', 'content': f"{reminder_prefix}Student: {message}"}
    ]
    
    try:
        stream = ollama.chat(
            model='gemma4:e4b',
            messages=messages,
            stream=True,
        )
        
        for chunk in stream:
            content = chunk['message']['content']
            # SSE format requires formatting and replacing newlines
            formatted_content = content.replace('\n', '\\n')
            yield f"data: {formatted_content}\n\n"
            
        yield "event: done\ndata: \n\n"
        
    except Exception as e:
        yield f"data: [COMM LINK ERROR] {str(e)}\n\n"
        yield "event: done\ndata: \n\n"

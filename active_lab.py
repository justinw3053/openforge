# BOSS FIGHT: Clean Log Pipeline (Simplified)
#
# Welcome to your first Boss Fight!
# You are going to build a simple, bulletproof parser to clean a raw string log.
#
# Input list format: ["justin:active", "carl:pending", "malformed_row"]
# Output expected: [{"username": "justin", "status": "active"}, ...]
#
# Tip:
# 1. Loop over 'raw_logs' using 'for line in raw_logs:'
# 2. Check if the line is valid: if ":" in line:
# 3. Split the line into name and status: parts = line.split(":")
# 4. Extract username and status from parts and append as a dictionary!

def clean_log_pipeline(raw_logs):
    cleaned_data = []
    # Complete the loops and conditions below using active placeholders!
    for line in ...:
        if ... in line:
            parts = ...
            if len(parts) == 2:
                username = ...
                status = ...
                
                # Construct dictionary and append
                record = {"username": ..., "status": ...}
                cleaned_data.append(...)
                
    return cleaned_data

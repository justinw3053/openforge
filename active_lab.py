total = 0
for i in range(1, 6):
    total = i # Attempt to accumulate by assigning directly

print(f"Result: {total}") # Expected 15, but got 5! The state history is wiped out.
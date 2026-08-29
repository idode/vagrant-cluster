#!/usr/bin/env python3
import random
def generate_realistic_walk(steps=12, start_val=50, step_size=7):
    data = [start_val]
    
    for _ in range(steps - 1):

        movement = random.uniform(-step_size, step_size)
        next_val = data[-1] + movement
        
        next_val = max(0, min(100, next_val))
        data.append(round(next_val, 2))        
    
    return data

grafana_data = generate_realistic_walk()
print(grafana_data)
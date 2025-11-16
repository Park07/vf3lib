#!/usr/bin/env python3
import sys
from collections import defaultdict

def convert_slf_to_vf3(slf_file, vf3_file):
    adj = defaultdict(list)
    vertices = {}
    n_vertices = 0
    
    with open(slf_file) as f:
        for line in f:
            parts = line.strip().split()
            if not parts: continue
            if parts[0] == 't':
                n_vertices = int(parts[1])
            elif parts[0] == 'v':
                vertices[int(parts[1])] = int(parts[2])
            elif parts[0] == 'e':
                adj[int(parts[1])].append(int(parts[2]))
    
    with open(vf3_file, 'w') as f:
        f.write(f"{n_vertices}\n")
        for vid in range(n_vertices):
            f.write(f"{vid} {vertices.get(vid, 1)}\n")
        for vid in range(n_vertices):
            neighbors = adj[vid]
            f.write(f"{len(neighbors)}\n")
            for dst in neighbors:
                f.write(f"{vid} {dst}\n")

if __name__ == "__main__":
    convert_slf_to_vf3(sys.argv[1], sys.argv[2])

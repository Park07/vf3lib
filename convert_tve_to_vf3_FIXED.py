#!/usr/bin/env python3
import sys
from collections import defaultdict

def convert_tve_to_vf3(tve_file, vf3_file):
    adj = defaultdict(set)
    nodes = {}
    
    print(f"Reading TVE file: {tve_file}...")
    with open(tve_file) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            parts = line.split()
            
            if parts[0] == 't':
                pass
            elif parts[0] == 'v':
                nodes[int(parts[1])] = parts[2]
            elif parts[0] == 'e':
                u, v = int(parts[1]), int(parts[2])
                adj[u].add(v)
                adj[v].add(u)
    
    node_list = sorted(nodes.keys())
    node_mapping = {old_id: new_id for new_id, old_id in enumerate(node_list)}
    n = len(node_list)
    
    print(f"Writing VF3 format...")
    with open(vf3_file, 'w') as f:
        # Nodes
        f.write(f"{n}\n")
        for old_id in node_list:
            new_id = node_mapping[old_id]
            label = nodes[old_id]
            f.write(f"{new_id} {label}\n")
        
        # Edges
        for old_id in node_list:
            new_id = node_mapping[old_id]
            neighbors = sorted([node_mapping[nbr] for nbr in adj[old_id]])
            f.write(f"{len(neighbors)}\n")
            for nbr_id in neighbors:
                f.write(f"{new_id} {nbr_id}\n")  # NO LABEL HERE!
    
    total_edges = sum(len(adj[v]) for v in nodes) // 2
    print(f"✓ Converted: {n} vertices, {total_edges} edges")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 script.py <input> <output>")
        sys.exit(1)
    convert_tve_to_vf3(sys.argv[1], sys.argv[2])

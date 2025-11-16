#!/usr/bin/env python3
import sys
from collections import defaultdict

def convert_tve_to_vf3(tve_file, vf3_file):
    adj_out = defaultdict(list) # Store tuples of (dst, label)
    nodes = {} # Use a dict to store labels
    
    print(f"Reading TVE file: {tve_file}...")
    with open(tve_file) as f:
        for line in f:
            line = line.strip()
            if not line: continue
            parts = line.split()
            
            if parts[0] == 't':
                pass # Header
            elif parts[0] == 'v':
                nodes[int(parts[1])] = parts[2] # v (id) (label)
            elif parts[0] == 'e':
                # e (src) (dst) (label)
                u, v, label = int(parts[1]), int(parts[2]), parts[3]
                adj_out[u].append((v, label))
                adj_out[v].append((u, label)) # Add the reverse edge
    
    all_node_ids = set(adj_out.keys())
    for n_id in nodes.keys():
        all_node_ids.add(n_id)
        
    node_list = sorted(list(all_node_ids))
    node_mapping = {old_id: new_id for new_id, old_id in enumerate(node_list)}
    n = len(node_list)
    
    print(f"Writing VF3 format to: {vf3_file}...")
    with open(vf3_file, 'w') as f:
        f.write(f"{n}\n")
        # Write vertex list
        for old_id in node_list:
            new_id = node_mapping[old_id]
            label = nodes.get(old_id, '1') 
            f.write(f"{new_id} {label}\n")
        
        # Write edge list (adjacency format)
        for old_id in node_list:
            new_id = node_mapping[old_id]
            
            neighbors_with_labels = []
            for nbr_old, edge_label in adj_out[old_id]:
                if nbr_old in node_mapping:
                    neighbors_with_labels.append((node_mapping[nbr_old], edge_label))
            
            neighbors_with_labels.sort()
            
            f.write(f"{len(neighbors_with_labels)}\n")
            for nbr_new_id, edge_label in neighbors_with_labels:
                # Write: src_id dst_id attribute
                f.write(f"{new_id} {nbr_new_id} {edge_label}\n")
    
    total_edges = sum(len(adj_out[v]) for v in node_list) // 2
    print(f"✓ Converted TVE: {n} vertices, {total_edges} edges")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 convert_tve_to_vf3_adjacency.py <input> <output>")
        sys.exit(1)
    convert_tve_to_vf3(sys.argv[1], sys.argv[2])

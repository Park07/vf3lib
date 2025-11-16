#!/usr/bin/env python3
import sys
from collections import defaultdict

def convert_snap_to_vf3(snap_file, vf3_file):
    adj = defaultdict(set)
    nodes = set()
    
    print(f"Reading SNAP file: {snap_file}...")
    with open(snap_file) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            parts = line.split()
            if len(parts) >= 2:
                u, v = int(parts[0]), int(parts[1])
                if u == v: continue
                nodes.add(u)
                nodes.add(v)
                adj[u].add(v)
                adj[v].add(u)
    
    node_list = sorted(nodes)
    node_mapping = {old_id: new_id for new_id, old_id in enumerate(node_list)}
    n = len(node_list)
    
    print(f"Writing VF3 format to: {vf3_file}...")
    print(f"  Nodes: {n}")
    print(f"  Writing node section...")
    
    with open(vf3_file, 'w') as f:
        # SECTION 1: Node count
        f.write(f"{n}\n")
        
        # SECTION 2: All nodes (id label)
        for i in range(n):
            f.write(f"{i} 1\n")
        
        # SECTION 3: Edge lists for each node
        print(f"  Writing edge section...")
        for old_id in node_list:
            new_id = node_mapping[old_id]
            neighbors = sorted([node_mapping[nbr] for nbr in adj[old_id]])
            f.write(f"{len(neighbors)}\n")
            for nbr_id in neighbors:
                f.write(f"{new_id} {nbr_id}\n")
    
    total_edges = sum(len(adj[v]) for v in nodes) // 2
    print(f"✓ Converted: {n} vertices, {total_edges} edges")

if __name__ == "__main__":
    convert_snap_to_vf3(sys.argv[1], sys.argv[2])

"""
script for replacing {calculate-distance} with the actual pddl code
"""

import re
import sys

REPLACEMENTS = {
    "{calculate-distance ?c}": "(^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5)",
    "{calculate-distance ?p}": "(^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5)",
    "{calculate-distance ?obj}": "(^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5)"
    }

def main(infile, outfile):
    with open(infile, "r") as f:
        content = f.read()

    for old, new in REPLACEMENTS.items():
        content = content.replace(old, new)

    with open(outfile, "w") as f:
        f.write(content)

    print(f"Saved output to {outfile}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python replace.py input.txt output.txt")
    else:
        main(sys.argv[1], sys.argv[2])


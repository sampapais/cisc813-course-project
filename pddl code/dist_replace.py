"""
script for replacing {calculate-distance} with the actual pddl code
"""

import re
import sys

def main(infile, outfile):
    
    to_replace = "{calculate-distance}"
    replace_with = "(^ (+ (^ (- (x-obj ?o)(x-arm)) 2)(^ (- (y-obj ?o) (y-arm)) 2)) 0.5)" #pddl code for calculating distance
                                                                                         #between two (x, y) coordinates

    with open(infile, "r") as f:
        content = f.read()

    # Replace anything of the form { ... }
    replaced = re.sub(to_replace, replace_with, content)

    with open(outfile, "w") as f:
        f.write(replaced)

    print(f"Saved output to {outfile}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python replace.py input.txt output.txt")
    else:
        main(sys.argv[1], sys.argv[2])

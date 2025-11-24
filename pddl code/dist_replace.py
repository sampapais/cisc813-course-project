"""
script for replacing {calculate-distance} with the actual pddl code
"""

import re
import sys

def main(infile, outfile):
    
    to_replace_c = "{calculate-distance ?c}"
    replace_with_c = "(^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5)" #pddl code for calculating distance
                                                                                         #between two (x, y) coordinates

    to_replace_p = "{calculate-distance ?p}"
    replace_with_p = "(^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5)"

    to_replace_obj = "{calculate-distance ?obj}"
    replace_with_obj = "(^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5)" 

    with open(infile, "r") as f:
        content = f.read()

    # Replace anything of the form { ... }
    replaced = re.sub(to_replace_c, replace_with_c, content)
    replaced = re.sub(to_replace_p, replace_with_p, content)
    replaced = re.sub(to_replace_obj, replace_with_obj, content)


    with open(outfile, "w") as f:
        f.write(replaced)

    print(f"Saved output to {outfile}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python replace.py input.txt output.txt")
    else:
        main(sys.argv[1], sys.argv[2])

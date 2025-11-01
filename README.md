# Canadarm3

## Overview

This domain models some of the functionality and the safety protocols of the Canadarm3, Canada's contribution to NASA's Lunar Gateway. 
Since the robotic arm will function autonomously for the most part, there is a necessity to ensure that its safety protocols are robust.

The motivation behind this model is to ensure that there are no logical gaps in the safety protocols outlined for the Canadarm3.
This model uses PDDL+ to model a hybrid domain for the arm. The way this model falsifies the off-nominal behaviours is by using problem files
that are intended to produce failure states and seeing if the planner is able to produce a plan to achieve these failure states. If 
it can, then there may be an issue with the safety protocols outlined for the system.

This model currently captures:
- Sensing and tracking objects.
- Continuous movement of the arm towards objects in space and towards itself.
- Safety protocols for collision avoidance.

## Files in the repository

- There are two domain files in this repository currently: an old and new version. The old version (domain-old.pddl) does not capture the 2-dimensional grid space that the new version (domain.pddl) currently has. Ignore the old domain -- it is just there for my own easy reference.
- There is a txt document of notes -- these are also just for my own reference.
- The draft of the report is included in this repository as well.

## Draft NOTE:

See the main branch for the right version of the repository. I will continue working in the "domain" branch as this is being marked.
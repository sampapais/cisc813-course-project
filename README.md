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
- Safety protocols for collision avoidance with both crafts and space debris.
- The orbit of the Lunar Gateway around the Moon and how this affects the arm's battery life.
- How the sensor breaking can impact the Canadarm3's functionality.

## Folders and files in the repository

In the main branch:
- The folder titled "misc" contains the report draft, some notes, and some code for replacing bits of code with other bits of code. This can be ignored.
- The folder titled "old domains" contains old drafts of the domain. This can also be ignored, but it's fun(ny) to look at.
- The folder titled "pddl code" contains the domain as well as the 12 problem files used to falsify the model.
- The folder titled "plans" contains the plans output by the planner when a path to failure could be found.
- The final report can be found in the home directory, titled "CISC813 Final Project Report"

## How to run the problem files:

To obtain the plans, I used ENHSP-2020 in the planutils environment. The plans can therefore be run from within the planutils environment (instructions on how to access this found [here](https://github.com/AI-Planning/planutils)). After entering the "pddl code" folder, you can run the individual plans with the following command (substituting the desired problem file for problem1.pddl): 

enhsp-2020 --domain domain.pddl --problem problem1.pddl -pe

Note that adding the -pe flag to the end displays the events (which I believe is crucial with this model, since many things rely on events and processes---there are only 5 actions in the whole model).

To generate plans, I used the following complete command with a timeout of 600 seconds (10 minutes):

enhsp-2020 --domain domain.pddl --problem problem1.pddl -sp out1.plan -pe -timeout 600


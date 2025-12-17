(define (problem craftcollision1) (:domain canadarm3-real)
(:objects 
    craft1 - craft
    port1 - port
)

(:init
    ;initialize function values
    (= (collision-distance) 3) ; min distance the craft can be before a collision is a detected
    (= (sensor-range) 20) ; how far the sensor can see
    (= (arm-speed) 1) ; how fast the arm should be moving
    ;(= (craft-speed craft1) 1)
    (= (craft-deceleration craft1) -0.25)

    ;port coords
    (= (x-obj port1) 40)
    (= (y-obj port1) 30)



    ;arm coords
    (= (x-arm) 30)
    (= (y-arm) 30)

    ;velocity of the arm
    (= (vx-arm) 0) ; should be 0 -- just assume it's stationary -- everything should be measured relative to the arm... obj velocity more needed to test for collisions
    (= (vy-arm) 0)
    
    (= (x-obj craft1) 0)
    (= (y-obj craft1) 0)

    ;velocity of craft1
    (= (vx-obj craft1) 1)
    (= (vy-obj craft1) 1)



    (= (orbit-clock) 5) ;will let us use a toggle to go between T/F for  in-sun
    (= (orbit-clock-counter) 5) ;same as orbit clock max time (hack)

    (= (sensor-repair-clock) 20) ;sensor can be repaired after a certain amount of time
    (= (sensor-repair-clock) 20) ;same as sensor repair clock max time (hack)

    (= (battery-level) 1000) ;how much battery the arm has currently (affected by charging and draining)
    (= (battery-drain-rate) 1) ;rate at which the battery drains when in shade
    (= (battery-charge-rate) 2) ;rate at which the battery charges when in sun
    (= (full-battery-capacity) 1000) ;how much charge the battery can hold (max capacity)

    (= (num-collisions) 0)

    (port-free port1)
    (grasp-free)
    (in-sun)
    (sensor-functional)
    (moving craft1)
)

(:goal (failure-collision craft1)
)
)



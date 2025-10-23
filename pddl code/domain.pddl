(define (domain canadarm_safety_validation)
    (:requirements :typing :fluents :time :durative-actions )

    (:types spacecraft - object
            location
    )

    (:predicates
        (at-obj ?obj) ; to indicate the arm is next to an object
        (at-loc ?loc) ; to indicate the arm is at a specific location
        (obj-at-loc ?obj ?loc) ; to indicate an object is at a particular location
        (velocity-matched ?obj) ; to indicate when the arm has matched its velocity to another obj
        (holding ?obj) ; to indicate what obj the arm is holding
        (grasp-free) ; T/F if the arm is currently holding anything
        (detected ?obj) ; indicates if an object has been detected by the sensor
        ()
    )

    (:functions
        (relative-velocity); in meters/sec
        (distance); in meters
    )

    ; events
    (:event collision)

    (:event spacecraft_detected)

    (:event spacecraft_aligned)

    (:event arrived_at_port)


    ; processes
    (:process move)

    (:process match_velocity)

    (:process collision_detection) ; hopefully get this to be predictive but maybe for now just detect a collision right before it occurs?

    (:process collision_avoidance) ; not sure how to use this right now. should continuously prevent collision if possible

    (:process move_to_dock)
    

    ; durative actions


    ; discrete actions
    (:action track_craft)

    (:action begin_moving)

    (:action grasp)

    (:action dock_craft)

    (:action emergency_halt) ; if collision imminent on current trajectory, stop movement
)
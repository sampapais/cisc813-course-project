(define (domain canadarm_safety_validation)
    (:requirements :typing :fluents :time :durative-actions :numeric-fluents :negative-preconditions 
    :continuous-effects)

    (:types craft - object
            port - location
    )

    (:predicates
        (at-obj ?obj - object) ; to indicate the arm is next to an object
        (at-loc ?loc - location) ; to indicate the arm is at a specific location
        (obj-at-loc ?obj - object ?loc - location) ; to indicate an object is at a particular location
        (velocity-matched ?obj - object) ; to indicate when the arm has matched its velocity to another obj
        (holding ?obj - object) ; to indicate what obj the arm is holding
        (grasp-free) ; T/F if the arm is currently holding anything
        (detected ?obj - object) ; indicates if an object has been detected by the sensor
        (collision-imminent ?obj - object) ; collision detected with obj
        (port-free ?port - port) ; indicates if a given port is free -- maybe change to more general location free predicate?
        (tracking ?c) ; indicates which craft we are currently tracking
        (moving) ; if the arm is moving or not
        (safety-mode) ; safety mode indicates we should be trying to recover from a failure 
    )

    (:functions
        (relative-velocity ?c - craft); relative velocity to the craft, in meters/sec
        (obj-distance ?obj - object); distance from the craft/obj, in meters
        (port-distance ?p - port) ; how far away is the port -- at some point, set locations/distances for all ports
        (collision-distance) ; min distance the craft can be before a collision is a detected
        (sensor-range)
    )

    ; events
    (:event collision
     :parameters (?c - craft) ; detects an imminent collision if the obj is too close and the velocity is not yet matched
     :precondition (and
        (detected ?c)
        (not (velocity-matched ?c))
        (<= (craft-distance ?c)(collision-distance))
        (not (collision-imminent ?c)))
     :effect (and
        (collision-imminent ?c))
    )

    ; not sure i even need the below effects -- write the processes and see if it makes sense to remove/alter these
    (:event object_detected
     :parameters (?obj - object)
     :precondition (and ; within range of sensor, not detected previously
        (not (detected ?obj))
        (<= (obj-distance ?obj)(sensor-range)))
     :effect (and ; now detected
        (detected ?obj))
    )

    (:event spacecraft_aligned
     :parameters (?c - craft)
     :precondition (and ; craft must be being tracked, velocity must be matched
        ;(detected ?c)
        (tracking ?c)
        (velocity-matched ?c)
        (not (velocity-matched ?c)))
     :effect (and
        (velocity-matched ?c))
    )

    (:event arrived_at_port
     :parameters (?p - port) ; can just track the arm's distance to the port
     :precondition (and
        (<= (port-distance ?p)0.5)
        (not (at-loc ?p)))
     :effect ( ; at the port
        (at-loc ?p))
    )


    ; processes

    ; might need some process for the craft's movement? not sure

    (:process move
     :parameters (?from ?to - location)
     :precondition ()
     :effect () ; not at from, now at to
    )

    (:process match_velocity
     :parameters ()
     :precondition ()
     :effect ()
    )

    (:process collision_avoidance ; not sure how to use this right now. should continuously prevent collision if possible
     :parameters ()
     :precondition ()
     :effect ()
    ) 

    (:process move_to_dock
     :parameters ()
     :precondition ()
     :effect ()
    )
    

    ; durative actions


    ; discrete actions
    (:action track_craft
     :parameters (?c - craft)
     :precondition (and
        (detected ?c)
        (not (tracking ?c))) ; if craft is detected, start tracking it -- assuming for now there's only one craft at a time
     :effect (and
        (tracking ?c))
    )

    (:action begin_moving
     :parameters (?from ?to - location)
     :precondition (and
        ())
     :effect (and
        ())
    )

    (:action grasp ; to grasp a particular object
     :parameters (?obj - object) ; NOTE HERE: how am i handling locations?
     :precondition (and
        (at-obj ?obj)
        (grasp-free))
     :effect (and
        (not (grasp-free))
        (holding ?obj)
        (not (at-obj ?obj)))
    )

    (:action dock_craft
     :parameters (?p - port ?c - craft)
     :precondition (and
        (at-loc ?p)
        (holding ?c)
        (not (moving)) ; take another look at this -- not sure if I need this
        (port-free ?p))
     :effect (and
        (not (holding ?c))
        (not (port-free ?p))
        (obj-at-loc ?c ?p)
        (grasp-free))
    )

    (:action emergency_halt ; if collision imminent, stop movement and enter safety mode
     :parameters (?obj - object)
     :precondition (and
        (collision-imminent ?obj)) ; do i even need this lmao i feel like i should just enter safety mode from the event itself
                                   ; and also probably have like. multiple safety modes depending on what's wrong.
                                   ; revise!
     :effect (and
        (safety-mode))
    ) 
)
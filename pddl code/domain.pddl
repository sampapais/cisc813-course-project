(define (domain canadarm3-original)
   (:requirements :typing :fluents :time :durative-actions :numeric-fluents :negative-preconditions 
   :continuous-effects)

   (:types craft port debris - object
   )

   (:predicates
      (at ?obj - object) ; to indicate the arm is next to an object/location      
      (velocity-matched ?obj - object) ; to indicate when the arm has matched its velocity to another obj
      (holding ?obj - object) ; to indicate what obj the arm is holding
      (grasp-free) ; T/F if the arm is currently holding anything
      (detected ?obj - object) ; indicates if an object has been detected by the sensor
      (collision-imminent ?obj - object) ; collision detected with obj
      (port-free ?port - port) ; indicates if a given port is free -- maybe change to more general location free predicate?
      (tracking ?c - craft) ; indicates which craft we are currently tracking
      (safety-mode) ; safety mode indicates we should be trying to recover from a failure 
      (catching ?c - craft)
      (successful-dock) ; state indicating a successful dock has occurred
      (failure-collision) ; state indicating that there has been a collision failure
      (in-sun) ;true if arm is in the sun
      (sensor-functional) ;true if sensor works ****NEED TO GO BACK AND ADD AS PRECONDTIION
   )

   (:functions
      ;(relative-velocity ?c - craft); relative velocity to the craft, in meters/sec -- GET RID OF THIS -- NO POINT SETTING I THINK
      (collision-distance) ; min distance the craft can be before a collision is a detected
      (sensor-range) ; how far the sensor can see
      (arm-speed) ; how fast the arm should be moving
      (craft-speed ?c)

      ;coord sys for arm/objs + velocities
      (x-arm)
      (y-arm)

      ;velocity of the arm
      (vx-arm) ; should be 0 -- just assume it's stationary -- everything should be measured relative to the arm... obj velocity more needed to test for collisions
      (vy-arm)
      
      (x-obj ?obj - object)
      (y-obj ?obj - object)

      ;velocity of objects
      (vx-obj ?obj - object)
      (vy-obj ?obj - object)

      (orbit-clock) ;will let us use a toggle to go between T/F for  in-sun
      (sensor-repair-clock) ;sensor can be repaired after a certain amount of time
   )

   ; events
   (:event collision-warning ; detects an imminent collision if velocities are pointed at each other + the objs are too close
    :parameters (?obj - object) 
    :precondition (and
      (detected ?obj) 
      (< (+ (* (- (vx-arm) (vx-obj ?obj)) (- (x-arm) (x-obj ?obj)))(* (- (vy-arm) (vy-obj ?obj)) (- (y-arm) (y-obj ?obj)))) 0) ; see if their velocities are pointed at each other (even if arm velocity is 0 which i think i'll keep it at...)
      (<= {calculate-distance ?obj}(collision-distance)) ;check if they're within a certain distance of each other deemed unsafe
      (not (collision-imminent ?obj)))
    :effect (and
      (collision-imminent ?obj)
      (safety-mode)) ; should trigger collision safety protocol to take place/prevent unsafe actions
   )

   (:event collision ;COME BACK TO THIS
    :parameters (?obj - craft)
    :precondition (<= {calculate-distance ?obj} 0) ;see if an object has hit the arm
    :effect (failure-collision) ;collision failure has occurred
   )

   (:event exit_safety_mode 
    :parameters (?obj - craft)
    :precondition (and
      (safety-mode)
      (collision-imminent ?obj)
      (or (> {calculate-distance ?obj} (collision-distance))(and (<= (vx-obj ?obj) 0) (<= (vy-obj ?obj) 0)))) ;ok if obj is either still or if it is far enough away where collision is no longer a concern
    :effect (and
      (not (collision-imminent ?c))
      (not (safety-mode)))
   )

   (:event object_detected
    :parameters (?obj - object)
    :precondition (and ; within range of sensor, not detected previously
      (not (detected ?obj))
      (<= {calculate-distance ?obj}(sensor-range)))
    :effect (detected ?obj) ; now detected
   )

   (:event spacecraft_aligned
    :parameters (?c - craft)
    :precondition (and ; craft must be being tracked, velocity must be matched
      ;(detected ?c)
      (tracking ?c)
      ;(<= (relative-velocity ?c) 0.05)
      (<= (abs (- (vx-arm) (vx-obj ?c))) 0.05) ;some small num ? might be ok to be 0.... but come back
      (<= (abs (- (vy-arm) (vy-obj ?c))) 0.05)
      (not (velocity-matched ?c))) 
    :effect (and
      (velocity-matched ?c))
   )

   (:event reached_craft
    :parameters (?c - craft)
    :precondition (and
      (<= {calculate-distance ?c} 0.1)
      (not (at ?c))
      (catching ?c))
    :effect (and ; at the port
      (at ?c)
      (not (catching ?c)))
   )

   (:event arrived_at_port
    :parameters (?p - port)
    :precondition (and
      (<= {calculate-distance ?p} 0.1)
      (not (at ?p)))
    :effect (at ?p) ; at the port
   )

   ; processes

   ;craft approaches the station
   (:process approach_station
    :parameters (?c - craft)
    :precondition (and
      (tracking ?c)
      (not (velocity-matched ?c))
      (not (safety-mode))
      (>= {calculate-distance ?c} 10.0))
    :effect (and
      (decrease (x-obj ?c) (* #t (craft-speed ?c)(/ (- (x-obj ?c)(x-arm)){calculate-distance ?c}))) ; move in dir of the craft
      (decrease (y-obj ?c) (* #t (craft-speed ?c)(/ (- (y-obj ?c)(y-arm)){calculate-distance ?c}))))
   )

   ;actually extends the arm towards the craft
   (:process reach_towards_craft
    :parameters (?c - craft)
    :precondition (and
      (tracking ?c)
      (velocity-matched ?c) ; as we're moving, the velocity won't be matched..... not sure if i need this though
      (not (safety-mode))
      (>= {calculate-distance ?c} 0.1) ; stop when 0.1 away -- should set a function for this so it's adjustable
      (catching ?c))
    :effect (and
      (decrease (x-arm) (* #t (arm-speed)(/ (- (x-arm)(x-obj ?c)) {calculate-distance ?c}))) ; reach towards the craft
      (decrease (y-arm) (* #t (arm-speed)(/ (- (y-arm)(y-obj ?c)) {calculate-distance ?c}))))
   )

   ;need to come back to this -- see below for revised version
   ; (:process match_velocity
   ; :parameters (?c - craft)
   ; :precondition (and
   ;    (tracking ?c)
   ;    (not (velocity-matched ?c))
   ;    (<= {calculate-distance ?c} 10.0)
   ;    (not (safety-mode))) ; match velocity when close enough
   ; :effect (and
   ;    (decrease (relative-velocity ?c) (* #t 0.1))) ; make the relative velocity approach 0
   ; )

   (:process match_velocity
    :parameters (?c - craft)
    :precondition (and
      (tracking ?c)
      (not (velocity-matched ?c))
      (<= {calculate-distance ?c} 10.0) ; match velocity when craft is close enough
      (not (safety-mode))) 
    :effect (and
      (decrease (vx-obj ?c) (* #t 0.1))
      (decrease (vy-obj ?c) (* #t 0.1))) ; make the relative velocity approach 0 -- match the craft whose velocity should also be 0...
   )

   (:process collision_avoidance_debris ; prevents collisions with debris if one is detected
    :parameters (?d - debris)
    :precondition (and
      (safety-mode)
      (collision-imminent ?d))
    :effect (and
      (increase (x-arm) (* #t (arm-speed) (/ (vy-obj ?d) (^ (+ (^ (vx-obj ?d) 2) (^ (vy-obj ?d) 2)) 0.5)))) 
      (increase (y-arm) (* #t (arm-speed) (/ (- (vx-obj ?d)) (^ (+ (^ (vx-obj ?d) 2) (^ (vy-obj ?d) 2)) 0.5))))) ; move the arm perpendicular to the velocity of the incoming debris (flip sign)
   )

   (:process collision_avoidance_craft ; prevents collisions if one is detected w a CRAFT -- craft comes to a stop immediately
    :parameters (?c - craft)
    :precondition (and
      (safety-mode)
      (collision-imminent ?c))
    :effect (and
      (decrease (vx-obj ?c) (* #t 0)) ; make the craft stop immediately
      (decrease (vy-obj ?c) (* #t 0)))
   ) 

   (:process move_to_dock
    :parameters (?p - port ?c - craft)
   :precondition (and
       (holding ?c)
      (not (at ?p))
      (not (safety-mode)))
    :effect (and
      (decrease (x-arm) (* #t (arm-speed)(/ (- (x-arm)(x-obj ?p)) {calculate-distance ?p}))) ;update arm coords.
      (decrease (y-arm) (* #t (arm-speed)(/ (- (y-arm)(y-obj ?p)) {calculate-distance ?p}))) 
      (decrease (x-obj ?c) (* #t (arm-speed)(/ (- (x-obj ?c)(x-obj ?p)) {calculate-distance ?p}))) ;update craft coords.
      (decrease (y-obj ?c) (* #t (arm-speed)(/ (- (y-obj ?c)(y-obj ?p)) {calculate-distance ?p})))) 
   )

   ; discrete actions
   (:action track_craft
    :parameters (?c - craft)
    :precondition (and
      (detected ?c)
      (not (tracking ?c))) ; if craft is detected, start tracking it -- assuming for now there's only one craft at a time
   :effect (and
      (tracking ?c))
   )

   (:action catch_craft
    :parameters (?c - craft)
    :precondition (and
      (tracking ?c)
      (velocity-matched ?c) ; as we're moving, the velocity won't be matched..... not sure if i need this though
      (not (safety-mode))
      (>= {calculate-distance ?c} 0.1) ; stop when 0.1 away -- should set a function for this so it's adjustable
    )  
    :effect (catching ?c)  ;trigger process to move arm to craft
   )

   (:action grasp ; to grasp a particular object
    :parameters (?obj - object)
    :precondition (and
      (at ?obj)
      (grasp-free)
      (velocity-matched ?obj)) ;don't want to grab anything coming at us fast
    :effect (and
      (not (grasp-free))
      (holding ?obj)
      (not (at ?obj)))
   )

   (:action dock_craft
    :parameters (?p - port ?c - craft)
    :precondition (and
      (at ?p)
      (holding ?c)
      (port-free ?p))
    :effect (and
      (not (holding ?c))
      (not (port-free ?p))
      (grasp-free)
      (successful-dock))
   )


   ;low power functionality + protocols

   ;only vital systems should remain active, e.g. collision avoidance + detecting objects with sensors
   ;but shouldn't try to catch/dock ships, for ex.

   ;idea is the arm gets power from the LG which gets power from the sun w solar panels
   ;so we need to model being in shade versus being in sunlight
   ;do this with events/some counter that toggle ever k seconds, switching from light to shadow
   ;process of using battery is always on
   ;charging when in sunlight
   ;draining when in shadow
   ;can define a function for how quickly the battery charges + drains -- if drains faster than charges, might be low power error... need to wait until it's back in the sun to resume operations
   ;***************** PUT PRECONDITION IN PREVIOUS ACTIONS/PROCESSES/EVENT THAT THEY CAN ONLY BE EXECUTED IF NOT LOW BATTERY

   (:process orbit-countdown ;should always be going (paired with event that resets this every k seconds -- see next)
    :precondition (> (orbit-clock) 0)
    :effect (decrease (orbit-clock)(* #t 1))
   )

   (:event toggle-sun
    :precondition (<= (orbit-clock) 0) ;toggle betwene settings when the clock hits 0
    :effect (and
      (when (in-sun) (not (in-sun))) ;go into shade
      (when (not (in-sun)) (in-sun))) ;go into sunlight
   )

   (:process battery-draining
    :parameters ()
    :precondition ()
    :effect ()
   )

   (:process battery-charging
    :parameters ()
    :precondition ()
    :effect ()
   )


   ;sensor breaks + protocols

   ;arm should not do anything -- should retract as close as possible to the base and wait to be repaired
   ;becomes functional again after a certain period of time -- set a clock
   ;sensor breaking is set in the problem file as a timed initial literal (TIL)
   ;***************** PUT PRECONDITION IN PREVIOUS ACTIONS/PROCESSES/EVENT THAT THEY CAN ONLY BE EXECUTED IF SENSOR IS ACTIVE

   (:event sensor_fixed
    :precondition (and 
      (<= (sensor-repair-clock) 0)
      (not (sensor-functional))) ;when countdown hits 0
    :effect (sensor-functional)
   )

   (:process sensor-repair-countdown
    :precondition (and
      (> (sensor-repair-clock) 0)
      (not (sensor-functional)))
    :effect (decrease (sensor-repair-clock) (* #t 1)) ;countdown by 1 
   )
)




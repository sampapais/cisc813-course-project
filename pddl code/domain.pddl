(define (domain canadarm3-real)
   (:requirements :typing :negative-preconditions :conditional-effects :adl :fluents)
   
   (:types trackable location - object
           craft debris - trackable ;two types of objects can be tracked
           port - location) ;port is the only location

   (:predicates
      (at ?obj - object) ; to indicate the arm is next to an object/location      
      (velocity-matched ?obj - object) ; to indicate when the arm has matched its velocity to another object
      (holding ?obj - object) ; to indicate what object the arm is holding
      (grasp-free) ; T/F if the arm is currently holding anything
      (detected ?obj - object) ; indicates if an object has been detected by the sensor
      (collision-imminent ?obj - object) ; imminent collision detected with object
      (port-free ?port - port) ; indicates if a given port is free
      (tracking ?c - craft) ; indicates which crafts we are currently tracking
      (safety-mode) ; being in safety mode indicates we should be trying to recover from a collision failure 
      (catching ?c - craft) ;indicates that the arm is currently reaching out to catch a craft
      (successful-dock ?c - craft) ; state indicating a successful dock has occurred
      (failure-collision ?obj - object) ; state indicating that there has been a collision failure
      (in-sun) ;true if arm is in the sun
      (sensor-functional) ;true if sensor is currently functional
      (failure-battery-drained);indicates failure -- true when battery is drained
      (battery-low) ;true when battery is below 20% of max capacity
      (approached ?c - craft) ;indicates when a craft has approached close enough to the arm to be caught
      (moving ?obj - object) ;indicates when an object is in motion
      (moving-to-port ?p - port) ;indicates when the arm is moving to a port to dock a craft
   )

   (:functions
      (collision-distance) ; min distance the craft can be before a collision is a detected
      (sensor-range) ; how far the sensor can see
      (arm-speed) ; how fast the arm is moving
      (craft-deceleration ?c - craft) ;how fast the craft is able to slow down/match velocity with arm (0 velocity)

      ;coords of arm
      (x-arm)
      (y-arm)

      ;velocity of the arm
      (vx-arm) ; should be 0 -- just assume it's stationary -- everything should be measured relative to the arm
      (vy-arm)
      
      ;coords of objects
      (x-obj ?obj - object)
      (y-obj ?obj - object)

      ;velocity of objects
      (vx-obj ?obj - object)
      (vy-obj ?obj - object)

      (orbit-clock) ;will let us use a toggle to go between T/F for  in-sun
      (orbit-clock-counter) ;the actual countdown -- should be set to the same value as orbit-clock in most cases
      (sensor-repair-clock) ;sensor can be repaired after a certain amount of time
      (sensor-repair-clock-counter) ;the actual countdown -- should be set to the same value as sensor-repair-clock in most cases

      (battery-level) ;how much battery the arm has currently (affected by charging and draining)
      (battery-drain-rate) ;rate at which the battery drains when in shade
      (battery-charge-rate) ;rate at which the battery charges when in sun
      (full-battery-capacity) ;how much charge the battery can hold (max capacity)

      (num-collisions) ;how many collisions have occurred so far
   )

    ; COLLISION SYSTEM AND DOCKING SYSTEM

   (:event collision-warning ; detects an imminent collision if the velocity of the arm and the object are pointed at each other + the object is too close to the arm
    :parameters (?obj - object) 
    :precondition (and
      (not (catching ?obj))
      (not (moving-to-port ?obj))
      (detected ?obj) ;collision warning system should only work if detection system is working
      (moving ?obj) ;object should be moving
      (not (safety-mode))
      (<= (+ (* (- (vx-arm) (vx-obj ?obj)) (- (x-arm) (x-obj ?obj)))(* (- (vy-arm) (vy-obj ?obj)) (- (y-arm) (y-obj ?obj)))) 0) ; check if object is coming closer rather than moving away
      (<= (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5)(collision-distance)) ;check if they're within a certain distance of each other deemed unsafe
      (not (collision-imminent ?obj)))
    :effect (and
      (collision-imminent ?obj)
      (safety-mode)) ; should trigger collision safety protocol to take place/prevent unsafe actions
   )

    ;need another event for collisions after safety mode has already been entered -- logs new collisions -- otherwise identical to above
   (:event additional-collision-warning
    :parameters (?obj - object) 
    :precondition (and
      (not (catching ?obj))
      (not (moving-to-port ?obj))
      (safety-mode)
      (detected ?obj) 
      (moving ?obj)
      (<= (+ (* (- (vx-arm) (vx-obj ?obj)) (- (x-arm) (x-obj ?obj)))(* (- (vy-arm) (vy-obj ?obj)) (- (y-arm) (y-obj ?obj)))) 0) ; check if object is coming closer rather than moving away
      (<= (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5)(collision-distance)) ;check if they're within a certain distance of each other deemed unsafe
      (not (collision-imminent ?obj))
      (not (failure-collision ?obj)))
    :effect (and
      (collision-imminent ?obj))
   )

   (:event collision ;triggers failure if the distance between an obj and the arm is <= 0.01
    :parameters (?obj - object)
    :precondition (and
      (<= (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj)(y-arm)) 2)) 0.5) 0.01)
      (collision-imminent ?obj) ;see if an object has hit the arm
      (not (failure-collision ?obj)))
    :effect (and 
      (failure-collision ?obj) ;collision failure has occurred
      (increase (num-collisions) 1)
      (not (collision-imminent ?obj))) 
   )

   (:event exit_safety_mode ;exit safety mode if obj is either stationary or if it is far enough away where collision is no longer a concern
    :parameters (?obj - object)
    :precondition (and
      (safety-mode)
      (collision-imminent ?obj)
      (or 
        (> (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5) (collision-distance))
        (and 
          (<= (* (vx-obj ?obj) (vx-obj ?obj)) 0.0025) ;see if it's stationary
          (<= (* (vy-obj ?obj) (vy-obj ?obj)) 0.0025)
        )
      )
    ) 
    :effect (and
      (not (collision-imminent ?obj))
      (not (safety-mode)))
   )

   (:event object_detected ;detect an object if it's within range of the sensor
    :parameters (?obj - trackable)
    :precondition (and ; within range of sensor, not detected previously
      (not (detected ?obj))
      (not (failure-battery-drained))
      (sensor-functional)
      (<= (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5)(sensor-range)))
    :effect (detected ?obj) ; now detected
   )

   (:event object_undetected ;because it moved out of sensor range
    :parameters (?obj - trackable)
    :precondition (and
      (detected ?obj)
      (not (failure-battery-drained))
      (sensor-functional)
      (> (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5)(sensor-range)))
    :effect (not (detected ?obj))
   )

   (:event object_untracked ;because it moved out of sensor range
    :parameters (?obj - trackable)
    :precondition (and
      (tracking ?obj)
      (not (failure-battery-drained))
      (sensor-functional)
      (> (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5)(sensor-range)))
    :effect (not (tracking ?obj))
  )

   (:event spacecraft_aligned ;triggers when velocity has been matched
    :parameters (?c - craft)
    :precondition (and 
      (tracking ?c)
      (and
        (>= (- (vx-arm) (vx-obj ?c)) -0.005) ;check to see if velocity has dropped to 0 (the expected velocity of the arm -- it's relative)
        (<= (- (vx-arm) (vx-obj ?c))  0.005) ;note to self: in the future, this can likely be changed to just not(moving ?c) but i'm not messing with this now... this is a delicate ecosystem
        (>= (- (vy-arm) (vy-obj ?c)) -0.005)
        (<= (- (vy-arm) (vy-obj ?c))  0.005)
      )
      (not (velocity-matched ?c))
      (<= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 10.0)) ;must be close enough to the station
    :effect (and
      (velocity-matched ?c))
   )

   (:event spacecraft_approached ;signifies when a craft has come close enough to the arm to match velocity + be caught
    :parameters (?c - craft)
    :precondition (and
      (tracking ?c)
      (<= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 10.0)
      (not (velocity-matched ?c))
      (not (approached ?c)))
    :effect (approached ?c)
   )

   (:event reached_craft ;signifies when the arm has reached the craft
    :parameters (?c - craft)
    :precondition (and
      (<= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 5)
      (not (at ?c))
      (catching ?c))
    :effect (and
      (at ?c)
      (not (catching ?c))) ;reached craft -- ready to grasp
   )

   (:event arrived_at_port ;signifies when the arm has arrived at the free port to dock the craft
    :parameters (?p - port ?c - craft)
    :precondition (and
      (moving-to-port ?p)
      (holding ?c)
      (<= (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5) 0.1)
      (not (at ?p)))
    :effect (and 
      (not (moving-to-port ?p))
      (at ?p)) ; at the port 
   )

   ;craft approaches the station
   (:process approach_station
    :parameters (?c - craft)
    :precondition (and
      (tracking ?c)
      (not (velocity-matched ?c))
      (not (safety-mode))
      (>= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 10.0)
      ;(sensor-functional) ;seems like more dependent on the craft so commenting these out
      ;(not (battery-low))
      )
    :effect (and
      (increase (x-obj ?c) (* #t (vx-obj ?c)))
      (increase (y-obj ?c) (* #t (vy-obj ?c))))
   )

   ;actually extends the arm towards the craft
   (:process reach_towards_craft
    :parameters (?c - craft)
    :precondition (and
      (tracking ?c)
      (velocity-matched ?c) ; as we're moving, the velocity won't be matched..... not sure if i need this though
      (not (safety-mode))
      (> (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 5) ; stop when 0.1 away -- should set a function for this so it's adjustable
      (catching ?c)
      (sensor-functional)
      (not (battery-low))
      (not (failure-battery-drained)))
    :effect (and
      (decrease (x-arm) (* #t (* (arm-speed)(/ (- (x-arm)(x-obj ?c)) (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c)(y-arm)) 2)) 0.5))))) ; reach towards the craft
      (decrease (y-arm) (* #t (* (arm-speed)(/ (- (y-arm)(y-obj ?c)) (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c)(y-arm)) 2)) 0.5))))))
   )

   (:process move_x ;move everything that has a velocity in the x direction
    :parameters (?obj - object)
    :precondition (and
      (moving ?obj)
      (>= (* (vx-obj ?obj) (vx-obj ?obj)) 0.0025)) ; if close to 0, consider the velocity to be 0
    :effect (increase (x-obj ?obj) (* #t (vx-obj ?obj)))
   )

   (:process move_y ;move everything that has a velocity in the y direction
    :parameters (?obj - object)
    :precondition (and
      (moving ?obj)
      (>= (* (vy-obj ?obj) (vy-obj ?obj)) 0.0025)) ; if close to 0, consider the velocity to be 0
    :effect (increase (y-obj ?obj) (* #t (vy-obj ?obj)))
   )

   (:event stopped_moving ;make object be considered still if velocity is sufficiently low
    :parameters (?obj - object)
    :precondition (and
      (<= (* (vx-obj ?obj) (vx-obj ?obj)) 0.0025) ;note to self: change this to < in the future...... idk why this hasn't broken anything yet
      (<= (* (vy-obj ?obj) (vy-obj ?obj)) 0.0025)
      (moving ?obj))
    :effect (and 
      (not (moving ?obj))
      (assign (vx-obj ?obj) 0)
      (assign (vy-obj ?obj) 0))
   )

   (:process match_velocity ;match craft velocity to the arm/station velocity
    :parameters (?c - craft)
    :precondition (and
      (tracking ?c)
      (not (velocity-matched ?c))
      (<= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 10.0) ; match velocity when craft is close enough
      (not (safety-mode))
      ;(sensor-functional) ;commenting these out because it seems like more of an issue with the station communicating with the incoming craft
      ;(not (battery-low)) 
      ) 
    :effect (and
      (increase (vx-obj ?c) (* #t (* (vx-obj ?c) (craft-deceleration ?c)))) ; make the relative velocity approach 0 -- match the craft whose velocity should also be 0...
      (increase (vy-obj ?c) (* #t (* (vy-obj ?c) (craft-deceleration ?c)))))
   )

   (:process collision_avoidance_debris ; prevents collisions with debris if one is detected by moving it 90 degrees to the velocity of the debris
    :parameters (?d - debris)
    :precondition (and
      (safety-mode)
      (not (failure-battery-drained))
      (sensor-functional)
      (collision-imminent ?d))
    :effect (and
      (increase (x-arm) (* #t (* (arm-speed) (/ (vy-obj ?d) (^ (+ (^ (vx-obj ?d) 2) (^ (vy-obj ?d) 2)) 0.5))))) 
      (increase (y-arm) (* #t (* (arm-speed) (/ (* (vx-obj ?d) -1) (^ (+ (^ (vx-obj ?d) 2) (^ (vy-obj ?d) 2)) 0.5)))))) ; move the arm perpendicular to the velocity of the incoming debris (flip sign)
   )

   (:process collision_avoidance_craft ; prevents collisions if one is detected w a CRAFT -- craft comes to a stop
    :parameters (?c - craft)
    :precondition (and
      (safety-mode)
      (collision-imminent ?c))
    :effect (and
      (increase (vx-obj ?c) (* #t (* (vx-obj ?c) (* (craft-deceleration ?c) 2))))
      (increase (vy-obj ?c) (* #t (* (vy-obj ?c) (* (craft-deceleration ?c) 2)))))
   ) 

   (:process moving_to_port ;move the arm and the captured craft to the port
    :parameters (?p - port ?c - craft)
    :precondition (and
      (moving-to-port ?p)
      (holding ?c)
      (> (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5) 0.1)
      (not (at ?p))
      (not (safety-mode))
      (sensor-functional)
      (not (battery-low))
      (not (failure-battery-drained)))
    :effect (and
      (decrease (x-arm) (* #t (* (arm-speed)(/ (- (x-arm)(x-obj ?p)) (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5))))) ;update arm coords.
      (decrease (y-arm) (* #t (* (arm-speed)(/ (- (y-arm)(y-obj ?p)) (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5))))) 
      (decrease (x-obj ?c) (* #t (* (arm-speed)(/ (- (x-obj ?c)(x-obj ?p)) (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5))))) ;update craft coords.
      (decrease (y-obj ?c) (* #t (* (arm-speed)(/ (- (y-obj ?c)(y-obj ?p)) (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5)))))) 
   )

   (:action track_object ;start tracking an object
    :parameters (?obj - trackable) ;note to self: in the future, change this to ?c - craft -- i don't think we care about tracking debris, just detecting it
    :precondition (and
      (detected ?obj)
      (not (tracking ?obj))
      (sensor-functional)
      (not (battery-low))
      (not (failure-battery-drained))) ; if craft is detected, start tracking it
   :effect (and
      (tracking ?obj))
   )

   (:action catch_craft ;reach out to grasp the craft
    :parameters (?c - craft)
    :precondition (and
      (not (at ?c)) ;make sure you're not already there
      (grasp-free)
      (tracking ?c)
      (velocity-matched ?c)
      (not (safety-mode))
      (> (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 0.1) ; stop when 0.1 away -- should set a function for this so it's adjustable
      (sensor-functional)
      (not (battery-low))
      (not (failure-battery-drained)))  
    :effect (catching ?c)  ;trigger process to move arm to craft
   )

   (:action grasp ; to grasp a particular object
    :parameters (?obj - object)
    :precondition (and
      (at ?obj)
      (grasp-free)
      (velocity-matched ?obj) ;don't want to grab anything coming at us fast
      (sensor-functional)
      (not (battery-low))
      (not (failure-battery-drained))) 
    :effect (and
      (not (grasp-free))
      (holding ?obj)
      (not (at ?obj)))
   )

   (:action go_to_port ;starts the process of moving the arm and craft to a port 
    :parameters (?p - port ?c - craft)
    :precondition (and 
      (not (at ?p))
      (holding ?c)
      (port-free ?p)
      (sensor-functional)
      (not (safety-mode))
      (not (battery-low))
      (not (failure-battery-drained)))
    :effect (moving-to-port ?p)
    )

   (:action dock_craft ;dock the craft at the port
    :parameters (?p - port ?c - craft)
    :precondition (and
      (at ?p)
      (holding ?c)
      (port-free ?p)
      (sensor-functional)
      (not (safety-mode))
      (not (battery-low))
      (not (failure-battery-drained)))
    :effect (and
      (not (holding ?c))
      (not (port-free ?p))
      (grasp-free)
      (successful-dock ?c))
   )


   ;ORBITAL AND ENERGY SYSTEMS

   ;only vital systems should remain active, e.g. collision avoidance + detecting objects with sensors
   ;but shouldn't try to catch/dock ships, for ex.

   ;idea is the arm gets power from the LG which gets power from the sun w solar panels
   ;so we need to model being in shade versus being in sunlight
   ;do this with events/some counter that toggles every k seconds, switching from light to shadow
   ;process of using battery is always on, but changes depending on if we're at low battery or not
   ;charging when in sunlight
   ;draining when in shadow
   ;can define a function for how quickly the battery charges + drains -- if drains faster than charges, might be low power error... need to wait until it's back in the sun to resume operations

   (:process orbit_countdown ;should always be going (paired with events that resets this every k seconds -- see next)
    :parameters ()
    :precondition (>= (orbit-clock-counter) 0)
    :effect (decrease (orbit-clock-counter)(#t))
   )

   (:event toggle_sun_on
    :parameters ()
    :precondition (and
      (<= (orbit-clock-counter) 0)
      (not (in-sun)))
    :effect (and
      (in-sun)
      (increase (orbit-clock-counter) (orbit-clock))) ;go into sunlight
   )

    (:event toggle_sun_off
    :parameters ()
    :precondition (and 
      (<= (orbit-clock-counter) 0)
      (in-sun)) 
    :effect (and
      (not (in-sun))
      (increase (orbit-clock-counter) (orbit-clock))) ;go into shade
   )

   (:event battery_low ;battery reaches some critical threshold that makes it enter a power-conserving mode where only collision avoidance still functions
    :parameters ()
    :precondition (and 
      (not (battery-low))
      (<= (battery-level)(/ (full-battery-capacity) 5))) ;less than 20% of full charge
    :effect (battery-low)
   )

   (:event battery_sufficient ;battery is no longer low and can perform all tasks
    :parameters ()
    :precondition (and
      (battery-low)
      (> (battery-level)(/ (full-battery-capacity) 5))) ;more than 20% of full charge
    :effect (not (battery-low))
   )

   (:event battery_drained ;battery has run out -- failure state
    :parameters ()
    :precondition (and 
      (not (failure-battery-drained))
      (<= (battery-level) 0.05))
    :effect (failure-battery-drained) ;failure -- battery drained
   )

   (:process battery_draining_normal ;normal drain rate of the battery when in shadow
    :parameters ()
    :precondition (and 
      (not (in-sun))
      (not (battery-low))) ;should drain if not in the sun
    :effect (decrease (battery-level) (* #t (battery-drain-rate)))
   )

   (:process battery_draining_critical ;battery drain rate when battery is low (lots of functions disabled) -- set to 50% of normal drain rate
    :parameters ()
    :precondition (and 
      (battery-low)
      (not (in-sun)))
    :effect (decrease (battery-level) (* #t (/ (battery-drain-rate) 2))) ;drain battery by 50% of normal drain rate
    ) 

   (:process battery_charging ;battery charges when station is in the sun
    :parameters ()
    :precondition (in-sun)
    :effect (increase (battery-level) (* #t (battery-charge-rate)))
   )


   ;SENSOR SYSTEM

   ;arm should not do anything if the sensor is broken
   ;becomes functional again after a certain period of time -- set a clock
   ;sensor breaking is caused by collisions

   (:event sensor_broken
    :parameters (?obj - object)
    :precondition (and 
      (failure-collision ?obj) ;sensor should break if a collision occurs
      (sensor-functional))
    :effect (and
      (not (sensor-functional)))
   )

   (:event sensor_fixed ;when countdown runs out, the sensor is repaired
    :parameters ()
    :precondition (and 
      (<= (sensor-repair-clock-counter) 0)
      (not (sensor-functional))) ;when countdown hits 0
    :effect (and 
      (sensor-functional)
      (increase (sensor-repair-clock-counter) (sensor-repair-clock))) ;reset the timer, in case the sensor breaks again
   )

   (:process sensor_repair_countdown ;pretend like it takes a certain amount of time for a person to fix the sensors
    :parameters ()
    :precondition (and
      (> (sensor-repair-clock-counter) 0)
      (not (sensor-functional)))
    :effect (decrease (sensor-repair-clock-counter) (* #t 1)) ;countdown by 1 
   )
)
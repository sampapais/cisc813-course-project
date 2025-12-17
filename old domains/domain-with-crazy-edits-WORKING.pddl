(define (domain canadarm3-real-old)
   (:requirements :typing :negative-preconditions :conditional-effects :adl :fluents)
   (:types craft port debris - object)

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
      (failure-battery-drained);indicates failure -- true when battery is drained
      (battery-low) ;true when battery is below 20% of max capacity
      (approached ?c - craft)
      (moving ?obj - object)
   )

   (:functions
      ;(relative-velocity ?c - craft); relative velocity to the craft, in meters/sec -- GET RID OF THIS -- NO POINT SETTING I THINK
      (collision-distance) ; min distance the craft can be before a collision is a detected
      (sensor-range) ; how far the sensor can see
      (arm-speed) ; how fast the arm should be moving
      (craft-speed ?c - craft)

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
      (orbit-clock-counter)
      (sensor-repair-clock) ;sensor can be repaired after a certain amount of time
      (sensor-repair-clock-counter)

      (battery-level) ;how much battery the arm has currently (affected by charging and draining)
      (battery-drain-rate) ;rate at which the battery drains when in shade
      (battery-charge-rate) ;rate at which the battery charges when in sun
      (full-battery-capacity) ;how much charge the battery can hold (max capacity)
   )

   ;events
   (:event collision-warning ; detects an imminent collision if velocities are pointed at each other + the objs are too close
    :parameters (?obj - object) 
    :precondition (and
      (detected ?obj) 
      (<= (+ (* (- (vx-arm) (vx-obj ?obj)) (- (x-arm) (x-obj ?obj)))(* (- (vy-arm) (vy-obj ?obj)) (- (y-arm) (y-obj ?obj)))) 0) ; see if their velocities are pointed at each other (even if arm velocity is 0 which i think i'll keep it at...)
      (<= (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5)(collision-distance)) ;check if they're within a certain distance of each other deemed unsafe
      (not (collision-imminent ?obj)))
    :effect (and
      (collision-imminent ?obj)
      (safety-mode)) ; should trigger collision safety protocol to take place/prevent unsafe actions
   )

   (:event collision ;COME BACK TO THIS
    :parameters (?obj - object)
    :precondition (<= (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5) 0) ;see if an object has hit the arm
    :effect (failure-collision) ;collision failure has occurred
   )

   (:event exit_safety_mode 
    :parameters (?obj - object)
    :precondition (and
      (safety-mode)
      (collision-imminent ?obj)
      (or (> (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5) (collision-distance))(and (<= (vx-obj ?obj) 0) (<= (vy-obj ?obj) 0)))) ;ok if obj is either still or if it is far enough away where collision is no longer a concern
      ;(and (<= (vx-obj ?obj) 0) (<= (vy-obj ?obj) 0)))
      ;(> (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5) (collision-distance)))
      ;(<= (vx-obj ?obj) 0))
    :effect (and
      (not (collision-imminent ?obj))
      (not (safety-mode)))
   )

   (:event object_detected
    :parameters (?obj - object)
    :precondition (and ; within range of sensor, not detected previously
      (not (detected ?obj))
      (<= (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5)(sensor-range)))
    :effect (detected ?obj) ; now detected
   )

   (:event spacecraft_aligned ;triggers when velocity has been matched
    :parameters (?c - object)
    :precondition (and 
      (tracking ?c)
      (and
        (>= (- (vx-arm) (vx-obj ?c)) -0.005)
        (<= (- (vx-arm) (vx-obj ?c))  0.005)
        (>= (- (vy-arm) (vy-obj ?c)) -0.005)
        (<= (- (vy-arm) (vy-obj ?c))  0.005)
      )
      (not (velocity-matched ?c))
      (<= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 10.0)) ;must be close enough to the station
    :effect (and
      (velocity-matched ?c))
   )

   (:event spacecraft_approached
    :parameters (?c - object)
    :precondition (and
      (tracking ?c)
      (<= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 10.0)
      (not (velocity-matched ?c))
      (not (approached ?c)))
    :effect (approached ?c)
   )

   (:event reached_craft
    :parameters (?c - craft)
    :precondition (and
      (<= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 0.1)
      (not (at ?c))
      (catching ?c))
    :effect (and
      (at ?c)
      (not (catching ?c))) ;reached craft -- ready to grasp
   )

   (:event arrived_at_port
    :parameters (?p - port)
    :precondition (and
      (<= (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5) 0.1)
      (not (at ?p)))
    :effect (at ?p) ; at the port
   )

   ; processes

   ;craft approaches the station
   (:process approach_station
    :parameters (?c - object)
    :precondition (and
      (tracking ?c)
      (not (velocity-matched ?c))
      (not (safety-mode))
      (>= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 10.0)
      ;(sensor-functional) ;seems like more dependent on the craft so commenting these out
      ;(not (battery-low))
      )
    :effect (and
      ;(decrease (x-obj ?c) (* #t (* (craft-speed ?c)(/ (- (x-obj ?c)(x-arm))(^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c)(y-arm)) 2)) 0.5))))) ; move in dir of the craft
      ;(decrease (y-obj ?c) (* #t (* (craft-speed ?c)(/ (- (y-obj ?c)(y-arm))(^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c)(y-arm)) 2)) 0.5))))))
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
      (>= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 0.1) ; stop when 0.1 away -- should set a function for this so it's adjustable
      (catching ?c)
      (sensor-functional)
      (not (battery-low)))
    :effect (and
      (decrease (x-arm) (* #t (* (arm-speed)(/ (- (x-arm)(x-obj ?c)) (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c)(y-arm)) 2)) 0.5))))) ; reach towards the craft
      (decrease (y-arm) (* #t (* (arm-speed)(/ (- (y-arm)(y-obj ?c)) (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c)(y-arm)) 2)) 0.5))))))
   )

   (:process move ;move everything that has a velocity
    :parameters (?obj - object)
    :precondition (and
      ; if close to 0, consider the velocity to be 0
      (moving ?obj)
      (>= (* (vx-obj ?obj) (vx-obj ?obj)) 0.0025)
      (>= (* (vy-obj ?obj) (vy-obj ?obj)) 0.0025)
      ;(>= (^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj) (y-arm)) 2)) 0.5) 10.0)
      (not (detected ?obj)))
    :effect (and
      (increase (x-obj ?obj) (* #t (vx-obj ?obj)))
      (increase (y-obj ?obj) (* #t (vy-obj ?obj))))
      ;(decrease (x-obj ?obj) (* #t (* (craft-speed ?obj)(/ (- (x-obj ?obj)(x-arm))(^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj)(y-arm)) 2)) 0.5))))) ; move in dir of the craft
      ;(decrease (y-obj ?obj) (* #t (* (craft-speed ?obj)(/ (- (y-obj ?obj)(y-arm))(^ (+ (^ (- (x-obj ?obj)(x-arm)) 2)(^ (- (y-obj ?obj)(y-arm)) 2)) 0.5))))))
   )

   (:event stopped_moving
    :parameters (?obj - object)
    :precondition (and
      (<= (* (vx-obj ?obj) (vx-obj ?obj)) 0.0025)
      (<= (* (vy-obj ?obj) (vy-obj ?obj)) 0.0025)
      (moving ?obj))
    :effect (and 
      (not (moving ?obj))
      (assign (vx-obj ?obj) 0)
      (assign (vy-obj ?obj) 0))
    )

   (:process match_velocity
    :parameters (?c - object)
    :precondition (and
      (tracking ?c)
      (not (velocity-matched ?c))
      (<= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 10.0) ; match velocity when craft is close enough
      (not (safety-mode))
      ;(sensor-functional) ;commenting these out because it seems like more of an issue
      ;(not (battery-low)) ;with the station communicating with the incoming craft
      ) 
    :effect (and
      ;(decrease (vx-obj ?c) (* #t 0.1))
      ;(decrease (vy-obj ?c) (* #t 0.1))) ; make the relative velocity approach 0 -- match the craft whose velocity should also be 0...
      (increase (vx-obj ?c) (* #t (* (vx-obj ?c) -0.1)))
      (increase (vy-obj ?c) (* #t (* (vy-obj ?c) -0.1))))
   )

   (:process collision_avoidance_debris ; prevents collisions with debris if one is detected
    :parameters (?d - debris)
    :precondition (and
      (safety-mode)
      (collision-imminent ?d))
    :effect (and
      (increase (x-arm) (* #t (* (arm-speed) (/ (vy-obj ?d) (^ (+ (^ (vx-obj ?d) 2) (^ (vy-obj ?d) 2)) 0.5))))) 
      (increase (y-arm) (* #t (* (arm-speed) (/ (- (vx-obj ?d)) (^ (+ (^ (vx-obj ?d) 2) (^ (vy-obj ?d) 2)) 0.5)))))) ; move the arm perpendicular to the velocity of the incoming debris (flip sign)
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
      (not (safety-mode))
      (sensor-functional)
      (not (battery-low)))
    :effect (and
      (decrease (x-arm) (* #t (* (arm-speed)(/ (- (x-arm)(x-obj ?p)) (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5))))) ;update arm coords.
      (decrease (y-arm) (* #t (* (arm-speed)(/ (- (y-arm)(y-obj ?p)) (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5))))) 
      (decrease (x-obj ?c) (* #t (* (arm-speed)(/ (- (x-obj ?c)(x-obj ?p)) (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5))))) ;update craft coords.
      (decrease (y-obj ?c) (* #t (* (arm-speed)(/ (- (y-obj ?c)(y-obj ?p)) (^ (+ (^ (- (x-obj ?p)(x-arm)) 2)(^ (- (y-obj ?p) (y-arm)) 2)) 0.5)))))) 
   )

   ; discrete actions
   (:action track_craft
    :parameters (?obj - object)
    :precondition (and
      (detected ?obj)
      (not (tracking ?obj))
      (sensor-functional)
      (not (battery-low))) ; if craft is detected, start tracking it -- assuming for now there's only one craft at a time
   :effect (and
      (tracking ?obj))
   )

   (:action catch_craft
    :parameters (?c - craft)
    :precondition (and
      (tracking ?c)
      (velocity-matched ?c) ; as we're moving, the velocity won't be matched..... not sure if i need this though
      (not (safety-mode))
      (>= (^ (+ (^ (- (x-obj ?c)(x-arm)) 2)(^ (- (y-obj ?c) (y-arm)) 2)) 0.5) 0.1) ; stop when 0.1 away -- should set a function for this so it's adjustable
      (sensor-functional)
      (not (battery-low)))  
    :effect (catching ?c)  ;trigger process to move arm to craft
   )

   (:action grasp ; to grasp a particular object
    :parameters (?obj - object)
    :precondition (and
      (at ?obj)
      (grasp-free)
      (velocity-matched ?obj)
      (sensor-functional)
      (not (battery-low))) ;don't want to grab anything coming at us fast
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
      (port-free ?p)
      (sensor-functional)
      (not (battery-low)))
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
      (>= (battery-level)(/ (full-battery-capacity) 5))) ;more than 20% of full charge
    :effect (not (battery-low))
   )

   (:event battery_drained ;battery has run out -- failure state
    :parameters ()
    :precondition (and 
      (not (failure-battery-drained))
      (<= (battery-level) 0))
    :effect (failure-battery-drained) ;failure
   )

   (:process battery_draining_normal
    :parameters ()
    :precondition (and 
      (not (in-sun))
      (not (battery-low))) ;should drain if not in the sun
    :effect (decrease (battery-level) (* #t (battery-drain-rate)))
   )

   (:process battery_draining_critical ;battery drain rate when battery is low (lots of functions disabled) -- set to 50% of normal drain rate?
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

   ;sensor breaks + protocols

   ;arm should not do anything -- should retract as close as possible to the base and wait to be repaired
   ;becomes functional again after a certain period of time -- set a clock
   ;sensor breaking is set in the problem file as a timed initial literal (TIL)
   ;***************** PUT PRECONDITION IN PREVIOUS ACTIONS/PROCESSES/EVENT THAT THEY CAN ONLY BE EXECUTED IF SENSOR IS ACTIVE

   (:event sensor_fixed
    :parameters ()
    :precondition (and 
      (<= (sensor-repair-clock) 0)
      (not (sensor-functional))) ;when countdown hits 0
    :effect (sensor-functional)
   )

   (:process sensor_repair_countdown
    :parameters ()
    :precondition (and
      (> (sensor-repair-clock) 0)
      (not (sensor-functional)))
    :effect (decrease (sensor-repair-clock) (* #t 1)) ;countdown by 1 
   )
)
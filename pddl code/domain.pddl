(define (domain canadarm3)
   (:requirements :typing :fluents :time :durative-actions :numeric-fluents :negative-preconditions 
   :continuous-effects)

   (:types craft port - object
   )

   (:predicates
   ;   (at-obj ?obj - object) ; to indicate the arm is next to an object
   ;   (at-loc ?loc - location) ; to indicate the arm is at a specific location
   ;   (obj-at-loc ?obj - object ?loc - location) ; to indicate an object is at a particular location
   ;   (velocity-matched ?obj - object) ; to indicate when the arm has matched its velocity to another obj
   ;   (holding ?obj - object) ; to indicate what obj the arm is holding
   ;   (grasp-free) ; T/F if the arm is currently holding anything
   ;   (detected ?obj - object) ; indicates if an object has been detected by the sensor
   ;   (collision-imminent ?obj - object) ; collision detected with obj
   ;   (port-free ?port - port) ; indicates if a given port is free -- maybe change to more general location free predicate?
   ;   (tracking ?c - craft) ; indicates which craft we are currently tracking
   ;   (moving) ; if the arm is moving or not
   ;   (safety-mode) ; safety mode indicates we should be trying to recover from a failure 

      (at ?obj - object) ; to indicate the arm is next to an object/location      
      (velocity-matched ?obj - object) ; to indicate when the arm has matched its velocity to another obj
      (holding ?obj - object) ; to indicate what obj the arm is holding
      (grasp-free) ; T/F if the arm is currently holding anything
      (detected ?obj - object) ; indicates if an object has been detected by the sensor
      (collision-imminent ?obj - object) ; collision detected with obj
      (port-free ?port - port) ; indicates if a given port is free -- maybe change to more general location free predicate?
      (tracking ?c - craft) ; indicates which craft we are currently tracking
      (safety-mode) ; safety mode indicates we should be trying to recover from a failure 

      )

      (:functions
      (relative-velocity ?c - craft); relative velocity to the craft, in meters/sec
      (obj-distance ?obj - object); distance from the craft/obj, in meters
      (collision-distance) ; min distance the craft can be before a collision is a detected
      (sensor-range) ; how far the sensor can see
      (arm-speed) ; how fast the arm should be moving

      ;add new coord sys for port and craft
      (x-arm)
      (y-arm)
      
      (x-obj ?obj - object)
      (y-obj ?obj - object)

   )

   ; events
   (:event collision
   :parameters (?c - craft) ; detects an imminent collision if the obj is too close and the velocity is not yet matched
   :precondition (and
      (tracking ?c) 
      (not (velocity-matched ?c))
      (<= (obj-distance ?c)(collision-distance))
      (not (collision-imminent ?c)))
   :effect (and
      (collision-imminent ?c)
      (safety-mode)) ; should trigger collision safety protocol to take place/prevent unsafe actions
   )

   (:event exit_safety_mode ;may need to revisit this -- for all objects/crafts, is it safe to exit safety mode? may be multiple things to consider
   :parameters (?c - craft)
   :precondition (and
      (safety-mode)
      (collision-imminent ?c)
      (> (obj-distance ?c) (collision-distance)))
   :effect (and
      (not (collision-imminent ?c))
      (not (safety-mode)))
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
      (<= (relative-velocity ?c) 0.05) ; some small num -- multipying by time so won't be 0
      (not (velocity-matched ?c))) 
   :effect (and
      (velocity-matched ?c))
   )

   (:event reached_craft
   :parameters (?c - craft)
   :precondition (and
      (<= (obj-distance ?c) 0.1)
      (not (at ?p)))
   :effect ( ; at the port
      (at ?p)
      (not (catching ?c)))
   )

   (:event arrived_at_port
   :parameters (?p - port)
   :precondition (and
      (<= (obj-distance ?p) 0.1)
      (not (at ?p)))
   :effect ( ; at the port
      (at ?p))
   )


   ; processes

   ;probably need a process to continuously update the distance of the arm to other objects?
   ;unless i just dont want to deal w this and compute if the x, y coords are close enough when checking
   ;i dont think i can use sqrt functions anyways?
   ;nvm we can roll with this just use ^0.5
   (:process update-distance 
   :parameters (?obj - object)
   :precondition (>= (obj-distance ?obj) 0.0)
   :effect (assign (obj-distance ?obj) 
                  (^ (+ (^ (- (x-obj ?o)(x-arm)) 2)(^ (- (y-obj ?o) (y-arm)) 2)) 0.5)) ; get dist btw. 2 points
                  ;i think this needs to change with time for it to be a process. hm. 
   )

   ;supposed to represent the station moving closer. might have to remove. irl this wouldn't be how it goes i think.
   ;the craft would have to be responsible for matching velocity with the station and the arm by extension. 
   ;otherwise i think the orbital trajectory of the LG around the moon would be messed up. which would be bad :/
   ;but i'm no rocket scientist. maybe it's actually chill and fine
   (:process approach_craft
   :parameters (?c - craft)
   :precondition (and
      (tracking ?c)
      (not (velocity-matched ?c)) ; as we're moving, the velocity won't be matched..... not sure if i need this though
      (not (safety-mode))
      (>= (obj-distance ?c) 10.0)) ; stop when 10m away -- should set a function for this so it's adjustable
   :effect (and
      (decrease (x-arm) (* #t (arm-speed)(/ (- (x-arm)(x-obj ?c))(obj-distance ?c)))) ; move in dir of the craft
      (decrease (y-arm) (* #t (arm-speed)(/ (- (y-arm)(y-obj ?c))(obj-distance ?c)))))
   )

   ;actually extends the arm towards the craft
   (:process reach_towards_craft
   :parameters (?c - craft)
   :precondition (and
      (tracking ?c)
      (velocity-matched ?c) ; as we're moving, the velocity won't be matched..... not sure if i need this though
      (not (safety-mode))
      (>= (obj-distance ?c) 0.1) ; stop when 0.1 away -- should set a function for this so it's adjustable
      (catching ?c))
   :effect (and
      (decrease (x-arm) (* #t (arm-speed)(/ (- (x-arm)(x-obj ?c)) (obj-distance ?c)))) ; reach towards the craft
      (decrease (y-arm) (* #t (arm-speed)(/ (- (y-arm)(y-obj ?c)) (obj-distance ?c)))))
   )

   ;need to come back to this
   (:process match_velocity
   :parameters (?c - craft)
   :precondition (and
      (tracking ?c)
      (not (velocity-matched ?c))
      (<= (obj-distance ?c) 10.0)
      (not (safety-mode))) ; match velocity when close enough
   :effect (and
      (decrease (relative-velocity ?c) (* #t 0.1))) ; make the relative velocity approach 0
   )

   (:process collision_avoidance ; prevents collisions if one is detected
   :parameters (?c - craft)
   :precondition (and
      (safety-mode)
      (collision-imminent ?c))
   :effect (and
      (increase (x-arm) (* #t (arm-speed)(/ (- (x-arm)(x-obj ?c)) (obj-distance ?c)))) ; makes the arm back away from the object it may collide with
      (increase (y-arm) (* #t (arm-speed)(/ (- (y-arm)(y-obj ?c)) (obj-distance ?c)))))
   ) 

   (:process move_to_dock
   :parameters (?p - port ?c - craft)
   :precondition (and
      (holding ?c)
      (not (at ?p))
      (not (safety-mode)))
   :effect (and
      (decrease (x-arm) (* #t (arm-speed)(/ (- (x-arm)(x-obj ?p)) (obj-distance ?p))))
      (decrease (y-arm) (* #t (arm-speed)(/ (- (y-arm)(y-obj ?p)) (obj-distance ?p)))))
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
      (>= (obj-distance ?c) 0.1) ; stop when 0.1 away -- should set a function for this so it's adjustable
    )  
    :effect ( ;trigger process
      catching ?c)  
   )

   (:action grasp ; to grasp a particular object
   :parameters (?obj - object)
   :precondition (and
      (a-obj ?obj)
      (grasp-free))
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
      (grasp-free))
   )
)
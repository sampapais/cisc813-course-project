(define (domain canadarm3-old3)
   (:requirements :typing :fluents :time :durative-actions :numeric-fluents :negative-preconditions 
   :continuous-effects)

   (:types craft port - object
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
   )

   (:functions
      (relative-velocity ?c - craft); relative velocity to the craft, in meters/sec -- GET RID OF THIS -- NO POINT SETTING I THINK
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
   (:event collision-warning
   :parameters (?c - craft) ; detects an imminent collision if the obj is too close and the velocity is not yet matched
   :precondition (and
      (tracking ?c) 
      (not (velocity-matched ?c))
      (<= {calculate-distance ?c}(collision-distance))
      (not (collision-imminent ?c)))
   :effect (and
      (collision-imminent ?c)
      (safety-mode)) ; should trigger collision safety protocol to take place/prevent unsafe actions
   )

   (:event collision ;COME BACK TO THIS
    :parameters (?c - craft)
    :precondition (<= {calculate-distance ?c} 0)
    :effect (failure-collision) ;collision failure has occurred
   )

   (:event exit_safety_mode ;may need to revisit this -- for all objects/crafts, is it safe to exit safety mode? may be multiple things to consider -- maybe separate into two events? one for triggering that a coll. is no longer imminent w that obj, and another for checking all objs to
                            ; make sure there are no imminent collisions left
   :parameters (?c - craft)
   :precondition (and
      (safety-mode)
      (collision-imminent ?c)
      (> {calculate-distance ?c} (collision-distance)))
   :effect (and
      (not (collision-imminent ?c))
      (not (safety-mode)))
   )

   (:event object_detected
   :parameters (?obj - object)
   :precondition (and ; within range of sensor, not detected previously
      (not (detected ?obj))
      (<= {calculate-distance ?obj}(sensor-range)))
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
      (<= {calculate-distance ?c} 0.1)
      (not (at ?c))
      (catching ?c))
   :effect ( ; at the port
      (at ?c)
      (not (catching ?c)))
   )

   (:event arrived_at_port
   :parameters (?p - port)
   :precondition (and
      (<= {calculate-distance ?p} 0.1)
      (not (at ?p)))
   :effect ( ; at the port
      (at ?p))
   )

   (:event overheated) ;should trigger failure

   (:event getting_hot) ;should trigger cooling system

   (:event cooled_down) ;should deactivate cooling system

   ; processes

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
      (>= {calculate-distance ?c} 10.0)) ; stop when 10m away -- should set a function for this so it's adjustable
   :effect (and
      (decrease (x-arm) (* #t (arm-speed)(/ (- (x-arm)(x-obj ?c)){calculate-distance ?c}))) ; move in dir of the craft
      (decrease (y-arm) (* #t (arm-speed)(/ (- (y-arm)(y-obj ?c)){calculate-distance ?c}))))
   )

   ; revised process where the craft approaches the station instead of the opposite
   (:process approach_station
    :parameters (?c - craft)
    :precondition (and
      (tracking ?c)
      (not (velocity-matched ?c))
      (not (safety-mode))
      (>= {calculate-distance ?c} 10.0))
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

   ;need to come back to this
   (:process match_velocity
   :parameters (?c - craft)
   :precondition (and
      (tracking ?c)
      (not (velocity-matched ?c))
      (<= {calculate-distance ?c} 10.0)
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
      (increase (x-arm) (* #t (arm-speed)(/ (- (x-arm)(x-obj ?c)) {calculate-distance ?c}))) ; makes the arm back away from the object it may collide with
      (increase (y-arm) (* #t (arm-speed)(/ (- (y-arm)(y-obj ?c)) {calculate-distance ?c}))))
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

   (:process rotation_temperature ; models the fluctuating temperature of the arm as the station rotates around the moon
    :parameters ()
    :precondition () ; should always be on
    :effect ()
   )

   (:process solar_flare
    :parameters ()
    :precondition (and
      ())
    :effect(and
      ())
   )

   (:process cool_down
    :parameters ()
    :precondition (and
      ())
    :effect(and
      ())
   )

   (:process lunar_dust)

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
      (grasp-free)
      (successful-dock))
   )
)
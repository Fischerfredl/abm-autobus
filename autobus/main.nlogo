globals [
  seconds
  hours
  minutes
  total_minutes
  time
  routeTB
  routeBT
  schedule
  max-bikers
  bikers-spawn-points

  tram_arrival_ns ;; Second of the arrival of a tram going from north to south
  tram_arrival_sn ;; Second of the arrival of a tram going from south to north
  tram_exists_ns ;; Dummy-Variable ob eine Tram existiert (Evtl überflüssig) => Only one tram per direction at once possible
  tram_exists_sn
  tram_passengers_ns ;; How many passengers the tram going from north to south is transporting that want to get out at Innovationspark/LFU
  tram_passengers_sn ;; How many passengers the tram going from south to north is transporting that want to get out at Innovationspark/LFU

  ;; Counting the employees for not over-spawning employees. The function is check-employees
  count_employees_enterprise_a ;; all employees currently existing that are assigned to Enterprise A
  count_employees_enterprise_b ;; all employees currently existing that are assigned to Enterprise B
  count_employees_enterprise_c ;; all employees currently existing that are assigned to Enterprise C
  count_visitors_bhouse ;; all employees currently existing that are assigned to the Boarding House

  distance_to_pedestrian ;distance of a bus stop to a pedestrian
  rand_pedestrian ;random number to spawn different pedestrians
]

;; ordering of breed represents drawing order on map; breeds declared later overlap those declared earlier
breed [nodes node] ;; nodes are agents representing the stops and turning points of the route the bus drives along
breed [bikers biker]
breed [pedestrians pedestrian] ;; breed pedestrians
breed [trams tram] ;; agents representing the trams
breed [tramriders tramrider] ;; agents representing the tramriders
breed [tr_nodes tr_node] ;; tr_nodes are agents representing the waypoints of the routes of the tramriders
breed [busses bus] ;; agents, representing the autonomus bus

;; attributes of pedestrians
pedestrians-own[
  pedestrian_type
  goalx
  goaly
  crossingx
  crossingy
  next-patchx
  next-patchy
  crossing-street?
  movement_status
  exit_bus_stop
  waiting-time
]

patches-own [
  street
  boardwalk
  misc
]

busses-own [
  target      ;; the node where the bus is currently driving towards
  status      ;; information about the current state of this agent ("driving", "waiting")
  route       ;; list containing the nodes which represents the current route of the bus; either from boarding house to TZI or vice versa
  passengers  ;; list containing agents which are currently on the bus
  BTcalced?   ;; indicates wether boarding time was already calculated or not (used in busBoard function)
  waited      ;; seconds/ticks since bus stopped for boarding
  toWait      ;; seconds/ticks that bus has to wait according to number of passenger getting on/off the bus
]

nodes-own [
  busstop? ;; bool determining wether this is a busstop or not
  name     ;; name of the node for identification
]

bikers-own [
  velocity
  time-alive
]

trams-own[
  t_type ;; Type of the Tram. Splitted in two types, the new trams (NF8 Combino and Cityflex) and the old trams (GT6M)
  t_direction ;; Direction into which the tram goes. 'ns' is for 'north to south' (From Stadtbergen to Haunstetten West). 'sn' is for the opposite direction.
  t_passengers ;; How many passengers the tram is transporting that want to get out at Innovationspark/LFU (vmtl sinnlos, da globale Variable exisitert)
  t_stop_duration ;; How long the tram stands at the stop
  t_duration_after_empty ;; How long the tram stands at the stop after all the passengers wanting to get out left the tram
  t_duration_after_boarding ;; How long the tram stands at the stop after the boarding is done completely (all the passengers wanting to get out left the tram and all the passengers wanting to get in entered the tram)
  t_status ;; Current status of the tram: "arriving" = 'Arriving at the stop', "active" = 'Standing at the stop, doors open', "closed" = 'Standing at the stop, doors locked', "departing" = 'Departing from the stop'
]

tramriders-own [
  tr_home ;; Describes in which direction the home of the tramrider is located. Possible states: "north", "south"
  movement_status ;; Describes the current movement of the tramrider. Possible states: "going to bus stop", "waiting for bus", "going to work", "working", "exiting bus"
  tr_ultimate_destination ;; Describes the ultimate destination the tramrider wants to reach. Possible states: "enterprise a", "enterprise b", enterprise c", "boarding house", "tram_ns", "tram_sn"
  tr_current_destination ;; Describes the current destination the tramrider wants to reach. Possible states are the bus stops, the workplace, the boarding house or the tram station
  tr_target ;; Describes which waypoint a tramrider is targeting in order to reach its destination
  tr_waiting_time ;; Describes how long the tramrider has already waited for the bus
  tr_ragelimit ;; Describes how much a tramrider wants to wait for the bus at maximum
  tr_stop ;; A boolean variable for the collision
  tr_random_val ;; A random variable for several different probability decisions, e.g. for choosing a route
  tr_max_working_time ;; The working time the employee works a day
  tr_time_spent_working ;; The current time an employee has already spent working today
  exit_bus_stop  ;; The bus stop where the tramrider going by bus wants to get out of the bus
]

tr_nodes-own [
  tr_n_id
  tr_n_name
]


;; resets everything and reloads the map
to setup-map
  clear-patches
  setup-patches
  setup
end

;; resets everything but the map (to save loading time)
to setup
  clear-turtles clear-globals clear-drawing clear-all-plots clear-output reset-ticks ;; clear everything but patches
  set hours 0
  set minutes 0
  set seconds 0
  set time ""
  setup-bus
  setup-schedule
  setup-bikers
  setup-pedestrians
  setup-tr_nodes

end

;; reads the maplayer files from the maplayer folder and tranfers the information to the patches
to setup-patches
  ;; fill patch attributes
  file-open "maplayers/layer_rest.txt" ;; layer containing misc objects
  foreach sort patches [ p ->
    ask p [
      if not (file-at-end?)[
        set misc file-read
      ]
    ]
  ]
  file-close

  file-open "maplayers/layer_street.txt" ;; layer containing street
  foreach sort patches [ p ->
    ask p [
      if not (file-at-end?)[
          set street file-read
      ]
    ]
  ]
  file-close

  file-open "maplayers/layer_boardwalk.txt" ;; layer containing boardwalk
  foreach sort patches [ p ->
    ask p [
      if not (file-at-end?)[
          set boardwalk file-read
      ]
    ]
  ]
  file-close

  ;; color patches
  ask patches [
    if (misc = 5) or (misc = 10) or (misc = 1) or (misc = 2)[ ;; dark_green, green_area, abschnitt, bauflaeche
      set pcolor green
    ]
    if (misc = 6) or (misc = 7) or (misc = 8) or (misc = 9)[ ;; enterprises
      set pcolor orange
    ]
    if misc = 13 [ ;; tram
      set pcolor red
    ]
    if misc = 3 [ ;; bhouse
      set pcolor yellow
    ]
    if (misc = 11) or (misc = 4) or (misc = 12) [ ;; no_car, bus_line, schraffur
      set pcolor blue
    ]
    if street = 1 [ ;; street
      set pcolor gray
      set misc 999
    ]
    if boardwalk = 1 [ ;; boardwalk
      set pcolor white
    ]
  ]
end

;; updates globals "time", "hours" and "minutes"
to update-time
  set seconds ticks mod 60
  set total_minutes (floor(ticks / 60)) + 300
  if total_minutes = 1440 [
    set total_minutes 0
  ]
  set minutes (floor(ticks / 60)) mod 60
  set hours ((floor(ticks / 3600)) + 5) mod 24
  let min_str ""
  let hr_str ""
  ifelse minutes < 10 [
    set min_str (word 0 minutes)
  ]
  [
    set min_str (word minutes)
  ]
  ifelse hours < 10 [
    set hr_str (word 0 hours)
  ]
  [
    set hr_str (word hours)
  ]
  set time (word hr_str ":" min_str)
end

;; main function
to go
  update-time
  if hours >= 22 [
    ask turtles [ die ]
    stop
  ]
  process-bus
  process-bikers
  spawn-pedestrians
  move-pedestrians
  check-tram
  move-tramriders
  tick
end



;; ===== BIKER IMPLEMENTATION =====

;; === public ===

;; used in setup
;; setup global variables
to setup-bikers
  if (max-bikers = 0) [ set max-bikers 30] ;; set only if not already set via slider
  set bikers-spawn-points [[278 611] [17 534] [384 44] [615 21] [884 302]]
end

;; used in go
to process-bikers
  bikers-spawn
  bikers-move
  bikers-kill
end

;; === private ===

;; spawn bikers on every spawn-poin
to bikers-spawn
  foreach bikers-spawn-points [
    n ->
    if (count bikers < max-bikers and (ticks mod 60) = 0) [  ;; spawn biker every minute, not more than bikers-max
      create-bikers 1 [
        setxy (item 0 n) (item 1 n)
        set size 10
        set velocity 5
        set time-alive 0
        set color red
      ]
    ]
  ]
end

;; move one biker. seeks possible direction to move
to biker-move
  let turn 0
  let dest patch-at-heading-and-distance heading velocity

  ;; loop looking for turn angle
  while [turn < 360 and (dest = nobody or ([street] of dest) != 1)] [
    ifelse (turn >= 0) [set turn ((turn + 1) * -1)] [set turn (turn * -1)]
    set dest patch-at-heading-and-distance (heading + turn) velocity
  ]

  ;; turn and move only if loop successfull
  if (not (turn >= 360)) [
    set heading ( heading + turn )
    fd velocity
  ]
end

;; move all bikers and increase live counter
to bikers-move
  ask bikers [
    biker-move
    set time-alive time-alive + 1
  ]
end

;; kill bikers near spawn points
to bikers-kill
  ask bikers [
    foreach bikers-spawn-points [
      n ->
      ;; die if close to spawn point and lived longer then a minute
      if (time-alive > 60 and (distancexy (item 0 n) (item 1 n) < 20)) [die]
    ]
  ]
end


;; ===== Pedestrian IMPLEMENTATION =====

to setup-pedestrians
  ask pedestrians[die]
end


;;
; spawn the different types of pedestrians
; atm there are 4 types of pedestrians taking different routes
;;
to spawn-pedestrians
  ; spawn a pedestrian every 20 seconds/ticks
  if (ticks mod 20 = 0) [
    ; set a random number to spawn a random pedestrian-type
    set rand_pedestrian random 6


    if(rand_pedestrian = 0)[
      create-pedestrians 1 [
        set pedestrian_type "no_bus"
        set shape "person"
        set color red
        set xcor 307
        set ycor 507
        set goalx 373
        set goaly 56
        set size 10
        set waiting-time 0
        facexy goalx goaly
      ]
    ]

    if(rand_pedestrian = 1)[
      create-pedestrians 1 [
        set pedestrian_type "bus_to_tram"
        set shape "person"
        set color red
        set xcor 285
        set ycor 620
        set goalx 390
        set goaly 54
        set size 10
        set waiting-time one-of [120 240 480 600]
        set exit_bus_stop "bus_stop_tram"
        facexy goalx goaly
      ]
    ]

    if(rand_pedestrian = 2)[
      create-pedestrians 1 [
        set pedestrian_type "no_bus"
        set shape "person"
        set color red
        set xcor 15
        set ycor 636
        set goalx 267
        set goaly 618
        set size 10
        set waiting-time 0
        facexy goalx goaly
      ]
    ]

    if(rand_pedestrian = 3)[
      create-pedestrians 1 [
        set pedestrian_type "bus_to_center"
        set shape "person"
        set color red
        set xcor 20
        set ycor 527
        set goalx 390
        set goaly 54
        set size 10
        set waiting-time one-of [120 240 480 600]
        set exit_bus_stop "bus_stop_center"
        facexy goalx goaly
      ]
    ]

    if(rand_pedestrian = 4)[
      create-pedestrians 1 [
        set pedestrian_type "no_bus"
        set shape "person"
        set color red
        set xcor 285
        set ycor 620
        set goalx 390
        set goaly 54
        set size 10
        set waiting-time 0
        facexy goalx goaly
      ]
    ]

    if(rand_pedestrian = 5)[
      create-pedestrians 1 [
        set pedestrian_type "no_bus"
        set shape "person"
        set color red
        set xcor 20
        set ycor 527
        set goalx 390
        set goaly 54
        set size 10
        set waiting-time 0
        facexy goalx goaly
      ]
    ]
  ]
end

;;
; move the pedestrians on the map
;;
to move-pedestrians

  ask pedestrians [

    ;if movement_status is "waiting", wait
    ifelse (movement_status = "waiting") [
      pedestrian-wait
    ]
    [
      ;pedestrians can only move if they are visible ( = not on bus)
      if (hidden? = false) [
        ;check if a steet has to be crossed
        check-crossing
        ;die if the goal has been reached
        ifelse ([pxcor] of patch-here = goalx and [pycor] of patch-here = goaly)[
          die
        ]
        [
          ;cross the street if crossing-street? is true or walk normally otherwise
          ifelse (crossing-street? = true) [
            cross-street
          ]
          [
            ;get the distance to the nearest busstop and temporarily save it in distance_to_pedestrian
            ask (min-one-of nodes with [busstop? = true] [distance myself]) [
              set distance_to_pedestrian distance myself
            ]

            ;check if the nearest bus stop is less than 25 away
            ;also check if the pedestrian wants to take the bus
            ;also check if the pedestrian is willing to wait for the bus or has given up
            ;if true, walk to the nearest bus stop
            ;if false, walk on normally
            ifelse (distance_to_pedestrian < 25 and pedestrian_type != "no_bus" and movement_status != "no_more_waiting") [
              walk-to-bus-stop
            ][
              walk-normally
            ]
          ]
        ]
      ]
    ]
  ]
end

;;
; pedestrians check if they are standing at a street that can be crossed
; and set their target coordinates for the crossing of the street
;;
to check-crossing

  if (([pxcor] of patch-here = 360 or [pxcor] of patch-here = 361) and [pycor] of patch-here = 354) [
    set crossing-street? true
    set crossingx 363
    set crossingy 344
  ]

  if (([pxcor] of patch-here = 378 or [pxcor] of patch-here = 379) and ([pycor] of patch-here = 256 or [pycor] of patch-here = 257)) [
    set crossing-street? true
    set crossingx 378
    set crossingy 231
  ]

  if ([pxcor] of patch-here = 317 and [pycor] of patch-here = 527) [
    set crossing-street? true
    set crossingx 324
    set crossingy 508
  ]

  if ([pxcor] of patch-here = 183 and [pycor] of patch-here = 537) [
    set crossing-street? true
    set crossingx 182
    set crossingy 518
  ]

  if ([pxcor] of patch-here = one-of [23 24 25] and [pycor] of patch-here = one-of [381 382]) [
    set crossing-street? true
    set crossingx 25
    set crossingy 369
  ]

  if ([pxcor] of patch-here = 159 and [pycor] of patch-here = 360) [
    set crossing-street? true
    set crossingx 162
    set crossingy 360
  ]

  if ([pxcor] of patch-here = 162 and [pycor] of patch-here = 269) [
    set crossing-street? true
    set crossingx 177
    set crossingy 269
  ]

  if ([pxcor] of patch-here = 373 and goalx != 373 and [pycor] of patch-here = 56 and goaly != 56) [
    set crossing-street? true
    set crossingx 389
    set crossingy 56
  ]

  ;this one could be an old/drunk person who MAY remember how to get home, if not, they go around until they find their goal
  if (([pxcor] of patch-here = 625 or [pxcor] of patch-here = 626 or [pxcor] of patch-here = 627) and [pycor] of patch-here = 330) [
    if (random 5 < 3)[
      set goalx 610
      set goaly 114
    ]
  ]

end


;;
; cross the street if the other side has not been reached yet
;;
to cross-street
  ; if the end of the crossing has been reached, face the goal patch again, walk towards it otherwise
  ifelse ([pxcor] of patch-here = crossingx and [pycor] of patch-here = crossingy) [
    set crossing-street? false
    facexy goalx goaly
  ]
  [
    facexy crossingx crossingy
    fd 1
  ]

end

;;
; READ THIS TO UNDERSTAND WTF IS GOING ON IN THIS FUNCTION
; definition of walking ground: boardwalk or misc = 11 or misc = 4
; check if the patch ahead is walking ground and walk if walkable
; otherwise check the patches left-and-ahead and right-and-ahead for walking ground and go there if walkable
; otherwise check the patches left and right for walking ground and go there if walkable
; otherwise check the patches left-and-ahead and right-and-ahead behind them for walking ground and go there if walkable
; otherwise GET THE FUCK OUT OF HERE!
;;
to walk-normally

  ifelse ([boardwalk] of patch-ahead 1.4 = 1 or [misc] of patch-ahead 1.4 = 11 or [misc] of patch-ahead 1.4 = 4) [
    ;walk with 5 km/h
    fd 1.4

  ]
  [
    ifelse ([boardwalk] of patch-left-and-ahead 45 1 = 1 or [misc] of patch-left-and-ahead 45 1 = 11 or [misc] of patch-left-and-ahead 45 1 = 4) [
      set next-patchx ([pxcor] of patch-left-and-ahead 45 1)
      set next-patchy ([pycor] of patch-left-and-ahead 45 1)
      facexy next-patchx next-patchy
      fd 1.4
    ]
    [
      ifelse ([boardwalk] of patch-right-and-ahead 45 1 = 1 or [misc] of patch-right-and-ahead 45 1 = 11 or [misc] of patch-right-and-ahead 45 1 = 4) [
        set next-patchx ([pxcor] of patch-right-and-ahead 45 1)
        set next-patchy ([pycor] of patch-right-and-ahead 45 1)
        facexy next-patchx next-patchy
        fd 1.4
      ]
      [
        ifelse ([boardwalk] of patch-right-and-ahead 90 1 = 1 or [misc] of patch-right-and-ahead 90 1 = 11 or [misc] of patch-right-and-ahead 90 1 = 4) [
            set next-patchx ([pxcor] of patch-right-and-ahead 90 1)
            set next-patchy ([pycor] of patch-right-and-ahead 90 1)
            facexy next-patchx next-patchy
            ;;setxy next-patchx next-patchy
            fd 1.4
            facexy goalx goaly
        ]
        [
          ifelse ([boardwalk] of patch-left-and-ahead 90 1 = 1 or [misc] of patch-left-and-ahead 90 1 = 11 or [misc] of patch-left-and-ahead 90 1 = 4) [
            set next-patchx ([pxcor] of patch-left-and-ahead 90 1)
            set next-patchy ([pycor] of patch-left-and-ahead 90 1)
            facexy next-patchx next-patchy
            fd 1.4
            facexy goalx goaly
          ]
          [
            ifelse ([boardwalk] of patch-left-and-ahead 135 1 = 1 or [misc] of patch-left-and-ahead 135 1 = 11 or [misc] of patch-left-and-ahead 135 1 = 4) [
              set next-patchx ([pxcor] of patch-left-and-ahead 135 1)
              set next-patchy ([pycor] of patch-left-and-ahead 135 1)
              facexy next-patchx next-patchy
              fd 1.4
              facexy goalx goaly
            ]
            [
              ifelse ([boardwalk] of patch-right-and-ahead 135 1 = 1 or [misc] of patch-right-and-ahead 135 1 = 11 or [misc] of patch-right-and-ahead 135 1 = 4) [
                set next-patchx ([pxcor] of patch-right-and-ahead 135 1)
                set next-patchy ([pycor] of patch-right-and-ahead 135 1)
                facexy next-patchx next-patchy
                fd 1.4
                facexy goalx goaly
              ]
              [
                ; GET THE FUCK OUT!
                die
              ]
            ]
          ]
        ]
      ]
    ]
  ]

end

;;
; walk to the bus stop
;;
to walk-to-bus-stop
  ifelse (distance_to_pedestrian < 2)[
    ;move to the nearest node that is a bus stop
    move-to min-one-of nodes with [busstop? = true] [distance myself]
    set movement_status "waiting"
  ]
  [
    face min-one-of nodes with [busstop? = true] [distance myself]
    fd 1.4
  ]
end

;;
; if the waiting time is > 0, decrement it (simulates a second of waiting), give up otherwise
;;
to pedestrian-wait
  ifelse (waiting-time > 0) [
    ;decrement waiting time
    set waiting-time waiting-time - 1
  ]
  [
    ;pedestrian gives up waiting and decides to walk
    set movement_status "no_more_waiting"
  ]
end








;; ===== BUS IMPLEMENTATION =====
;; reads the bus schedule from one of the txt-files depending on which interval the user chose
to setup-schedule
  file-open (word "schedules/" interval "min.txt")
  if not (file-at-end?) [
    set schedule file-read
  ]
  file-close
end

;; creates the bus instance and sets its initial parameter values
to setup-bus
  setup-bustrack
  create-busses 1 [
    set shape "autobus"
    set color white
    setxy 797 208
    set size 20
    set status "waiting"
    set target one-of nodes with [name = "stop_tram"]
    set route routeTB
    set BTcalced? false
    set toWait 0
    set waited 0
    set passengers nobody
  ]
end

;; sets up the nodes which enable the bus to move along the route
to setup-bustrack
  let coords [[172 517] [166 384] [165 365] [415 346] [733 320] [723 216] [797 208]] ;; xy-coords of the nodes
  let names ["stop_bhouse" "stop_enterpriseC" "turn_1" "stop_center" "turn_2" "turn_3" "stop_tram"] ;; names of the nodes
  create-nodes 7 [
    set hidden? false ;; hide, because nodes are just locigal elements
    set shape "circle"
    set size 15
    set color violet
  ]
  ;; read data from lists above and set agent-variables respectively
  foreach sort nodes [ p ->
    ask p [
      setxy (item 0 (item 0 coords)) (item 1 (item 0 coords))
      set name item 0 names
      ifelse member? "stop" name [
        set busstop? true
      ]
      [
        set busstop? false
      ]
      ;; remove first item from list so next iteration uses new data
      set coords remove-item 0 coords
      set names remove-item 0 names
    ]
  ]

  ;; set up the two routes by placing the nodes in the respective order in a global list
  set routeBT [0 0 0 0 0 0 0] ;; fill lists with dummy values
  set routeTB [0 0 0 0 0 0 0]
  ;; replace dummy values in first route with nodes in right order
  set routeBT replace-item 0 routeBT (one-of nodes with [name = "stop_bhouse"])
  set routeBT replace-item 1 routeBT (one-of nodes with [name = "stop_enterpriseC"])
  set routeBT replace-item 2 routeBT (one-of nodes with [name = "turn_1"])
  set routeBT replace-item 3 routeBT (one-of nodes with [name = "stop_center"])
  set routeBT replace-item 4 routeBT (one-of nodes with [name = "turn_2"])
  set routeBT replace-item 5 routeBT (one-of nodes with [name = "turn_3"])
  set routeBT replace-item 6 routeBT (one-of nodes with [name = "stop_tram"])
  ;; with routeBT complete setting up routeTB becomes easier
  let counter 6
  foreach routeBT [ x ->
    set routeTB replace-item counter routeTB x
    set counter counter - 1
  ]
end

;; executed each tick in go-function; determines status of bus and calls functions respectively
to process-bus
  ask busses [
    ifelse status != "waiting" [ ;; if status is not waiting behave depending on status
     if status = "driving" [
        busDrive
      ]
      if status = "boarding" [
        busBoard
      ]
    ]
    [                           ;; if bus is waiting, watch the time and set status to "boarding" if bus must drive due to schedule
      ;; if time is between 5:30 and 21:00 and bus must drive due to schedule
      if (total_minutes >= 330) and (total_minutes <= 1260) and (member? time schedule) [
        set status "boarding"
      ]
    ]
  ]
end

;; bus behaviour while status is "driving"
to busDrive
  ask busses [
    ifelse distance target <= 3 [               ;; check if bus is near a node and - if yes - move it to this node
      face target
      move-to target
      ifelse [busstop?] of target = true [      ;; check if reached node is a busstop
        set status "boarding"                   ;; if so, set status to "boarding"
      ]
      [
        set target item 0 route                 ;; if node is not a bus stop set new target and update route list and keep status "driving"
        set route remove-item 0 route
      ]
    ]
    [                                           ;; if bus is not near a node, just move it with 12 km/h (3 m/s) towards the next node (target)
      face target
      fd 3
    ]
  ]
end

;; bus behaviour while status is "boarding"
to busBoard
  ask busses [
    ifelse BTcalced? = false [
      calcBoardingTime
    ]
    [ ;; only execute when boardingTime (toWait) is calculated
      ifelse waited < toWait [   ;; if boarding is not yet finished
        set waited waited + 1    ;; add 1 second to waited
      ]
      [                          ;; if boarding time is finished
        set waited 0
        ;; check if this was the last stop on the route
        ifelse length route != 0 [ ;; if not, set status to "driving", set new target and update route list
          set target item 0 route
          set route remove-item 0 route
          set status "driving"
        ]
        [                          ;; if it was the last stop, set status to "waiting" and update route list
          set status "waiting"
          ifelse [name] of target = "stop_tram" [
            set route routeTB
          ]
          [
            set route routeBT
          ]
        ]
        set BTcalced? false        ;; reset BTcalced as well as toWait and waited
        set waited 0
        set toWait 0
      ]
    ]
  ]
end

;; calculates the time necessary for boarding (depending on how many passengers get on/off the bus)
to calcBoardingTime
  let boardingTime 0
  let currentStop [target] of self
  let passengersHopOn nobody
  let passengersHopOff nobody
  let remainingNodesOnRoute []

  ;; add all remaining nodes of the route to the variable
  foreach route [ x ->
    if x != target [ ;; since target is yet set to the node where the bus is currently at; this one is excluded
      set remainingNodesOnRoute lput ([name] of x) remainingNodesOnRoute
    ]
  ]

  ;; check if any possible passengers are waiting for the bus at this stop and add them to "passengersHopOn"
  if (any? ((pedestrians-here) with [movement_status = "waiting_for_bus"])) or
     (any? ((tramriders-here) with [movement_status = "waiting_for_bus"])) [
    show "entered waiting if passengersHopOn"
    set passengersHopOn (turtle-set (pedestrians-here) with [movement_status = "waiting_for_bus"] (tramriders-here) with [movement_status = "waiting_for_bus"])
  ]

  ;; for each passenger that is waiting for the bus, check if the bus is going in the right direction
  ;; for the passenger to reach its "exit_bus_stop"; if that is the case, add 1.5 seconds of boarding time
  if passengersHopOn != nobody [
    foreach passengersHopOn [ p ->
      if member? ([exit_bus_stop] of p) remainingNodesOnRoute [
        set boardingTime boardingTime + 1.5
      ]
    ]
  ]

  ;; check the passenger agentset of the bus for passengers willig to get off the bus at the current stop
  if [passengers] of self != nobody [
    set passengersHopOff ([passengers] of self) with [exit_bus_stop = ([name] of currentStop)]
  ]

  ;; add 1.5 seconds of boarding time foreach passengerHopOff
  if passengersHopOff != nobody [
    set boardingTime boardingTime + ((count passengersHopOff) * 1.5)
  ]
  show passengersHopOff
  show passengersHopOn
  show remainingNodesOnRoute
  set toWait boardingTime ;; set toWait variable so bus waites for this amount of time
  set BTcalced? true      ;; set BTcalced? to true so it's not calculated again
end





;; ===== TRAM IMPLEMENTATION =====

to check-schedule
  ;; Tram schedule for the station Innovationspark/LFU (Date of Last Update: 31.03.2018)
  ;; For simplifying purposes, trams regularly only arrive at a full minute
  if seconds = 0 [
    if hours = 0 [
      if (minutes = 13 or minutes = 0)[ ;;minutes = 0 ist testweise, nachher wieder rauswerfen
        set tram_arrival_ns 1]
      if (minutes = 13 or minutes = 28 or minutes = 0)[
        set tram_arrival_sn 1]
    ]
    if hours = 1 [
      if (minutes = 13 or minutes = 0)[ ; die komplette hour ist testweise, nachher wieder rauswerfen
        set tram_arrival_ns 1]
      if (minutes = 28 or minutes = 0)[
        set tram_arrival_sn 1]
    ]

    if hours = 4 [
      if (minutes = 47 or minutes = 58)[
        set tram_arrival_ns 1]
      if (minutes = 58)[
        set tram_arrival_sn 1]
    ]
    if hours = 5 [
      if (minutes = 13 or minutes = 28 or minutes = 43 or minutes = 52 or minutes = 58)[
        set tram_arrival_ns 1]
      if (minutes = 13 or minutes = 28 or minutes = 43 or minutes = 58)[
        set tram_arrival_sn 1]
    ]
    if hours = 6 [
      if (minutes = 7 or minutes = 13 or minutes = 22 or minutes = 28 or minutes = 38 or minutes = 48 or minutes = 55)[
        set tram_arrival_ns 1]
      if (minutes = 10 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 53 or minutes = 58)[
        set tram_arrival_sn 1]
    ]
    if hours = 7 [
      if (minutes = 3 or minutes = 10 or minutes = 17 or minutes = 22 or minutes = 28 or minutes = 33 or minutes = 38 or minutes = 43 or minutes = 48 or minutes = 53 or minutes = 58)[
        set tram_arrival_ns 1]
      if (minutes = 3 or minutes = 8 or minutes = 13 or minutes = 18 or minutes = 23 or minutes = 30 or minutes = 35 or minutes = 40 or minutes = 48 or minutes = 55)[
        set tram_arrival_sn 1]
    ]
    if hours = 8 [
      if (minutes = 3 or minutes = 8 or minutes = 13 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 55)[
        set tram_arrival_ns 1]
      if (minutes = 3 or minutes = 10 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 55)[
        set tram_arrival_sn 1]
    ]
    if hours = 9 or hours = 10 [
      if (minutes = 3 or minutes = 10 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 55)[
        set tram_arrival_ns 1]
      if (minutes = 3 or minutes = 10 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 55)[
        set tram_arrival_sn 1]
    ]
    if hours = 11 [
      if (minutes = 3 or minutes = 10 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 55)[
        set tram_arrival_ns 1]
      if (minutes = 3 or minutes = 10 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 53 or minutes = 58)[
        set tram_arrival_sn 1]
    ]
    if hours = 12 [
      if (minutes = 3 or minutes = 10 or minutes = 13 or minutes = 18 or minutes = 23 or minutes = 28 or minutes = 33 or minutes = 38 or minutes = 43 or minutes = 48 or minutes = 53 or minutes = 58)[
        set tram_arrival_ns 1]
      if (minutes = 3 or minutes = 8 or minutes = 13 or minutes = 18 or minutes = 23 or minutes = 28 or minutes = 33 or minutes = 38 or minutes = 43 or minutes = 48 or minutes = 53 or minutes = 58)[
        set tram_arrival_sn 1]
    ]
    if hours = 13 or hours = 14 or hours = 15 or hours = 16 [
      if (minutes = 3 or minutes = 8 or minutes = 13 or minutes = 18 or minutes = 23 or minutes = 28 or minutes = 33 or minutes = 38 or minutes = 43 or minutes = 48 or minutes = 53 or minutes = 58)[
        set tram_arrival_ns 1]
      if (minutes = 3 or minutes = 8 or minutes = 13 or minutes = 18 or minutes = 23 or minutes = 28 or minutes = 33 or minutes = 38 or minutes = 43 or minutes = 48 or minutes = 53 or minutes = 58)[
        set tram_arrival_sn 1]
    ]
        if hours = 17 [
      if (minutes = 3 or minutes = 8 or minutes = 13 or minutes = 18 or minutes = 23 or minutes = 28 or minutes = 33 or minutes = 38 or minutes = 43 or minutes = 48 or minutes = 53 or minutes = 58)[
        set tram_arrival_ns 1]
      if (minutes = 3 or minutes = 8 or minutes = 13 or minutes = 18 or minutes = 23 or minutes = 28 or minutes = 33 or minutes = 38 or minutes = 43 or minutes = 48 or minutes = 55)[
        set tram_arrival_sn 1]
    ]
    if hours = 18 [
      if (minutes = 3 or minutes = 8 or minutes = 13 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 55)[
        set tram_arrival_ns 1]
      if (minutes = 3 or minutes = 10 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 55)[
        set tram_arrival_sn 1]
    ]
    if hours = 19 [
      if (minutes = 3 or minutes = 10 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 55)[
        set tram_arrival_ns 1]
      if (minutes = 3 or minutes = 10 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 40 or minutes = 48 or minutes = 55)[
        set tram_arrival_sn 1]
    ]
    if hours = 20 [
      if (minutes = 3 or minutes = 10 or minutes = 18 or minutes = 25 or minutes = 33 or minutes = 43 or minutes = 58)[
        set tram_arrival_ns 1]
      if (minutes = 3 or minutes = 7 or minutes = 13 or minutes = 22 or minutes = 28 or minutes = 37 or minutes = 43 or minutes = 58)[
        set tram_arrival_sn 1]
    ]
    if hours = 21 or hours = 22 or hours = 23[
      if (minutes = 13 or minutes = 28 or minutes = 43 or minutes = 58)[
        set tram_arrival_ns 1]
      if (minutes = 13 or minutes = 28 or minutes = 43 or minutes = 58)[
        set tram_arrival_sn 1]
    ]
  ]
end


to check-tram

  ;; Checking the schedule of the tram
  check-schedule

  ;; Check the standing-durations of the tram
  check-times

  ;; Board entering people
  board-people

  ;; Spawn trams
  spawn-trams

  ;; Proceed the animations of the trams
  animate-trams

  ;; Spawn tramriders
  trams-spawn-tramriders

  ;; resetting the variable of the arrival in order to spawn a tram only once
  set tram_arrival_ns 0
  set tram_arrival_sn 0
end

;;to check-employees
;;  set count_employees_enterprise_a count tramriders with [tr_ultimate_destination = "enterprise a"] + 0 ;; Zeug noch anfügen
;;  set count_employees_enterprise_b count tramriders with [tr_ultimate_destination = "enterprise b"] + 0
;;  set count_employees_enterprise_c count tramriders with [tr_ultimate_destination = "enterprise c"] + 0
;;  set count_visitors_bhouse count tramriders with [tr_ultimate_destination = "boarding house"] + 0
;;end

to check-times
  ;; Calculating the standing time
  ask trams with [t_status = "active" or t_status = "closed"][set t_stop_duration (t_stop_duration + 1)] ;; Increasing by 1 every second

  ;; Calculating the standing time after the people wanting to get out left the tram
  ask trams with [t_direction = "ns" and t_status != "arriving" and t_status != "departing"][if tram_passengers_ns = 0 [set t_duration_after_empty (t_duration_after_empty + 1)]] ;; Increasing by 1 every second
  ask trams with [t_direction = "sn" and t_status != "arriving" and t_status != "departing"][if tram_passengers_sn = 0 [set t_duration_after_empty (t_duration_after_empty + 1)]] ;; Increasing by 1 every second

  ;; Departure of a tram once it surpassed all standing-duration-minimas
  ;; Direction: Haunstetten West
  if tram_exists_ns = 1 [
    ask trams [if (t_status = "closed" and t_stop_duration > 15 and t_duration_after_empty >= 10 and t_duration_after_boarding >= 10) [set t_status "departing"]]
  ]
  ;; Direction: Stadtbergen
  if tram_exists_sn = 1 [
    ask trams [if (t_status = "closed" and t_stop_duration > 15 and t_duration_after_empty >= 10 and t_duration_after_boarding >= 10) [set t_status "departing"]]
  ]
end

to board-people
  ;; Boarding of people wanting to get in
  ;; Direction: Haunstetten West
  ask trams with [t_direction = "ns"][
    ;; Defining the people currently getting into the tram
    let people-getting-in-tram-ns count tramriders with [tr_current_destination = "tram_ns" and xcor = 809 and ycor = 172]
    ;; Setting a maximum for the number of people being able to enter the tram at the same time based on the trams type (new vs old)
    if t_type = "old" and people-getting-in-tram-ns > 8 [set people-getting-in-tram-ns 8]
    if t_type = "new" and people-getting-in-tram-ns > 14 [set people-getting-in-tram-ns 14]
    ;; Simulating the boarding process as killing the boarding agents (Only if the trams' doors are open)
    if t_status = "active" [
      if tram_passengers_ns = 0 [ask n-of people-getting-in-tram-ns tramriders with [tr_current_destination = "tram_ns" and xcor = 809 and ycor = 172] [die]]
    ]
    ;; Locking the doors of the tram and starting the counter after everyone entered the tram
    if tram_passengers_ns = 0 and people-getting-in-tram-ns = 0 and t_duration_after_boarding = 0 and t_status = "active" [set t_status "closed"]
    if tram_passengers_ns = 0 and people-getting-in-tram-ns = 0  and t_status != "arriving" and t_status != "departing" [set t_duration_after_boarding (t_duration_after_boarding + 1)]
    ;; The Tram also has to be able to drive away after the doors are closed, even if there are new people arriving at the station
    if tram_passengers_ns = 0 and people-getting-in-tram-ns > 0 and t_status = "closed" [set t_duration_after_boarding (t_duration_after_boarding + 1)]
  ]
  ;; Direction: Stadtbergen
  ask trams with [t_direction = "sn"][
    ;; Defining the people currently getting into the tram
    let people-getting-in-tram-sn count tramriders with [tr_current_destination = "tram_sn" and xcor = 830 and ycor = 162]
    ;; Setting a maximum for the number of people being able to enter the tram at the same time based on the trams type (new vs old)
    if t_type = "old" and people-getting-in-tram-sn > 8 [set people-getting-in-tram-sn 8]
    if t_type = "new" and people-getting-in-tram-sn > 14 [set people-getting-in-tram-sn 14]
    ;; Simulating the boarding process as killing the boarding agents
    if t_status = "active" [
      if tram_passengers_sn = 0 [ask n-of people-getting-in-tram-sn tramriders with [tr_current_destination = "tram_sn" and xcor = 830 and ycor = 162] [die]]
    ]
    ;; Locking the doors of the tram and starting the counter after everyone entered the tram
    if tram_passengers_sn = 0 and people-getting-in-tram-sn = 0 and t_duration_after_boarding = 0 and t_status = "active" [set t_status "closed"]
    if tram_passengers_sn = 0 and people-getting-in-tram-sn = 0  and t_status != "arriving" and t_status != "departing" [set t_duration_after_boarding (t_duration_after_boarding + 1)]
    ;; The Tram also has to be able to drive away after the doors are closed, even if there are new people arriving at the station
    if tram_passengers_sn = 0 and people-getting-in-tram-sn > 0 and t_status = "closed" [set t_duration_after_boarding (t_duration_after_boarding + 1)]
  ]
end

to spawn-trams
  ;; Spawning of a tram
  ;; Direction: Haunstetten West
  ;; Only if the arrival is true and there is no tram already existing
  if (tram_arrival_ns = 1 and tram_exists_ns = 0) [
    create-trams 1 [
      ;; Setting the model of the tram at random
      ifelse (random 100) > ((11 / 79) * 100) ;; there are 79 regularly active trams belonging to the swa. Only 11 of them are of the "old" model GT6M
        [set t_type "new"]
        [set t_type "old"]

      ;; Setting the initial variables
      set t_direction "ns"
      set t_status "arriving"
      set t_stop_duration 0
      set t_duration_after_empty 0
      set t_duration_after_boarding 0

      ;; Setting the appearance, the starting positing and the heading
      set color green
      if t_type = "new" [set shape "tram_new"]
      if t_type = "old" [set shape "tram_old"]
      set size 80
      set heading 180
      setxy 881 349

      ;; Calculating the number of passengers within the tram
      ;; <> !!! <> VORLÄUFIG (Bis zur Einigung) <> !!! <>: Tramriders can only be spawned when there is still space in one of the three enterprises
      if count_employees_enterprise_a < 40 or count_employees_enterprise_b < 60 or count_employees_enterprise_c < 400 [
        ;; The first number is the factor for the rushhour, the second one the factor for the tram and the third one a random factor
        set tram_passengers_ns floor(1 * 20 * random-float 1.5)]
      ;; Limiting the possible amount of passengers within the trams based on its model, new or old
      if t_type = "new" [
        ;; There is an additional subdivision for new trams. 16 out of 68 newer trams have a maximum amount of passengers of 248. The other 52 have a maximum amount of passengers of 228.
        ifelse random 68 > 16
          [if tram_passengers_ns > 228 [set tram_passengers_ns 228]] ;; Maximum amount of passengers for NFX Combino Serie 2/3 and Cityflex: 228
          [if tram_passengers_ns > 248 [set tram_passengers_ns 248]] ;; Maximum amount of passengers for NFX Combino Serie 1: 248
      ]
      if t_type = "old" [
        if tram_passengers_ns > 159 [set tram_passengers_ns 159] ;; Maximum amount of passengers for GT6M: 159
      ]
    ]
    ;; Setting the tram to existent once it's been created
    set tram_exists_ns 1
  ]

  ;; Direction: Stadtbergen
  ;; Only if the arrival is true and there is no tram already existing
  if (tram_arrival_sn = 1 and tram_exists_sn = 0) [
    create-trams 1 [
      ;; Setting the model of the tram at random
      ifelse (random 100) > ((11 / 79) * 100) ;; there are 79 regularly active trams belonging to the swa. Only 11 of them are of the "old" model GT6M
        [set t_type "new"]
        [set t_type "old"]

      ;; Setting the initial variables
      set t_direction "sn"
      set t_status "arriving"
      set t_stop_duration 0
      set t_duration_after_empty 0
      set t_duration_after_boarding 0

      ;; Setting the appearance, the starting positing and the heading
      set color green
      if t_type = "new" [set shape "tram_new"]
      if t_type = "old" [set shape "tram_old"]
      set size 80
      set heading 0
      setxy 795 77

      ;; Calculating the number of passengers within the tram
      ;; <> !!! <> VORLÄUFIG (Bis zur Einigung) <> !!! <>: Tramriders can only be spawned when there is still space in one of the three enterprises
      if count_employees_enterprise_a < 40 or count_employees_enterprise_b < 60 or count_employees_enterprise_c < 400 [
        ;; The first number is the factor for the rushhour, the second one the factor for the tram and the third one a random factor
        set tram_passengers_sn floor(1 * 2 * random-float 1.5)]
      ;; Limiting the possible amount of passengers within the trams based on its model, new or old
      if t_type = "new" [
        ;; There is an additional subdivision for new trams. 16 out of 68 newer trams have a maximum amount of passengers of 248. The other 52 have a maximum amount of passengers of 228.
        ifelse random 68 > 16
          [if tram_passengers_sn > 228 [set tram_passengers_sn 228]] ;; Maximum amount of passengers for NFX Combino Serie 2/3 and Cityflex: 228
          [if tram_passengers_sn > 248 [set tram_passengers_sn 248]] ;; Maximum amount of passengers for NFX Combino Serie 1: 248
      ]
      if t_type = "old" [
        if tram_passengers_sn > 159 [set tram_passengers_sn 159] ;; Maximum amount of passengers for GT6M: 159
      ]
    ]
    ;; Setting the tram to existent once it's been created
    set tram_exists_sn 1
  ]
end

to animate-trams
  ;; Animation for the departure
  ask trams with [t_status = "departing"][
    ;; Direction: Haunstetten West
    if t_direction = "ns"[
      ;; Killing the tram and setting it to non-existent once it goes out of the map
      if xcor = 785 and ycor = 85 [set tram_exists_ns 0]
      if xcor = 785 and ycor = 85 [die]
      ;; The route of the leaving tram
      if xcor = 785 and ycor = 105 [setxy 785 85]
      if xcor = 785 and ycor = 125 [setxy 785 105]
      if xcor = 795 and ycor = 135 [setxy 785 125]
      if xcor = 785 and ycor = 125 [set heading 180]
      if xcor = 805 and ycor = 150 [setxy 795 135]
      if xcor = 810 and ycor = 160 [setxy 805 150]
      if xcor = 820 and ycor = 178 [setxy 810 160]
    ]
    ;; Direction: Stadtbergen
    if t_direction = "sn"[
      ;; Killing the tram and setting it to non-existent once it goes out of the map
      if xcor = 891 and ycor = 344 [set tram_exists_sn 0]
      if xcor = 891 and ycor = 344 [die]
      ;; The route of the leaving tram
      if xcor = 885 and ycor = 285 [setxy 891 344]
      if xcor = 875 and ycor = 255 [setxy 885 285]
      if xcor = 885 and ycor = 285 [set heading 0]
      if xcor = 860 and ycor = 225 [setxy 875 255]
      if xcor = 855 and ycor = 215 [setxy 860 225]
      if xcor = 860 and ycor = 225 [set heading 20]
      if xcor = 850 and ycor = 203 [setxy 855 215]
      if xcor = 840 and ycor = 187 [setxy 850 203]
      if xcor = 830 and ycor = 173 [setxy 840 187]
    ]
  ]
  ;; Arrival of trams
  ask trams with [t_status = "arriving"][
    ;; Direction: Haunstetten West
    if t_direction = "ns"[
      ;; Activate the tram once it arrived at the stop
      if xcor = 820 and ycor = 178 [set t_status "active"]
      ;; The route of the arriving tram
      if xcor = 830 and ycor = 192 [setxy 820 178]
      if xcor = 840 and ycor = 208 [setxy 830 192]
      if xcor = 845 and ycor = 220 [setxy 840 208]
      if xcor = 850 and ycor = 230 [setxy 845 220]
      if xcor = 865 and ycor = 260 [setxy 850 230]
      if xcor = 850 and ycor = 230 [set heading 210]
      if xcor = 875 and ycor = 290 [setxy 865 260]
      if xcor = 881 and ycor = 349 and tram_arrival_ns = 0 [setxy 875 290]
      if xcor = 875 and ycor = 290 [set heading 200]
    ]
    ;; Direction: Stadtbergen
    if t_direction = "sn"[
      ;; Activate the tram once it arrived at the stop
      if xcor = 830 and ycor = 173 [set t_status "active"]
      ;; The route of the arriving tram
      if xcor = 820 and ycor = 158 [setxy 830 173]
      if xcor = 815 and ycor = 153 [setxy 820 158]
      if xcor = 805 and ycor = 135 [setxy 815 153]
      if xcor = 795 and ycor = 120 [setxy 805 135]
      if xcor = 795 and ycor = 100 [setxy 795 120]
      if xcor = 795 and ycor = 120 [set heading 30]
      if xcor = 795 and ycor = 77 and tram_arrival_sn = 0 [setxy 795 100]
    ]
  ]
end

to trams-spawn-tramriders
  ;; Spawning tramriders

  ;; The spawning of the tramriders is subdivisioned by 1. the tram's direction, 2. the tram's model and 3. the tram's doors

  ;; Direction: Haunstetten West
  ;; Selecting the tram which is being active and going into the right direction for the spawning procedure
  let active-tram-ns one-of trams with [t_direction = "ns" and t_status = "active"]

  ;; New trams
  if active-tram-ns != nobody and [t_type] of active-tram-ns = "new"  [

    ;; Door 1 (single door)
    ;; Tramriders can only be spawned if there are enough passengers on the tram wanting to get out
    if (tram_exists_ns = 1 and tram_passengers_ns >= 1)[
      create-tramriders 1 [
        ;; Setting the cosmetics
        set shape "person"
        set color yellow
        set size 10
        ;; Setting the position outside of the trams' door
        setxy 800 156
        ;; Setting the variables
        ;; Saving the direction the tramrider came from to go back home after the tramrider is done working
        set tr_home "north"
        ;; Since all tramriders intend to go to the bus stop, the movement status is also set to "going to bus stop"
        set movement_status "going to bus stop"
        ;; Calculation of the enterprise the tramrider is working at
        ;; At first, a random value is calculated in order to assign the person in the following step
        ;; 40 people are working at Enterprise A, 60 at Enterprise B, 400 at Enterprise C and 5 are included for the Boarding House
        set tr_random_val random (505 - count_employees_enterprise_a - count_employees_enterprise_b - count_employees_enterprise_c - count_visitors_bhouse)
        ;; Depending of the result for the random value, one of the four possible destinations is chosen
        if tr_random_val <= (40 - count_employees_enterprise_a) [set tr_ultimate_destination "enterprise a"]
        if tr_random_val > (40 - count_employees_enterprise_a) and tr_random_val <= (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) [set tr_ultimate_destination "enterprise b"]
        if tr_random_val > (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) and tr_random_val <= (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) [set tr_ultimate_destination "enterprise c"]
        if tr_random_val > (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) and tr_random_val <= (505 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c + count_visitors_bhouse)) [set tr_ultimate_destination "boarding house"]
        ;; Based on the calculation of the destination of the tramrider, the desired bus stop for existing the bus is chosen:
        ;; Enterprise A: 50% of the employees exit the bus at the stop in the center of the map, 50% exit at enterprise C
        if tr_ultimate_destination = "enterprise a" [
          set tr_random_val random 100
          if tr_random_val > 50 [set exit_bus_stop "bus_stop_center" ]
        ]
        ;; Enterprise B: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise b" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Enterprise C: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise c" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Boarding house: All of the employees exit the bus at the bus stop near the Boarding House
        if tr_ultimate_destination = "boarding house" [set exit_bus_stop "bus_stop_bhouse"]
        ;; A new spawn should also increase the count of people existing for the assigned Enterprise by 1
        if tr_ultimate_destination = "enterprise a" [set count_employees_enterprise_a (count_employees_enterprise_a + 1)] ;; Enterprise A
        if tr_ultimate_destination = "enterprise b" [set count_employees_enterprise_b (count_employees_enterprise_b + 1)] ;; Enterprise B
        if tr_ultimate_destination = "enterprise c" [set count_employees_enterprise_c (count_employees_enterprise_c + 1)] ;; Enterprise C
        if tr_ultimate_destination = "boarding house" [set count_visitors_bhouse (count_visitors_bhouse + 1)] ;; Boarding House
        ;; Since all tramriders intend to go to the bus stop, the current destination is set to the nearest bus stop, which is the bus stop at the tram
        set tr_current_destination "bus_stop_tram"
        ;; The first waypoint after leaving the tram for a tramrider coming from the city is the North Eastern Corner of the TZI
        ;; The tramrider is facing the waypoint immediatly after leaving the tram
        set tr_target one-of tr_nodes with [tr_n_name = "TZI NE-Corner"]
        face tr_target
        ;; Setting the waiting time to 0
        set tr_waiting_time 0
        ;; Setting the ragelimt based on probability
        ifelse random 100 > 20
          ;; The Maximum waiting time for the bus is 5 Minutes
          [set tr_ragelimit random 300]
          ;; 20% of people don't even want to intend the bus
          [set tr_ragelimit 0]
      ]
      ;; passengers who left are being subtracted from the total count
      set tram_passengers_ns (tram_passengers_ns - 1)
    ]

    ;; Door 2 (double door)
    ;; Tramriders can only be spawned if there are enough passengers on the tram wanting to get out
    if (tram_exists_ns = 1 and tram_passengers_ns >= 2)[
      create-tramriders 2 [
        ;; Setting the cosmetics
        set shape "person"
        set color yellow
        set size 10
        ;; Setting the position outside of the trams' door
        setxy 804 165
        ;; Setting the variables
        ;; Saving the direction the tramrider came from to go back home after the tramrider is done working
        set tr_home "north"
        ;; Since all tramriders intend to go to the bus stop, the movement status is also set to "going to bus stop"
        set movement_status "going to bus stop"
        ;; Calculation of the enterprise the tramrider is working at
        ;; At first, a random value is calculated in order to assign the person in the following step
        ;; 40 people are working at Enterprise A, 60 at Enterprise B, 400 at Enterprise C and 5 are included for the Boarding House
        set tr_random_val random (505 - count_employees_enterprise_a - count_employees_enterprise_b - count_employees_enterprise_c - count_visitors_bhouse)
        ;; Depending of the result for the random value, one of the four possible destinations is chosen
        if tr_random_val <= (40 - count_employees_enterprise_a) [set tr_ultimate_destination "enterprise a"]
        if tr_random_val > (40 - count_employees_enterprise_a) and tr_random_val <= (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) [set tr_ultimate_destination "enterprise b"]
        if tr_random_val > (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) and tr_random_val <= (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) [set tr_ultimate_destination "enterprise c"]
        if tr_random_val > (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) and tr_random_val <= (505 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c + count_visitors_bhouse)) [set tr_ultimate_destination "boarding house"]
        ;; Based on the calculation of the destination of the tramrider, the desired bus stop for existing the bus is chosen:
        ;; Enterprise A: 50% of the employees exit the bus at the stop in the center of the map, 50% exit at enterprise C
        if tr_ultimate_destination = "enterprise a" [
          set tr_random_val random 100
          if tr_random_val > 50 [set exit_bus_stop "bus_stop_center" ]
        ]
        ;; Enterprise B: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise b" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Enterprise C: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise c" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Boarding house: All of the employees exit the bus at the bus stop near the Boarding House
        if tr_ultimate_destination = "boarding house" [set exit_bus_stop "bus_stop_bhouse"]
        ;; A new spawn should also increase the count of people existing for the assigned Enterprise by 1
        if tr_ultimate_destination = "enterprise a" [set count_employees_enterprise_a (count_employees_enterprise_a + 1)] ;; Enterprise A
        if tr_ultimate_destination = "enterprise b" [set count_employees_enterprise_b (count_employees_enterprise_b + 1)] ;; Enterprise B
        if tr_ultimate_destination = "enterprise c" [set count_employees_enterprise_c (count_employees_enterprise_c + 1)] ;; Enterprise C
        if tr_ultimate_destination = "boarding house" [set count_visitors_bhouse (count_visitors_bhouse + 1)] ;; Boarding House
        ;; Since all tramriders intend to go to the bus stop, the current destination is set to the nearest bus stop, which is the bus stop at the tram
        set tr_current_destination "bus_stop_tram"
        ;; The first waypoint after leaving the tram for a tramrider coming from the city is the North Eastern Corner of the TZI
        ;; The tramrider is facing the waypoint immediatly after leaving the tram
        set tr_target one-of tr_nodes with [tr_n_name = "TZI NE-Corner"]
        face tr_target
        ;; Setting the waiting time to 0
        set tr_waiting_time 0
        ;; Setting the ragelimt based on probability
        ifelse random 100 > 20
          ;; The Maximum waiting time for the bus is 5 Minutes
          [set tr_ragelimit random 300]
          ;; 20% of people don't even want to intend the bus
          [set tr_ragelimit 0]
      ]
      ;; passengers who left are being subtracted from the total count
      set tram_passengers_ns (tram_passengers_ns - 2)
    ]
  ]

  ;; Old trams
  if active-tram-ns != nobody and [t_type] of active-tram-ns = "old" [

    ;; Door 1 (double door)
    ;; Tramriders can only be spawned if there are enough passengers on the tram wanting to get out
    if (tram_exists_ns = 1 and tram_passengers_ns >= 2)[
      create-tramriders 2 [
        ;; Setting the cosmetics
        set shape "person"
        set color yellow
        set size 10
        ;; Setting the position outside of the trams' door
        setxy 807 168
        ;; Setting the variables
        ;; Saving the direction the tramrider came from to go back home after the tramrider is done working
        set tr_home "north"
        ;; Since all tramriders intend to go to the bus stop, the movement status is also set to "going to bus stop"
        set movement_status "going to bus stop"
        ;; Calculation of the enterprise the tramrider is working at
        ;; At first, a random value is calculated in order to assign the person in the following step
        ;; 40 people are working at Enterprise A, 60 at Enterprise B, 400 at Enterprise C and 5 are included for the Boarding House
        set tr_random_val random (505 - count_employees_enterprise_a - count_employees_enterprise_b - count_employees_enterprise_c - count_visitors_bhouse)
        ;; Depending of the result for the random value, one of the four possible destinations is chosen
        if tr_random_val <= (40 - count_employees_enterprise_a) [set tr_ultimate_destination "enterprise a"]
        if tr_random_val > (40 - count_employees_enterprise_a) and tr_random_val <= (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) [set tr_ultimate_destination "enterprise b"]
        if tr_random_val > (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) and tr_random_val <= (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) [set tr_ultimate_destination "enterprise c"]
        if tr_random_val > (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) and tr_random_val <= (505 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c + count_visitors_bhouse)) [set tr_ultimate_destination "boarding house"]
        ;; Based on the calculation of the destination of the tramrider, the desired bus stop for existing the bus is chosen:
        ;; Enterprise A: 50% of the employees exit the bus at the stop in the center of the map, 50% exit at enterprise C
        if tr_ultimate_destination = "enterprise a" [
          set tr_random_val random 100
          if tr_random_val > 50 [set exit_bus_stop "bus_stop_center" ]
        ]
        ;; Enterprise B: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise b" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Enterprise C: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise c" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Boarding house: All of the employees exit the bus at the bus stop near the Boarding House
        if tr_ultimate_destination = "boarding house" [set exit_bus_stop "bus_stop_bhouse"]
        ;; A new spawn should also increase the count of people existing for the assigned Enterprise by 1
        if tr_ultimate_destination = "enterprise a" [set count_employees_enterprise_a (count_employees_enterprise_a + 1)] ;; Enterprise A
        if tr_ultimate_destination = "enterprise b" [set count_employees_enterprise_b (count_employees_enterprise_b + 1)] ;; Enterprise B
        if tr_ultimate_destination = "enterprise c" [set count_employees_enterprise_c (count_employees_enterprise_c + 1)] ;; Enterprise C
        if tr_ultimate_destination = "boarding house" [set count_visitors_bhouse (count_visitors_bhouse + 1)] ;; Boarding House
        ;; Since all tramriders intend to go to the bus stop, the current destination is set to the nearest bus stop, which is the bus stop at the tram
        set tr_current_destination "bus_stop_tram"
        ;; The first waypoint after leaving the tram for a tramrider coming from the city is the North Eastern Corner of the TZI
        ;; The tramrider is facing the waypoint immediatly after leaving the tram
        set tr_target one-of tr_nodes with [tr_n_name = "TZI NE-Corner"]
        face tr_target
        ;; Setting the waiting time to 0
        set tr_waiting_time 0
        ;; Setting the ragelimt based on probability
        ifelse random 100 > 20
          ;; The Maximum waiting time for the bus is 5 Minutes
          [set tr_ragelimit random 300]
          ;; 20% of people don't even want to intend the bus
          [set tr_ragelimit 0]
      ]
      ;; passengers who left are being subtracted from the total count
      set tram_passengers_ns (tram_passengers_ns - 2)
    ]

    ;; Exceptional case: Since old trams only have double-doors, if one passenger is remaining in the tram, he also needs to get out
    if (tram_exists_ns = 1 and tram_passengers_ns = 1)[
      create-tramriders 1 [
        ;; Setting the cosmetics
        set shape "person"
        set color yellow
        set size 10
        ;; Setting the position outside of the trams' door
        setxy 807 168
        ;; Setting the variables
        ;; Saving the direction the tramrider came from to go back home after the tramrider is done working
        set tr_home "north"
        ;; Since all tramriders intend to go to the bus stop, the movement status is also set to "going to bus stop"
        set movement_status "going to bus stop"
        ;; Calculation of the enterprise the tramrider is working at
        ;; At first, a random value is calculated in order to assign the person in the following step
        ;; 40 people are working at Enterprise A, 60 at Enterprise B, 400 at Enterprise C and 5 are included for the Boarding House
        set tr_random_val random (505 - count_employees_enterprise_a - count_employees_enterprise_b - count_employees_enterprise_c - count_visitors_bhouse)
        ;; Depending of the result for the random value, one of the four possible destinations is chosen
        if tr_random_val <= (40 - count_employees_enterprise_a) [set tr_ultimate_destination "enterprise a"]
        if tr_random_val > (40 - count_employees_enterprise_a) and tr_random_val <= (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) [set tr_ultimate_destination "enterprise b"]
        if tr_random_val > (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) and tr_random_val <= (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) [set tr_ultimate_destination "enterprise c"]
        if tr_random_val > (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) and tr_random_val <= (505 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c + count_visitors_bhouse)) [set tr_ultimate_destination "boarding house"]
        ;; Based on the calculation of the destination of the tramrider, the desired bus stop for existing the bus is chosen:
        ;; Enterprise A: 50% of the employees exit the bus at the stop in the center of the map, 50% exit at enterprise C
        if tr_ultimate_destination = "enterprise a" [
          set tr_random_val random 100
          if tr_random_val > 50 [set exit_bus_stop "bus_stop_center" ]
        ]
        ;; Enterprise B: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise b" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Enterprise C: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise c" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Boarding house: All of the employees exit the bus at the bus stop near the Boarding House
        if tr_ultimate_destination = "boarding house" [set exit_bus_stop "bus_stop_bhouse"]
        ;; A new spawn should also increase the count of people existing for the assigned Enterprise by 1
        if tr_ultimate_destination = "enterprise a" [set count_employees_enterprise_a (count_employees_enterprise_a + 1)] ;; Enterprise A
        if tr_ultimate_destination = "enterprise b" [set count_employees_enterprise_b (count_employees_enterprise_b + 1)] ;; Enterprise B
        if tr_ultimate_destination = "enterprise c" [set count_employees_enterprise_c (count_employees_enterprise_c + 1)] ;; Enterprise C
        if tr_ultimate_destination = "boarding house" [set count_visitors_bhouse (count_visitors_bhouse + 1)] ;; Boarding House
        ;; Since all tramriders intend to go to the bus stop, the current destination is set to the nearest bus stop, which is the bus stop at the tram
        set tr_current_destination "bus_stop_tram"
        ;; The first waypoint after leaving the tram for a tramrider coming from the city is the North Eastern Corner of the TZI
        ;; The tramrider is facing the waypoint immediatly after leaving the tram
        set tr_target one-of tr_nodes with [tr_n_name = "TZI NE-Corner"]
        face tr_target
        ;; Setting the waiting time to 0
        set tr_waiting_time 0
        ;; Setting the ragelimt based on probability
        ifelse random 100 > 20
          ;; The Maximum waiting time for the bus is 5 Minutes
          [set tr_ragelimit random 300]
          ;; 20% of people don't even want to intend the bus
          [set tr_ragelimit 0]
      ]
      ;; passengers who left are being subtracted from the total count
      set tram_passengers_ns (tram_passengers_ns - 1)
    ]
  ]

  ;; Direction: Stadtbergen
  ;; Selecting the tram which is being active and going into the right direction for the spawning procedure
  let active-tram-sn one-of trams with [t_direction = "sn" and t_status = "active"]

  ;; New trams
  if active-tram-sn != nobody and [t_type] of active-tram-sn = "new"  [

    ;; Door 1 (single door)
    ;; Tramriders can only be spawned if there are enough passengers on the tram wanting to get out
    if (tram_exists_sn = 1 and tram_passengers_sn >= 1)[
      create-tramriders 1 [
        ;; Setting the cosmetics
        set shape "person"
        set color yellow
        set size 10
        ;; Setting the position outside of the trams' door
        setxy 849 196
        ;; Setting the variables
        ;; Saving the direction the tramrider came from to go back home after the tramrider is done working
        set tr_home "south"
        ;; Since all tramriders intend to go to the bus stop, the movement status is also set to "going to bus stop"
        set movement_status "going to bus stop"
        ;; Calculation of the enterprise the tramrider is working at
        ;; At first, a random value is calculated in order to assign the person in the following step
        ;; 40 people are working at Enterprise A, 60 at Enterprise B, 400 at Enterprise C and 5 are included for the Boarding House
        set tr_random_val random (505 - count_employees_enterprise_a - count_employees_enterprise_b - count_employees_enterprise_c - count_visitors_bhouse)
        ;; Depending of the result for the random value, one of the four possible destinations is chosen
        if tr_random_val <= (40 - count_employees_enterprise_a) [set tr_ultimate_destination "enterprise a"]
        if tr_random_val > (40 - count_employees_enterprise_a) and tr_random_val <= (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) [set tr_ultimate_destination "enterprise b"]
        if tr_random_val > (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) and tr_random_val <= (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) [set tr_ultimate_destination "enterprise c"]
        if tr_random_val > (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) and tr_random_val <= (505 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c + count_visitors_bhouse)) [set tr_ultimate_destination "boarding house"]
        ;; Based on the calculation of the destination of the tramrider, the desired bus stop for existing the bus is chosen:
        ;; Enterprise A: 50% of the employees exit the bus at the stop in the center of the map, 50% exit at enterprise C
        if tr_ultimate_destination = "enterprise a" [
          set tr_random_val random 100
          if tr_random_val > 50 [set exit_bus_stop "bus_stop_center" ]
        ]
        ;; Enterprise B: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise b" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Enterprise C: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise c" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Boarding house: All of the employees exit the bus at the bus stop near the Boarding House
        if tr_ultimate_destination = "boarding house" [set exit_bus_stop "bus_stop_bhouse"]
        ;; A new spawn should also increase the count of people existing for the assigned Enterprise by 1
        if tr_ultimate_destination = "enterprise a" [set count_employees_enterprise_a (count_employees_enterprise_a + 1)] ;; Enterprise A
        if tr_ultimate_destination = "enterprise b" [set count_employees_enterprise_b (count_employees_enterprise_b + 1)] ;; Enterprise B
        if tr_ultimate_destination = "enterprise c" [set count_employees_enterprise_c (count_employees_enterprise_c + 1)] ;; Enterprise C
        if tr_ultimate_destination = "boarding house" [set count_visitors_bhouse (count_visitors_bhouse + 1)] ;; Boarding House
        ;; Since all tramriders intend to go to the bus stop, the current destination is set to the nearest bus stop, which is the bus stop at the tram
        set tr_current_destination "bus_stop_tram"
        ;; The first waypoint after leaving the tram for a tramrider coming from the city is the North Eastern Corner of the TZI
        ;; The tramrider is facing the waypoint immediatly after leaving the tram
        set tr_target one-of tr_nodes with [tr_n_name = "sn tram crossing"]
        face tr_target
        ;; Setting the waiting time to 0
        set tr_waiting_time 0
        ;; Setting the ragelimt based on probability
        ifelse random 100 > 20
          ;; The Maximum waiting time for the bus is 5 Minutes
          [set tr_ragelimit random 300]
          ;; 20% of people don't even want to intend the bus
          [set tr_ragelimit 0]
      ]
      ;; passengers who left are being subtracted from the total count
      set tram_passengers_sn (tram_passengers_sn - 1)
    ]

    ;; Door 2 (double door)
    ;; Tramriders can only be spawned if there are enough passengers on the tram wanting to get out
    if (tram_exists_sn = 1 and tram_passengers_sn >= 2)[
      create-tramriders 2 [
        ;; Setting the cosmetics
        set shape "person"
        set color yellow
        set size 10
        ;; Setting the position outside of the trams' door
        setxy 845 189
        ;; Setting the variables
        ;; Saving the direction the tramrider came from to go back home after the tramrider is done working
        set tr_home "south"
        ;; Since all tramriders intend to go to the bus stop, the movement status is also set to "going to bus stop"
        set movement_status "going to bus stop"
        ;; Calculation of the enterprise the tramrider is working at
        ;; At first, a random value is calculated in order to assign the person in the following step
        ;; 40 people are working at Enterprise A, 60 at Enterprise B, 400 at Enterprise C and 5 are included for the Boarding House
        set tr_random_val random (505 - count_employees_enterprise_a - count_employees_enterprise_b - count_employees_enterprise_c - count_visitors_bhouse)
        ;; Depending of the result for the random value, one of the four possible destinations is chosen
        if tr_random_val <= (40 - count_employees_enterprise_a) [set tr_ultimate_destination "enterprise a"]
        if tr_random_val > (40 - count_employees_enterprise_a) and tr_random_val <= (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) [set tr_ultimate_destination "enterprise b"]
        if tr_random_val > (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) and tr_random_val <= (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) [set tr_ultimate_destination "enterprise c"]
        if tr_random_val > (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) and tr_random_val <= (505 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c + count_visitors_bhouse)) [set tr_ultimate_destination "boarding house"]
        ;; Based on the calculation of the destination of the tramrider, the desired bus stop for existing the bus is chosen:
        ;; Enterprise A: 50% of the employees exit the bus at the stop in the center of the map, 50% exit at enterprise C
        if tr_ultimate_destination = "enterprise a" [
          set tr_random_val random 100
          if tr_random_val > 50 [set exit_bus_stop "bus_stop_center" ]
        ]
        ;; Enterprise B: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise b" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Enterprise C: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise c" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Boarding house: All of the employees exit the bus at the bus stop near the Boarding House
        if tr_ultimate_destination = "boarding house" [set exit_bus_stop "bus_stop_bhouse"]
        ;; A new spawn should also increase the count of people existing for the assigned Enterprise by 1
        if tr_ultimate_destination = "enterprise a" [set count_employees_enterprise_a (count_employees_enterprise_a + 1)] ;; Enterprise A
        if tr_ultimate_destination = "enterprise b" [set count_employees_enterprise_b (count_employees_enterprise_b + 1)] ;; Enterprise B
        if tr_ultimate_destination = "enterprise c" [set count_employees_enterprise_c (count_employees_enterprise_c + 1)] ;; Enterprise C
        if tr_ultimate_destination = "boarding house" [set count_visitors_bhouse (count_visitors_bhouse + 1)] ;; Boarding House
        ;; Since all tramriders intend to go to the bus stop, the current destination is set to the nearest bus stop, which is the bus stop at the tram
        set tr_current_destination "bus_stop_tram"
        ;; The first waypoint after leaving the tram for a tramrider coming from the city is the North Eastern Corner of the TZI
        ;; The tramrider is facing the waypoint immediatly after leaving the tram
        set tr_target one-of tr_nodes with [tr_n_name = "sn tram crossing"]
        face tr_target
        ;; Setting the waiting time to 0
        set tr_waiting_time 0
        ;; Setting the ragelimt based on probability
        ifelse random 100 > 20
          ;; The Maximum waiting time for the bus is 5 Minutes
          [set tr_ragelimit random 300]
          ;; 20% of people don't even want to intend the bus
          [set tr_ragelimit 0]
      ]
      ;; passengers who left are being subtracted from the total count
      set tram_passengers_sn (tram_passengers_sn - 2)
    ]
  ]

  ;; Old trams
  if active-tram-sn != nobody and [t_type] of active-tram-sn = "old" [

    ;; Door 1 (double door)
    if (tram_exists_sn = 1 and tram_passengers_sn >= 2)[
      create-tramriders 2 [
        ;; Setting the cosmetics
        set shape "person"
        set color yellow
        set size 10
        ;; Setting the position outside of the trams' door
        setxy 841 182
        ;; Setting the variables
        ;; Saving the direction the tramrider came from to go back home after the tramrider is done working
        set tr_home "south"
        ;; Since all tramriders intend to go to the bus stop, the movement status is also set to "going to bus stop"
        set movement_status "going to bus stop"
        ;; Calculation of the enterprise the tramrider is working at
        ;; At first, a random value is calculated in order to assign the person in the following step
        ;; 40 people are working at Enterprise A, 60 at Enterprise B, 400 at Enterprise C and 5 are included for the Boarding House
        set tr_random_val random (505 - count_employees_enterprise_a - count_employees_enterprise_b - count_employees_enterprise_c - count_visitors_bhouse)
        ;; Depending of the result for the random value, one of the four possible destinations is chosen
        if tr_random_val <= (40 - count_employees_enterprise_a) [set tr_ultimate_destination "enterprise a"]
        if tr_random_val > (40 - count_employees_enterprise_a) and tr_random_val <= (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) [set tr_ultimate_destination "enterprise b"]
        if tr_random_val > (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) and tr_random_val <= (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) [set tr_ultimate_destination "enterprise c"]
        if tr_random_val > (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) and tr_random_val <= (505 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c + count_visitors_bhouse)) [set tr_ultimate_destination "boarding house"]
        ;; Based on the calculation of the destination of the tramrider, the desired bus stop for existing the bus is chosen:
        ;; Enterprise A: 50% of the employees exit the bus at the stop in the center of the map, 50% exit at enterprise C
        if tr_ultimate_destination = "enterprise a" [
          set tr_random_val random 100
          if tr_random_val > 50 [set exit_bus_stop "bus_stop_center" ]
        ]
        ;; Enterprise B: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise b" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Enterprise C: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise c" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Boarding house: All of the employees exit the bus at the bus stop near the Boarding House
        if tr_ultimate_destination = "boarding house" [set exit_bus_stop "bus_stop_bhouse"]
        ;; A new spawn should also increase the count of people existing for the assigned Enterprise by 1
        if tr_ultimate_destination = "enterprise a" [set count_employees_enterprise_a (count_employees_enterprise_a + 1)] ;; Enterprise A
        if tr_ultimate_destination = "enterprise b" [set count_employees_enterprise_b (count_employees_enterprise_b + 1)] ;; Enterprise B
        if tr_ultimate_destination = "enterprise c" [set count_employees_enterprise_c (count_employees_enterprise_c + 1)] ;; Enterprise C
        if tr_ultimate_destination = "boarding house" [set count_visitors_bhouse (count_visitors_bhouse + 1)] ;; Boarding House
        ;; Since all tramriders intend to go to the bus stop, the current destination is set to the nearest bus stop, which is the bus stop at the tram
        set tr_current_destination "bus_stop_tram"
        ;; The first waypoint after leaving the tram for a tramrider coming from the city is the North Eastern Corner of the TZI
        ;; The tramrider is facing the waypoint immediatly after leaving the tram
        set tr_target one-of tr_nodes with [tr_n_name = "sn tram crossing"]
        face tr_target
        ;; Setting the waiting time to 0
        set tr_waiting_time 0
        ;; Setting the ragelimt based on probability
        ifelse random 100 > 20
          ;; The Maximum waiting time for the bus is 5 Minutes
          [set tr_ragelimit random 300]
          ;; 20% of people don't even want to intend the bus
          [set tr_ragelimit 0]
      ]
      ;; passengers who left are being subtracted from the total count
      set tram_passengers_sn (tram_passengers_sn - 2)
    ]

    ;; If only 1 passenger remains
    if (tram_exists_sn = 1 and tram_passengers_sn = 1)[
      create-tramriders 1 [
        ;; Setting the cosmetics
        set shape "person"
        set color yellow
        set size 10
        ;; Setting the position outside of the trams' door
        setxy 841 182
        ;; Setting the variables
        ;; Saving the direction the tramrider came from to go back home after the tramrider is done working
        set tr_home "south"
        ;; Since all tramriders intend to go to the bus stop, the movement status is also set to "going to bus stop"
        set movement_status "going to bus stop"
        ;; Calculation of the enterprise the tramrider is working at
        ;; At first, a random value is calculated in order to assign the person in the following step
        ;; 40 people are working at Enterprise A, 60 at Enterprise B, 400 at Enterprise C and 5 are included for the Boarding House
        set tr_random_val random (505 - count_employees_enterprise_a - count_employees_enterprise_b - count_employees_enterprise_c - count_visitors_bhouse)
        ;; Depending of the result for the random value, one of the four possible destinations is chosen
        if tr_random_val <= (40 - count_employees_enterprise_a) [set tr_ultimate_destination "enterprise a"]
        if tr_random_val > (40 - count_employees_enterprise_a) and tr_random_val <= (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) [set tr_ultimate_destination "enterprise b"]
        if tr_random_val > (100 - (count_employees_enterprise_a + count_employees_enterprise_b)) and tr_random_val <= (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) [set tr_ultimate_destination "enterprise c"]
        if tr_random_val > (500 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c)) and tr_random_val <= (505 - (count_employees_enterprise_a + count_employees_enterprise_b + count_employees_enterprise_c + count_visitors_bhouse)) [set tr_ultimate_destination "boarding house"]
        ;; Based on the calculation of the destination of the tramrider, the desired bus stop for existing the bus is chosen:
        ;; Enterprise A: 50% of the employees exit the bus at the stop in the center of the map, 50% exit at enterprise C
        if tr_ultimate_destination = "enterprise a" [
          set tr_random_val random 100
          if tr_random_val > 50 [set exit_bus_stop "bus_stop_center" ]
        ]
        ;; Enterprise B: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise b" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Enterprise C: All of the employees exit the bus at the bus stop next to Enterprise C
        if tr_ultimate_destination = "enterprise c" [set exit_bus_stop "bus_stop_enterpriseC"]
        ;; Boarding house: All of the employees exit the bus at the bus stop near the Boarding House
        if tr_ultimate_destination = "boarding house" [set exit_bus_stop "bus_stop_bhouse"]
        ;; A new spawn should also increase the count of people existing for the assigned Enterprise by 1
        if tr_ultimate_destination = "enterprise a" [set count_employees_enterprise_a (count_employees_enterprise_a + 1)] ;; Enterprise A
        if tr_ultimate_destination = "enterprise b" [set count_employees_enterprise_b (count_employees_enterprise_b + 1)] ;; Enterprise B
        if tr_ultimate_destination = "enterprise c" [set count_employees_enterprise_c (count_employees_enterprise_c + 1)] ;; Enterprise C
        if tr_ultimate_destination = "boarding house" [set count_visitors_bhouse (count_visitors_bhouse + 1)] ;; Boarding House
        ;; Since all tramriders intend to go to the bus stop, the current destination is set to the nearest bus stop, which is the bus stop at the tram
        set tr_current_destination "bus_stop_tram"
        ;; The first waypoint after leaving the tram for a tramrider coming from the city is the North Eastern Corner of the TZI
        ;; The tramrider is facing the waypoint immediatly after leaving the tram
        set tr_target one-of tr_nodes with [tr_n_name = "sn tram crossing"]
        face tr_target
        ;; Setting the waiting time to 0
        set tr_waiting_time 0
        ;; Setting the ragelimt based on probability
        ifelse random 100 > 20
          ;; The Maximum waiting time for the bus is 5 Minutes
          [set tr_ragelimit random 300]
          ;; 20% of people don't even want to intend the bus
          [set tr_ragelimit 0]
      ]
      ;; passengers who left are being subtracted from the total count
      set tram_passengers_sn (tram_passengers_sn - 1)
    ]
  ]
end


;; ===== TRAMRIDER IMPLEMENTATION =====

to setup-tr_nodes
  ;; Creating the waypoints for the tramriders' movement around the map as agents
  ;; setting an id, a name and the coordinates and hiding the node-agent
  create-tr_nodes 1 [
    set tr_n_id 1
    set tr_n_name "TZI NE-Corner"
    setxy 830 205
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 2
    set tr_n_name "sn tram crossing"
    setxy 852 200
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 3
    set tr_n_name "tram entrance ns"
    setxy 809 172
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 4
    set tr_n_name "tram entrance sn"
    setxy 830 162
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 5
    set tr_n_name "bus_stop_tram"
    setxy 812 208
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 6
    set tr_n_name "bus_stop_center"
    setxy 411 347
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 7
    set tr_n_name "bus_stop_enterpriseC"
    setxy 175 385
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 8
    set tr_n_name "bus_stop_bhouse"
    setxy 173 517
    hide-turtle
  ]

  ;; Route 1
  create-tr_nodes 1 [
    set tr_n_id 20
    set tr_n_name "r1_waypoint1"
    setxy 756 222
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 21
    set tr_n_name "r1_waypoint2"
    setxy 730 298
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 22
    set tr_n_name "r1_waypoint3"
    setxy 645 302
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 23
    set tr_n_name "r1_waypoint4"
    setxy 624 304
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 24
    set tr_n_name "r1_waypoint5"
    setxy 626 327
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 25
    set tr_n_name "r1_waypoint6"
    setxy 379 347
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 26
    set tr_n_name "r1_waypoint7"
    setxy 361 348
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 27
    set tr_n_name "r1_waypoint8"
    setxy 222 360
    hide-turtle
  ]

    ;; Route 2
  create-tr_nodes 1 [
    set tr_n_id 30
    set tr_n_name "r2_waypoint1"
    setxy 638 221
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 31
    set tr_n_name "r2_waypoint2"
    setxy 618 223
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 32
    set tr_n_name "r2_waypoint3"
    setxy 466 234
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 33
    set tr_n_name "r2_waypoint4"
    setxy 451 131
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 34
    set tr_n_name "r2_waypoint5"
    setxy 420 133
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 35
    set tr_n_name "r2_waypoint6"
    setxy 391 115
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 36
    set tr_n_name "r2_waypoint7"
    setxy 375 116
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 37
    set tr_n_name "r2_waypoint8"
    setxy 377 230
    hide-turtle
  ]


  ;; Interroute waypoints = Waypoints between the routes
  create-tr_nodes 1 [
    set tr_n_id 40
    set tr_n_name "inter_r1r2_waypoint1"
    setxy 375 288
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 41
    set tr_n_name "inter_r1r2_waypoint2"
    setxy 378 257
    hide-turtle
  ]

  create-tr_nodes 1 [
    set tr_n_id 42
    set tr_n_name "inter_r1bh_waypoint1"
    setxy 306 509
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 43
    set tr_n_name "inter_r1bh_waypoint2"
    setxy 240 514
    hide-turtle
  ]

  ;; Interbuilding waypoints = waypoints between the enterprises' buildings
  create-tr_nodes 1 [
    set tr_n_id 51
    set tr_n_name "interbuilding_waypoint1"
    setxy 169 246
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 52
    set tr_n_name "interbuilding_waypoint2"
    setxy 170 270
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 53
    set tr_n_name "interbuilding_waypoint3"
    setxy 174 311
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 54
    set tr_n_name "interbuilding_waypoint4"
    setxy 176 361
    hide-turtle
  ]


  ;; Enterprise Nodes
   create-tr_nodes 1 [
    set tr_n_id 61
    set tr_n_name "entrance_enterprise_a"
    setxy 256 239
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 62
    set tr_n_name "building_enterprise_a"
    setxy 252 213
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 63
    set tr_n_name "entrance_enterprise_b"
    setxy 180 311
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 64
    set tr_n_name "building_enterprise_b"
    setxy 273 302
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 65
    set tr_n_name "entrance_enterprise_c"
    setxy 164 311
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 66
    set tr_n_name "building_enterprise_c"
    setxy 110 315
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 67
    set tr_n_name "entrance_boarding_house"
    setxy 236 531
    hide-turtle
  ]
  create-tr_nodes 1 [
    set tr_n_id 68
    set tr_n_name "building_boarding_house"
    setxy 234 554
    hide-turtle
  ]



end

to move-tramriders
  ask tramriders [
    ;; The following 3 functions define the tramrider's next waypoint once the current waypoint is reached
    ;; Going to work
    check-tramriders-waypoints-going-to-work
    ;; Between the routes and the enterprises
    check-tramriders-inter-and-enterprise-waypoints
    ;; Going to tram
    check-tramriders-waypoints-going-to-tram

    ;; The tramriders are working when they reach their Enterprise
    tramriders-work

    ;; Ragemode-Calculation
    ;; Increasing the time waiting for the bus by one each second
    if movement_status = "waiting for bus"
      [set tr_waiting_time (tr_waiting_time + 1)]

    ;; Ending the waiting-on-the-bus process
    ;; When the waiting time exceeds the ragelimit, the tramrider decides to go to this destination by foot
    if movement_status = "waiting for bus" and tr_waiting_time > tr_ragelimit [
      ;; Set the destination to the location that should've been previously approached by using the bus
      set tr_current_destination tr_ultimate_destination
      ;; When the destination is one of the trams: go to the tram. Else: Go to work
      ifelse tr_ultimate_destination = "tram_ns" or tr_ultimate_destination = "tram_sn"
        [set movement_status "going to tram"
         set tr_waiting_time 0]
        [set movement_status "going to work"
         set tr_waiting_time 0]
    ]


    ;; Starting the waiting-on-the-bus process
    ;; When a tramrider reaches the bus stop he wanted to go to, his status is turned to "waiting"
    if movement_status = "going to bus stop" and distance tr_target = 0 and [tr_n_name] of tr_target = "bus_stop_tram"
      [set movement_status "waiting for bus"]
    if movement_status = "going to bus stop" and distance tr_target = 0 and [tr_n_name] of tr_target = "bus_stop_center"
      [set movement_status "waiting for bus"]
    if movement_status = "going to bus stop" and distance tr_target = 0 and [tr_n_name] of tr_target = "bus_stop_enterpriseC"
      [set movement_status "waiting for bus"]
    if movement_status = "going to bus stop" and distance tr_target = 0 and [tr_n_name] of tr_target = "bus_stop_bhouse"
      [set movement_status "waiting for bus"]

    ;; Check the possible collisions in order to control the moving process when the tramrider is not standing still
    if movement_status != "working" and movement_status != "waiting for bus" [check-collision]

    ;; Moving towards the target
    ;; once the distance is less than 1, use move-to to land exactly on the target.
    ;; The tramrider is not allowed to move when he is waiting for the bus or working at his workplace
    if tr_stop = false and movement_status != "waiting" and movement_status != "working" [
      ifelse distance tr_target < 1
        [ move-to tr_target ]
        [ fd 1.4 ] ;; 5km/h
    ]

    ;; Reset of the collision detection for next tick
    set tr_stop false
]
end



to check-tramriders-waypoints-going-to-work

  ;; Waypoints of the tramriders' movement

  ;; on the eastern side, between the bus_stop and the tram station
  if tr_current_destination = "bus_stop_tram" [
  ;; If the distance to the target is 0 and the tramrider has a certain destination => recalculate the target to the next waypoint and face it
  if distance tr_target = 0 and [tr_n_name] of tr_target = "TZI NE-Corner"
    [set tr_target one-of tr_nodes with [tr_n_name = "bus_stop_tram"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "sn tram crossing"
    [set tr_target one-of tr_nodes with [tr_n_name = "TZI NE-Corner"]
      face tr_target]
  ]

  ;; Going to work by foot: Deciding which Route to take
  if movement_status = "going to work" [
  ;; Chosing different routes with different probabilites based on different destinations
  if distance tr_target = 0 and [tr_n_name] of tr_target = "bus_stop_tram" [
    ;; Calculating the deciding factor at random
    set tr_random_val random 100
    ;; Destination: Enterprise A
    if tr_ultimate_destination = "enterprise a" [
      ;; Random decision which path is chosen
      if tr_random_val <= 50 [ ;; 50% chance for chosing the 1. route
        set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint1"]
        face tr_target
      ]
      if tr_random_val > 50 [ ;; 50% chance for chosing the 1. route
        set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint1"]
        face tr_target
      ]
    ]
    ;; Destination: Enterprise B
    if tr_ultimate_destination = "enterprise b" [
      if tr_random_val <= 70 [ ;; 70% chance for chosing the 1. route
        set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint1"]
        face tr_target
      ]
      if tr_random_val > 70 [ ;; 30% chance for chosing the 1. route
        set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint1"]
        face tr_target
      ]
    ]
    ;; Destination: Enterprise C
    if tr_ultimate_destination = "enterprise c" [
      if tr_random_val <= 70 [
        set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint1"]
        face tr_target
      ]
      if tr_random_val > 70 [
        set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint1"]
        face tr_target
      ]
    ]
    ;; Destination: Boarding House
    if tr_ultimate_destination = "boarding house" [
      if tr_random_val <= 80 [
        set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint1"]
        face tr_target
      ]
      if tr_random_val > 80 [
        set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint1"]
        face tr_target
      ]
    ]
  ]


  ;; Route 1
  ;; The northern route, going through the pedestrian precinct
  if distance tr_target = 0 and [tr_n_name] of tr_target = "" and tr_current_destination = ""
    [set tr_target one-of tr_nodes with [tr_n_name = ""]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint1"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint2"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint2"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint3"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint3"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint4"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint4"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint5"]
      face tr_target]

  ;; The route goes past the central bus stop
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint5"
    [set tr_target one-of tr_nodes with [tr_n_name = "bus_stop_center"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "bus_stop_center"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint6"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint6"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint7"]
      face tr_target]

  ;; Decision on Route 1, right after crossing the Forschungsallee, between Enterprise B+C and Enterprise A and the Boarding house
  ;; If the destination is Enterprise A: Turn south
  ;; If the destination is Enterprise B or Enterprise C: Stay on route 1, go straight forward
  ;; If the destination is the Boarding House: Turn north
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint7" [
    if tr_ultimate_destination = "enterprise a" [
      set tr_target one-of tr_nodes with [tr_n_name = "inter_r1r2_waypoint1"]
      face tr_target]
    if tr_ultimate_destination = "enterprise b"
      [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint4"]
      face tr_target]
    if tr_ultimate_destination = "enterprise c"
      [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint4"]
      face tr_target]
    if tr_ultimate_destination = "boarding house"
      [set tr_target one-of tr_nodes with [tr_n_name = "inter_r1bh_waypoint1"]
      face tr_target]
  ]



  ;; Route 2
  ;; The southern of the routes
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r2_waypoint1"
    [set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint2"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r2_waypoint2"
    [set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint3"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r2_waypoint3"
    [set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint4"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r2_waypoint4"
    [set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint5"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r2_waypoint5"
    [set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint6"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r2_waypoint6"
    [set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint7"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r2_waypoint7"
    [set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint8"]
      face tr_target]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r2_waypoint8"
    [set tr_target one-of tr_nodes with [tr_n_name = "entrance_enterprise_a"]
      face tr_target]

  ;; The route goes past the entrance to Enterprise A
  ;; If the tramrider is an employee of Enterprise A he should turn to the building. Else he should go straight on the boardwalk in order to reach the area between the buildings
  if distance tr_target = 0 and [tr_n_name] of tr_target = "entrance_enterprise_a" [
    ifelse tr_ultimate_destination = "enterprise a"
      [set tr_target one-of tr_nodes with [tr_n_name = "building_enterprise_a"]
          face tr_target]
      [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint1"]
        face tr_target]
  ]

  ;; Route 3



  ;; Route at the Boarding House


  ;; From route 1 to boarding house
  if distance tr_target = 0 and [tr_n_name] of tr_target = "inter_r1bh_waypoint1"
    [set tr_target one-of tr_nodes with [tr_n_name = "inter_r1bh_waypoint2"]
      face tr_target]

  ;; If the person at the opposite side of the street at the boarding house wants to go inside of the boarding house, cross the street. Else, go to the Bus Stop.
  if distance tr_target = 0 and [tr_n_name] of tr_target = "inter_r1bh_waypoint2" [
    ifelse  tr_ultimate_destination = "boarding house"
      [set tr_target one-of tr_nodes with [tr_n_name = "entrance_boarding_house"]
        face tr_target]
      [set tr_target one-of tr_nodes with [tr_n_name = "bus_stop_bhouse"]
        face tr_target]
  ]
  ;; People who are at the entrance of the boarding house always want to go inside
  if distance tr_target = 0 and [tr_n_name] of tr_target = "entrance_boarding_house"
      [set tr_target one-of tr_nodes with [tr_n_name = "building_boarding_house"]
        face tr_target]
  ]

end


to check-tramriders-inter-and-enterprise-waypoints

  ;; Going to work
  if movement_status = "going to work" [
  ;; Inter-Route waypoints
  ;; Employees of Enterprise A that chose to go along the Route 1 took a turn south after crossing the Forschungsallee.
  ;; These are the waypoints between Route 1 and Route 2 at the Forschungsallee
  if distance tr_target = 0 and [tr_n_name] of tr_target = "inter_r1r2_waypoint1" and tr_ultimate_destination = "enterprise a"
    [set tr_target one-of tr_nodes with [tr_n_name = "inter_r1r2_waypoint2"]
      face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "inter_r1r2_waypoint2" and tr_ultimate_destination = "enterprise a"
    [set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint8"]
      face tr_target]


  ;; Inter-Building waypoints
  ;; These waypoints define the movement between the 3 Enterprises

  ;; Decision between employees of Enterprises A and the rest
  if distance tr_target = 0 and [tr_n_name] of tr_target = "interbuilding_waypoint1" [
    ifelse tr_ultimate_destination != "enterprise a"
      [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint2"]
        face tr_target]
      [set tr_target one-of tr_nodes with [tr_n_name = "entrance_enterprise_a"]
        face tr_target]
  ]

  ;; Decision between employees of Enterprises A and the rest
  if distance tr_target = 0 and [tr_n_name] of tr_target = "interbuilding_waypoint2" [
    ifelse tr_ultimate_destination != "enterprise a"
      [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint3"]
        face tr_target]
      [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint1"]
        face tr_target]
  ]

  ;; Decision between visitors of the Boarding House and the rest
  if distance tr_target = 0 and [tr_n_name] of tr_target = "interbuilding_waypoint4" and tr_ultimate_destination != "boarding house"
    [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint3"]
      face tr_target]

  ;; Interbuilding Waypoint 3 is directly between Enterprise B and C.
  ;; Employees of Enterprise A: Go south
  ;; Employees of Enterprise B: Go to the entrance of Enterprise B
  ;; Employees of Enterprise C: Go to the entrance of Enterprise C
  ;; Visitor of the Boarding House: Go north
  if distance tr_target = 0 and [tr_n_name] of tr_target = "interbuilding_waypoint3" [
    if tr_ultimate_destination = "enterprise a" [
      set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint2"]
      face tr_target]
    if tr_ultimate_destination = "enterprise b"
      [set tr_target one-of tr_nodes with [tr_n_name = "entrance_enterprise_b"]
      face tr_target]
    if tr_ultimate_destination = "enterprise c"
      [set tr_target one-of tr_nodes with [tr_n_name = "entrance_enterprise_c"]
        face tr_target]
    if tr_ultimate_destination = "boarding house"
      [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint4"]
      face tr_target]
  ]

  ;; Enterprise Waypoints
  ;; These are the waypoints of the Enterprises for the employees
  if distance tr_target = 0 and [tr_n_name] of tr_target = "entrance_enterprise_b" [
    ifelse tr_ultimate_destination = "enterprise b"
      [set tr_target one-of tr_nodes with [tr_n_name = "building_enterprise_b"]
        face tr_target]
      [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint3"]
        face tr_target]
  ]

  if distance tr_target = 0 and [tr_n_name] of tr_target = "entrance_enterprise_c" [
    ifelse tr_ultimate_destination = "enterprise c"
      [set tr_target one-of tr_nodes with [tr_n_name = "building_enterprise_c"]
        face tr_target]
      [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint3"]
        face tr_target]
  ]
]


end

to check-tramriders-waypoints-going-to-tram

  ;; Going to tram

  ;; Going to bus stop at first
  if movement_status = "going to bus stop" [
  ;; Leaving the buildings
  if [tr_n_name] of tr_target = "building_enterprise_a" and distance tr_target = 0
    [set tr_target one-of tr_nodes with [tr_n_name = "entrance_enterprise_a"]
       face tr_target]
  if [tr_n_name] of tr_target = "entrance_enterprise_a" and distance tr_target = 0
    [if tr_current_destination = "bus_stop_enterpriseC"
      [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint1"]
        face tr_target ]
     if tr_current_destination = "bus_stop_center"
      [set tr_target one-of tr_nodes with [tr_n_name = "r2_waypoint8"]
        face tr_target ]
      ]

  if [tr_n_name] of tr_target = "building_enterprise_b" and distance tr_target = 0
    [set tr_target one-of tr_nodes with [tr_n_name = "entrance_enterprise_b"]
       face tr_target]
  if [tr_n_name] of tr_target = "entrance_enterprise_b" and distance tr_target = 0
    [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint4"]
       face tr_target]

  if [tr_n_name] of tr_target = "building_enterprise_c" and distance tr_target = 0
    [set tr_target one-of tr_nodes with [tr_n_name = "entrance_enterprise_c"]
       face tr_target]
  if [tr_n_name] of tr_target = "entrance_enterprise_c" and distance tr_target = 0
    [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint4"]
       face tr_target]



  ;; going to bus stop
  ;; Bus Stop Enterprise C
  if [tr_n_name] of tr_target = "interbuilding_waypoint1" and distance tr_target = 0
    [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint2"]
       face tr_target]

  if [tr_n_name] of tr_target = "interbuilding_waypoint2" and distance tr_target = 0
    [set tr_target one-of tr_nodes with [tr_n_name = "interbuilding_waypoint4"]
       face tr_target]

  if [tr_n_name] of tr_target = "interbuilding_waypoint4" and distance tr_target = 0
    [set tr_target one-of tr_nodes with [tr_n_name = "bus_stop_enterpriseC"]
       face tr_target]

  ;; Bus Stop Center

  if distance tr_target = 0 and [tr_n_name] of tr_target = "r2_waypoint8"
      [set tr_target one-of tr_nodes with [tr_n_name = "inter_r1r2_waypoint2"]
        face tr_target]
    if distance tr_target = 0 and [tr_n_name] of tr_target = "inter_r1r2_waypoint2"
      [set tr_target one-of tr_nodes with [tr_n_name = "inter_r1r2_waypoint1"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "inter_r1r2_waypoint1"
      [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint7"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint7"
      [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint6"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint6"
      [set tr_target one-of tr_nodes with [tr_n_name = "bus_stop_center"]
        face tr_target]
  ]


  ;; going to tram by foot
  if movement_status = "going to tram" [
  ;; Route 1
  if distance tr_target = 0 and [tr_n_name] of tr_target = "bus_stop_enterpriseC"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint8"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint8"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint7"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint7"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint6"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint6"
    [set tr_target one-of tr_nodes with [tr_n_name = "bus_stop_center"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "bus_stop_center"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint5"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint5"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint4"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint4"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint3"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint3"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint2"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint2"
    [set tr_target one-of tr_nodes with [tr_n_name = "r1_waypoint1"]
        face tr_target]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "r1_waypoint1"
    [set tr_target one-of tr_nodes with [tr_n_name = "TZI NE-Corner"]
        face tr_target]


  ;; The tram station
  if distance tr_target = 0 and [tr_n_name] of tr_target = "TZI NE-Corner" [
    ifelse tr_current_destination = "tram_ns"
      [set tr_target one-of tr_nodes with [tr_n_name = "tram entrance ns"]
        face tr_target]
      [set tr_target one-of tr_nodes with [tr_n_name = "sn tram crossing"]
        face tr_target]
  ]
  if distance tr_target = 0 and [tr_n_name] of tr_target = "sn tram crossing"
    [set tr_target one-of tr_nodes with [tr_n_name = "tram entrance sn"]
        face tr_target]
  ]
end


to tramriders-work

  ;; Start working
  ;; If the Employees are on the position of a Building, the start working
  ;; The Tramrider is hidden visually because he is inside the building
  ;; The Working time is calculated randomly
  ;; The status of movement is set to "working"
  if movement_status = "going to work" [
  ;; Enterprise A
  if [tr_n_name] of tr_target = "building_enterprise_a" and distance tr_target = 0 [
    hide-turtle
    set tr_max_working_time random 60 ;; Angestellte arbeiten bis zu 1 Minute täglich
    set movement_status "working"
  ]
  ;; Enterprise B
  if [tr_n_name] of tr_target = "building_enterprise_b" and distance tr_target = 0 [
    hide-turtle
    set tr_max_working_time random 60 ;; Angestellte arbeiten bis zu 1 Minute täglich
    set movement_status "working"
  ]
  ;; Enterprise C
  if [tr_n_name] of tr_target = "building_enterprise_c" and distance tr_target = 0 [
    hide-turtle
    set tr_max_working_time random 60 ;; Angestellte arbeiten bis zu 1 Minute täglich
    set movement_status "working"
  ]
  ]

  ;; Working
  ;; While a tramrider is working, the time he spent working is increased by 1 every second
  if movement_status = "working" [
    set tr_time_spent_working (tr_time_spent_working + 1)
  ]

  ;; Finish working
  ;; Only possible for people who are working
  if movement_status = "working" [
    ;; When the time, the employee spent working, reaches his maximum working time, the employee finishes working
    if tr_time_spent_working >= tr_max_working_time [
      ;; Since the tramrider intends to take the bus, the movement is set to going to bus stop
      set movement_status "going to bus stop"
      ;; Almost every employee wants to go the the Busstop between the Enterprises, right next to Enterprise C
      set tr_current_destination "bus_stop_enterpriseC"
      ;; Only people working at Enterprise A may decide between the bus stop at the enterprises and the busstop next to the Forschungsallee
      if xcor = 252 and ycor = 213 [ ;;Coordinates of Enterprise A
        ;; Calculate a random value for that decision
        set tr_random_val random 100
        ;; 50% Chance of taking either one of the bus stops
        ifelse tr_random_val > 50
          [set tr_current_destination "bus_stop_enterpriseC"]
          [set tr_current_destination "bus_stop_center"]
      ]

      ;; Which tram to take?
      ;; The destination, which tram the tramrider wants to take, is based on the direction of his arrival
      ;; If he came from the direction of the city / Stadtbergen, he will take the tram back there
      if tr_home = "north" [set tr_ultimate_destination "tram_sn"]
      ;; If he came from the direction of Haunstetten , he will take the tram back there
      if tr_home = "south" [set tr_ultimate_destination "tram_ns"]

      ;; Since the ultimate destination of a tramrider going home from work is always the tram, the exit bus stop should be the bus stop near the tram
      set exit_bus_stop "bus_stop_tram"

      ;; The tramriders that finished working are colored black to decide between them and the ones going to work
      set color black
      ;; Since the tramrider was hidden when starting to work, now the tramrider has to be made visible again
      show-turtle
    ]
  ]

;;  Stored since tram: tr_home ;; Home of the tramrider (north or south)
;;  Reassigned after work: movement_status ;; Going to Bus stop, waiting, going to work
;;  Reassigned after work: tr_ultimate_destination ;; Enterprise A,B,C or Tram
;;  Reassigned after work: tr_current_destination
;;  Reassigned after work, leaving the building: tr_target
;;  Reset after stopping to wait for the tram: tr_waiting_time
;;  Stored since tram: tr_ragelimit
;;  Reset every tick: tr_stop
;;  Recalculated at various points: tr_random_val
;;  Not changed after work: tr_max_working_time
;;  Not changed after work: tr_time_spent_working


end



to check-collision
  ;; Trams general
  if any? trams-on patch-ahead 1
    [set tr_stop true]

  ;; Tram-crossing for sn tramdrivers wanting to leave the tram station
  if tr_current_destination = "bus_stop_tram" and xcor = 852 and ycor = 200 [
    if any? trams with [t_direction = "ns" and t_status ="arriving"]
    or any? trams with [t_direction = "sn" and t_status = "closed"]
    or any? trams with [t_direction = "sn" and t_status = "departing" and xcor < 875 and ycor < 255]
      [set tr_stop true]
  ]

  ;; Tram-crossing for sn tramdrivers wanting to enter the tram station
  if tr_current_destination = "tram_sn" and xcor = 830 and ycor = 205 [
    if any? trams with [t_direction = "ns" and t_status ="arriving"]
    or any? trams with [t_direction = "sn" and t_status = "closed"]
    or any? trams with [t_direction = "sn" and t_status = "departing" and xcor < 875 and ycor < 255]
      [set tr_stop true]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
7
165
926
812
-1
-1
1.0
1
10
1
1
1
0
0
0
1
0
910
0
637
0
0
1
ticks
30.0

BUTTON
6
129
69
162
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
7
93
124
126
NIL
setup-map
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
73
129
148
162
go once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
130
93
193
126
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
868
110
925
155
Time
time
17
1
11

MONITOR
1003
350
1190
395
count_employees_enterprise_a
count_employees_enterprise_a
17
1
11

MONITOR
1003
396
1190
441
NIL
count_employees_enterprise_b
17
1
11

MONITOR
1003
442
1190
487
NIL
count_employees_enterprise_c
17
1
11

MONITOR
1003
489
1190
534
NIL
count_visitors_bhouse
17
1
11

MONITOR
1056
212
1233
257
tramriders waiting for ns tram
tramriders with [tr_current_destination = \"tram_ns\" and xcor = 809 and ycor = 172]
17
1
11

CHOOSER
520
113
658
158
interval
interval
10 15 20
2

TEXTBOX
521
48
671
104
Bus is going between 5:30 and 21:00. You can choose the interval between the bus rides (in minutes).
11
0.0
1

MONITOR
1058
262
1235
307
tramriders waiting for sn tram
tramriders with [tr_current_destination = \"tram_sn\" and xcor = 830 and ycor = 162]
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

autobus
false
0
Polygon -7500403 true true 0 225 30 45 255 45 300 225
Circle -16777216 true false 195 180 90
Circle -16777216 true false 15 180 90
Circle -7500403 true true 32 195 58
Circle -7500403 true true 210 195 58
Rectangle -16777216 true false 60 75 105 135
Rectangle -16777216 true false 195 75 240 135
Rectangle -16777216 false false 120 90 180 210

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tram_new
true
0
Circle -11221820 true false 135 15 30
Circle -11221820 true false 135 255 30
Rectangle -7500403 true true 135 30 165 270
Line -16777216 false 135 60 165 60
Line -16777216 false 135 105 165 105
Line -16777216 false 135 135 165 135
Line -16777216 false 135 165 165 165
Line -16777216 false 135 195 165 195
Line -16777216 false 135 240 165 240
Rectangle -1 false false 135 30 165 270

tram_old
true
0
Circle -11221820 true false 135 60 30
Circle -11221820 true false 135 210 30
Rectangle -7500403 true true 135 75 165 225
Line -16777216 false 135 120 165 120
Line -16777216 false 135 180 165 180
Rectangle -1 false false 135 75 165 225

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@

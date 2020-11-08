// Elixer Space Company - ASDS Script [version 0.3.1]




// Landing Parameters


parameter landingZone is latlng(-0.17519274452922, -72.6814256594596).


// Initialization


wait until ag8.
rcs on.
set currentFacing to facing.
lock steering to currentFacing.
wait 3.


// ASDS & AOTL Functions


    clearscreen.
    print "Elixer Landing Software".
    print "-".

    set steeringManager:maxstoppingtime to 5.
    set steeringManager:rollts to 20.


    // Landing Variables


    set radarOffset to 21.15. // This must be changed to the height of the landing vehicle (on gear)
    lock trueRadar to alt:radar - radarOffset.
    lock g to constant:g * body:mass / body:radius^2.
    lock maxDecel to (ship:availablethrust / ship:mass) - g.
    lock stopDist to ship:verticalspeed^2 / (2 * maxDecel).
    lock idealThrottle to stopDist / trueRadar.
    lock impactTime to trueRadar / abs(ship:verticalspeed).
    lock aoa to 30.
    lock errorScaling to 1.


    // Guidance Functions


    function getImpact {
        if addons:tr:hasimpact { return addons:tr:impactpos. }
            return ship:geoposition.
        }

    function lngError {
        return getImpact():lng - landingZone:lng.
        }

    function latError {
        return getImpact():lat - landingZone:lat.
        }

    function errorVector {
        return getImpact():position - landingZone:position.
        }

    function getSteering {
        local errorVector is errorVector().
        local velVector is -ship:velocity:surface.
        local result is velVector + errorVector*errorScaling.

        if vang(result, velVector) > aoa
        {
            set result to velVector:normalized
                        + tan(aoa)*errorVector:normalized.
        }

        return lookdirup(result, facing:topvector).
    }

rcs on.
lock steering to srfretrograde. 
brakes on.
wait until ship:verticalspeed <-700.
    lock throttle to 1.
    lock aoa to -5.
    lock steering to getSteering(). // Comment line when grabbing coordinates
    toggle ag1.
    toggle ag7.
	rcs off.

wait until ship:verticalspeed > -200.
    lock throttle to 0.
    lock aoa to 17.5. 
    lock steering to getSteering().
    steeringManager:resettodefault().
    rcs on.

wait until alt:radar < 12000.
    lock aoa to 10.

wait until alt:radar < 7000.
    lock aoa to 5.

WAIT UNTIL ship:verticalspeed < -10. 
	rcs on.
	when impactTime < 3.5 then {gear on.} 

WAIT UNTIL trueRadar < stopDist. 
    lock throttle to 1.
    lock aoa to -3.
    lock steering to getSteering().

wait until ship:verticalspeed > -45.
    toggle ag1.
    lock throttle to idealThrottle.
    lock aoa to -2.
    lock steering to getSteering().

when impactTime < 0.75 then {lock steering to heading(90, 90).}
   
WAIT UNTIL ship:verticalspeed > -0.1. //there you go, The falcon has landed.
	set ship:control:pilotmainthrottle to 0.
	RCS off.
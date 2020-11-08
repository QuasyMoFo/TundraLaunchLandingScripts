// Ah yes
// Mission Setup


wait until ag6.

missionSetup(

    // Will change depending on mission

    "ASDS",  // ["ASDS"] | ["RTLS"] | ["AOTL"] | ["EEHL"]
    500000,  // Target Orbit (Meters) (Station Freedom - 210000)
    28.6,       // Target Inclination (Degrees)
    "Cargo",  // ["Cargo"]
    false // Wait for launch window? (true / false)

).

function missionSetup {

    parameter lMode, tOrbit, tInc, pType, window.

    clearscreen.

    // LandingMode Setup
    print "Landing Mode: " + lMode.
    if (lMode = "ASDS" or lMode = "AOTL") {global a is 120. global fuelToLand is 5000.} // 80
    else {set a to 130. set fuelToLand to 5800.}

    // TargetOrbit Setup
    if (tOrbit < 100000) {print "Target Orbit too low: " + tOrbit. abort on.}
    else {print "Target Orbit: " + tOrbit.}
    global atmosphericAlt is body:atm:height.
    global targetOrbit is tOrbit.

    // TargetInclination Setup
    if (tInc > 90) {print "Target Inclination too high: " + tInc. abort on.}
    else if (tInc < -90) {print "Target Inclination too low: " + tInc. abort on.}
    else {print "Target Inclination: " + tInc.}
    global targetInclination is tInc.

    lights on.

    // PayloadType Setup
    print "Payload Type: " + pType.
    if (pType = "Cargo") {global hasFairings is true. global fairingSepAlt is 80000. cargoFlight().} // 90 timer

}



// Other Variables

function pitchOfVector {

    parameter vecT.
    return 90 - vang(ship:up:vector, vecT).

}



// Cargo Ascent Functions

function cargoFlight {

    // Steeringmanager Setup
    set steeringmanager:rollts to 25.
    set steeringmanager:maxstoppingtime to 10.

    set orbitalInsertionBurnLock to true.

    // Script Setup

    runOncePath("0:/lib_lazcalc").

    // Liftoff  

    toggle ag2.
    wait 10.
    stage.
    lock throttle to 1.
    wait 2.
    stage.
    lock steering to up.
    wait 8.

    print "Liftoff".

    wait 1.5.
    if verticalSpeed > 1 {
        print "Nominal liftoff".
    } else {
        print "Abort activated".
        abort on.
        shutdown.
    }

    // Functions

    cargoAscent().
    cargoMeco().
    cargoSecondStage().
    cargoOrbitalBurn().

}

function cargoAscent {

    local azimuth_data is LAZcalc_init(targetOrbit, targetInclination).

    local slope is (0-90) / (1000 * (a - 10 - a * 0.05) - 0).

    until (ship:liquidfuel <= fuelToLand + 100) {

        local pitch is slope * ship:apoapsis + 90.

        if pitch < 0 {

            set pitch to 0.

        }

        if pitch > pitchOfVector(velocity:surface) + 5 {

            set pitch to pitchOfVector(velocity:surface) + 5.

        } else if pitch < pitchOfVector(velocity:surface) - 5 {

            set pitch to pitchOfVector(velocity:surface) -5.

        }

        local azimuth is LAZcalc(azimuth_data).

        lock steering to heading(azimuth, pitch).

    }

}

function cargoMeco {

    wait until (ship:liquidfuel <= fuelToLand + 100).
        rcs on.
        set currentFacing to facing.
        lock steering to currentFacing.
        wait until (ship:oxidizer <= fuelToLand).
            lock throttle to 0.
            lock steering to currentFacing.
            wait 0.5.
            print "MECO".
            rcs on.
            toggle ag8.
            stage.
            print "STAGE SEP".
            wait 3.5.
            lock throttle to 1.
            print "SSI1".

}

function cargoSecondStage {

    lock steering to currentFacing.
    wait 5.
    lock steering to prograde.

    when (ship:altitude >= fairingSepAlt and hasFairings = true) then {

        stage.
        print "Fairing sep".

    }

    when missionTime >= 280 then {
        print "Signal Kermuda, Stage 2 FTS Safed".
    }

    wait until (ship:apoapsis >= targetOrbit).
        lock throttle to 0.
        print "SECO1".

    wait until (ship:altitude >= atmosphericAlt).
        set orbitalInsertionBurnLock to false.
        print "Atmospheric Exit".
        print eta:apoapsis.

}

function cargoOrbitalBurn {

    set targetVel to sqrt(ship:body:mu / (ship:orbit:body:radius + ship:orbit:apoapsis)).
    set apVel to sqrt(((1 - ship:orbit:eccentricity) * ship:orbit:body:mu) / ((1 + ship:orbit:eccentricity) * ship:orbit:semimajoraxis)).
    set dv to targetVel - apVel.
    set myNode to node(time:seconds + eta:apoapsis, 0, 0, dv).
    add myNode.

    lock steering to lookdirup(ship:prograde:vector, heading(180, 0):vector).

    set nd to nextNode.
    set max_acc to ship:maxthrust / ship:mass.
    set burn_duration to nd:deltav:mag / max_acc.
    wait until nd:eta <= (burn_duration / 2 + 60).

    set np to nd:deltav.
    lock steering to np.
    wait until vang(np, ship:facing:vector) < 0.33.

    wait until nd:eta <= (burn_duration / 2).

    set dv0 to nd:deltav.
    set done to false.

    until done {

        wait 0.
        set max_acc to ship:maxthrust / ship:mass.

        lock throttle to min(nd:deltav:mag / max_acc, 1).

        print "SSI2".

        if vdot(dv0, nd:deltav) < 0 {

            lock throttle to 0.
            print "SECO2".
            break.

        }

        if nd:deltav:mag < 0.1 {

            wait until vdot(dv0, nd:deltav) < 0.5.
            lock throttle to 0.
            print "SECO2".
            shutdown.
            sas on.

        }

    }

}


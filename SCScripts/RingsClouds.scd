(

s.waitForBoot {

//// Delcare initial vars

var chordIndex = 0;

var chords = [
        [48, 52, 55, 59], // Cmaj7
        [53, 57, 60, 64], // Fmaj7
        [57, 59, 60, 55], // ABCF
        [60, 62, 64, 69]  // CDEA
    ];

var currentChord = chords[0];

var invertChord = { |chord, inversion|
    // Move the lowest note(s) up by 12 semitones per inversion
    var newChord = chord.collect { |note, i|
        (i < inversion).if { note + 12 } { note };
    };
    newChord;  // Return the inverted chord
};

//// Rings/Clouds SynthDef


SynthDef(\testRingsArp, {
    arg freq = 60, bright = 0.01, chord = #[60, 62, 63, 64], trigRate = 0.75, verb = 0.5, damp = 0.7;
    
    // Chord selection logic should be based on control values, not UGens
    var trig, ringsSound, cloudsSound, freqIndex;

    // Trigger impulses at the rate defined by 'trigRate'
    trig = Impulse.kr(trigRate);

    // Cycle through the notes in the selected chord
	freqIndex = Stepper.kr(trig: trig, min: 0, max: chord.size - 1);  // Steps through each note in the chord
	freqIndex.poll;
    freq = Select.kr(freqIndex, chord); // Selects the note index from passed chord
    freq.poll;

    // Generate sound using MiRings
    ringsSound = MiRings.ar(
        trig: trig,
        pit: freq,  // Pass arpeggiated note
        struct: 0.0,
        bright: bright,
        damp: damp,
        pos: 0.4,
        model: 2,
        poly: 4
    );

    cloudsSound = MiClouds.ar(
			ringsSound * 0.8,    // Signal input (MiRings output)
			// freeze: 0,             // Freeze off by default -- add in a freeze option for hand pose?
			pos: 0.5,           // Fixed grain position -- add in 2nd hand control?
			size: 0.3,           // Fixed grain size -- add in 2nd hand control?
			dens: 7.0,           // Fixed grain density
			spread: 0.9,
            tex: 0.8,
			rvb: verb,
			drywet: verb            // Fixed dry/wet mix -- add in 2nd hand control?
		);

    // Output the sound
    Out.ar(0, Limiter.ar(Pan2.ar(cloudsSound, 0) * 3), 0.8);
}).add;


//// Wait for Server and instantiate synth

s.sync;

~synth = Synth(\testRingsArp, [\chord, currentChord, \verb, 0.1, \bright, 0.1, \damp, 0.7, \drywet, 0.1]);


//// OSC Defs


// OSC control for changing the currently selected chord
OSCdef(\chordSet, { |msg|
    chordIndex = msg[1].linlin(0, 1000, 0, 4).asInteger;  // Clip to avoid out-of-range errors
    currentChord = chords[chordIndex];
    // ~synth.set(\chord, chordValue);  // Set 'chord' control value
}, '/control/chord');

// OSC control for setting inversion and sending chord

OSCdef(\chordInvert, { |msg|
    var invertNum = msg[1].linlin(0, 1000, 3, 0).asInteger;
    var chordInversion = invertChord.(currentChord, invertNum);
    ~synth.set(\chord, chordInversion);  // Set 'chord' control value
}, '/control/inversion');

// OSC control for changing reverb mix

OSCdef(\verbControl, { |msg|
    var verbValue = msg[1].linlin(0, 1000, 0.8, 0.01);
    ~synth.set(\verb, verbValue);  // Set 'chord' control value
}, '/control/verb');

// OSC control for dry/wet, incoming from the verb OSC message

OSCdef(\wetControl, { |msg|
    var wetValue = msg[1].linlin(0, 1000, 0.7, 0.05);
    ~synth.set(\drywet, wetValue);  // Set 'chord' control value
}, '/control/verb');

// OSC control for changing brightness

OSCdef(\brightControl, { |msg|
    var brightValue = msg[1].linexp(0, 1000, 0.7, 0.01);
    ~synth.set(\bright, brightValue);  // Set 'chord' control value
}, '/control/bright');

// OSC control for changing arp speed

OSCdef(\trigRateControl, { |msg|
    var newRate = msg[1].linexp(0, 1000, 8, 0.5);
    ~synth.set(\trigRate, newRate);
}, '/control/trigRate');

// OSC control for changing damping

OSCdef(\dampControl, { |msg|
    var dampValue = msg[1].linlin(0, 1000, 0.1, 0.9);
    ~synth.set(\damp, dampValue);
}, '/control/damp');

}
)
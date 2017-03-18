Mplay.jl
========

*Mplay* is a full functional MIDI player written in pure *Julia*.
It reads Standard MIDI Files (SMF) and sends them to MIDI devices
(or software synthesizers) while giving visual feedback.

This is a beta release which runs on *macOS X* and *Windows*.
Future versions will be available for *Linux*, too. Apart from a
*GLFW* wrapper (for the GUI part), there are no dependencies on
other packages. *Mplay* has been tested with *Julia* 0.5.1 (or
0.6) and *GLFW* 1.3.0.

*macOS X* and *Windows* systems come with a builtin software
synthesizer (*Apple* DLS SoftSynth, *Microsoft* GS Wavetable SW
Synth). On those systems *Mplay* runs out of the box. However,
best results can be achieved with the Roland Sound Canvas VA
software synthesizer:

![Mplay](http://josefheinen.de/pub/Mplay+SC.jpg)

**Hightlights:**

* Full functional MIDI player
* Mixer with mute and solo options
* Ability to change channel parameters (delay, chorus, reverb, pan)
* Volume sliders
* Pulldown menus for GM instrument sounds
* MIDI VU meter
* Show note, chord and lyrics information
* Change key, tempo
* Transport controls
* Keyboard shortcuts

| Key                | Action                  |
|:------------------:|:-----------------------:|
| a                  | un-mute all channels    |
| b/B                | toggle/solo bass        |
| d/D                | toggle/solo drums       |
| g/G                | toggle/solo guitar(s)   |
| k/K                | toggle/solo keyboard(s) |
| 1234567890!@#$%^   | toggle channel 1-16     |
| -/+                | decrease/increase tempo |
| SPACE              | stop/resume song        |
| > <                | transpose up/down       |
| TAB                | select next channel     |
| ESC                | quit Mplay              |

**Installation:**

This is preliminary version - the first "official" release will be available
as a Julia package and can be installed using `Pkg.add("Mplay")`.

*macOS X*

```
cc -shared -o libmidi.dylib libmidi.c \
   -framework CoreMIDI -framework CoreAudio -framework AudioUnit \
   -framework AudioToolbox -framework Cocoa
export JULIA_LOAD_PATH=`pwd`
```
*Windows*

```
cl /c libmidi.c
link /out:libmidi.dll libmidi.obj -dll winmm.lib
set JULIA_LOAD_PATH=%cd%
```

**Usage:**

```
julia mplay.jl <midifile>
```

**Internals**

*Mplay* has no innovative features - the main focus is on
simplicity and ease of use. It uses texture blitting to guarantee
highest refresh rates. That's why it responds in real-time in the
order of milliseconds, both to user interactions and MIDI events.

**Links:**

[*Mplay* website](http://josefheinen.de/mplay.html "Mplay website")

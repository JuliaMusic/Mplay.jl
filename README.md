Mplay.jl
========

*Mplay* is a full functional MIDI player written in pure *Julia*.
It reads Standard MIDI Files (SMF) and sends them to MIDI devices
(or software synthesizers) while giving visual feedback.

This is a pre-release which runs on *macOS X* and *Windows*.
*Mplay* has been tested with *Julia* 1.0 (or later) and *GLFW* 1.5.

*macOS X* and *Windows* systems come with a builtin software
synthesizer (*Apple* DLS SoftSynth, *Microsoft* GS Wavetable SW
Synth). On those systems *Mplay* runs out of the box. However,
best results can be achieved with the Roland Sound Canvas VA
software synthesizer:

![Mplay](Mplay+SC.png)

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

```
Pkg.clone("https://github.com/JuliaMusic/Mplay.jl")
```

On macOS X and Windows systems *Mplay* comes as a self-contained
package with its own wrappers for *GLFW* and *OpenGL* as well as
the required run-time libraries for the GUI and Midi subsystems.

**Usage:**

```
using Mplay
mplay(<path to midi file>)
```

You can also create your own wrapper script to use *Mplay* from the
command line (`main.jl` is contained in the package), e.g.:

```
julia main.jl <path to midi file>
```

**Internals**

*Mplay* has no innovative features - the main focus is on
simplicity and ease of use. It uses texture blitting to guarantee
highest refresh rates. That's why it responds in real-time in the
order of milliseconds, both to user interactions and MIDI events.

If, for any reason, the contained MIDI run-time doesn't work, you can
build your own binaries:

*macOS X*

```
cc -shared -o libmidi.dylib libmidi.c \
   -framework CoreMIDI -framework CoreAudio -framework AudioUnit \
   -framework AudioToolbox -framework Cocoa
```
*Windows*

```
cl /c libmidi.c
link /out:libmidi.dll libmidi.obj -dll winmm.lib
```

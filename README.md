Mplay.jl
========

*Mplay* is a MIDI player written in pure *Julia*. This is a first
release wich runs on *macOS X*. Future versions will be available for
*Windows* and *Linux*, too. Apart from an *GLFW* wrapper (for the GUI
part), there are no dependencies on other packages. *Mplay* has been
tested with *Julia* 0.5.1 (or 0.6) and *GLFW* 3.1.

*macOS X* and *Windows* systems come with a builtin software synthesizer
(*Apple* DLS SoftSynth, *Microsoft* GS Wavetable SW Synth). On those systems *Mplay* runs out of the box. However, best results can be achieved with the
Roland Sound Canvas VA software synthesizer:

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

**Links:**

[*Mplay* website](http://josefheinen.de/mplay.html "Mplay website")

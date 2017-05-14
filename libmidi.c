/*
 macOS X:
   cc -shared -o libmidi.dylib libmidi.c \
      -framework CoreMIDI -framework CoreAudio -framework AudioUnit \
      -framework AudioToolbox -framework Cocoa
 Windows:
   cl /c libmidi.c
   link /out:libmidi.dll libmidi.obj -dll winmm.lib
 */

#include <stdio.h>

typedef struct {
  unsigned int timeStamp;
  unsigned int data;
} midievent_t;

static midievent_t midiEvent[256];
static int readIndex = 0, writeIndex = 0;

#ifdef __APPLE__

#include <CoreMIDI/MIDIServices.h>
extern UInt64 AudioGetCurrentHostTime();
#include <CoreServices/CoreServices.h>
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>

#define DLLEXPORT

static AudioUnit synthUnit = 0;
static AUGraph graph = 0;
static MIDIClientRef client = 0;
static MIDIPortRef input_port = 0, output_port = 0;
static MIDIEndpointRef src, dest;

#endif

#ifdef _WIN32

#include <windows.h>
#include <mmsystem.h>

#define DLLEXPORT __declspec(dllexport)

static HMIDIOUT midi_out;

#endif

static
void fatal(char *message)
{
  fprintf(stderr, "midi: %s\n", message);
  exit(0);
}

#ifdef __APPLE__

static
void readProc(const MIDIPacketList *newPackets, void *refCon,
              void *connRefCon)
{
  MIDIPacket *packet = (MIDIPacket *) &newPackets->packet[0];
  int packetIndex;

  for (packetIndex = 0; packetIndex < newPackets->numPackets; packetIndex++)
    {
      if (packet->length <= 3)
        {
          unsigned char *data = packet->data;

          midiEvent[writeIndex].timeStamp = packet->timeStamp;
          midiEvent[writeIndex].data = (data[2]<<16) + (data[1]<<8) + data[0];

          writeIndex = (writeIndex + 1) % 256;
          if (writeIndex == readIndex)
            fprintf(stderr, "midi: MIDI buffer overflow");
        }
      packet = MIDIPacketNext(packet);
    }
}
#endif

DLLEXPORT void midiopen(char *device)
{
#ifdef __APPLE__
  if (strcmp(device, "dlss") == 0 || MIDIGetDestination(0) == 0 )
    {
      AUNode synthNode, limiterNode, outNode;
      AudioComponentDescription cd;
      OSStatus result;

      require_noerr (result = NewAUGraph (&graph), home);

      cd.componentManufacturer = kAudioUnitManufacturer_Apple;
      cd.componentFlags = 0;
      cd.componentFlagsMask = 0;
      cd.componentType = kAudioUnitType_MusicDevice;
      cd.componentSubType = kAudioUnitSubType_DLSSynth;
      require_noerr (result = AUGraphAddNode (graph, &cd, &synthNode), home);

      cd.componentType = kAudioUnitType_Effect;
      cd.componentSubType = kAudioUnitSubType_PeakLimiter;
      require_noerr (result = AUGraphAddNode (graph, &cd, &limiterNode), home);

      cd.componentType = kAudioUnitType_Output;
      cd.componentSubType = kAudioUnitSubType_DefaultOutput;
      require_noerr (result = AUGraphAddNode (graph, &cd, &outNode), home);

      require_noerr (result = AUGraphOpen (graph), home);
      require_noerr (result = AUGraphConnectNodeInput (graph, synthNode, 0, limiterNode, 0), home);
      require_noerr (result = AUGraphConnectNodeInput (graph, limiterNode, 0, outNode, 0), home);

      require_noerr (result = AUGraphNodeInfo(graph, synthNode, 0, &synthUnit), home);

      require_noerr (result = AUGraphInitialize (graph), home);
      require_noerr (result = AUGraphStart (graph), home);
    }
  else
    {
      void *conRef = NULL;

      if (MIDIClientCreate(CFSTR("Mplay"), NULL, NULL, &client) != noErr)
        fatal("cannot create MIDI client");

      if (MIDIOutputPortCreate(client, CFSTR("Output port"), &output_port) != noErr)
        fatal("cannot create MIDI output port");
      if ((dest = MIDIGetDestination(atoi(device))) == 0)
        fatal("cannot get MIDI destination");

      if (MIDIInputPortCreate(client, CFSTR("Input port"), readProc, NULL, &input_port) != noErr)
        fatal("cannot create MIDI input port");

      if ((src = MIDIGetSource(atoi(device))) == 0)
        printf("cannot get MIDI source\n");
      else
        {
          if (MIDIPortConnectSource(input_port, src, conRef) != noErr)
            fatal("cannot connect MIDI input source");
        }
    }
home:
  ;
#endif
#ifdef _WIN32
  if (midiOutOpen(&midi_out, MIDIMAPPER, 0L, 0L, 0L) != 0)
    fatal("cannot open MIDI output");
#endif
}

DLLEXPORT void midiwrite(unsigned char *buffer, int nbytes)
{
#ifdef __APPLE__
  if (synthUnit)
    {
      if (nbytes <= 3)
        {
          UInt32 inStatus, inData1, inData2, inOffsetSampleFrame;
          inStatus = buffer[0];
          inData1 = nbytes > 1 ? buffer[1] : 0;
          inData2 = nbytes > 2 ? buffer[2] : 0;
          inOffsetSampleFrame = 0;
          MusicDeviceMIDIEvent(synthUnit, inStatus, inData1, inData2, inOffsetSampleFrame);
        }
    }
  else
    {
      static Byte midi_buffer[1024];
      MIDIPacketList *pktlist = (MIDIPacketList *) midi_buffer;
      MIDIPacket *packet;
      packet = MIDIPacketListInit(pktlist);
      packet = MIDIPacketListAdd(pktlist, sizeof(midi_buffer), packet,
                                 AudioGetCurrentHostTime(), nbytes, buffer);
      if (MIDISend(output_port, dest, pktlist) != noErr)
        fatal("cannot send MIDI packet\n");
    }
#endif
#ifdef _WIN32
  if (nbytes <= 3)
    {
      DWORD dw = 0;
      memcpy(&dw, buffer, nbytes);
      midiOutShortMsg(midi_out, dw);
    }
  else
    {
      MIDIHDR midihdr;
      midihdr.lpData = buffer;
      midihdr.dwBufferLength = nbytes;
      midihdr.dwFlags = 0;
      midiOutPrepareHeader(midi_out, &midihdr, sizeof(midihdr));
      midiOutLongMsg(midi_out, &midihdr, sizeof(midihdr));
      midiOutUnprepareHeader(midi_out, &midihdr, sizeof(midihdr));
    }
#endif
}

DLLEXPORT void midiread(unsigned int *timeStamp, unsigned int *event)
{
  *timeStamp = 0;
#ifdef __APPLE__
  if (readIndex != writeIndex)
    {
      *timeStamp = midiEvent[readIndex].timeStamp;
      *event = midiEvent[readIndex].data;
      readIndex++;
    }
#endif
}

DLLEXPORT void mididataset1(int address, int data)
{
  static unsigned char sysex[11] = {
    0xf0, 0x41, 0x10, 0x42, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0xf7
  };
  register unsigned int i, sum;

  sysex[5] = (address >> 16) & 0xff;
  sysex[6] = (address >> 8) & 0xff;
  sysex[7] = address & 0xff;
  sysex[8] = (unsigned char) data;
  sum = 0;
  for (i = 5; i <= 8; i++)
    sum += sysex[i];
  sysex[9] = 128 - (sum % 128);

  midiwrite(sysex, 11);
}

DLLEXPORT void midiclose()
{
#ifdef __APPLE__
  if (synthUnit)
    {   
      if (graph)
        {   
          AUGraphStop(graph);
          DisposeAUGraph(graph);
        }
    }
  else
    {
      if (output_port != 0)
        MIDIPortDispose(output_port);
      if (client != 0)
        MIDIClientDispose(client);
    }
#endif
#ifdef _WIN32
  midiOutClose(midi_out);
#endif
}

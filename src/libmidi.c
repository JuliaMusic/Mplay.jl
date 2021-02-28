/*
 macOS:
   cc -shared -arch arm64 -arch x86_64 -o libmidi.dylib libmidi.c \
      -framework CoreMIDI -framework CoreAudio -framework AudioUnit \
      -framework AudioToolbox -framework Cocoa
 Windows:
   cl /c libmidi.c
   link /out:libmidi.dll libmidi.obj -dll winmm.lib
 */

#include <stdio.h>
#include <stdint.h>

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

#include <mach/mach_init.h>
#include <mach/mach_error.h>
#include <mach/mach_host.h>
#include <mach/vm_map.h>

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

#ifdef __linux__

#include "alsa/asoundlib.h"

#define DLLEXPORT

static snd_rawmidi_t *midi_out = 0;

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
  if (strcmp(device, "dlss") == 0 || strcmp(device, "scva") == 0 || MIDIGetDestination(0) == 0 )
    {
      AUNode synthNode, outNode;
      AudioComponentDescription cd;
      OSStatus result;

      __Require_noErr (result = NewAUGraph (&graph), home);

      cd.componentFlags = 0;
      cd.componentFlagsMask = 0;

      if (strcmp(device, "scva") == 0)
        {
          cd.componentType = 'aumu';
          cd.componentSubType = 'Sc55';
          cd.componentManufacturer = 'rolD';
        }
      else
        {
          cd.componentType = kAudioUnitType_MusicDevice;
          cd.componentSubType = kAudioUnitSubType_DLSSynth;
          cd.componentManufacturer = kAudioUnitManufacturer_Apple;
        }

      __Require_noErr (result = AUGraphAddNode (graph, &cd, &synthNode), home);

      cd.componentType = kAudioUnitType_Output;
      cd.componentSubType = kAudioUnitSubType_DefaultOutput;
      cd.componentManufacturer = kAudioUnitManufacturer_Apple;

      __Require_noErr (result = AUGraphAddNode (graph, &cd, &outNode), home);

      __Require_noErr (result = AUGraphOpen (graph), home);
      __Require_noErr (result = AUGraphConnectNodeInput (graph, synthNode, 0, outNode, 0), home);

      __Require_noErr (result = AUGraphNodeInfo(graph, synthNode, 0, &synthUnit), home);

      __Require_noErr (result = AUGraphInitialize (graph), home);
      __Require_noErr (result = AUGraphStart (graph), home);
    }
  else
    {
      int index;
      char name[255];
      CFStringRef displayName;
      void *conRef = NULL;

      if (*device != '\0')
        index = atoi(device);
      else
        index = MIDIGetNumberOfDestinations() - 1;

      if (MIDIClientCreate(CFSTR("Mplay"), NULL, NULL, &client) != noErr)
        fatal("cannot create MIDI client");

      if (MIDIOutputPortCreate(client, CFSTR("Output port"), &output_port) != noErr)
        fatal("cannot create MIDI output port");
      if ((dest = MIDIGetDestination(index)) == 0)
        fatal("cannot get MIDI destination");

      MIDIObjectGetStringProperty(dest, kMIDIPropertyDisplayName, &displayName);
      CFStringGetCString(displayName, name, 255, kCFStringEncodingASCII);
      printf("MIDI destination:  %s\n", name);

      if (MIDIInputPortCreate(client, CFSTR("Input port"), readProc, NULL, &input_port) != noErr)
        fatal("cannot create MIDI input port");

      if ((src = MIDIGetSource(index)) == 0)
        fprintf(stderr, "cannot get MIDI source\n");
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
#ifdef __linux__
  if (snd_rawmidi_open(NULL, &midi_out, device, 0))
    fatal("cannot open MIDI output");
#endif
}

#ifdef __APPLE__
void completionProc(MIDISysexSendRequest *request)
{
  assert(request->complete == true);
}
#endif

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
      else
        {
          MusicDeviceSysEx(synthUnit, buffer, nbytes);
        }
    }
  else
    {
      if (nbytes <= 3)
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
      else
        {
          static MIDISysexSendRequest request;
          request.destination = dest;
          request.data = buffer;
          request.bytesToSend = nbytes;
          request.complete = false;
          request.completionProc = completionProc;
          request.completionRefCon = NULL;
          if (MIDISendSysex(&request) != noErr)
            fatal("cannot send MIDI SysEx message");
        }
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
#ifdef __linux__
  if (nbytes <= 3)
    {
      snd_rawmidi_write(midi_out, buffer, nbytes);
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
#ifdef __linux__
  snd_rawmidi_drain(midi_out);
  snd_rawmidi_close(midi_out);
#endif
}

static
float CalculateCPULoad(uint64_t idleTicks, uint64_t totalTicks)
{
  static uint64_t previousTotalTicks = 0;
  static uint64_t previousIdleTicks = 0;
  uint64_t totalTicksSinceLastTime = totalTicks - previousTotalTicks;
  uint64_t idleTicksSinceLastTime = idleTicks - previousIdleTicks;
  float ret;

  if (totalTicksSinceLastTime > 0)
    ret = 1.0f - (float) idleTicksSinceLastTime / totalTicksSinceLastTime;
  else
    ret = 0.0f;

  previousTotalTicks = totalTicks;
  previousIdleTicks = idleTicks;

  return ret;
}

#ifdef __APPLE__

float midisystemload()
{
  uint64_t totalTicks, idleTicks;
  host_cpu_load_info_data_t cpuinfo;
  mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
  int i;
  float ret;

  if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t) &cpuinfo,
		      &count) == KERN_SUCCESS)
    {
      totalTicks = 0;
      for (i = 0; i < CPU_STATE_MAX; i++)
	totalTicks += cpuinfo.cpu_ticks[i];
      idleTicks = cpuinfo.cpu_ticks[CPU_STATE_IDLE];

      ret = CalculateCPULoad(idleTicks, totalTicks);
    }
  else
    ret = -1.0f;

  return ret;
}

#endif

#ifdef _WIN32

static
uint64_t FileTimeToInt64(const FILETIME ft)
{
  return (((uint64_t) (ft.dwHighDateTime)) << 32) | ((uint64_t) ft.dwLowDateTime);
}

DLLEXPORT float midisystemload(void)
{
  FILETIME idleTime, kernelTime, userTime;
  float ret;

  if (GetSystemTimes(&idleTime, &kernelTime, &userTime))
    ret = CalculateCPULoad(FileTimeToInt64(idleTime),
			   FileTimeToInt64(kernelTime) + FileTimeToInt64(userTime));
  else
    ret = -1.0f;

  return ret;
}

#endif

#ifdef __linux__

float midisystemload()
{
  return -1.0f;
}

#endif


/* The installation's choreography clock, in seconds (the HOLO-OS design's
   eight scenes; Kernel is one second longer for the installer's question).
   The clock stops twice: at WAIT until the player chooses to install, and
   just before Done until the server confirms. The sound cues on this clock
   are generated in sounds.ts. */

export const SCENES = {
  Post: 0,     // CRT powers on, the Kiroshi emblem assembles ring by ring, BIOS POST
  Kernel: 3,   // HOLO-OS boots dmesg style, the emblem docks in the corner, the installer asks
  Network: 7,  // carrier scan, join the grid node, download and verify the package
  Cortex: 11,  // map the V1 phase cells on the occipital bus, calibrate the synaptic interface
  Nerve: 15,   // bind both optic nerves through the chiasm, sync the spinal relay
  Flash: 19,   // erase sectors, hexdump, write the firmware, warm the emitter
  Verify: 23,  // self-test: the emblem explodes and spins as the emitter test pattern
  Done: 26,    // clear, emblem and wordmark, reboot countdown, CRT powers off
} as const;
export type Cues = typeof SCENES;

/** The installer's question is on screen: the clock waits for Install or Cancel. */
export const ASK = SCENES.Kernel + 3.3;
export const WAIT = SCENES.Kernel + 3.6;
/** Install jumps here: the answer typed, then the network stage. */
export const CONFIRM = SCENES.Kernel + 3.65;
/** The request leaves when the flash starts; a retry restarts there. */
export const REQUEST_AT = SCENES.Flash;
/** Without the server's answer the clock holds just short of Done. */
export const HOLD = SCENES.Done - 0.001;
/** The CRT is off: the interface opens. */
export const END = SCENES.Done + 3.0;

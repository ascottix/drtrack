# Dr. Track
**...the first "MOD" player and editor for DOS!**

It was in 1991 (or maybe 1990) when a friend showed me what would become one of the most successful products ever: the SoundBlaster card. It was capable of playing MIDI files but, most of all, could record and playback digital 8-bit samples. At the time the Amiga was the leading platform for (home) gaming and its audio capabilities were astounding: it had four independent digital channels with hardware-supported effects and awesome sound quality. Instead, the PC was blessed with a squeaky speaker and, if you were lucky, an AdLib card. But the SoundBlaster would soon start a revolution...

I was really impressed with the SoundBlaster, which came bundled with several remarkable demos, but the program that really floored me was written by a German hacker, who named it the SoundTracker. The SoundTracker was able to emulate the Amiga sound hardware on a standard SoundBlaster: it would compute the output of each channel in software, emulating hardware effects if necessary, and mix all four of them into a single channel that was then sent to the SoundBlaster. The result was astonishing and I still consider the SoundTracker as a true work of art.

When I saw that, I hadn't a clue how it worked... in fact I didn't know anything about the Amiga too! But I really wanted to know more...

In 1991 internet wasn't an option down here in Italy. Best you could do was getting a modem (I started with a 300 baud modem... can you imagine transferring data at about 30 characters per second?) and with a bit of luck connecting to a BBS, which usually allowed you to exchange messages and download files. But I'm digressing already. The point is: there was no Google to look for info, and you had to go straight to the source... the machine code. So I disassembled and reverse engineered the SoundTracker, and was able to grab many of its secrets. Also, thanks to bits of information retrieved here and there, and with the help of Amiga friends, I was able to obtain some more info about the MOD format, and even the source of a MOD player written for the Amiga (in Assembly for the 68000 of course...).

The MOD format is simple and ingenious. It contains the sequence of notes to play (with effects and all) organized in units called patterns, as well as the digitized samples used by the song. So, a MOD is a self contained unit and you had just everything you needed packed into a single file.

After the MOD format was also reverse engineered, I started working on a player. My PC was a 286 when I started (later, a friend of mine gave me a used 16 MHz 386 motherboard... a huge step forward!) and there are so many computations to do when playing a MOD that writing in Assembly was the only option... Eventually, the player started to work well. The code was very fast and I clocked everything on the interrupts that came from the DMA controller. This was a good choice: since the module was entirely loaded in memory and I was using only the SoundBlaster card hardware, it was possible to start the player and then shell back to DOS to work normally... the player took so little CPU that I could start it, then open the DOS prompt and run Windows 3.1, which would run flawlessly!

At that point, I also wanted to be able to create my own modules. Because there was no editor for the PC, I decided to write one and after a while... Dr. Track was born! Dr. Track was a good program and still works like a charm for editing MODs, just run it in DOSBox and see. Because Dr. Track was the first and only MOD editor for the PC, I decided to run a little experiment and published the program as [__shareware__](https://en.wikipedia.org/wiki/Shareware). It was priced at more or less the equivalent of 18 euros, which included the program, an extra 3.5" floppy disk full of MODs, packing and postage. It sold well and I continued to update it until version 1.30 in 1992. Then I had to leave for one year to serve in the Army and on coming back home I was so happy that the next release was completely free. The program was finally updated to version 1.45 in 1993, and that's the last version of Dr. Track.

Its features include:
- 4 digitalized channels (SoundTracker compatible);
- real-time recording and test mode;
- 4-voice background player;
- complete sample management;
- support for EGA/VGA BIOS enhancements (43/50 line mode, full colors);
- context sensitive hypertextual help;
- macro recording and playback for automating repetitive input sequences;
- sample libraries: store, catalog and retrieve samples easily;
- EMS support: can keep part of the MOD in EMS;
- complete support for the SB Pro (stereo and mixer control);
- graphical waveforms even in text mode;
- VOC and WAVE support;
- antivirus check: program computes and checks its own CRC at startup;
- graphical setup and configuration;
- much more...

Here are some screenshots captured in [DOSBox](https://www.dosbox.com/):

![Main screen in playing mode, 25 lines](https://ascottix.github.io/drtrack/drt_1.png)

Main screen in playing mode (25 lines)

![Instrument editor, 43 lines](https://ascottix.github.io/drtrack/drt_2.png)

Instrument editor (43 lines): a bit earlier I had invented a way to display graphics in text mode, which allowed my to add the nice waveform to this view

![Main screen, 43 lines](https://ascottix.github.io/drtrack/drt_3.png)

In extended mode (43 lines) the screen shows a lot of information, with the extra space even the mixer output can be displayed graphically in real-time in the upper right corner

## Source code

Dr. Track is written in Assembly and Turbo Pascal, the full source is in the `src` directory.

Probably it's not easy to recompile it now, so there also is a complete installation package in the `dist` directory. Just unzip it somewhere and mount the directory with [DOSBox](https://www.dosbox.com/). 

Finally, the `doc` directory contains an HTML version of the original manual. Although the manual is in Italian, the program contains a complete help system in English, so you won't have any problem to use it. Enjoy!

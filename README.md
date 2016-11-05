# Ultrasonic Ranger/Obstacle detector

## This device generates a tone increasing in pitch as you get closer to a wall, using ultrasonic ranging

Requires a HC-SR04 sensor

Code is for a Microchip PIC 16F628A

Using MPASM from MPLAB IDE 8.70 for Windows

description at http://www.richardmudhar.com/blog/2016/10/sonar-ranger-for-the-visually-impaired/

Battery test via potential divider on RA1 is shown in schematic but not implemented in PIC code yet 


5 Nov 2016 echoranger_mpasm_v09_rc01.asm 

Added a chirping to the sound when within ~ 13cm of object. This means it's within touching/ imminent bumping into range.
I found it easier to follow along walls using the chirping sound and round corners after you get used to it


25 Oct 2016 echoranger_mpasm_v08_rc01.asm 

first release 
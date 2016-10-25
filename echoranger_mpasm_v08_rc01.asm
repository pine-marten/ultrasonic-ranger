;******************************************************************* 
; Function:  Echoranger using a HC-SR04 ultrasound sensor. Makes a tone rises in pitch as you approach a hard surface  
; Processor: PIC16F628 at 4 MHz using internal RC oscillator 
; Revision:  $Id$
; Author:    Richard Mudhar 
; Date:      22 Oct 2016
; Notes:     release candidate 22/10/2016 
; Notes:     Can't easily use PWM to get the right frequency, must compute two variables
; Notes:     TMR0 is the measurement, TMR1 and the CCP make the tone, TMR2 makes an overflow timeout
; TODO       test battery before powering up
; TODO       chirp/interrupt the sound at 2cm       
;******************************************************************* 
        ERRORLEVEL -302 ;remove message about using proper bank
        LIST P=16F628, R=DEC    ; Use the PIC16F628 and decimal system 

        #include "P16F628A.INC"  ; Include header file 

        __config  _INTRC_OSC_NOCLKOUT & _LVP_OFF & _WDT_ON & _PWRTE_ON & _BODEN_ON  & _CP_OFF & _MCLRE_OFF

;---------------------------------------------------------





;   PIC PINOUT
;                                         ------------------------------
;                                        | 1 RA2          RA1        18 | 
;                                SIGOUT  | 2 RA3          RA0        17 | 
;                                        | 3 RA4          RA7        16 |
;                                        | 4 RA5(MCLR)    RA6        15 |
;                                    GND | 5 GND          VCC        14 | +5V
;                                   ECHO | 6 RB0          RB7        13 | 
;                                PULSout | 7 RX/RB1       RB6        12 | 
;                                  TONE  | 8 TX/RB2       RB5        11 |
;                                        | 9 RB3          RB4        12 |
;                                         ------------------------------
;

        CBLOCK 0x20             ; Declare variable addresses starting at 0x20 
            flags
            wreg
            sreg
            TMRH
            d1
            d2
            period  ; this is the period of the oscillator. Use ISR to toggle pin with this
        ENDC 
    #define PULSout PORTB,1
    #define SIGOUT  PORTA,3
    #define ECHO PORTB,0
    #define TONE PORTB,2
    #define valid flags,0


;---------------------------------------------------------
; Set the program origin for subsequent code.
      org 0x00
      GOTO          start

      ORG       0x04
      GOTO  ISR

;---------------------------------------------------------




start:
        clrwdt
        movlw   0x07
        movwf   CMCON           ;turn comparators off (make it like a 16F84)        

        banksel OPTION_REG
        movlw   b'01000100'        ; set timer 0 running int clock prescale to 64uS period
        movwf   OPTION_REG


        banksel T1CON
        movlw   b'00010001'     ; T1 prescale 2 T1OSC off, intOSC T1on
        movwf   T1CON

        banksel CCPR1H  
        movlw   .1
        movwf   CCPR1H
        movlw   .1
        movwf   CCPR1L

        banksel CCP1CON
        movlw   b'00001011'     ; compare mode, clear TMR1 on match
        movwf   CCP1CON


        banksel T2CON
        movlw   b'00010111'     ; T2 postscale 8 T2on, prescale 16 that is in total 128uS period ( ie 33 ms overflow)
        movwf   T2CON

        banksel PIE1
        bsf     PIE1, CCP1IE


        banksel TRISA 

        movlw b'11110111'       ; 0 is output
        movwf TRISA             ; portA   A3 is the output
        ;clrf   TRISA           ; make all port a o/p       

        banksel TRISB 

        movlw b'11111001'       ; 0 is output
        movwf TRISB             ; portB  B1,B2 out


        bcf STATUS,RP0          ; RAM PAGE 0
        bsf INTCON, PEIE        ; enable peripheral interrups
        bsf INTCON, GIE         ; enable interrupt


; http://randomnerdtutorials.com/complete-guide-for-ultrasonic-sensor-hc-sr04/
; If the HC-SR04 does not receive an echo then the output never goes low.
; Devantec and Parallax sensors time out after 36ms and I think 28ms respectively. 

forever:
        clrwdt
        call    ping
        call    Delay200us
        clrwdt
        ; now set the timeout timer
        clrf    TMR0    ; TMR0 measure the pulse with a finer resolution while
        clrf    TMR2    ; TMR2 has a coarser resolution but gives a timeout to detect no response or stuck sensor
        bcf     PIR1, TMR2IF
        bcf     INTCON,T0IF     ; so we can detect if it overflowed
        ; ECHO should be low for a short while after outgoing pulse. If not it got stuck last time, ignore result
        btfsc   ECHO
        goto    ignore
        btfss   ECHO
        goto    $-1     ; loop till high - this is the detect phase starting to listen for a return
        bsf     SIGOUT
        clrwdt      

retest:
        btfsc   PIR1, TMR2IF
        goto    ignore  ; high for too long, TMR2 timed out, toss result
        clrwdt
        btfsc   ECHO
        goto    retest
        ; drops through this part if TMR2 hasn't timed out by the time ECHO drops 

        btfsc   INTCON,T0IF     ; TMR0 overflowed?  this may have a shorter timeout, it's about 1.5m for use indoors
        goto    ignore          ; skip if it did
        bsf     valid
        movfw   TMR0
        movwf   CCPR1L          ; this is what changes the tone by copying TMR0 to the CCP comparison reset on TMR1 match target
        goto    continue
ignore:
        bcf     valid

continue:
        bcf     SIGOUT
        ; now loop on ECHO, wait for it to drop before progressing
        bcf     PIR1, TMR2IF    ; to make the final timeout on a raster
        clrwdt
        btfsc   ECHO
        goto    ignore          ; loop till low
timeout:
        clrwdt
        btfss   PIR1, TMR2IF    ; loop till high
        goto timeout
        goto forever







ping:
        bsf     PULSout     ; ping out
        movlw   .4          ; roughly 10 cycles
        movwf   TMRH
fv01:
        decfsz  TMRH,f
        goto    fv01
        bcf     PULSout
        return



reset:
        nop
        return


Delay1ms
            ;993 cycles
    movlw   0xC6
    movwf   d1
    movlw   0x01
    movwf   d2
Delay1ms_0
    decfsz  d1, f
    goto    $+2
    decfsz  d2, f
    goto    Delay1ms_0

            ;3 cycles
    goto    $+1
    nop

            ;4 cycles (including call)
    return




Delay200us
            ;196 cycles
    movlw   0x41
    movwf   d1
Delay200us_0
    decfsz  d1, f
    goto    Delay200us_0

            ;4 cycles (including call)
    return



; Actual delay = 0.06 seconds = 60000 cycles
; Error = 0 %

Delay60ms
            ;59993 cycles
    movlw   0xDE
    movwf   d1
    movlw   0x2F
    movwf   d2
Delay60ms_0
    decfsz  d1, f
    goto    $+2
    decfsz  d2, f
    goto    Delay60ms_0

            ;3 cycles
    goto    $+1
    nop

            ;4 cycles (including call)
    return







;the ISR

ISR     bcf     INTCON,GIE      ; disable all interrupts

                                ; save registers, swiped from microchip data sheet p105
        movwf   wreg            ; copy W to temp register, could be in either bank
        swapf   STATUS,w        ; swap status to be saved into W
        bcf     STATUS,RP0      ; change to bank 0 regardless of current bank
        movwf   sreg            ; save status to bank 0 register

        bcf     STATUS,RP0          ; RAM PAGE 0
        
        btfsc   PIR1,CCP1IF     ; test for timer 1  (PIR1 is still im ram page 0)
        goto    timer1isr
        goto    exit
        
timer1isr
        bcf     PIR1,CCP1IF
        movlw   b'00000100'     ; pick out bit 2
        btfsc   valid           ; only flip if valid
        xorwf   PORTB,f         ; flip TONE





exit:
    
        bcf     STATUS,RP0      ; change to bank 0 regardless of current bank
                                ; restore wreg and status register, pinched from microchip datasheet p105
        swapf   sreg,w
        movwf   STATUS      
        swapf   wreg,f
        swapf   wreg,w  
        retfie                  ; gie should get set back on here





        END 


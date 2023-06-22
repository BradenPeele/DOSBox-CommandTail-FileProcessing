MyStack SEGMENT STACK

DW 512 DUP (?)

MyStack ENDS

;=====

MyData SEGMENT

inFile DB 16 DUP(0)
numeral DW 0
inHandle DW 0
outHandle DW 0
outFile DB "output.txt", 0              ; I know it works with .txt
inBuffer DB 64 DUP (' ')
oneByteBuffer DB 0

inBufferSize DW 0
inBufferPos DW 0
aName DB 22 DUP (0)
nameSize DW 0
number DW 0

startTime DW 0

errorMsg DB "Error!", 0Ah, "$"

MyData ENDS

;==========

MyCode SEGMENT

myMain PROC
    
    ASSUME DS:MyData, CS:MyCode

    MOV AX, MyData 
    MOV DS, AX              ; DS point to data segment

    MOV AH, 0               ; get ticks
    INT 1AH                 ; 
    MOV startTime, DX       ; save startTime

    CALL commandTail        ; main control for looping 

    MOV AX, 0B800h
    MOV ES, AX              ; ES points to screen memory segment

    CALL openInFile
    CALL openOutFile
    CALL fillInBuffer

    mainLoop:               ; I know it's unstructured but it is what it is
        CALL processBuffer
        JMP mainLoop

    MOV AH, 4Ch             ; exit
    INT 21h                 ;

myMain ENDP

;==========

commandTail PROC
 
PUSH AX BX CX DX DI SI

        MOV SI, 80h
        MOV CL, ES:[SI]     ; length of command tail
        ADD SI, 2           ; get to first char
        LEA DI, inFile

    filenameLoop:
        MOV AL, ES:[SI]     ; get next byte from tail
        CMP AL, ' '         ; if space skip to getting number
        JE exitFilename
        MOV DS:[DI], AL     ; add to filename
        INC DI
        INC SI
        LOOP filenameLoop

    exitFilename:
        MOV DS:[DI], BYTE PTR 0     ; terminate filename with 0
        INC SI
        SUB CX, 3           
        MOV AX, 0           ; AX will act as the accumulator

    numeralLoop:
        MOV BL, ES:[SI]     ; get next byte from tail
        SUB BL, '0'         ; convert to int       
        MOV BH, 0
        ADD AX, BX          ; add to accumulator
        MOV BX, 10          ; 
        MOV DX, 0           ; clear DX
        MUL BX              ; move number over for next digit
        INC SI
        LOOP numeralLoop

        MOV BL, ES:[SI]     ; get next byte
        SUB BL, '0'         ; convert to int       
        MOV BH, 0
        ADD AX, BX          ; add to accumulator

        MOV numeral, AX

POP SI DI DX CX BX AX
RET

commandTail ENDP

;==========

errorMessage PROC

PUSH AX BX CX DX DI SI

        MOV AH, 09h
        LEA DX, errorMsg
        INT 21h

POP SI DI DX CX BX AX
RET

errorMessage ENDP

;==========

openInFile PROC

PUSH AX BX CX DX DI SI

        MOV AX, 3D00h           
        MOV DX, OFFSET inFile
        INT  21h 
        JNC noInFileError
        CALL errorMessage       ; display error message
        MOV AH, 4Ch             ; exit if error
        INT 21h                 ;
    noInFileError:
        MOV inHandle, AX

POP SI DI DX CX BX AX
RET

openInFile ENDP

;==========

openOutFile PROC

PUSH AX BX CX DX DI SI

        MOV  AH, 3Ch          
        MOV CL, 0           
        LEA DX, outFile
        INT  21h 
        JNC noOutFileError
        CALL errorMessage       ; display error message
        MOV AH, 4Ch             ; exit if error
        INT 21h                 ;
    noOutFileError:
        MOV outHandle, AX

POP SI DI DX CX BX AX
RET

openOutFile ENDP

;==========

fillInBuffer PROC

PUSH AX BX CX DX DI SI
 
        MOV AH, 3FH             ; read from file
        MOV BX, inHandle
        MOV CX, 64              ; number of bytes to be read
        LEA DX, inBuffer        ; address of buffer
        INT 21H
        MOV inBufferSize, AX    ; number of bytes read
        MOV inBufferPos, 0      ; reset buffer position
        JNC noReadError         ; if error set buffer size to 0
        CALL exitProg           ; exit program if no more buffer or error
    noReadError:

POP SI DI DX CX BX AX
RET

fillInBuffer ENDP

;==========

writeToOutFile PROC

PUSH AX BX CX DX DI SI

        MOV AX, number          ; compare number after name to command tail numeral
        CMP AX, numeral         ; 
        JLE dontWrite           ; only write if number is bigger than command tail numeral
        MOV AH, 40h
        MOV BX, outHandle
        MOV CX, nameSize        ; number of bytes to write
        LEA DX, aName           ; what is being written to file
        INT 21H

    dontWrite:

POP SI DI DX CX BX AX
RET

writeToOutFile ENDP

;==========

processBuffer PROC

PUSH AX BX CX DX DI SI
    
        CALL clearWhitespace    ; remove white space and returns next byte in oneByteBuffer
        LEA DI, aName           ; name variable
        MOV BL, oneByteBuffer   ; the byte returned by clearWhitespace
        MOV DS:[DI], BL         ; add byte to name
        INC DI                  ; next byte in name
        MOV nameSize, 1         ; initialize nameSize
        MOV CX, 19              ; max of 20 char per name

    nameLoop:
        CALL getNextByte        ; returns next byte in oneByteBuffer
        MOV BL, oneByteBuffer
        CMP BL, ' '             ; check for space / new line
        JLE exitNameLoop        
        MOV DS:[DI], BL         ; add byte to name
        INC DI                  ; next byte in name
        INC nameSize            
        LOOP nameLoop

    exitNameLoop:
        MOV DS:[DI], BYTE PTR 0Dh   ; add new line to end of name
        INC DI                      ;
        MOV DS:[DI], BYTE PTR 0Ah   ; 
        ADD nameSize, 2             ; account for the extra 2 bytes
        MOV CX, 5                   ; max 5 digits for number
        MOV AX, 0                   ; AX will act as the accumulator for converting to int
        MOV number, 0
        CALL clearWhitespace        ; remove white space

    numberLoop:
        MOV BL, oneByteBuffer       ; byte from last clearWhitespace call
        SUB BL, '0'                 ; convert to int
        MOV BH, 0                   ;
        ADD AX, BX                  ; add to accumulator
        MOV number, AX
        CALL getNextByte            ; check next byte for a number
        CMP oneByteBuffer, ' '      ;
        JLE exitNumberLoop          ; end of number
        MOV BX, 10                  ;
        MOV DX, 0                   ;
        MUL BX                      ; move number over for next digit
        LOOP numberLoop
        
    exitNumberLoop:
        MOV number, AX
        CALL writeToOutFile

POP SI DI DX CX BX AX
RET

processBuffer ENDP

;==========

clearWhitespace PROC

PUSH AX BX CX DX DI SI

    clearLoop:
        CALL getNextByte
        MOV AL, oneByteBuffer
        CMP AL, ' '     
        JG exitClearWhitespace  ; continue looping until a non whitespace character is found    
        JMP clearLoop           ; infinite loop

    exitClearWhitespace:

POP SI DI DX CX BX AX 
RET

clearWhitespace ENDP

;==========

getNextByte PROC

; loads buffer when buffer is empty

PUSH AX BX CX DX DI SI

        LEA SI, inBuffer        ; assign SI to current position in buffer
        MOV BX, inBufferPos     ;
        MOV AL, [SI + BX]       ; get next byte
        MOV oneByteBuffer, AL   ; save byte
        INC inBufferPos

        MOV BX, inBufferPos    
        CMP BX, inBufferSize    ; check for empty buffer
        JL getNextByteExit
        CMP inBufferSize, 64    ; check if it is last buffer
        JL exitProgram          ; if it is exit
        CALL fillInBuffer       ; fill buffer if not at end of file
        JMP getNextByteExit

    exitProgram:
        CMP oneByteBuffer, ' '    
        JLE getNextByteExit    

        MOV BL, oneByteBuffer       ; final byte
        SUB BL, '0'                 ; convert to int
        MOV BH, 0                   
        MOV AX, number              ; save existing accumulation
        MOV number, BX              ; save final byte
        MOV BX, 10                   
        MOV DX, 0                   
        MUL BX                      ; move number over for final digit
        ADD number, AX              ; put final digit in

        CALL writeToOutFile     ; put last name in file
        CALL exitProg

    getNextByteExit:

POP SI DI DX CX BX AX 
RET

getNextByte ENDP

;==========

displayTime PROC

PUSH AX BX CX DX DI SI

MOV DI, 10

        ; 1000 x numSeconds = 55 * ticks
        MOV AX, startTime   ; elapsed time put into startTime variable
        MOV BX, 55
        MUL BX              ; multiply elapsed time by 55

        MOV BX, 10

        XOR DX, DX          ; remove digit
        DIV BX              ;

        XOR DX, DX          ; remove digit
        DIV BX              ;

        XOR DX, DX          ; get digit
        DIV BX              ;
        ADD DX, '0'         ; convert to char
        MOV DH, 07h         ; set color
        MOV ES:[DI], DX     ; print to screen
        SUB DI, 2       

        MOV ES:[DI], BYTE PTR '.'   ; add decimal point
        SUB DI, 2    

        XOR DX, DX          ; get digit
        DIV BX              ;
        ADD DX, '0'         ; convert to char
        MOV DH, 07h         ; set color
        MOV ES:[DI], DX     ; print to screen
        SUB DI, 2     

POP SI DI DX CX BX AX 
RET

displayTime ENDP

;==========

exitProg PROC

        MOV AH, 0               ; get ticks
        INT 1AH                 ; 
        SUB DX, startTime       ; get elapsed time
        MOV startTime, DX       ; put elapsed time in startTime 
        CALL displayTime        ; display time

        MOV AH, 3Eh             ; close outFile
        LEA BX, outFile         ;
        INT 21h                 ;

        MOV AH, 3Eh             ; close inFile
        LEA BX, inFile          ;
        INT 21h                 ;

        MOV AH, 4Ch             ; exit
        INT 21h                 ;

exitProg ENDP

;==========

MyCode ENDS

end myMain
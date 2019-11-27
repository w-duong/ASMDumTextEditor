@@	as -g RASM4.s -o RASM4.o
@@	ld -o RASM4 /usr/lib/arm-linux-gnueabihf/libc.so RASM4.o -dynamic-linker /lib/ld-linux-armhf.so.3 ../lib/*.a

@@	RESERVED REGISTERS:
@@	R0-R3, R12 = unsafe: string subroutines, malloc, free, SYSCALLs will modify
@@	R4    	   = safe for starting dereferencing loops
@@	R5	  	   = safe for storing address to next 'node'
@@	R7	       = SYSCALL value
@@	R9         = file descriptor (integer value) for I/O
@@	R10        = current memory consumption (in bytes)
@@  R11        = current number of 'nodes' in list

		.data

@@	MAIN MENU DISPLAY LINES
strzLine000:			.asciz			"\n                RASM4 TEXT EDITOR"
strzLine001:			.asciz			"\n    Data Structure Memory Consumption (bytes): "
strzLine002:			.asciz			"\n    Number of Nodes: "

strzLine01:				.asciz			"****************************************************\n"
strzLine02:				.asciz			"*                                                  *\n"
strzLine03:				.asciz			"* <1> View all strings                             *\n"
strzLine04:				.asciz			"* <2> Add string                                   *\n"
strzLine05:				.asciz			"*     <a> from Keyboard                            *\n"
strzLine06:				.asciz			"*     <b> from File                                *\n"
strzLine07:				.asciz			"* <3> Delete string.                               *\n"
strzLine08:				.asciz			"* <4> Edit string.                                 *\n"
strzLine09:				.asciz			"* <5> String search.                               *\n"
strzLine10:				.asciz			"* <6> Save File.                                   *\n"
strzLine11:				.asciz			"* <7> Quit.                                        *\n"
strzLine12:				.asciz			"\n             INPUT CHOICE (1-7): "

		.equ			BUFSIZE,		1024
strKBBuffer:			.skip			BUFSIZE

@@	POINTER LABELS
strPointer1:			.word			0	@TEMPORARY POINTER FOR 'DATA'
firstPointer:			.word			0	@PERMANENT POINTER FOR BEGINNING OF LIST
lastPointer:			.word			0	@PERMANENT POINTER FOR ENDING OF LIST
currentPointer:			.word			0	@TEMPORARY POINTER FOR TRAVERSAL/DELETION
toBeDeleted:			.word			0	@TEMPORARY POINTER ONLY
bigConcat:				.word			0

@@	INTEGER VARIABLES
iValNode:				.word			0
iValMemory:				.word			0
iValInput:				.word			0

@@	MISCELLANEOUS PROMPTS/LABELS
strzInputSubMenu:		.asciz			"\nINPUT CHOICE ('a' or 'b'): "
strzEmptyList:			.asciz			"\nUnable to complete: LINKED LIST CURRENTLY EMPTY.\n"
strzUserPrompt:			.asciz			"\nEnter string (blank to quit): "
strzUserPromptEdit:		.asciz			"\nEnter new string: "
strzEnterSearch:		.asciz			"\nEnter search item: "
strzEnterAny:			.asciz			"\nENTER any key to continue: "
strzOutputResult:		.asciz			"\nLocation of node at: "
strzConfirm:			.asciz			"\n\nIs this the correct entry? => "
strzUserChoice:			.asciz			"\nConfirm (Y/N): "
strzInvalid:			.asciz			"\nINVALID CHOICE. PLEASE INPUT AGAIN."
invalidEditStr:			.asciz			"\nINVALID STRING EDIT! Please try again."
strzDenial:				.asciz			"\nString does not exist in list. Try again.\n"
strzOKDelete:			.asciz			"\nString successfully deleted!\n"
fileOutput:				.asciz			"out.txt"
fileInput:				.asciz			"input.txt"
cSearch:				.asciz			"\n"

@@	STRING VARIABLES
strSearchItem:			.skip			128
strNodeCount:			.skip			12
strMemConsumed:			.skip			12
strNodeAddress:			.skip			12
strAnyKey:				.skip			10
strUserYN:				.skip			10
strzInput1:				.skip			5
strzInput2:				.skip			5
strzInput3:				.skip			3
strFileInputBuf:		.skip			1
strzInput4:				.skip			3

		.balign							4
cENDL:					.byte			10
cTAB:					.byte			9
bTempOccupied:			.byte			0

		.text

		.global _start
		
_start:
	MOV		R9, #0
	MOV		R10, #0
	MOV		R11, #0

doWhile:
	BL		rasm4_printMenu
	LDR		R1, =strzLine12
	BL		putstring
	LDR		R1, =strzInput1
	MOV		R2, #5
	BL		getstring
	BL		ascint32
	LDR		R2, =iValInput
	STR		R0, [R2]
	MOV		R4, R0
	
	CMP		R4, #1
	BLEQ	printTraverse
	CMP		R4, #2
	BLEQ	subMenu
	CMP		R4, #3
	BLEQ	deleteNode
	CMP		R4, #4
	BLEQ	editString
	CMP		R4, #5
	BLEQ	searchList
	CMP		R4, #6
	BLEQ	writeToFile	
	CMP		R4, #7
	BEQ		exit
	B		doWhile
	
exit:
	BL		destroyList
	MOV		R7, #1
	SVC		0

@@@@@@@@@@@@
@@
@@	SUBMENU SYSTEM
@@
@@@@@@@@@@@@
subMenu:
	PUSH	{R4-R11, LR}
	
subBegin:
	LDR		R1, =strzLine05
	BL		putstring
	LDR		R1, =strzLine06
	BL		putstring
	LDR		R1, =strzInputSubMenu
	BL		putstring
	LDR		R1, =strzInput2
	MOV		R2, #5
	BL		getstring
	
	LDRB	R1, [R1]
	CMP		R1, #'a'
	BEQ		KBBLoop
	CMP		R1, #'A'
	BEQ		KBBLoop
	CMP		R1, #'b'
	BEQ		fromFile
	CMP		R1, #'B'
	BEQ		fromFile
	LDR		R1, =strzInvalid
	BL		putstring
	LDR		R1, =cENDL
	BL		putch
	B		subBegin

KBBLoop:
	LDR		R1, =strzUserPrompt			@prompt user
	BL		putstring
	
	LDR		R1, =strKBBuffer			@temporary storage into 'strKBBuffer'
	MOV		R2, #BUFSIZE
	BL		getstring
	
	LDRB	R4, [R1]					@check for user exit condition
	CMP		R4, #0x00
	BEQ		subExit
	BL		buildNode
	B		KBBLoop
	
fromFile:
	LDR		R0, =fileInput
	MOV		R1, #0000					@'0000' = READ only
	LDR		R2, =0666					@permissions (all access???)
	MOV		R7, #5						@system call number for 'open'. R0 must hold
										@'filename', R1 holds read/write flag options,
										@R2 declares accessibility.
	SVC		0
	MOV		R5, R0
	
readFrom:
	LDR		R1, =strFileInputBuf
	MOV		R0, #0x00
	STR		R0, [R1]
	MOV		R2, #1
	MOV		R0, R5
	MOV		R7, #3
	SVC		0
	
	BL		string_length
	CMP		R0, #0x00
	BEQ		suffixAppend
	BL		fileParse
	B		readFrom

suffixAppend:
	@@	KEYBOARD BUFFER PARSING FUNCTION HAS ONE LAST STRING THAT NEEDS TO
	@@	BE MANUALLY ADDED HERE
	
	LDR		R3, =bTempOccupied
	LDRB	R3, [R3]
	CMP		R3, #0x00
	BEQ		exitFrom
	LDR		R1, =toBeDeleted
	LDR		R1, [R1]
	BL		buildNode
	
	LDR		R0, =toBeDeleted
	LDR		R0, [R0]
	BL		free
	MOV		R0, #0
	LDR		R3, =bTempOccupied
	STRB	R0, [R3]
	
exitFrom:
	@@	CLOSE SYSCALL
	MOV		R0, R5
	MOV		R7, #6
	SVC		0
	
subExit:
	POP		{R4-R11, LR}
	BX		LR

@@@@@@@@@@@@
@@
@@	READ THROUGH ENTIRE LIST
@@
@@@@@@@@@@@@
printTraverse:
	PUSH	{R4-R11, LR}
	
	LDR		R0, =firstPointer									
	LDR		R0, [R0]					@dereference 'firstPointer' = address of '1st node'
	CMP		R0, #0x00
	BNE		loopPrint
	LDR		R1, =strzEmptyList
	BL		putstring
	B		printEnd
	
loopPrint:
	LDR		R1, =currentPointer
	STR		R0, [R1]					@address of '1st node' copied to 'currentPointer'
	
	LDR		R1, [R1]					@dereference 'currentPointer' = address of '1st node'
	LDR		R1, [R1]					@dereference first 4-bytes of '1st node' = 1st string
	
	BL		string_length
	MOV		R4, R0
	SUB		R4, #1
	BL		putstring					@display to terminal 'data' of current 'node'
	ADD		R1, R4						@move to last char of 'data' and check if '\n'
	LDRB	R1, [R1]					@exists. If not, append '\n' to advance to new
	CMP		R1, #0x0A					@line, otherwise, move to 'next' node.
	BEQ		nextString
	
	LDR		R1, =cENDL
	BL		putch
	
nextString:
	LDR		R1, =currentPointer			@reload 'currentPointer' and load a
	LDR		R1, [R1]					@temporary register with address of 'next'
	LDR		R0, [R1, #4]				@node
	CMP		R0, #0x00					@if 'next' node == \00, branch to exit,
	BEQ		printEnd					@otherwise, loop back to assign address
	B		loopPrint					@in temp register ('next') into 'currentPointer'
	
printEnd:
	BL		getChar

	POP		{R4-R11, LR}
	BX		LR

@@@@@@@@@@@@
@@
@@	BUILDING LINKED LIST FORWARD, ONE NODE AT A TIME
@@		- R1 SHOULD HOLD ADDRESS OF STRING TO BE ADDED AS NEW 'DATA'
@@		- 'firstPointer' AND 'lastPointer' SHOULD BE DECLARED IN DATA SECTION,
@@		   EVEN IF THEY CURRENTLY DO NOT POINT TO ANY NODES - SUBROUTINE
@@		   WILL ASSIGN AS NEEDED
@@		- 'iValMemory' AND 'iValNode' SHOULD BE DECLARED IN DATA SECTION
@@		- 'strPointer1' SHOULD BE DECLARED IN DATA SECTION
@@
@@@@@@@@@@@@
buildNode:
	PUSH	{R4-R11, LR}
	LDR		R10, =iValMemory
	LDR		R10, [R10]
	LDR		R11, =iValNode
	LDR		R11, [R11]
	
inputLoop:	
	BL		string_length
	CMP		R0, #0x00
	BEQ		inputEnd
	ADD		R10, R0						@adds to total memory consumption 

	BL		string_copy					@dynamically allocate memory and 
	LDR		R1, =strPointer1			@copy user input into storage for insertion
	STR		R0, [R1]
	
	MOV		R0, #8
	BL		malloc						@malloc 8-byte 'node' structure
	ADD		R10, #8						@adds memory required by 'node' to total
	ADD		R11, #1						@increment 'node' count
	
	LDR		R1, =strPointer1
	LDR		R1, [R1]					@retrieve, dereference and store
	STR		R1, [R0]					@user input into first 4-bytes of 'node'
	
	LDR		R1, =firstPointer			@check if 'firstPointer' is \00, 
	LDR		R3, [R1]					@if not, branch to insert from 'lastPointer'
	CMP		R3, #0x00
	BNE		skipFirst
	STR		R0, [R1]					@if 'firstPointer' == \00, then newly
	LDR		R2, =lastPointer			@malloc-d 'node' is assigned to 'firstPointer'
	STR		R0, [R2]					@and 'lastPointer'
	B		inputEnd					@loop back for additional user input
	
skipFirst:
	LDR		R2, =lastPointer			@retrieve and dereference the last
	LDR		R3, [R2]					@node of the list, then store newly
	STR		R0, [R3, #4]				@malloc-d 'node' into second 4-bytes
	STR		R0, [R2]					@IMPORTANT: updating 'lastPointer' to
	B		inputEnd					@newly malloc-d 'node' before loop back	
	
inputEnd:
	LDR		R8, =iValMemory
	STR		R10, [R8]
	LDR		R9, =iValNode
	STR		R11, [R9]

	POP		{R4-R11, LR}
	BX		LR
	
@@@@@@@@@@@@
@@
@@	PARSES FROM 'KEYBOARD BUFFER' FOR STRINGS ENDING IN '\N'.
@@		- IF POSSIBLE, NEW NODE WILL BE ALLOCATED FOR 'EXTRACTED' SUBSTRINGS
@@		  ENDING IN '\N' (INCLUDING BLANK LINES)
@@		- IF NOT POSSIBLE, STRING WILL BE STORED TEMPORARILY TO BE CONCATENATED TO
@@		  NEXT ITERATION OF 'KEYBOARD BUFFER'
@@		- R1 SHOULD HOLD STRING TO BE PARSED, I.E. 'strFileInputBuf'
@@		- R0-R3 WILL BE USED THROUGHOUT THIS SUBROUTINE, SO AT THE END RANDOM SHIT 
@@		  WILL BE RETURNED TO MAIN IN THESE REGISTERS (!!!)
@@
@@@@@@@@@@@@
fileParse:
	PUSH	{R4-R11, LR}
	
	MOV		R11, R1						@backing up address of evaluated string
	MOV		R5, #0						@beginning index of 'extracted' substring
	MOV		R6, #0						@ending index of 'extracted' substring
	LDR		R9, =bTempOccupied			@preload bool/flag for temporary storage
	
preParse:
	LDRB	R10, [R9]					@check if temporary storage occupied
	CMP		R10, #0x00
	BEQ		startParse					@if not, start parsing procedure normally
	MOV		R2, R1						@...otherwise, load temporary string
	LDR		R1, =toBeDeleted			@and 'keyboard buffer' into respective
	LDR		R1, [R1]					@registers to start 'string_concat'
	BL		string_concat
	LDR		R11, =bigConcat				@'bigConcat' becomes evaluated string for rest
	STR		R0, [R11]					@of this subroutine
	MOV		R11, R0						@override backup address of evaluated string
	MOV		R0, R1
	BL		free						@deallocate temporary storage and reset flag
	MOV		R10, #0
	STRB	R10, [R9]
	MOV		R1, R11

startParse:	
	LDR		R2, =cSearch				@start search for '\n': if not found, 
	BL		string_indexOf_1			@branch to temporary storage. Otherwise,
	CMP		R0, #-1						@branch to addition of new 'node'.
	BEQ		endParse
	MOV		R6, R0
	
	MOV		R2, R5						@R2 and R3 require beginning and ending
	MOV		R3, R6						@index values of substring to 'extract'
	BL		string_substring_1
	LDR		R1, =toBeDeleted
	STR		R0, [R1]
	LDR		R1, [R1]
	MOV		R10, #1
	STRB	R10, [R9]
	BL		buildNode
	LDR		R0, =toBeDeleted
	LDR		R0, [R0]
	BL		free
	MOV		R10, #0
	STRB	R10, [R9]
	
	ADD		R6, #1
	MOV		R5, R6
	ADD		R11, R5						@advance the evaluated string to new
	MOV		R1, R11						@index value - i.e. to the end of the 
	MOV		R5, #0						@'extracted' string. Then reset beginning
	MOV		R6, #0						@and ending index values for new loop
	B		startParse
	
endParse:
	BL		string_length				@if no '\n' found in 'keyboard buffer',
	MOV		R2, #0						@'extract' and store remaining string in
	MOV		R3, R0						@temporary storage, then trip storage flag
	BL		string_substring_1			@for next iteration to concatenate
	LDR		R1, =toBeDeleted
	STR		R0, [R1]
	LDR		R1, [R1]
	MOV		R10, #1
	STRB	R10, [R9]
	
	LDR		R0, =bigConcat
	LDR		R0, [R0]
	CMP		R0, #0x00					@IF 'bigConcat' was used this subroutine,
	BEQ		exitRZA						@deallocate the memory block it used
	BL		free
	MOV		R0, #0x00
	LDR		R1, =bigConcat
	STR		R0, [R1]

exitRZA:
	POP		{R4-R11, LR}
	BX		LR
	
@@@@@@@@@@@@
@@
@@	DELETE SPECIFIC STRING/NODE
@@
@@@@@@@@@@@@
deleteNode:
	PUSH	{R4-R11, LR}
	
	@@	PRE-LOAD STATS INTO R10 AND R11
	LDR		R10, =iValMemory
	LDR		R10, [R10]
	LDR		R11, =iValNode
	LDR		R11, [R11]
	
	@@	CASE 1: LIST IS EMPTY
	LDR		R1, =firstPointer			@pre-check: is list empty? if so, deny
	LDR		R1, [R1]					@user, branch back to main.
	CMP		R1, #0x00
	BEQ		emptyList
	
	BL		searchList					@...otherwise, user attempts search for string
	CMP		R0, #-1						@IF: string of interest is not in list,
	BEQ		exitDelete					@branch back to main
	
	LDR		R1, =firstPointer			@IF: address returned by 'searchList' is
	LDR		R1, [R1]					@NOT equal to 'firstPointer', 'node' exists in
	CMP		R1, R0						@middle of list, handle with CASE 3.
	BNE		middleOfList
	LDR		R2, =lastPointer			@IF: address returned by 'searchList' IS
	LDR		R2, [R2]					@equal to 'firstPointer' AND 'lastPointer', handle
	CMP		R2, R0						@with CASE 2A.
	BNE		firstButMore				@...otherwise, handle with CASE 2B.
	
	@@	CASE 2A: 'NODE' OF INTEREST IS FIRST AND _ONLY_ 'NODE'
firstAndOnly:
	LDR		R4, [R1]					@temporary register gets address of 'data'
	BL		free						@deallocate 'node' of interest

	SUB		R11, #1						@decrement 'node' count
	SUB		R10, #8						@subtract 'node' size from total
	MOV		R1, R4						@memory consumption
	BL		string_length				@subtract 'data' size from total
	SUB		R10, R0						@memory consumption
	
	MOV		R0, R4
	BL		free						@deallocate 'data' from 'node' of interest
	
	LDR		R1, =firstPointer
	MOV		R0, #0x00
	STR		R0, [R1]					@reset 'firstPointer' to 'null'
	LDR		R1, =lastPointer
	STR		R0, [R1]					@reset 'lastPointer' to 'null'
	B		succesfulDelete
	
	@@	CASE 2B: 'NODE' OF INTEREST IS FIRST BUT _NOT ONLY_ 'NODE'
firstButMore:
	LDR		R4, [R1]					@1st temporary register gets address of 'data'
	LDR		R5, [R1, #4]				@2nd temporary register gets address of 'next'
	BL		free						@deallocate 'node' of interest

	SUB		R11, #1						@decrement 'node' count
	SUB		R10, #8						@subtract 'node' size from total
	MOV		R1, R4						@memory consumption
	BL		string_length				@subtract 'data' size from total
	SUB		R10, R0						@memory consumption
	
	MOV		R0, R4
	BL		free						@deallocate 'data' from 'node' of interest
	
	LDR		R1, =firstPointer
	STR		R5, [R1]
	B		succesfulDelete
	
	@@	CASE 3A: 'NODE' OF INTEREST IS MIDDLE OF LIST
middleOfList:	
	LDR		R1, =firstPointer
	LDR		R1, [R1]

loopDelete:	
	MOV		R4, R1
	LDR		R1, [R1, #4]
	CMP		R1, R0
	BEQ		foundDelete
	CMP		R1, #0x00
	BEQ		foundLast
	B		loopDelete
	
foundDelete:
	LDR		R5, [R1, #4]
	LDR		R6, [R1]
	MOV		R0, R1
	BL		free
	SUB		R11, #1
	SUB		R10, #8
	
	MOV		R1, R6
	BL		string_length
	SUB		R10, R0
	MOV		R0, R6
	BL		free
	STR		R5, [R4, #4]
	B		succesfulDelete
	
	@@	CASE 3B: 'NODE' OF INTEREST IS THE LAST NODE OF LIST
foundLast:
	LDR		R6, [R1]
	MOV		R0, R1
	BL		free
	SUB		R11, #1
	SUB		R10, #8
	
	MOV		R1, R6
	BL		string_length
	SUB		R10, R0	
	MOV		R0, R6
	BL		free
	MOV		R0, #0x00
	STR		R0, [R4, #4]
	
	LDR		R1, =lastPointer
	STR		R4, [R1]
	B		succesfulDelete
	
emptyList:
	LDR		R1, =strzEmptyList
	BL		putstring
	BL		getChar
	B		exitDelete
	
succesfulDelete:
	LDR		R1, =strzOKDelete
	BL		putstring

exitDelete:
	@@	STATS CONVERSION TO STRING VALUES
	LDR		R8, =iValMemory
	STR		R10, [R8]
	LDR		R9, =iValNode
	STR		R11, [R9]
	
	POP		{R4-R11, LR}
	BX		LR
	
@@@@@@@@@@@@
@@
@@	EDIT STRING BASED ON USER SEARCHED INPUT FROM SEARCH_LIST
@@		- R2 SHOULD HOLD/POINT TO ADDRESS OF STRING 'TARGET' (DEREFERENCED)
@@		- R3 SHOULD BE FREE FOR USE BY THIS SUBROUTINE
@@		- R0 RETURNS ADDRESS OF 'NODE' OF INTEREST (WILL RETURN -1 IF NOT FOUND)
@@		- R1 RETURNS ADDRESS OF 'DATA' OF 'NODE' OF INTEREST (IF FOUND)
@@
@@@@@@@@@@@@
editString:
	PUSH	{R4-R11, LR}
	
	LDR		R10, =iValMemory
	LDR		R10, [R10]
	LDR		R11, =iValNode
	LDR		R11, [R11]

editStringLoop:
	BL 		searchList
	CMP		R0, #-1						@if list empty or 'node' not found, deny caller
	BEQ		doneEdit
	MOV 	R7, R0						@address of 'node' found
	MOV 	R8, R1						@address of 'data' of 'node' found

	LDR		R1, =strzUserPromptEdit		@prompt user for new string
	BL		putstring
	
	LDR		R1, =strKBBuffer			@temporary storage into 'strKBBuffer'
	MOV		R2, #BUFSIZE
	BL		getstring

	BL		string_length				@checks string length to see if string exists
	MOV		R6, R0
	CMP		R0, #0x00
	BEQ		invalidEdit

	BL		string_copy					@dynamically allocate memory and 
	LDR		R1, =strPointer1			@copy user input into storage for insertion
	STR		R0, [R1]					@string copy stores string in r0, then is stored in r1 ptr

	MOV		R1, R8
	BL		string_length				@subtract amount of memory used by old
	SUB		R10, R0						@'data' prior to deletion
	MOV		R0, R8						@free old 'data' of 'node' before
	BL		free						@replacing with new 'data'

	LDR		R1, =strPointer1
	LDR		R1, [R1]					@retrieve, dereference and store
	STR		R1, [R7]					@user input into first 4-bytes of 'node'
	ADD		R10, R6						@add amount of memory used by new 'data'
	B		doneEdit					@to running total
	
invalidEdit:
	LDR		R1, =invalidEditStr
	BL		putstring
	B		editStringLoop

doneEdit:
	LDR		R8, =iValMemory
	STR		R10, [R8]
	LDR		R9, =iValNode
	STR		R11, [R9]
	
	POP		{R4-R11, LR}
	BX		LR

@@@@@@@@@@@@
@@
@@	SEARCH THROUGH LIST ONE NODE AT A TIME
@@		- R2 SHOULD HOLD/POINT TO ADDRESS OF STRING 'TARGET' (DEREFERENCED)
@@		- R3 SHOULD BE FREE FOR USE BY THIS SUBROUTINE
@@		- R0 RETURNS ADDRESS OF 'NODE' OF INTEREST (WILL RETURN -1 IF NOT FOUND)
@@		- R1 RETURNS ADDRESS OF 'DATA' OF 'NODE' OF INTEREST (IF FOUND)
@@
@@@@@@@@@@@@
searchList:
	PUSH	{R4-R11, LR}
	
preSearch:
	LDR		R3, =firstPointer
	LDR		R3, [R3]
	CMP		R3, #0x00
	BNE		preSearchOK
	LDR		R1, =strzEmptyList
	BL		putstring
	BL		getChar
	B		printDenialEmpty
	
preSearchOK:
	LDR		R1, =strzEnterSearch
	BL		putstring
	LDR		R1, =strSearchItem
	MOV		R2, #128
	BL		getstring

	BL		string_copy					@exists for scope of this subroutine only
	MOV		R1, R0
	BL		string_toUpperCase			@capitalize to ignore casing
	
	MOV		R2, R1
	MOV		R11, R2						@backup address of capitalized 'target' string (COPY!!!)
	
	LDR		R3, =firstPointer
	LDR		R3, [R3]

startSearch:
	MOV		R10, R3						@backup address of current 'node'
	LDR		R4, [R3, #4]				@dereference into temp register, address of 'next'
	CMP		R4, #0x00
	BEQ		conditionalEnd
	
	LDR		R1, [R3]					@dereference into temp register, address of 'data'
	MOV		R9, R1						@backup address of 'data' of 'current' node (ORIGINAL!!!)
	
	BL		string_copy					@dynamically allocate copy of evaluated string,
	MOV		R1, R0						@exists for this iteration of loop only
	BL		string_toUpperCase			@capitalize to ignore casing
	
	MOV		R2, R11						@restore 'target' string to R2 (lost in shuffle?)
	BL		string_indexOf_3
	CMP		R0, #-1						@IF: not found, move to next 'node' and loop back to search again
	BNE		foundHit					@IF: found, branch to confirm

	MOV		R0, R1
	BL		free						@deallocating copy of evaluated string
	MOV		R3, R4						@before moving to next node
							
	B		startSearch
	
foundHit:
	MOV		R8, R1						@backup address of 'data' of 'current' node (COPY!!!)
	
userLoop:
	LDR		R1, =strzConfirm
	BL		putstring
	MOV		R1, R9						@display to user: the string found within node (ORIGINAL!!!)
	BL		putstring

	LDR		R1, =strzUserChoice			@prompt for user verification
	BL		putstring
	LDR		R1, =strUserYN
	MOV		R2, #10
	BL		getstring
	
	@@	SANITY CHECK STARTS HERE
	LDRB	R1, [R1]
	CMP		R1, #0x59					@IF: 'Y'
	BEQ		confirmChoice
	CMP		R1, #0x79					@IF: 'y'
	BEQ		confirmChoice
	CMP		R1, #0x4E					@IF: 'N'
	BEQ		denyChoice
	CMP		R1, #0x6E					@IF: 'n'
	BEQ		denyChoice
	LDR		R1, =strzInvalid			@IF: no valid options entered, continue
	BL		putstring					@prompting user for choice
	B		userLoop
	
conditionalEnd:
	LDR		R1, [R3]
	MOV		R9, R1
	CMP		R1, #0x00					@IF: list was empty to begin with, print
	BEQ		confirmedEnd				@denial message and return to caller
	
	BL		string_copy					@...otherwise, proceed normally
	MOV		R1, R0
	BL		string_toUpperCase
	
	MOV		R2, R11
	BL		string_indexOf_3			@check current (i.e. ONLY) 'node'
	CMP		R0, #-1						@for 'target'
	BNE		foundHit
	
	MOV		R0, R1						@deallocate copy of evaluated string
	BL		free						@before ending subroutine
	
confirmedEnd:
	MOV		R0, R11						@deallocate copy of 'target' string
	BL		free						@before ending subroutine

printDenial:
	LDR		R1, =strzDenial				@notify user 'target' not in list
	BL		putstring					@and return -1 to R0/caller
	BL		getChar
printDenialEmpty:
	MOV		R0, #-1
	B		exitSearch
	
confirmChoice:
	MOV		R0, R8						@deallocate capitalized, copy of 'data'
	BL		free
	MOV		R0, R11						@deallocate capitalized, copy of 'target'
	BL		free

	MOV		R0, R10						@return to caller: the address of 'node' of interest
	MOV		R1, R9						@return to caller: the address of 'data' of node of interest (ORIGINAL!!!)

	B		exitSearch

denyChoice:
	MOV		R0, R8
	BL		free
	
	CMP		R4, #0x00					@IF: user denies AND end of list, return to caller
	BEQ		confirmedEnd
	MOV		R3, R4						@...otherwise, move to 'next' node of list
	MOV		R2, R11						@restore address of 'target' string
	B		startSearch

exitSearch:
	POP		{R4-R11, LR}
	BX		LR
	
@@@@@@@@@@@@
@@
@@	WRITE LINKED LIST TO OUTPUT FILE
@@
@@@@@@@@@@@@
writeToFile:
	PUSH	{R4-R11, LR}
	
externalSave:
	LDR		R0, =fileOutput				@name of file required
	MOV		R1, #0101					@write ONLY + create file if it does not exist/overwrite
	LDR		R2, =0666					@accessability to users assigned
	MOV		R7, #5						@R7 = SYSCALL = 'open'
	SVC		0
	MOV		R9, R0						@backup to R9 the file descriptor value
	
	LDR		R4, =firstPointer
	LDR		R4, [R4]					@dereference 'firstPointer' = address of '1st node'
	
write:
	LDR		R1, [R4]					@R1 = dereferenced first 4-bytes of 'node' (!!!)
	MOV		R11, R1						@backup copy of address of string to write out
	LDR		R5, [R4, #4]				@R5 = dereferenced other 4-bytes of 'node' (!!!)
	BL		string_length
	MOV		R10, R0						@backup copy of string length
	MOV		R2, R0						@R2 = number of bytes to write out (from string_length)
	MOV		R0, R9						@R0 = requires file descriptor value
	MOV		R7, #4						@R7 = SYSCALL = 'write'
	SVC		0
	
	SUB		R10, #1						@get last index value of evaluated string
	ADD		R11, R10					@advance backup copy of address to last index
	LDRB	R11, [R11]
	CMP		R11, #0x0A					@if last char of evaluated string is already '\n'
	BEQ		skipCENDL					@no need to advance to next line in output file
	
	LDR		R1, =cENDL					@...otherwise, add '\n' to advance to next line in text file
	MOV		R2, #1
	MOV		R0, R9
	SVC		0

skipCENDL:
	CMP		R5, #0x00
	BEQ		writeEnd
	MOV		R4, R5
	B		write
	
writeEnd:
	MOV		R0, R9
	MOV		R7, #6
	SVC		0
	
	POP		{R4-R11, LR}
	BX		LR
	
@@@@@@@@@@@@
@@
@@	DESTROY/DEALLOCATE LINKED LIST (NODES + DATA ELEMENTS)
@@
@@@@@@@@@@@@
destroyList:
	PUSH	{R4-R11, LR}

	LDR		R0, =firstPointer
	LDR		R0, [R0]					@dereference 'firstPointer' = address of '1st node'
	CMP		R0, #0x00
	BEQ		deleteEnd

delete:
	LDR		R4, [R0]					@dereference into temp register, address of 'data'
										@which also needs to be deallocated
	LDR		R5, [R0, #4]				@loads temporary register with dereferenced
										@address of 'next' node
	BL		free						@deallocate 'node'
	MOV		R0, R4
	BL		free						@deallocate 'data'
	
	CMP		R5, #0x00
	BEQ		deleteEnd
	MOV		R0, R5
	B		delete
	
deleteEnd:
	POP		{R4-R11, LR}
	BX		LR
	
@@@@@@@@@@@@
@@
@@	CLEAR SCREEN
@@
@@@@@@@@@@@@
clearScreen:
	PUSH	{R4-R11, LR}
	
	MOV		R4, #0

loopENDL:
	CMP		R4, #50
	BEQ		endENDL
	LDR		R1, =cENDL
	BL		putch
	ADD		R4, #1
	B		loopENDL
	
endENDL:
	POP		{R4-R11, LR}
	BX		LR
	
@@@@@@@@@@@@
@@
@@	GETCH/PRESS 'ANY' KEY MACRO
@@
@@@@@@@@@@@@
getChar:
	PUSH	{R4-R11, LR}

	LDR		R1, =strzEnterAny
	BL		putstring
	LDR		R1, =strAnyKey
	MOV		R2, #10
	BL		getstring
	
	POP		{R4-R11, LR}
	BX		LR

@@@@@@@@@@@@
@@
@@	RASM4 MAIN MENU
@@
@@@@@@@@@@@@
rasm4_printMenu:
	PUSH	{R4-R11, LR}
	
	BL		clearScreen
	
	LDR		R0, =iValMemory
	LDR		R0, [R0]					@dereference literal value into R0
	LDR		R1, =strMemConsumed			@label to store string representation
	BL		intasc32
	
	LDR		R0, =iValNode
	LDR		R0, [R0]					@dereference literal value into R0
	LDR		R1, =strNodeCount			@label to store string representation
	BL		intasc32
	
	LDR		R1, =strzLine000
	BL		putstring
	LDR		R1, =strzLine001
	BL		putstring
	LDR		R1, =strMemConsumed
	BL		putstring
	LDR		R1, =strzLine002
	BL		putstring
	LDR		R1, =strNodeCount
	BL		putstring
	LDR		R1, =cENDL
	BL		putch
	BL		putch

	LDR		R1, =strzLine01
	BL		putstring
	LDR		R1, =strzLine02
	BL		putstring
	LDR		R1, =strzLine03
	BL		putstring
	LDR		R1, =strzLine02
	BL		putstring
	LDR		R1, =strzLine04
	BL		putstring
	LDR		R1, =strzLine02
	BL		putstring
	LDR		R1, =strzLine05
	BL		putstring
	LDR		R1, =strzLine06
	BL		putstring
	LDR		R1, =strzLine02
	BL		putstring
	LDR		R1, =strzLine07
	BL		putstring
	LDR		R1, =strzLine02
	BL		putstring
	LDR		R1, =strzLine08
	BL		putstring
	LDR		R1, =strzLine02
	BL		putstring
	LDR		R1, =strzLine09
	BL		putstring
	LDR		R1, =strzLine02
	BL		putstring
	LDR		R1, =strzLine10
	BL		putstring
	LDR		R1, =strzLine02
	BL		putstring
	LDR		R1, =strzLine11
	BL		putstring
	LDR		R1, =strzLine02
	BL		putstring
	LDR		R1, =strzLine01
	BL		putstring
	
	POP		{R4-R11, LR}
	BX		LR
	
		.end

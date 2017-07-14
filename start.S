#define rWTCON          0x53000000
#define rINTMSK         0x4A000008      /* Interupt-Controller base addresses */
#define rINTSUBMSK      0x4A00001C
#define rCLKDIVN        0x4C000014      /* clock divisor register */
#define rMPLLCON        0x4c000004
#define rUPLLCON        0x4c000008
#define rGPBCON         0x56000010
#define rGPBUP          0x56000018
#define rGPBDATA        0x56000014
#define rBWSCON         0x48000000
/*
 * NandFlash
 */
#define LENGTH_UBOOT    0x60000
#define NAND_CTL_BASE   0x4E000000
/* Offset */
#define oNFCONF         0x00
#define oNFCONT         0x04
#define oNFCMD          0x08
#define oNFSTAT         0x20

/*
 *  Stack position
 */
#define UndefStack       0x33FF5C00 
#define AbortStack       0x33FF6000
#define IRQStack         0x33FF7000
#define FIQStack         0x33FF8000
#define SVCStack         0x33FF5800

#define CONFIG_STACKSIZE	(128*1024)	/* regular stack */

#define CONFIG_ENV_SIZE 0x20000              /*size of environment */
#define CONFIG_SYS_MALLOC_LEN		(CONFIG_ENV_SIZE + 128*1024)
#define CONFIG_SYS_GBL_DATA_SIZE	128	/* size in bytes reserved for initial data */


/*
 *************************************************************************
 *
 * interrupt handler macro
 *
 *************************************************************************
 */
.macro Handler Addr
	sub     sp, sp, #4      
	stmfd   sp!, {r0}    
	ldr     r0, =\Addr    
	ldr     r0, [r0]          
	str     r0, [sp,#4]    
	ldmfd   sp!, {r0,pc}    
.endm
/*
 *************************************************************************
 *
 * Jump vector table as in table 3.1 in [1]
 *
 *************************************************************************
 */

.globl _start
_start:	b	start_code
	ldr	pc, _undefined_instruction
	ldr	pc, _software_interrupt
	ldr	pc, _prefetch_abort
	ldr	pc, _data_abort
	ldr	pc, _not_used
	ldr	pc, _irq
	ldr	pc, _fiq

_undefined_instruction:	.word undefined_instruction
_software_interrupt:	.word software_interrupt
_prefetch_abort:	.word prefetch_abort
_data_abort:		.word data_abort
_not_used:		.word not_used
_irq:			.word irq
_fiq:			.word fiq
	.balignl 16,0xdeadbeef


/*
 *************************************************************************
 *
 * Startup Code (called from the ARM reset exception vector)
 *
 * do important init only if we don't start from memory!
 * relocate armboot to ram
 * setup stack
 * jump to second stage
 *
 *************************************************************************
 */

_TEXT_BASE:
	.word	0x30000000

.globl _armboot_start
_armboot_start:
	.word _start

/*
 * These are defined in the board-specific linker script.
 */
.globl _bss_start
_bss_start:
	.word __bss_start

.globl _bss_end
_bss_end:
	.word _end


/*
 * the actual start code
 */

start_code:
	/*
	 * set the cpu to SVC32 mode
	 */
	mrs	r0, cpsr
	bic	r0, r0, #0x1f
	orr	r0, r0, #0xd3
	msr	cpsr, r0

	/* turn off the watchdog */
	ldr	r0, =rWTCON
	mov	r1, #0x0
	str	r1, [r0]

	/*
	 * mask all IRQs by setting all bits in the INTMR - default
	 */
	mov	r1, #0xffffffff
	ldr	r0, =rINTMSK
	str	r1, [r0]

        ldr     r1, =0x3fff
        ldr     r0, =rINTSUBMSK
        str     r1, [r0]

        /* Set system clock */
	/* FCLK:HCLK:PCLK = 1:4:8 */
	/* default FCLK is 400 MHz ! */
	ldr	r0, =rCLKDIVN
	mov	r1, #5
	str	r1, [r0]

	ldr r0, =rMPLLCON
	ldr r1, =(92<<12)|(1<<4)|(1)
	str r1, [r0]

        @ means Fclk:Hclk is not 1:1
	mrc p15,0,r0,c1,c0,0
	orr r0,r0,#0xc0000000;
	mcr p15,0,r0,c1,c0,0

	ldr r0, =rUPLLCON
	ldr r1, =(0x38<<12)|(0x02<<4)|(0x02)
	str r1, [r0]


	/*
	 * we do sys-critical inits only at reboot,
	 * not when booting from ram!
	 */
#ifndef CONFIG_SKIP_LOWLEVEL_INIT
	bl	cpu_init_crit
#endif


/*
 *************************************************************************
 *
 * Check code positon
 *
 *************************************************************************
 */
        adr     r0, _start              /* r0 <- current position of code   */
        ldr     r1, _TEXT_BASE          /* test if we run from flash or RAM */
        cmp     r0, r1                  /* don't reloc during debug         */
        beq     stack_setup
/*
 *************************************************************************
 *
 * Check boot flash
 *
 *************************************************************************
 */
        mov     r0, #rBWSCON 
        ldr     r0, [r0]
        bic     r0, r0, #0xfffffff5  /* BWSCON[2:1] is controled by OM[1:0] */
        cmp     r0, #0               /* when OM[1:0] is 00,BSWCON[2:1]=00, nand flash boot */
        bne     relocate             /* norflash boot */
/*
 *************************************************************************
 *
 * We boot from Nandflash
 *
 *************************************************************************
 */
        @ reset NAND
        mov     r1, #NAND_CTL_BASE
        ldr     r2, =( (7<<12)|(7<<8)|(7<<4)|(0<<0) )
        str     r2, [r1, #oNFCONF]
        ldr     r2, [r1, #oNFCONF]

        ldr     r2, =( (1<<4)|(0<<1)|(1<<0) )   @ Active low CE Control
        str     r2, [r1, #oNFCONT]
        ldr     r2, [r1, #oNFCONT]

        ldr     r2, =(0x6)      @ RnB Clear
        str     r2, [r1, #oNFSTAT]
        ldr     r2, [r1, #oNFSTAT]

        mov     r2, #0xff       @ RESET command
        strb    r2, [r1, #oNFCMD]

        mov     r3, #0  @ wait
nand1:
        add     r3, r3, #0x1
        cmp     r3, #0xa
        blt     nand1
nand2:
        ldr     r2, [r1, #oNFSTAT]      @ wait ready
        tst     r2, #0x4
        beq     nand2


        ldr     r2, [r1, #oNFCONT]
        orr     r2, r2, #0x2    @ Flash Memory Chip Disable
        str     r2, [r1, #oNFCONT]

        @ get read to call C functions (for nand_read())
        ldr     sp, DW_STACK_START      @ setup stack pointer
        mov     fp, #0  @ no previous frame, so fp=0

        @ copy U-Boot to RAM
        ldr     r0, _TEXT_BASE
        mov     r1, #0x0
        mov     r2, #LENGTH_UBOOT
        bl      CopyProgramFromNand
        tst     r0, #0x0
        beq     ok_nand_read

	ldr r0, =rGPBDATA
	ldr r1, =(0x0<<5)|(0x0<<6)|(0x0<<7)|(0x1<<8)
	str r1, [r0]
bad_nand_read:
loop2:
        b       loop2   @ infinite loop

ok_nand_read:
        @ verify
        mov     r0, #0
        ldr     r1, _TEXT_BASE
        mov     r2, #0x400      @ 4 bytes * 1024 = 4K-bytes
go_next:
        ldr     r3, [r0], #4
        ldr     r4, [r1], #4
        teq     r3, r4
        bne     notmatch
        subs    r2, r2, #4
        beq     stack_setup
        bne     go_next

notmatch:
loop3:
        b       loop3   @ infinite loop


/*
 *************************************************************************
 *
 * We boot from NorFlash
 *
 *************************************************************************
 */
relocate:				/* relocate U-Boot to RAM	    */
	adr	r0, _start		/* r0 <- current position of code   */
	ldr	r1, _TEXT_BASE		/* test if we run from flash or RAM */
	cmp	r0, r1			/* don't reloc during debug         */
	beq	stack_setup
	ldr	r2, _armboot_start
	ldr	r3, _bss_start
	sub	r2, r3, r2		/* r2 <- size of armboot            */
	add	r2, r0, r2		/* r2 <- source end address         */

copy_loop:
	ldmia	r0!, {r3-r10}		/* copy from source address [r0]    */
	stmia	r1!, {r3-r10}		/* copy to   target address [r1]    */
	cmp	r0, r2			/* until source end addreee [r2]    */
	ble	copy_loop
/*
 *************************************************************************
 *
 * Set up Stack
 *
 *************************************************************************
 */
stack_setup:
	mrs	r0, cpsr
	bic	r0, r0, #0x1f
	orr	r0, r0, #0xdb
	msr	cpsr, r0                @UndefMode		
	ldr	sp,=UndefStack		@UndefStack=0x33FF_5C00

	mrs	r0, cpsr
	bic	r0, r0, #0x1f
	orr	r0, r0, #0xd7
	msr	cpsr, r0                @AbortMode
	ldr	sp,=AbortStack		@AbortStack=0x33FF_6000

	mrs	r0, cpsr
	bic	r0, r0, #0x1f
	orr	r0, r0, #0xd2
	msr	cpsr, r0                @IRQMode
	ldr	sp,=IRQStack		@IRQStack=0x33FF_7000

	mrs	r0, cpsr
	bic	r0, r0, #0x1f
	orr	r0, r0, #0xd1
	msr	cpsr, r0                @FIQMode
	ldr	sp,=FIQStack		@FIQStack=0x33FF_8000

	mrs	r0, cpsr
	bic	r0, r0, #0x1f
	orr	r0, r0, #0xd3
	msr	cpsr, r0                @SVCMode
	ldr	sp,=SVCStack		@SVCStack=0x33FF_5800
/*
 *************************************************************************
 *
 * Clear Bss Section
 *
 *************************************************************************
 */
clear_bss:
	ldr	r0, _bss_start		/* find start of bss segment        */
	ldr	r1, _bss_end		/* stop here                        */
	mov	r2, #0x00000000		/* clear                            */

clbss_l:str	r2, [r0]		/* clear loop...                    */
	add	r0, r0, #4
	cmp	r0, r1
	ble	clbss_l

/*
 *************************************************************************
 *
 * Jump to main function
 *
 *************************************************************************
 */
	ldr	pc, _main
_main:	.word main 


#define STACK_BASE 0x33f00000
#define STACK_SIZE 0x10000
        .align  2
DW_STACK_START: .word   STACK_BASE+STACK_SIZE-4


/*
 ************************************************************************
 * CPU_init_critical registers
 *
 * setup important registers
 * setup memory timing
 *
 *************************************************************************
 */
#ifndef CONFIG_SKIP_LOWLEVEL_INIT
cpu_init_crit:
	/*
	 * flush v4 I/D caches
	 */
	mov	r0, #0
	mcr	p15, 0, r0, c7, c7, 0	/* flush v3/v4 cache */
	mcr	p15, 0, r0, c8, c7, 0	/* flush v4 TLB */

	/*
	 * disable MMU stuff and caches
	 */
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #0x00002300	@ clear bits 13, 9:8 (--V- --RS)
	bic	r0, r0, #0x00000087	@ clear bits 7, 2:0 (B--- -CAM)
	orr	r0, r0, #0x00000002	@ set bit 2 (A) Align
	orr	r0, r0, #0x00001000	@ set bit 12 (I) I-Cache
	mcr	p15, 0, r0, c1, c0, 0

	/*
	 * before relocating, we have to setup RAM timing
	 * because memory timing is board-dependend, you will
	 * find a lowlevel_init.S in your board directory.
	 */
	mov	ip, lr

	bl	lowlevel_init

	mov	lr, ip
	mov	pc, lr
#endif /* CONFIG_SKIP_LOWLEVEL_INIT */
/*
 *************************************************************************
 *
 * Interrupt handling
 *
 *************************************************************************
 */

@
@ IRQ stack frame.
@
#define S_FRAME_SIZE	72

#define S_OLD_R0	68
#define S_PSR		64
#define S_PC		60
#define S_LR		56
#define S_SP		52

#define S_IP		48
#define S_FP		44
#define S_R10		40
#define S_R9		36
#define S_R8		32
#define S_R7		28
#define S_R6		24
#define S_R5		20
#define S_R4		16
#define S_R3		12
#define S_R2		8
#define S_R1		4
#define S_R0		0

#define MODE_SVC	0x13
#define I_BIT		0x80

/*
 * use bad_save_user_regs for abort/prefetch/undef/swi ...
 * use irq_save_user_regs / irq_restore_user_regs for IRQ/FIQ handling
 */

	.macro	bad_save_user_regs
	sub	sp, sp, #S_FRAME_SIZE
	stmia	sp, {r0 - r12}			@ Calling r0-r12
	ldr	r2, _armboot_start
	sub	r2, r2, #(CONFIG_STACKSIZE)
	sub	r2, r2, #(CONFIG_SYS_MALLOC_LEN)
	/* set base 2 words into abort stack */
	sub	r2, r2, #(CONFIG_SYS_GBL_DATA_SIZE+8)
	ldmia	r2, {r2 - r3}			@ get pc, cpsr
	add	r0, sp, #S_FRAME_SIZE		@ restore sp_SVC

	add	r5, sp, #S_SP
	mov	r1, lr
	stmia	r5, {r0 - r3}			@ save sp_SVC, lr_SVC, pc, cpsr
	mov	r0, sp
	.endm

	.macro	irq_save_user_regs
	sub	sp, sp, #S_FRAME_SIZE
	stmia	sp, {r0 - r12}			@ Calling r0-r12
	add	r7, sp, #S_PC
	stmdb	r7, {sp, lr}^			@ Calling SP, LR
	str	lr, [r7, #0]			@ Save calling PC
	mrs	r6, spsr
	str	r6, [r7, #4]			@ Save CPSR
	str	r0, [r7, #8]			@ Save OLD_R0
	mov	r0, sp
	.endm

	.macro	irq_restore_user_regs
	ldmia	sp, {r0 - lr}^			@ Calling r0 - lr
	mov	r0, r0
	ldr	lr, [sp, #S_PC]			@ Get PC
	add	sp, sp, #S_FRAME_SIZE
	/* return & move spsr_svc into cpsr */
	subs	pc, lr, #4
	.endm

	.macro get_bad_stack
	ldr	r13, _armboot_start		@ setup our mode stack
	sub	r13, r13, #(CONFIG_STACKSIZE)
	sub	r13, r13, #(CONFIG_SYS_MALLOC_LEN)
	/* reserve a couple spots in abort stack */
	sub	r13, r13, #(CONFIG_SYS_GBL_DATA_SIZE+8)

	str	lr, [r13]			@ save caller lr / spsr
	mrs	lr, spsr
	str	lr, [r13, #4]

	mov	r13, #MODE_SVC			@ prepare SVC-Mode
	@ msr	spsr_c, r13
	msr	spsr, r13
	mov	lr, pc
	movs	pc, lr
	.endm

	.macro get_irq_stack			@ setup IRQ stack
	ldr	sp, =IRQStack
	.endm

	.macro get_fiq_stack			@ setup FIQ stack
	ldr	sp, =FIQStack
	.endm

/*
 * exception handlers
 */
	.align  5
undefined_instruction:
	get_bad_stack
	bad_save_user_regs
	bl	do_undefined_instruction

	.align	5
software_interrupt:
	get_bad_stack
	bad_save_user_regs
	bl	do_software_interrupt

	.align	5
prefetch_abort:
	get_bad_stack
	bad_save_user_regs
	bl	do_prefetch_abort

	.align	5
data_abort:
	get_bad_stack
	bad_save_user_regs
	bl	do_data_abort

	.align	5
not_used:
	get_bad_stack
	bad_save_user_regs
	bl	do_not_used


	.align	5
irq:
/*
	get_irq_stack
	irq_save_user_regs
	bl	do_irq
	irq_restore_user_regs
*/
/* use IRQ for USB and DMA */
    sub    lr, lr, #4                     @ the return address
    ldr    sp, =IRQStack            @ the stack for irq
    stmdb    sp!,     { r0-r12,lr }     @ save registers
    
    ldr    lr,    =int_return             @ set the return addr
    ldr    pc, =IRQ_Handle                @ call the isr
int_return:
    ldmia    sp!,     { r0-r12,pc }^     @ return from interrupt
	.align	5
fiq:
	get_fiq_stack
	/* someone ought to write a more effiction fiq_save_user_regs */
	irq_save_user_regs
	bl	do_fiq
	irq_restore_user_regs

do_fiq:



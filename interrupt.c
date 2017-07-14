#include "./usbslave/s3c24x0.h"
#include "./usbslave/s3c2440.h"
#include "./usbslave/io.h"
#include "./include/interrupt.h"
#include "./include/print.h"

void (*isr_handle_array[ISR_MAX])(void);    

void ClearPending_my(int bit) 
{
	struct s3c24x0_interrupt * const intregs = s3c24x0_get_base_interrupt();
 	writel(bit, &intregs->SRCPND);
	writel(bit, &intregs->INTPND);
}

void do_undefined_instruction(void)
{
	printk("Undefined instruction exception!!!\n");
	while(1);
}

void do_software_interrupt(void)
{
	printk("SWI exception!!!\n");
	while(1);
}

void do_prefetch_abort(void)
{
	printk("Pabort exception!!!\n");
	while(1);
}

void do_data_abort(void)
{
	printk("Dabort exception!!!\n");
	while(1);
}
void do_not_used(void)
{
	printk("Not used exception!!!\n");
	while(1);
}

void Dummy_isr(void)
{
	struct s3c24x0_interrupt * const intregs = s3c24x0_get_base_interrupt();
	printk("Dummy_isr error, interrupt number: %d, INTMSK = 0x%x\n", readl(&intregs->INTOFFSET), readl(&intregs->INTMSK));
	while(1);
}

void Isr_Init(void)
{
	int i = 0;
	struct s3c24x0_interrupt * const intregs = s3c24x0_get_base_interrupt();
    
	for (i = 0; i < sizeof(isr_handle_array) / sizeof(isr_handle_array[0]); i++ )
	{
		isr_handle_array[i] = Dummy_isr;
	}
	writel(0, &intregs->INTMOD);
	writel(BIT_ALLMSK, &intregs->INTMSK);
/*
   All=IRQ mode
   All interrupt is masked.
*/

}


void IRQ_Handle(void)
{
	struct s3c24x0_gpio * const gpio = s3c24x0_get_base_gpio();
	struct s3c24x0_interrupt * const intregs = s3c24x0_get_base_interrupt();
	unsigned long oft = readl(&intregs->INTOFFSET);
    
	// clean int
	if( oft == 4 ) {
		writel((1<<7), &gpio->EINTPEND);
	}
	writel((1<<oft), &intregs->SRCPND);
	writel(readl(&intregs->INTPND), &intregs->INTPND);
 

	/* run the isr */
	isr_handle_array[oft]();
}


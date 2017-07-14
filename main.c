
#include "./include/2440addr.h"
#include "./include/2440lib.h"
#include "./include/mmu.h"
#include "./include/interrupt.h"
#include "./include/print.h"

#include "usbslave/def.h"

extern void usb_init_slave(void);
extern u32 usb_receive(char *buf, size_t len, unsigned int wait);
extern void Isr_Init(void);


/*
 * 主函数
 */
int main(void)
{
	MMU_Init();
	Uart_Init();
	Port_Init();
	Isr_Init();
	Uart_SendByte('\n');

        rGPCCON = 0xAAAAA6AA;
        rGPCDAT &= ~(1<<5);
        
	enable_irq();

	printk("<***********************************************>\n");
	printk("           S3C2440 Test Program usbslave test\n");
	printk("               made by zhenguoyao\n");
	printk("<***********************************************>\n");  

       usb_init_slave();
       usb_receive((char *)0x30100000,0x00100000,1);
       while(1);
}

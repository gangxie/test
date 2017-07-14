#include "s3c24x0.h"
#include "s3c2440.h"
#include "io.h"
#include "../include/interrupt.h"

#define get_PCLK() 50000000 

//extern void (*isr_handle_array[ISR_MAX])(void);
 
extern void IsrUsbd(void);
extern void IsrDma2(void);
void (*isr_handle_array[ISR_MAX])(void);


extern void ClearPending_my(unsigned int bit);

static int intCount;

void Timer_InitEx(void)
{
	struct s3c24x0_interrupt * const intregs = s3c24x0_get_base_interrupt();
	intCount=0;	
 	writel((1<<13), &intregs->SUBSRCPND);
	ClearPending_my(BIT_WDT_AC97/*BIT_WDT*/);
 	writel((readl(&intregs->INTMSK) & ~(BIT_WDT_AC97 /*BIT_WDT*/)), &intregs->INTMSK);
	writel((readl(&intregs->INTSUBMSK) & ~(1<<13)), &intregs->INTSUBMSK);
}

void Timer_StartEx(void)
{
	struct s3c24x0_watchdog * const wdtregs = s3c24x0_get_base_watchdog();
    
	writel((((get_PCLK()/1000000-1)<<8)|(0<<3)|(1<<2)), &wdtregs->WTCON);  // 16us
	writel(0xffff, &wdtregs->WTDAT);
	writel(0xffff, &wdtregs->WTCNT);

	// 1/16/(65+1),interrupt enable,reset disable,watchdog enable
	writel((((get_PCLK()/1000000-1)<<8)|(0<<3)|(1<<2)|(0<<0)|(1<<5)), &wdtregs->WTCON);  
}

unsigned int Timer_StopEx(void)
{
	int count;
	struct s3c24x0_watchdog * const wdtregs = s3c24x0_get_base_watchdog();
	struct s3c24x0_interrupt * const intregs = s3c24x0_get_base_interrupt();

	writel(((get_PCLK()/1000000-1)<<8), &wdtregs->WTCON);
	writel((readl(&intregs->INTMSK) | BIT_WDT_AC97), &intregs->INTMSK);//禁止中断
	writel((readl(&intregs->INTSUBMSK) | (1<<13)), &intregs->INTSUBMSK);	//禁止中断

	count = (0xffff - readl(&wdtregs->WTCNT)) + (intCount*0xffff);
	return ((unsigned int)count*16/1000000);
}
void  IsrWatchdog(void)
{
	struct s3c24x0_interrupt * const intregs = s3c24x0_get_base_interrupt();
	writel((1<<13), &intregs->SUBSRCPND);  //单独清除watchdog标志
	ClearPending_my(BIT_WDT_AC97 /* BIT_WDT */);
	intCount++;   	//watchdog interrupt counts
}

int g_TimerIntHappen;  //这是一个标志
void  IsrTimer4(void)
{
	ClearPending_my(BIT_TIMER4);
	*(volatile int *)&g_TimerIntHappen = 1;//给标志置位
}

void Usb_Isr_Init(void)
{

    //绑定中断处理函数
        isr_handle_array[ISR_TIMER4_OFT] = IsrTimer4;//timer4中断
        isr_handle_array[ISR_WDT_OFT]  = IsrWatchdog;//watchdog中断

        isr_handle_array[ISR_USBD_OFT] = IsrUsbd; //usb device中断
        isr_handle_array[ISR_DMA2_OFT] = IsrDma2;//DMA2中断
        ClearPending_my(BIT_DMA2);
        ClearPending_my(BIT_USBD);
}


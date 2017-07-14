CC=arm-linux-gcc      
LD=arm-linux-ld

CFLAGS :=  -Wall -c

OBJCOPY=arm-linux-objcopy
OBJDUMP=arm-linux-objdump


objs := start.o lowlevel_init.o nand.o mmu.o mmulib.o interrupt.o  main.o  2440lib.o print.o
objs += ./usbslave/usbinit.o
objs += ./usbslave/usbmain.o
objs += ./usbslave/usblib.o
objs += ./usbslave/usbsetup.o
objs += ./usbslave/usbout.o
objs += ./usbslave/usbinterrupt.o

all: $(objs)
        
	$(LD) -Bstatic -Tboot.lds -Ttext 0x30000000 $(objs) \
        -L/home/sun/study/crosstools/4.4.3/lib/gcc/arm-none-linux-gnueabi/4.4.3 \
        -L/home/sun/study/crosstools/4.4.3/arm-none-linux-gnueabi/sys-root/usr/lib  \
        -Map usbslave.map -o usbslave.elf --start-group -lgcc -lgcc_eh -lgcov -lc --end-group    
	arm-linux-objdump -D usbslave.elf > usbslave.dis
 
	$(OBJCOPY)  -O binary  usbslave.elf usbslave.bin 


%.o:%.c
	$(CC) $(CFLAGS) -o $@ $<
%.o:%.S
	$(CC) $(CFLAGS) -o $@ $<
clean:
	rm -f *.bin *.elf  *.map *.o ./usbslave/*.o


# ahb_sram
## 1.功能介绍
  通过AHB slave 接口，完成对一个single port SRAM (1024 depth x 32 width) 的读写操作。
## 2.设计要求
  1）ASIC的话，0.13um 的综合速度要在300MHz~350MHz以上；fpga的话，使用Xilinx 7系列器件，可以跑到200MHz；
  2）要求 Code 的面积尽量小；
  3）考虑 SRAM 的 dout 延时比较大，可以在 SRAM 的 dout 后加一级寄存再送给 hrdata；
     PS：但这样做的话好像又损失了 SRAM 的 efficiency，可以考虑解决办法；
  4）需要仿真环境，并自动对比设计的正确性；
  

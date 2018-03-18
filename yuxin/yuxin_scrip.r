library(dplyr)

setwd("~/MyMD/yuxin")
library()
library(readr)

ww <- read_csv("yuxin_data.csv")
names(ww)
head(ww)
tail(ww)
dim(ww)
# row column
str(ww)
summary(ww)
subset(ww,batch==1)

mean.ww<-tapply(ww$ss,list(ww$exp,ww$day),mean)
sd.ww<-tapply(ww$ss,list(ww$exp,ww$day),sd)
n.ww<-tapply(ww$ss,list(ww$exp,ww$day),length)

barplot(mean.ww,
        xlab="day",
        ylab="ss")


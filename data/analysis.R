setwd("~/projects/owl-heart/data")
data <- read.csv("sample001.csv", header = F)
data <- c(t(data))
res <- abs(fft(data))
head(res)
plot(res)


install.packages("pracma")
library("pracma")
spec.pgram(detrend(data))

spec.pgram(data)

install.packages("xts")
library("xts")
data_ts <- xts(data, frequency = )
head(data_ts)
tail(data_ts)
plot(data_ts)
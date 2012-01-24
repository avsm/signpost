png("sim.png")
r <- read.table("sim.csv", header=T)
x <- seq(1, 100, 1)
l_20 <- r$perc_sp_20
l_15 <- r$perc_sp_15
l_10 <- r$perc_sp_10
l_5 <- r$perc_sp_5
l_2 <- r$perc_sp_2
plot(x, l_20, xlab="Percent signposts at edge", ylab="Factor of extra DNS load", 
    type="l", xlim=c(0, 100), ylim=c(0, 10))
lines(x, l_15, lty=2)
lines(x, l_10, lty=3)
lines(x, l_5, lty=4)
lines(x, l_2, lty=5)
leg.txt <- c("20 signposts", "15 signposts", "10 signposts", "5 signposts", "2 signposts")
legend(-3, 6, leg.txt, lty=c(1,2,3,4,5))
title("Factor increase in DNS traffic for signpost deployments\nSignpost traffic is 10% of DNS)\n10% of which is internal\n100 devices per resolver")
dev.off()
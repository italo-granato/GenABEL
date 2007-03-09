"ccfast" <-
function(y,data,snpsubset,idsubset,times=1,quiet=FALSE,bcast=10,clambda=TRUE) {
	if (class(data) != "gwaa.data") stop("wrong type of data argument, must be gwaa.data")
	if (!missing(snpsubset)) data <- data[,snpsubset]
	if (!missing(idsubset)) data <- data[idsubset,]
	if (any(data@gtdata@chromosome=="X") & dim(table(data@gtdata@male))>1) {
		data <- data[,data@gtdata@chromosome!="X"]
		if (!quiet) cat("X-chromosome data dropped\n")
	}

	attach(data@phdata,warn.conflicts=FALSE,pos=2)
	cc <- get(y,pos=2)
	detach(data@phdata)

        if (length(levels(as.factor(cc)))<2) stop("cc status is monomorphic!") 
        if (length(levels(as.factor(cc)))>2) stop("cc status has more then 2 levels!") 
        if (levels(as.factor(cc))[1] != 0 || levels(as.factor(cc))[2] != 1) stop ("cc is case-control status, with 0 as control and 1 as cases. No 0 and/or 1 found in the data")

	if (any(is.na(cc))) {
	  if (!quiet) warning(paste(sum(is.na(cc)),"people (out of",length(cc),") excluded as not having cc status\n"),immediate. = TRUE)
	  vec <- !is.na(cc)
	  data <- data[vec,]
	  cc1 <- cc[!is.na(cc)]
	} else {
	  cc1 <- cc
	}
	rm(cc)

	lenn <- data@gtdata@nsnps
	for (j in c(1:(times+1*(times>1)))) {
		if (j>1) cc1 <- sample(cc1,replace=FALSE)
		chi2 <- fcc(data@gtdata,cc1)
		if (j == 1) {
			chi2.1df <- chi2[1:lenn];
			chi2.2df <- chi2[(lenn+1):(2*lenn)];
			actdf <- chi2[(2*lenn+1):(3*lenn)];
			if (lenn<=10) {
				lambda <- list()
				lambda$estimate <- NA
				lambda$se <- NA
				chi2.c1df <- chi2.1df;
			} else {
				lambda <- estlambda(chi2.1df,plot=FALSE,prop=0.9)
				def <- 1/lambda$estimate
				if (def > 1 && clambda) {
					chi2.c1df <- chi2.1df;
				} else {
					chi2.c1df <- def*chi2.1df;
				}
			}
			effB <- chi2[(3*lenn+1):(lenn*4)]
			effAB <- chi2[(4*lenn+1):(lenn*5)]
			effBB <- chi2[(5*lenn+1):(lenn*6)]
			if (times>1) {
				pr.1df <- rep(0,lenn)
				pr.2df <- rep(0,lenn)
				pr.c1df <- rep(0,lenn)
			}
		} else {
			th1 <- max(chi2[1:lenn])
			pr.1df <- pr.1df + 1*(chi2.1df < th1)
			pr.2df <- pr.2df + 1*(chi2.2df < max(chi2[(lenn+1):(2*lenn)]))
			pr.c1df <- pr.c1df + 1*(chi2.c1df < th1)
			if (!quiet && ((j-1)/bcast == round((j-1)/bcast))) {
				cat("\b\b\b\b\b\b",round((100*(j-1)/times),digits=2),"%",sep="")
				flush.console()
			}
		}
	}
	out <- list()
	if (times>1) {
		out$P1df <- pr.1df/times
		out$P1df <- replace(out$P1df,(out$P1df==0),1/(1+times))
		out$P2df <- pr.2df/times
		out$P2df <- replace(out$P2df,(out$P2df==0),1/(1+times))
		out$Pc1df <- pr.c1df/times
		out$Pc1df <- replace(out$Pc1df,(out$Pc1df==0),1/(1+times))
	} else {
		out$P1df <- 1. - pchisq(chi2.1df,1)
		out$P2df <- 1. - pchisq(chi2.2df,actdf)
		out$Pc1df <- 1. - pchisq(chi2.c1df,1)
	}
	out$lambda <- lambda
	out$effB <- effB
	out$effAB <- effAB
	out$effBB <- effBB
	out$snpnames <- data@gtdata@snpnames
	out$map <- data@gtdata@map
	out$chromosome <- data@gtdata@chromosome
	out$idnames <- data@gtdata@idnames
	out$formula <- match.call()
	out$family <- "chi2 test for association, 2x2 and 2x3 tables"
	class(out) <- "scan.gwaa"
	out
}

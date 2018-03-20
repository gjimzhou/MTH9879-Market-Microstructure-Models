#--------------------------------------------------------------------------
#   Auxiliary functions: realized variance measures
#   Translated to R from Roel's 01-Feb-2007 Matlab code on 6-Aug-2008
#--------------------------------------------------------------------------
# gamma function (Optimized by Jing Chen, class of 2012. )
RVGAMMA <- function(p,h,q,k){
  n <- length(p);
  #If k==0, we can halve the calculation
  if (k==0){
    sample<-p[seq(h,n,q)] #Thanks to Tom!
    size<-length(sample)
    #Function diff is slower than direct subtraction
    r<-sample[2:size]-sample[1:(size-1)] #Thanks to Tom again!
    g<-sum(r*r)
  }
  else if (q==1){
    #This can be categorized as case III, but without seq function it runs faster
    #so we list it separately
    diff_overlap<-p[(h+k+1):(n-k)]-p[(h+k):(n-k-1)]
    r1<- c(p[(h+1):(h+k)]-p[h:(h+k-1)], diff_overlap)
    r2<- c(diff_overlap, p[(n-k+1):n]-p[(n-k):(n-1)])
    g<- sum(r1*r2)
  }
  else{
    index_m<-seq(h+k*q, n-k*q, q) #index of the overlapping part
    nm<-length(index_m)
    index_h<-seq(h, h+k*q, q) #index of the front
    index_t<-seq(index_m[nm], n, q) #index of the tail
    nh<-length(index_h)
    nt<-length(index_t)
    
    diff_m<-p[index_m[-1]]-p[index_m[-nm]]
    diff_h<-p[index_h[-1]]-p[index_h[-nh]]
    diff_t<-p[index_t[-1]]-p[index_t[-nt]]
    
    r1<- c(diff_h, diff_m)
    r2<- c(diff_m, diff_t)
    g<- sum(r1*r2)
  }
  return(g);
}

# realized variance
RVplain <- function(p,q){
    q <- max(1,round(as.double(q)));
    M <- length(p)-1;
    RV <- (M/q)/floor(M/q)*RVGAMMA(p,1,q,0);
return(RV);
}

# Zhou's subsampling RV
ZHOU <- function(p,q){
    q <- max(1,round(as.double(q)));
    M <- length(p)-1; RV <- 0;
    for (i in 1:q){
        RV <- RV + RVGAMMA(p,i,q,0) + 2*RVGAMMA(p,i,q,1);
    }
    RV <- M/(q*(M-q+1))*RV;
return(RV);
}

# ZMA two-scale RV
TSRV <- function(p,q){
    q <- max(2,round(as.double(q)));
    SS <- 0; RV <- RVGAMMA(p,1,1,0);
    M <- length(p)-1; Mb <- (M-q+1)/q;
    for (i in 1:q){
        SS <- SS + RVGAMMA(p,i,q,0);
    }
    RV <- (SS/q - Mb/M*RV)/(1-Mb/M);
return(RV);
}

# Zhang's multiscale RV
MSRV <- function(p,q){
    q <- max(2,round(as.double(q)));
    RV <- 0; i <- (1:q);
    a <- (12*(i/q^2)*(i/q-1/2)-6*i/q^3)/(1-q^(-2));
    for (h in 1:q){
        SS <- 0;
        for (i in 1:h){
            SS <- SS + RVGAMMA(p,i,h,0)/h;
        }
        RV <- RV + a[h]*SS;
    }
return(RV);
}

# Realized kernel with mod. Tukey-Hanning kernel
KRVTH <- function(p,q){
    q <- max(1,round(as.double(q)));
    r <- diff(p); RV <- RVGAMMA(p,1,1,0);
    for (s in 1:q){
        x <- (s-1)/q;
        RV <- RV + 2*(sin(pi/2*(1-x)^2))^2*RVGAMMA(p,1,1,s);
    }
return(RV);
}

# Realized kernel with Cubic kernel
KRVC <- function(p,q){
    q <- max(1,round(as.double(q)));
    r <- diff(p); RV <- RVGAMMA(p,1,1,0);
    for (s in 1:q){
        x <- (s-1)/q;
        RV <- RV + 2*(1-3*x^2+2*x^3)*RVGAMMA(p,1,1,s);
    }
return(RV);
}

# Realized kernel with Parzen kernel
KRVP <- function(p,q){
    q <- max(1,round(as.double(q)));
    r <- diff(p); RV <- RVGAMMA(p,1,1,0);
    for (s in 1:q){
        x <- (s-1)/q;
        if (x<1/2) { RV <- RV + 2*(1-6*x^2+6*x^3)*RVGAMMA(p,1,1,s);}
        else      { RV <- RV + 2*2*(1-x)^3*RVGAMMA(p,1,1,s); }
    }
return(RV);
}

#--------------------------------------------------------------------------
#   Ait-Sahalia, Mykland, Zhang (RFS, 2005) maximum likelihood estimator
#
#   (adapted from Yacine's code)                           10 December 2006
#--------------------------------------------------------------------------
AMZ <- function(y){
    n <- length(y); delta <- 1/n;
    s2ini <- max(sum(y^2)+2*sum(y[-1]*y[-n]),sum(y^2)/10);
    a2ini <- -sum(y[-1]*y[-n])/n;
    g2ini <- (2*a2ini + delta*s2ini + sqrt(delta)*sqrt(s2ini)*sqrt(4*a2ini + delta*s2ini))/2;
    etaini <-  (-2*a2ini - delta*s2ini + sqrt(delta)*sqrt(s2ini)*sqrt(4*a2ini + delta*s2ini))/(2*a2ini);
#    paramstart <- [g2ini;etaini]';
#    options <- optimset('Display','notify','TolX',1e-8,'TolFun',1e-10);
#    [param,fval,exitflag,output] <- fminsearch(@(par)MA1_triang_loglik(par,y), paramstart, options);

    opt <- optim(c(g2ini,etaini), function(par){MA1_triang_loglik(par,y)}, method = "L-BFGS-B",lower = -Inf, upper = Inf);
    s2 <- (opt$par[1]*(1 + 2*opt$par[2] + opt$par[2]^2))/delta;
    a2 <- - opt$par[1]*opt$par[2];
    return(list(a2=a2,s2=s2));
}

#--------------------------------------------------------------------------
#   Auxiliary function for AMZ (likelihood)
#--------------------------------------------------------------------------
MA1_triang_loglik <- function(par,y){

n <- length(y); g2 <- par[1]; eta <- par[2];

if (eta<0 && eta > -1 && g2>0){

    ytilde <- numeric(n);
    etavec <- (eta^(2*(1:(n+1))-2));
    etasum <- cumsum(etavec);
    etasumi <- etasum[-1];
    etasumim1 <- etasum[-(n+1)];
    dvec <- g2*etasumi/etasumim1;

    ytilde[1] <- y[1];
    for (i in 2 : n){
                       ytilde[i] <- y[i] - ytilde[i-1]*eta*etasumim1[i-1]/etasumim1[i];
                    }
    temp  <- - n*log(2*pi)/2 - sum(log(dvec))/2 - sum((ytilde^2)/dvec)/2; 
    f <- - temp/n;
    }

else {f <- 10^7;}

return(f);

}

#--------------------------------------------------------------------------
#   Malliavin and Mancino (Finance & Stochastics, 2002) Fourier estimator
#--------------------------------------------------------------------------
# Auxiliary functions
ab2 <- function(p,k){
    n <- length(p)-1;
    theta <- (0:n)/n*2*pi;
    cosseq <- cos(k*theta);
    ahat <- (p[n]-p[1])/pi - sum(p[-n]*diff(cosseq))/pi;
    sinseq <- sin(k*theta);
    bhat <- - sum(p[-n]*diff(sinseq))/pi;
return(ahat^2+bhat^2);
}
# Estimator from 
fourier <- function(p,s){
    tmp <- sum(sapply(1:s,function(k){ab2(p,k)}));
    return(pi^2/s*tmp);
}

#Test this estimator with artificial data
#x <- cumsum(rnorm(100000));
#res <- sapply(1:10,function(s){fourier(x,s)})

#Alternatively from Mancino and Sanfelici (2007)
fourier2 <- function(p,s){
    n <- length(p)-1;
    bigD <- function(dt){
        if (dt %% (2*pi) == 0) 1 else {1/(2*s+1)*sin((s+1/2)*dt)/sin(dt/2)};}
    dij <- sapply((0:(n-1))/n*2*pi,bigD);
    tmp <- convolve(diff(p),dij,type="c")
    return(diff(p) %*% tmp);
}
# fourier2 seems to be substantially faster than fourier for high cutoffs
# If the cutoff is low, fourier can be much faster.

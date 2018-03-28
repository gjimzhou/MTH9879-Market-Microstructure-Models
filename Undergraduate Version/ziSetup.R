#Book setup
L <- 30 #Set number of price levels to be included in iterations

# Generate initial book
LL <- 1000 #Total number of levels in buy and sell books

# Initialize book with asymptotic depth of 5 shares
initializeBook5 <- function()
{
  Price <<- -LL:LL    
  # Book shape is set to equal long-term average from simulation
  buySize <<- c(rep(5,LL-8),5,4,4,3,3,2,2,1,rep(0,LL+1))
  sellSize <<- c(rep(0,LL),0,1,2,2,3,3,4,4,5,rep(5,LL-8))
  book <<- data.frame(Price, buySize, sellSize ) 
  if(logging==T){eventLog <<- as.data.frame(matrix(0,nrow=numEvents,ncol=2))
  colnames(eventLog)<<-c("Type","Price")
  count <<- 0
  eventType <<- c("LB","LS","CB","CS","MB","MS")
  eventDescr <<- NA}
}


#Various utility functions
bestOffer <- function(){min(book$Price[book$sellSize>0])}
bestBid <- function(){max(book$Price[book$buySize>0])}
spread <- function(){bestOffer()-bestBid()}
mid <- function(){(bestOffer()+bestBid())/2}

#Functions to find mid-market
bidPosn<-function()length(book$buySize[book$Price<=bestBid()])
askPosn<-function()length(book$sellSize[book$Price<=bestOffer()])
midPosn<-function(){floor((bidPosn()+askPosn())/2)}

#Display center of book
go <- function(){book[(midPosn()-20):(midPosn()+20),]}

#Display book shape
bookShape<-function(band){c(book$buySize[midPosn()+(-band:0)],book$sellSize[midPosn()+1:band])}
bookPlot<-function(band){
  plot((-band:band),bookShape(band),
       col="red",type="l",xlab="Price",ylab="Quantity")
}

#Choose from L whole numbers in (1,...,L) with uniform probability
pick <- function(m){sample(1:m,1)}

# Switch logging on
logging <- T

#Buy limit order
limitBuyOrder <- function(price=NA){
  if (is.na(price))
  {prx <<- (bestOffer()-pick(L))}
  else prx <<-price  
  if(logging==T){eventLog[count,]<<- c("LB",prx)} 
  book$buySize[book$Price==prx]<<-book$buySize[book$Price==prx]+1} 

#Sell limit order
limitSellOrder <- function(price=NA){
  if (is.na(price))
  {prx <<- (bestBid()+pick(L))}
  else prx <<-price  
  if(logging==T){eventLog[count,] <<- c("LS",prx)}  
  book$sellSize[book$Price==prx]<<-book$sellSize[book$Price==prx]+1} 

#Cancel buy order            
cancelBuyOrder<-function(price=NA){
  q<-pick(nb) 
  tmp <- cumsum(rev(book$buySize))  #Cumulative buy size from 0
  posn <- length(tmp[tmp>=q]) #gives position in list where cumulative size >q
  prx <<- book$Price[posn] 
  if (!is.na(price)) {prx <<-price} 
  if(logging==T){eventLog[count,]<<- c("CB",prx)} 
  book$buySize[posn]<<-book$buySize[posn]-1}


#Cancel sell order
cancelSellOrder<-function(price=NA){
  q<-pick(ns) 
  tmp <- cumsum(book$sellSize)  #Cumulative sell size from 0
  posn <- length(tmp[tmp<q])+1 
  prx <<- book$Price[posn] 
  if (!is.na(price)) {prx <<-price}  
  if(logging==T){eventLog[count,]<<- c("CS",prx)} 
  book$sellSize[posn]<<-book$sellSize[posn]-1}

#Market buy order
marketBuyOrder <- function(){
  prx <<- bestOffer() 
  if(logging==T){eventLog[count,]<<- c("MB",prx)} 
  book$sellSize[book$Price==prx]<<-book$sellSize[book$Price==prx]-1}

#Market sell order
marketSellOrder <- function(){
  prx <<- bestBid() 
  if(logging==T){eventLog[count,]<<- c("MS",prx)} 
  book$buySize[book$Price==prx]<<-book$buySize[book$Price==prx]-1}


#Generate an event and update the buy and sell books
#Note that limit orders may be placed inside the spread
generateEvent <- function()
{
  nb <<- sum(book$buySize[book$Price>=(bestOffer()-L)]); # Number of cancelable buy orders
  ns <<- sum(book$sellSize[book$Price<=(bestBid()+L)]); # Number of cancelable sell orders
  eventRate <- nb*delta+ns*delta + mu +2*L*alpha;
  probEvent <- c(L*alpha,L*alpha,nb*delta,ns*delta,mu/2,mu/2)/eventRate;
  m <- sample(1:6, 1, replace = TRUE, probEvent); #Choose event type
  switch(m,
         limitBuyOrder(),
         limitSellOrder(),
         cancelBuyOrder(),
         cancelSellOrder(),
         marketBuyOrder(),
         marketSellOrder()
  );
  
}
#library(ks)
library(gtools)
library(dismo)

options(warn=-1)

# Retunnnth AUX given the pa and the prob
auc<-function(p0,pa) {
  mean(sample(p0[which(pa==1)],1000,replace=T)>sample(p0[which(pa!=1)],1000,replace=T),na.rm=T)
}

range01 <- function(x) x/sum(x,na.rm=T)

getraster<-function(file) {
  ras=raster(file)
  #In the case is one of my pgm files with no geo information
  if (substr(file,nchar(file)-3,nchar(file))==".pgm") {
    xmin(ras)=-180;xmax(ras)=180;ymin(ras)=-90;ymax(ras)=90
  }
  ras
}
	
#' membership
#' 
#' membership is used to develop an environmental model from known locations, 
#' and use them to predict further occurrences
#' 
#' The main application is species niche modelling.  
#' The algorithm implemented here claims to be both more accurate and 
#' more informative than other methods (hence the name 'WhyWhere').
#'
#' @param files A single environmental file
#' @param ext a geographic extent 
#' @param Basis Presence locations and absence locations
#' @param pa a vector of zeros and ones for presence and absence locations
#' @return A model object membership 

membership<-function(file, ext, Basis,pa) {
  r=getraster(file)
  ras=crop(r,ext)
  #Table of data
  e=na.omit(data.table(pa,Basis,values=extract(ras,Basis)))
  #Values into factor levels
  nbreaks=min(length(unique(e$values)),10)
  #Determine factors - if quantiles doesnt work do even breaks
  #print(paste("Doing",names(ras)))
  quants=quantile(e$values,seq(0,1,1/nbreaks))
  factors=try(cut(e$values,quants))
  if (class(factors) == "try-error") factors=try(cut(e$values,nbreaks))
  if (class(factors) == "try-error") return(NULL)
  e[,factors:=factors]
  setkey(e,factors)
  #Construct lookup table for probs on factors
  lookup=data.table(factors=levels(e$factors),levels=1:nlevels(e$factors))
  setkey(lookup,factors)
  lookup[,g1:=e[,table(factors)]]
  lookup[,g2:=e[pa==1,table(factors)]]
  lookup[,prob:=round(g2/g1,2)]
  lookup$prob[is.nan(lookup$prob)]<-0
  e=lookup[e]
  auc=round(auc(e$prob,e$pa),2)
  o=list(name=names(ras),AUC=auc,data=e,raster=ras,lookup=lookup)
}
	

#' predict
#' 
#' predict is used to develop an environmental map from known locations, 
#' and use them to predict further occurrences
#' 
#' The main application is species niche modelling.  
#' The algorithm implemented here claims to be both more accurate and 
#' more informative than other methods (hence the name 'WhyWhere').
#'
#' @param obj is a model object from whywhere
#' @return A raster of probability


predict.anomaly<-function(obj) {
  t=obj$lookup$factors
  n1=as.numeric(unique(unlist(strsplit(substr(t, 2, nchar(t)-1),","))))
  m=n1[order(n1)]
  ras=cut(obj$ras,m)
  id=data.frame(cbind(1:length(t),obj$lookup$prob))
  s=subs(ras,id)
}

#' whywhere
#' 
#' whywhere is used to develop an environmental model from known locations, 
#' and use them to predict further occurrences
#' 
#' The main application is species niche modelling.  
#' The algorithm implemented here claims to be both more accurate and 
#' more informative than other methods (hence the name 'WhyWhere').
#'
#' @param Pres A 2 column data.frame of known locations
#' @param files The environmental files for raster 
#' @param multi multiple dimensions
#' @param limit minimum for entry into results
#' @param beam number of entries to keep in table
#' @param e size of border around presence points
#' @return result A frame of results


whywhere<-function(Pres,files,multi=F,limit=0,beam=5,e=0.5) {
  ext=as.numeric(sapply(Pres,range))+c(-e,e,-e,e)
  Back=data.frame(lon=runif(1000,ext[1],ext[2]),
                  lat=runif(1000,ext[3],ext[4]))
  pa=c(rep(1,dim(Pres)[1]),rep(0,dim(Back)[1]))
  Basis=rbind(Pres,Back)
  result=data.table(name="limit",AUC=limit)
  for (i in files) {
    a=membership(i,ext, Basis,pa) 
    #membership failed test
    if (is.null(a)) { print(paste("Skipping: membership failed")) }
    else {
      #test to admit to results
      result=rbindlist(list(result,
                            data.table(name=a$name,AUC=a$AUC)))
      setorder(result,-AUC)
      #best one sofar - save some data and plot
      if (a$name==result[1]$name) {
        topdata=a$data
        plot(predict.anomaly(a),
             main=paste(a$name," AUC=",a$AUC,sep=""))
        points(Pres, col='blue')
      }
      print(result)
      #Test combination with first
      p=pmin(a$data$prob,topdata$prob)
      auc=auc(p,a$data$pa)
      #Add conjunc if better
      if (multi && auc>result[1]$AUC) {
        topdata=data.table(prob=p)
        result=rbindlist(list(result,
                              data.table(name=paste(result[1]$name,".",a$name,sep=""),AUC=auc)))
      }
      setorder(result,-AUC)
      #delete the last if maxed out
      if (dim(result)[1]>beam) result=result[1:beam,]
    }
  }
  result
}



plot.membership<-function(o) {
  #Needs to handle multiple obs
  #Plot it
  #barplot(Prob[,fin],width=diff(Breaks[,fin]),col=heat.colors(length(Prob[,fin])))
  
  side=floor(sqrt(length(o)))
  par(mfcol=c(1,side))
  lapply(o, function(x) {
    plot.ts(x$membership,ylim=c(0,1),xlab="Values",ylab="Response",
            plot.type="single",col=2:4)
    lines(x$fitted,lwd=3,col=4)
    title(x$name)
    })
}
  


% Generated by roxygen2 (4.1.0): do not edit by hand
% Please edit documentation in R/ww2.R
\name{predict.dseg}
\alias{predict.dseg}
\title{predict}
\usage{
predict.dseg(obj)
}
\arguments{
\item{obj}{is a model object from whywhere}
}
\value{
A raster of probability
}
\description{
predict is used to develop an environmental map from known locations,
and use them to predict further occurrences
}
\details{
The main application is species niche modelling.
The algorithm implemented here claims to be both more accurate and
more informative than other methods (hence the name 'WhyWhere').
}


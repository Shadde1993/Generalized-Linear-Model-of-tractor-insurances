install.packages("ggplot2")
install.packages("foreach")
install.packages("xlsx")
library(ggplot2)
library(foreach)
library(xlsx)

######################### Section 1: Read data #########################

# This is where your GLM data is read form tractors.csv into a table in R 
# Note that the folder in which you have tractors.csv must be set as the working directory 
###### You do not need to change anything in this section. The data will be sotred in a table named glmdata

glmdata <- read.table("Tractors.csv", header=TRUE, sep=";", dec="," )

rmYear <- glmdata[1] !=2003

glmdata<- glmdata[rmYear,]

rmW <- glmdata[3] >= 300

glmdata<- glmdata[rmW,]

######################### Section 2: Create groups & aggregate data #########################

# Now you need to modify your data so that you can perform a GLM analysis 

# First, any continuous variable needs to be grouped into discrete groups 
# The code below groups the variable weight, from you table glmdata, into six groups, and stores this in a new column, weight_group 
###### This is only an example. You need to create your own groups, with breaks that suit your data
###### You might also want to group other variables from glmdata, in a similar manner

glmdata$weight_group <- cut(glmdata$Weight, 
                       breaks = c(-Inf, 1000, 2000, 3000, 4000, 5000, Inf), 
                       labels = c("01_<1000kg", "02_1000-1999kg", "03_2000-2999kg", "04_3000-3999kg", "05_4000-4999kg", "06_>=5000kg"), 
                       right = FALSE)

glmdata$age_group <- cut(glmdata$VehicleAge, 
                            breaks = c(-Inf, 1, 4, 8, 14, 20, 26,30, Inf), 
                            labels = c("01_<1year", "02_<1-3year", "03_4-7year", "04_8-13year", "05_14-19year", "06_20-25year", "07_26-29year", "08_>=30year"), 
                            right = FALSE)

# Secondly, we want to aggregate the data.
# That is, instead of having one row per tractor, we want one row for each existing combination of variables 
# This code aggregates columns 6-8 of glmdata, by three variables: weight_group, Climate, and ActivityCode 
# Tha aggregated data is stored in a new table, glmdata2 
##### You need to consider if there are any other variables you want to aggregate by, and modify the code accordingly 

glmdata2 <- aggregate(glmdata[,6:8] ,by=list(weight_group = glmdata$weight_group,
                                             age_group = glmdata$age_group,
                                            Climate = glmdata$Climate,
                                            ActivityCode = glmdata$ActivityCode), FUN=sum, na.rm=TRUE)

# We then do some preparation for the output the GLM function will give.
# This piece of code creates a new table, glmdata3, with a row per variable and group, and with data on the total duration corresponding to this group.
##### You need ot modify the code to take into account any changes in variables you're using 

glmdata3 <-
  data.frame(rating.factor =
               c(rep("Weight", nlevels(glmdata2$weight_group)),
                 rep("VehicleAge", nlevels(glmdata2$age_group)),
                 rep("Climate", nlevels(glmdata2$Climate)),
                 rep("ActivityCode", nlevels(glmdata2$ActivityCode))),
             class =
               c(levels(glmdata2$weight_group),
                 levels(glmdata2$age_group),
                 levels(glmdata2$Climate),
                 levels(glmdata2$ActivityCode)),
             stringsAsFactors = FALSE)

new.cols <-
  foreach (rating.factor = c("weight_group","age_group", "Climate", "ActivityCode"),
           .combine = rbind) %do%
           {
             nclaims <- tapply(glmdata2$NoOfClaims, glmdata2[[rating.factor]], sum)
             sums <- tapply(glmdata2$Duration, glmdata2[[rating.factor]], sum)
             n.levels <- nlevels(glmdata2[[rating.factor]])
             contrasts(glmdata2[[rating.factor]]) <-
               contr.treatment(n.levels)[rank(-sums, ties.method = "first"), ]
             data.frame(duration = sums, n.claims = nclaims)
           }

glmdata3 <- cbind(glmdata3, new.cols)

rm(new.cols)

######################### Section 3: GLM analysis #########################

# Now we get to the fun part - the GLM analysis. It is performed using R's built in GLM function 

# First, we model the claims frequency. 
# The first part of this performs a GLM analysis, with glmdata2 as the data source modelling NoOfClaims, by the Duration. It looks at three variables: weight_group, Climate, and ActivityCode.
##### This is where you can modify the model by adding or removing variables 

model.frequency <-
  glm(NoOfClaims ~ weight_group +age_group+ Climate + ActivityCode + offset(log(Duration)),
      data = glmdata2, family = poisson)

# Then we save the coefficients resulting from the GLM analysis in an array
##### You should not need to modify this part of the code

rels <- coef(model.frequency)
rels <- exp(rels[1] + rels[-1])/exp(rels[1])

# Finally, we attach the coefficients to the already prepared table glmdata3, in a column named rels.frequency
# There is no good way of doing this automatically, so we need to do some manual tricks
# This code creates a vector with 6 positions consisting of the integer 1, and then positions number 1-5 in the rels array.
# Then it attaches this to rows 1-6 of glmdata3, sorted from highest to lowest duration, since the GLM data is on this form.
# In other words, the code takes the GLM coeffisients for the six weight groups and saves those in glmdata3, in the rows corresponding to those groups.
# After that, it does the same thing for the rest of the GLM coefficients, belonging to climate and activity code vairables.
##### You need to modify this code to suit your set of variables and groups, to make sure each GLM coefficient is saved in the correct place.


glmdata3$rels.frequency <-
  c(c(1, rels[1:6])[rank(-glmdata3$duration[1:7], ties.method = "first")],
    c(1, rels[7:13])[rank(-glmdata3$duration[8:15], ties.method = "first")],
    c(1, rels[14:15])[rank(-glmdata3$duration[16:18], ties.method = "first")],
    c(1, rels[16:25])[rank(-glmdata3$duration[19:29], ties.method = "first")])


# We then do the same thing again, now modelling severity instead of claim frequency.
# That means that, in this part, we want to look at the average claim. So first, we calculate the average claim for each row in glmdata2
##### You should not need to change anything in this piece of code.

glmdata2$avgclaim=glmdata2$ClaimCost/glmdata2$NoOfClaims

# Then we do the same thing as we did when modelling claims frequency, but we look at average claim;
# A GLM analysis is run, the coefficients stored, and saved in a new column, named rels.severity, glmdata3
##### You need to modify this part of the code in the same way as you did for the frequency. Add or remove variables, and make sure coefficients are stored correctly.
##### Remember that, according to the project instructions, you need to use the same variables for the severity as for the frequency.

model.severity <-
  glm(avgclaim ~ weight_group + age_group+ Climate + ActivityCode ,
      data = glmdata2[glmdata2$avgclaim>0,], family = Gamma("log"), weight=NoOfClaims)

rels <- coef(model.severity)
rels <- exp( rels[1] + rels[-1] ) / exp( rels[1] )
glmdata3$rels.severity <-
  c(c(1, rels[1:6])[rank(-glmdata3$duration[1:7], ties.method = "first")],
    c(1, rels[7:13])[rank(-glmdata3$duration[8:15], ties.method = "first")],
    c(1, rels[14:15])[rank(-glmdata3$duration[16:18], ties.method = "first")],
    c(1, rels[16:25])[rank(-glmdata3$duration[19:29], ties.method = "first")])

# Finally, the final risk factor is calculated, as the product of the frequency and severity factors. 
##### You should not have to modify this coed.
##### Congratulations! You now have a model for the risk!
glmdata3$rels.risk <- with(glmdata3, rels.frequency*rels.severity)

######################### Section 4: Plotting #########################

# In this section, the results from the GLM are plotted.

# First, long variable names need to be cut, to fit into the plots.
# This row of code cuts away everything except for the first letter for variable names belonging to activity codes.
##### If you have long variable names, modify here to cut them.
glmdata3[glmdata3$rating.factor == "ActivityCode",2] <- substr(glmdata3$class,1,1)[10:20]  


# Then the results are plotted. This code plots the GLM factors for frequency, severity, and total risk, for the three variables Weight, Climate, and Activity code.
##### If you have changed what variables are included in your model, add, remove, or modify sections of this code to plot them. 
##### This is also where you can make changes to change the look of your plots, if you would like to.

p1 <- ggplot(subset(glmdata3, rating.factor=="Weight"), aes(x=class, y=rels.frequency)) + 
      geom_point(colour="blue") + geom_line(aes(group=1), colour="blue") + ggtitle("Weight: frequency factors") +
      geom_text(aes(label=paste(round(rels.frequency,2))), nudge_y=1) +theme(axis.text.x = element_text(angle = 30, hjust = 1))

p2 <- ggplot(subset(glmdata3, rating.factor=="Weight"), aes(x=class, y=rels.severity)) + 
      geom_point(colour="blue") + geom_line(aes(group=1), colour="blue") + ggtitle("Weight: severity factors") +
      geom_text(aes(label=paste(round(rels.severity,2))), nudge_y=0.5)+theme(axis.text.x = element_text(angle = 30, hjust = 1))

p3 <- ggplot(subset(glmdata3, rating.factor=="Weight"), aes(x=class, y=rels.risk)) + 
      geom_point(colour="blue") + geom_line(aes(group=1), colour="blue") + ggtitle("Weight: risk factors") +
      geom_text(aes(label=paste(round(rels.risk,2))), nudge_y=1.6)+theme(axis.text.x = element_text(angle = 30, hjust = 1))

p4 <- ggplot(subset(glmdata3, rating.factor=="Climate"), aes(x=class, y=rels.frequency)) + 
  geom_point(colour="blue") + geom_line(aes(group=1), colour="blue") + ggtitle("Climate: frequency factors") +
  geom_text(aes(label=paste(round(rels.frequency,2))), nudge_y=0.05)

p5 <- ggplot(subset(glmdata3, rating.factor=="Climate"), aes(x=class, y=rels.severity)) + 
  geom_point(colour="blue") + geom_line(aes(group=1), colour="blue") + ggtitle("Climate: severity factors") +
  geom_text(aes(label=paste(round(rels.severity,2))), nudge_y=0.1)

p6 <- ggplot(subset(glmdata3, rating.factor=="Climate"), aes(x=class, y=rels.risk)) + 
  geom_point(colour="blue") + geom_line(aes(group=1), colour="blue") + ggtitle("Climate: risk factors") +
  geom_text(aes(label=paste(round(rels.risk,2))), nudge_y=0.1)

p7 <- ggplot(subset(glmdata3, rating.factor=="ActivityCode"), aes(x=class, y=rels.frequency)) + 
  geom_point(colour="blue") + geom_line(aes(group=1), colour="blue") + ggtitle("ActivityCode: frequency factors") +
  geom_text(aes(label=paste(round(rels.frequency,2))), nudge_y=0.5) 

p8 <- ggplot(subset(glmdata3, rating.factor=="ActivityCode"), aes(x=class, y=rels.severity)) + 
  geom_point(colour="blue") + geom_line(aes(group=1), colour="blue") + ggtitle("ActivityCode: severity factors") +
  geom_text(aes(label=paste(round(rels.severity,2))), nudge_y=0.5)

p9 <- ggplot(subset(glmdata3, rating.factor=="ActivityCode"), aes(x=class, y=rels.risk)) + 
  geom_point(colour="blue") + geom_line(aes(group=1), colour="blue") + ggtitle("ActivityCode: risk factors") +
  geom_text(aes(label=paste(round(rels.risk,2))), nudge_y=0.5)




multiplot(p1,p2,p3,p4,p5,p6,p7,p8,p9, cols=3)



######################### Section 5: Export factors to Excel #########################

#As a last step, the risk factors are exported to excel, on the format asked for in the project description. 
# The dopcument will be saved in the folder set as your working directory.

write.xlsx(glmdata3, "Factors.xlsx")



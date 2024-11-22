# Optimizing Course Sites using Mixed Integer Linear Programming
This repository shows an example of using SAS Optimization to select which sites to run courses to reduce the costs of running L&amp;D activities.

Here we have a sample dataset which has 3 staff members who've shown preferences for 2 courses running over 2 sites. We show three different ways of using SAS Optimization to show how you can use Mixed Integer Linear Programming to select which combination of course and site to run for each staff member.

The first example shows a utilitarian perspective where all courses run, and staff are given permission to go to whichever site best suits them. Whilst this is optimal in an objective sense, clearly it generates business waste because courses run across both sites. 

The second example shows how an assignment variable can be used to restrict the courses to run over only 1 site, thus we select the site that maximises the overall set of preferences. In this simple example we could equally do this without advanced analytics by simply looking at the site by popularity. In reality, dealing with many sites, courses and staff it may be far less obvious.

Finally, the third example shows the same again but this time the courses are mandatory, so each staff member has to attend each course at a given site. 

Whilst the examples here are simple, it demonstrates the flexibility of SAS Optimization and how, by adjusting the constraints, different business perspectives can be factored in.

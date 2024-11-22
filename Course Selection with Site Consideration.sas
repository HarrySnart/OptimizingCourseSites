/* This script shows an example of how Mixed Integer Linear Programming can be used
to match staff to courses and a further example of restricting the number of sites
a course is offered at to reduce costs.
 */

proc template;
   define style styles.mystyle;
      parent=styles.htmlblue;
         class pagebreak /
	     display=none;         
   end;
run;

ods html5 style=styles.mystyle;

/* load sample data */
data courses;
length person  $10. training  $10. site $10. preference std_pref 8.;
input person training site preference std_pref;
label person='Person' training='Training' site='Site' preference='Preference' std_pref = 'Preference (Standardized)';
datalines;
P1 C1 S1 1 1
P1 C2 S1 1 1
P1 C2 S2 2 0.5
P2 C1 S1 1 1
P2 C2 S2 1 1
P3 C1 S1 1 1
P3 C1 S2 2 0.5
P3 C2 S1 1 1
P4 C1 S1 1 1
P4 C2 S1 1 1
;
run;

proc odstext; p 'Using Optimization to Assign Staff to Courses by Site' / style=[fontsize=24 just=c color=navy];run;

proc odstext; p 'This example shows several various approaches depending whether it is important to restrict site (i.e. to reduce cost of running training) and whether courses are mandatory or not.' / style=[fontsize=11pt just=c];run;

proc odstext; p "Let's start by looking at a sample dataset. We have 3 staff, 2 courses and 2 possible sites. Staff have been asked to give preferences on where they do these courses. We've standardised this so that 1 means most preferred and 0 means least or unpreferred." / style=[fontsize=11pt just=c];run;


proc print data=courses L;title 'Sample Dataset' ;run;


/* We need an implicit preference of zero for all sites people don't put a preference against */
/* to do this we'll create a cartesian product of courses and sites */


proc odstext; p "We need to add an explicit preference of 0 so courses/sites that staff have not specified. To do this we create the cartesian product. This adds 2 rows to our data since 3 staff * 2 courses * 2 sites = 12 combinations." / style=[fontsize=11pt just=c];run;


/* this will give us 12 rows (3 people * 2 courses * 2 sites) */
data combinations;
    do Person = 'P1', 'P2', 'P3';
        do Training = 'C1', 'C2';
            do Site = 'S1', 'S2';
                output;
            end;
        end;
    end;
run;

proc print data=combinations;title 'All combinations of preferences';
run;
title;

/* match standardised preference against the combinations */
proc sql noprint; create table combinations_prefs as 
select a.*, b.std_pref from combinations as a left join courses as b 
on a.person=b.person and a.training=b.training and a.site=b.site;quit;


proc odstext; p "Once we've created out combinations we can lookup the preference from the original table." / style=[fontsize=11pt just=c];run;

proc print data= combinations_prefs L;title 'Combinations with Preferences';run;

proc odstext; p "Finally, we default missing preferences to an explicit preference of 0." / style=[fontsize=11pt just=c];run;

/* default missing preference to 0 */
data combinations_prefs;
set combinations_prefs;
if std_pref = . then std_pref = 0;
rename std_pref = Pref;
label pref='Preference';
run;

proc print data= combinations_prefs L;title 'Prepared Dataset for Optimization';run;


/* Optimization model 1: match staff to courses without restricting sites */

proc odstext; p "Let's run our first optimization problem. Here we maximise total preference and use a binary variable to select the combination of <person,course,site> that maximises satisfaction. We add a constraint that for all persons and courses only 1 site is selected. I.e assign staff to the courses in the site they prefer." / style=[fontsize=11pt  just=c];run;

proc optmodel misscheck ;
    /* Declare sets and parameters */
    set <str,str,str> PERSON_COURSE;
	set <str> PERSONS =/P1 P2 P3/;
	set <str> COURSES= /C1 C2 /;
	set <str> SITES= /S1 S2 /;
    num Pref {PERSON_COURSE};

    /* Read data from the dataset */
	read data WORK.combinations_prefs into  PERSON_COURSE=[Person Training Site] Pref=Pref;

    /* Declare decision variables */
    var Select {PERSON_COURSE} binary;

    /* Objective: Maximize the sum of Pref for selected sites and courses */
    maximize TotalPref = sum {i in PERSONS, c in COURSES,s in SITES} Pref[i,c,s] * Select[i,c,s];

    /* Constraints */

    /* Each person is assigned to two courses */
    con PersonAssignment {i in PERSONS,c in COURSES}: sum {s in SITES} Select[i,c,s] <= 1;

    /* Solve the MILP */
    solve;

    /* Print the results */
    print Select;
     create data solution from [Person Training Site] Select Pref; 
quit;

proc odstext; p "We can see from the OPTMODEL output that this has an objective value of 6, where everyone gets their preferred site." / style=[fontsize=11pt just=c];run;


proc print data=solution L;where select=1;title 'Optimization Selection for Course and Site without Constraining Site';
footnote 'Constraint that each person does each course maximising on individual preference';
run;


title;footnote;

/* Optimization model 2: restrict courses to run at only one site */

proc odstext; p "Now let's restrict the model so that all courses can only run from one site. This means that we select the site that maximises the overall satisfaction of everybody. " / style=[fontsize=11pt just=c];run;


proc optmodel misscheck;
    /* Declare sets and parameters */
    set <str,str,str> PERSON_COURSE;
    set <str> PERSONS = /P1 P2 P3/;
    set <str> COURSES = /C1 C2/;
    set <str> SITES = /S1 S2/;
    num Pref {PERSON_COURSE};

    /* Read data from the dataset */
    read data WORK.combinations_prefs into PERSON_COURSE=[Person Training Site] Pref=Pref;

    /* Declare decision variables */
    var Select {PERSON_COURSE} binary;
    var SiteUsed {SITES} binary;

    /* Objective: Maximize the sum of Pref for selected assignments */
    maximize TotalPref = sum {i in PERSONS, c in COURSES, s in SITES} Pref[i,c,s] * Select[i,c,s];

    /* Constraints */
    /* Each person is assigned to at most one course at each site */
     con PersonAssignment {i in PERSONS, c in COURSES}: sum {s in SITES} Select[i,c,s] <= 1; 

    /* Link SiteUsed variable to Select variable */
    con SiteLink {s in SITES}: sum {i in PERSONS, c in COURSES} Select[i,c,s] <= card(PERSONS) * card(COURSES) * SiteUsed[s];

    /* Restrict the total number of sites to 1 */
    con SingleSite: sum {s in SITES} SiteUsed[s] <= 1;

    /* Solve the MILP */
    solve;

    /* Print the results */
    print Select;
    create data solution2 from [Person Training Site] Select Pref;
quit;

proc odstext; p "We can see from the OPTMODEL results our objective value drops from 6 to 5, overall everyone is less satisfied - but we've saved on costs." / style=[fontsize=11pt just=c];run;

proc odstext; p "Its important to highlight that this model only returns 5 assignments, since person 2 did not want to do course 2 at site 1 and we've not made the courses mandatory." / style=[fontsize=11pt just=c];run;


proc print data=solution2 L;where select=1;title 'Optimization Selection for Course and Site with Site Constraint';
footnote 'Constraint that each course runs at only one site';
footnote3 'Note in this case we have 5 courses, since person 2 did not want to do course 2 at site 1. This may be optimal if course are non-mandatory';
run;

title;footnote;footnote3;

/* Optimization model 3 - ensure each course is mandatory and only 1 site is used that maximises the collective satisfaction */

proc odstext; p "Let's build a final model now that makes both courses mandatory and have them run at only one site." / style=[fontsize=11pt just=c];run;

proc optmodel misscheck;
    /* Declare sets and parameters */
    set <str,str,str> PERSON_COURSE;
    set <str> PERSONS = /P1 P2 P3/;
    set <str> COURSES = /C1 C2/;
    set <str> SITES = /S1 S2/;
    num Pref {PERSON_COURSE};

    /* Read data from the dataset */
    read data WORK.combinations_prefs into PERSON_COURSE=[Person Training Site] Pref=Pref;

    /* Declare decision variables */
    var Select {PERSON_COURSE} binary;
    var SiteUsed {SITES} binary;

    /* Objective: Maximize the sum of Pref for selected assignments */
    maximize TotalPref = sum {i in PERSONS, c in COURSES, s in SITES} Pref[i,c,s] * Select[i,c,s];

    /* Constraints */
    /* Each person is assigned to exactly one site for each course */
    con PersonAssignment {i in PERSONS, c in COURSES}: sum {s in SITES} Select[i,c,s] = 1;

    /* Link SiteUsed variable to Select variable */
    con SiteLink {s in SITES}: sum {i in PERSONS, c in COURSES} Select[i,c,s] <= card(PERSONS) * card(COURSES) * SiteUsed[s];

    /* Restrict the total number of sites to 1 */
    con SingleSite: sum {s in SITES} SiteUsed[s] <= 1;

    /* Solve the MILP */
    solve;

    /* Print the results */
    print Select;
    create data solution3 from [Person Training Site] Select Pref;
quit;

proc odstext; p "Looking at OPTMODEL we get the same objective value, since we have a preference of 0 for person 2 but we can see they've now been assigned to that course and site anyway ensuring everyone does both courses." / style=[fontsize=11pt just=c];run;


proc print data=solution3 L;where select=1;title 'Optimization Selection for Course and Site with Site Constraint and Mandatory Courses';
run;

proc odstext; p "We've seen how SAS PROC OPTMODEL can be used to make assignments that incorporate business constraints for optimal solutions." / style=[fontsize=11pt just=c];run;

ods html5 close;




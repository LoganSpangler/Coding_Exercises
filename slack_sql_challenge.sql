DROP TABLE employees;
DROP TABLE employees_projects;
DROP TABLE departments;
DROP TABLE projects;

/*
Time: We expect this exercise to take approximately 45 minutes, but feel free to take more or less time as you need. Please report how much time you spend. This allows us to be fair to candidates who are time constrained. 

Background on the Data: 
Slack has a system that allows apps to send alerts to Slack users in 3 channels (banner, push, sidebar). We write a log to a table called "alerts" whenever a user sees an alert (impression or 'imp') or a user clicks on an alert ('clk'). The table contains data for a single day. This logging is new and hasn't been vetted yet. Trust nothing, callout bad data, and work to clean the data as necessary to get the best answer.

Columns in the table:
user_id: numeric, unique and persistent id for each user
team_id: numeric, unique and persistent id for each team. Each userid belongs to exactly one team.
app_id: numeric, unique and persistent id for each app
event: string with values 'imp' (as in impression, so it was seen) or 'clk' (the user interacted with it)
primary_browser: string, the browser the user was using
alert_type: string, alert was in a banner/sidebar/push
eventtime: the timestamp of when the interaction happened

Questions:
#1 What is the best performing alert type?
#2 What apps are the best and worst performing?
#3 I’m curious about what the first alert a team clicked on in this day? For each alert_type, compute how many teams clicked an alert of that type as their first alert in a day.

Process
You should document your final solution in the left hand pane including any relevant thought process and exploration as well as your final answer to the questions. You may also interact with the data in the right hand pane as you work (but this won't be saved!). We'll be looking at the final product in the left hand pane but may also replay your entire session to see how you worked through the questions.
*/

SELECT * FROM alerts LIMIT 5 \G


/* Let's look at some distributions
*/

SELECT alert_type, COUNT(user_id)
FROM alerts
GROUP BY alert_type;

SELECT alerts.event, COUNT(user_id)
FROM alerts
WHERE alerts.event is not null
GROUP BY alerts.event;

SELECT app_id, COUNT(user_id) count_u
FROM alerts
GROUP BY app_id
ORDER BY count_u DESC;

/* sidebar alerts seem to be the more popular in this dataset, followed by push and banner.

Around 1/3 of the events are clicks. Not bad.

Regarding type of apps, #15 #4 are the most popular by far. Followed by #29, #31, and #1 */

/* Let's check for duplicates first */
SELECT user_id, eventtime, count(*) c
FROM alerts
GROUP BY user_id, eventtime
HAVING c > 1;

/* we have 60 rows of duplicates. We'll drop them */
CREATE TABLE alerts1
SELECT user_id, eventtime, MAX(team_id) team_id, MAX(app_id) app_id, MAX(event) event, 
MAX(primary_browser) primary_browser, MAX(alert_type) alert_type
FROM alerts
GROUP BY user_id, eventtime;

SELECT user_id, eventtime, count(*) c
FROM alerts1
GROUP BY user_id, eventtime
HAVING c > 1;

/* checked! no nulls in new table alerts1 */

/*Let's now look for Nulls */
SELECT count(*)
FROM alerts1
WHERE event is null;

/* No nulls in event column */

/* Part 1 */
SELECT 
x.alert_type, 
(y.count_clk / x.total_events)*100 AS CTR
FROM
( SELECT 
  alert_type,
  count(event) as total_events
  FROM alerts1 
  GROUP BY alert_type
  ) x
INNER JOIN
(SELECT 
  alert_type,
  count(event) as count_clk
  FROM alerts1
  WHERE event = 'clk'
  GROUP BY alert_type) y
ON x.alert_type = y.alert_type
ORDER BY CTR DESC;

/* We ranked alert_type based on CTR and it looks like sidebar is the alert with higher performance (CTR = 39.6%) followed by banner (CTR = 34.5%) and push (CTR = 20.19%). */

/* Part 2 */
SELECT 
x.app_id, 
(y.count_clk / x.total_events)*100 AS CTR
FROM
( SELECT 
  app_id,
  count(event) as total_events
  FROM alerts1 
  GROUP BY app_id
  ) x
INNER JOIN
(SELECT 
  app_id,
  count(event) as count_clk
  FROM alerts1
  WHERE event = 'clk'
  GROUP BY app_id) y
ON x.app_id = y.app_id
ORDER BY CTR DESC;

/* The best performing apps, ranked from best to worst, are: 
#17 (CTR = 67%, with 197 events)
#11 (CTR = 60%, with 5 events)
#10 (CTR = 60%, with 5 events)
#31 (CTR = 52%, with 284 events)
#7 (CTR = 50%, with 8 events)
#28 (CTR = 48.7%, with 80 events)
# 2 (CTR = 45%, with 55 events)
...
#29 (CTR = 40%, with 293 events)

We can probably discard those apps with less than 50 events. So, the rank would look something like this:
Best 3:
#17 (CTR = 67%, with 197 events)
#31 (CTR = 52%, with 284 events)
#28 (CTR = 48.7%, with 80 events)

Worst 3:
#3 (CTR = 34.5%, with 194 events)
#16 (CTR = 34.74%, with 118 events)
#21 (CTR = 35.7%, with 171 events)

I noticed that the most popular app (#15) didn't make it to the rank by CTR. I looked further and realized that all the events for this app are impressions, with 0 clicks. Most likely this could be caused by a log error so I woudl talk with the Engineering team to see why are not capturing clicks for this app.  

*/

SELECT event, COUNT(user_id)
FROM alerts1
WHERE app_id = 15
GROUP BY event;

/* Part 3 */

SELECT 
alert_type,
count(x.team_id) as count_teams
FROM

  (SELECT * 
    FROM alerts1 
  ) y
INNER JOIN
  (SELECT 
    team_id, 
    min(eventtime) as first_event
    FROM alerts1
    WHERE event = 'clk'
    GROUP BY team_id
  ) x
ON x.team_id = y.team_id
AND y.eventtime = x.first_event

GROUP BY alert_type
ORDER BY count_teams DESC;

/* Computing the number of teams that clicked each alert as their first one during this day, we can see that for most of the teams it was a sidebar alert the first one they clicked, which is correlated with the total number of alerts showed in that day. Interestingly banner alert made it to the second place, while there are ~30% more push alerts in this dataset.
This is how the final count looks like for each team:
sidebar_alert: 640  
banner_alert: 292 
push_alert: 225

I remember having count 1440 as total teams previously; but in my results the count adds up to 1157. These might be the teams who actually clicked on an alert during this day, which means that 283 teams didn't click in any of the alerts they received. I checked and that's correct. 

*/

/* Define TSA library */
libname tsa '/home/u64396252/tsa';   /* change path if needed */

/* Enforce valid SAS column names */
options validvarname=v7;

/* Import CSV */
proc import datafile='/home/u64396252/EPG1V2/data/TSAClaims2002_2017.csv'
    out=tsa.claims_raw
    dbms=csv
    replace;
    guessingrows=max;
run;

/* Structure */
proc contents data=tsa.claims_raw;
run;

/* Preview */
proc print data=tsa.claims_raw(obs=10);
run;

/* Explore key columns */
proc freq data=tsa.claims_raw;
    tables Claim_Site Disposition Claim_Type;
run;

proc sort data=tsa.claims_raw
          out=work.claims_nodup
          nodupkey;
    by _all_;
run;

proc sort data=work.claims_nodup;
    by Incident_Date;
run;

data tsa.claims_cleaned;
    set work.claims_nodup;

    /* ---------- Fix missing and '-' ---------- */
    array fixvars Claim_Type Claim_Site Disposition;
    do over fixvars;
        if missing(fixvars) or fixvars='-' then fixvars='Unknown';
    end;

    /* ---------- Claim_Type: take first value before / ---------- */
    if index(Claim_Type,'/') then
        Claim_Type = scan(Claim_Type,1,'/');

    /* ---------- Valid Claim_Type ---------- */
    if Claim_Type not in (
        'Bus Terminal','Complaint','Compliment','Employee Loss (MPCECA)',
        'Missed Flight','Motor Vehicle','Not Provided',
        'Passenger Property Loss','Passenger Theft','Personal Injury',
        'Property Damage','Property Loss','Unknown','Wrongful Death'
    ) then Claim_Type='Unknown';

    /* ---------- Valid Claim_Site ---------- */
    if Claim_Site not in (
        'Bus Station','Checked Baggage','Checkpoint','Motor Vehicle',
        'Not Provided','Other','Pre-Check','Unknown'
    ) then Claim_Site='Unknown';

    /* ---------- Valid Disposition ---------- */
    if Disposition not in (
        '*Insufficient','Approve in Full','Closed:Canceled',
        'Closed:Contractor Claim','Deny','In Review',
        'Pending Payment','Received','Settle','Unknown'
    ) then Disposition='Unknown';

    /* ---------- Fix State & StateName ---------- */
    State     = upcase(State);
    StateName = propcase(StateName);

    /* ---------- Date Issues ---------- */
    length Date_Issues $15;

    if missing(Incident_Date) or missing(Date_Received)
        or year(Incident_Date) < 2002 or year(Incident_Date) > 2017
        or year(Date_Received) < 2002 or year(Date_Received) > 2017
        or Incident_Date > Date_Received
    then Date_Issues='Needs Review';

    /* ---------- Formats ---------- */
    format Incident_Date Date_Received date9.
           Close_Amount dollar12.2;

    /* ---------- Labels ---------- */
    label
        Claim_Type   = "Claim Type"
        Claim_Site   = "Claim Site"
        Disposition  = "Disposition"
        Incident_Date= "Incident Date"
        Date_Received= "Date Received"
        Close_Amount = "Close Amount"
        Date_Issues  = "Date Issues";

    /* ---------- Drop unwanted columns ---------- */
    drop County City;
run;

proc freq data=tsa.claims_cleaned;
    tables Date_Issues;
    title "Overall Date Issues";
run;

proc freq data=tsa.claims_cleaned;
    where Date_Issues ne 'Needs Review';
    tables Incident_Date / plots=freqplot;
    format Incident_Date year4.;
    title "Claims per Year";
run;

%let StateValue=Hawaii;

proc freq data=tsa.claims_cleaned;
    where StateName="&StateValue"
          and Date_Issues ne 'Needs Review';
    tables Claim_Type Claim_Site Disposition;
    title "Claim Analysis for &StateValue";
run;

/* Define macro variable */
%let StateValue=Hawaii;

proc means data=tsa.claims_cleaned
           mean min max sum;
    where StateName="&StateValue"
          and Date_Issues ne 'Needs Review';
    var Close_Amount;
    format Close_Amount dollar12.;
    title "Close Amount Statistics for &StateValue";
run;



ods pdf file="~/ClaimReports.pdf" style=journal;


ods proclabel "Date Issues Summary";
proc freq data=tsa.claims_cleaned;
    tables Date_Issues;
run;

ods proclabel "Claims Per Year";
proc freq data=tsa.claims_cleaned;
    where Date_Issues ne 'Needs Review';
    tables Incident_Date / plots=freqplot;
    format Incident_Date year4.;
run;

ods proclabel "State Analysis";
proc freq data=tsa.claims_cleaned;
    where StateName="&StateValue"
          and Date_Issues ne 'Needs Review';
    tables Claim_Type Claim_Site Disposition;
run;

ods proclabel "Close Amount Statistics";
proc means data=tsa.claims_cleaned mean min max sum;
    where StateName="&StateValue"
          and Date_Issues ne 'Needs Review';
    var Close_Amount;
run;

ods pdf close;





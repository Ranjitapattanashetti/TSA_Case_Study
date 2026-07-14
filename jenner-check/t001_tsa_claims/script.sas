/* TSA Claims case study — data cleaning, validation, frequency analysis,
   and automated reporting. The original script imported an external
   216k-row CSV; here the same column layout is created inline so the
   bundle is self-contained. All cleaning and analysis logic below is
   unchanged from the case study. */

/* TSA library (local work path for a portable, self-contained run) */
libname tsa (work);

/* Sample data matching the TSAClaims2002_2017 column layout the case study
   reads (dates, categories, and Close_Amount). Pipe-delimited so category
   text keeps the embedded spaces the cleaning logic matches on, and seeded
   with the same quality issues that logic targets: a duplicate row, dashes,
   missing and out-of-range dates, and invalid categories. */
data tsa.claims_raw;
    length Claim_Type $40 Claim_Site $20 Item_Category $20
           Disposition $30 StateName $20 State $2 County $20 City $20;
    infile datalines dsd dlm='|' truncover;
    informat Date_Received Incident_Date date9.;
    format   Date_Received Incident_Date date9.;
    input Claim_Number Date_Received Incident_Date Claim_Type $
          Claim_Site $ Item_Category $ Close_Amount Disposition $
          StateName $ State $ County $ City $;
    datalines;
2002001|15JAN2002|10JAN2002|Passenger Property Loss|Checked Baggage|Jewelry|250.00|Approve in Full|hawaii|hi|Honolulu|Honolulu
2002002|20FEB2002|18FEB2002|Property Damage|Checkpoint|Clothing|120.50|Deny|california|ca|Los Angeles|Los Angeles
2003003|05MAR2003|01MAR2003|Property Damage|Checked Baggage|Electronics|1481.00|Settle|hawaii|hi|Honolulu|Honolulu
2004004|10APR2004|08APR2004|Personal Injury|Checkpoint|-|0.00|Deny|new york|ny|Queens|New York
2005005|12MAY2005|10MAY2005|Passenger Theft/Loss|Other|Cash|75.25|Approve in Full|illinois|il|Cook|Chicago
2006006|18JUN2006||Missed Flight|Pre-Check|-||In Review|washington|wa|King|Seattle
2007007|22JUL2007|20JUL2007|-|-|-|300.00|Received||tx||
2008008|30AUG2008|25AUG2008|Complaint|Other|Other|50.00|Approve in Full|florida|fl|Miami-Dade|Miami
2009009|14SEP2009|10SEP2009|Property Damage|Checkpoint|Baggage|1481.00|Deny|hawaii|hi|Maui|Kahului
2010010|05OCT2010|01OCT2010|Motor Vehicle|Motor Vehicle|Auto|900.00|Settle|texas|tx|Tarrant|Fort Worth
2011011|11NOV2011|09NOV2011|Compliment|Not Provided|Other|0.00|Closed:Canceled|georgia|ga|Fulton|Atlanta
2012012|20DEC2012|15DEC2012|Wrongful Death|Bus Station|Other|5000.00|Pending Payment|massachusetts|ma|Suffolk|Boston
2013013|25JAN2013|20JAN2013|Property Damage|Checked Baggage|Jewelry|1481.00|Approve in Full|hawaii|hi|Honolulu|Honolulu
2014014|15FEB2014||Bogus Type|Weird Site|Other|200.00|Bad Disposition|arizona|az|Maricopa|Phoenix
2015015|10MAR2015|08MAR2015|Property Loss|Other|Electronics|450.00|*Insufficient|colorado|co|Denver|Denver
2001099|01JAN2001|28DEC2000|Property Damage|Checkpoint|Other|100.00|Deny|california|ca|San Mateo|San Francisco
2018099|10FEB2018|05FEB2018|Property Damage|Checkpoint|Other|100.00|Deny|california|ca|San Mateo|San Francisco
2002001|15JAN2002|10JAN2002|Passenger Property Loss|Checked Baggage|Jewelry|250.00|Approve in Full|hawaii|hi|Honolulu|Honolulu
2016016|18JUN2016|20JUN2016|Property Damage|Checked Baggage|Other|1481.00|Settle|hawaii|hi|Honolulu|Honolulu
2017017|22JUL2017|20JUL2017|Employee Loss (MPCECA)|Other|Cash|80.00|Deny|nevada|nv|Clark|Las Vegas
;
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

proc means data=tsa.claims_cleaned
           mean min max sum;
    where StateName="&StateValue"
          and Date_Issues ne 'Needs Review';
    var Close_Amount;
    format Close_Amount dollar12.;
    title "Close Amount Statistics for &StateValue";
run;

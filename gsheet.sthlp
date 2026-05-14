{smcl}
{* *! version 3.0.4  13may2026}{...}
{vieweralsosee "[D] import" "help import"}{...}
{viewerjumpto "Syntax" "gsheet##syntax"}{...}
{viewerjumpto "Description" "gsheet##description"}{...}
{viewerjumpto "Options" "gsheet##options"}{...}
{viewerjumpto "Examples" "gsheet##examples"}{...}
{viewerjumpto "Author" "gsheet##author"}{...}
{title:Title}

{phang}
{bf:gsheet} {hline 2} Import public Google Sheets directly into Stata via Python


{marker syntax}{...}
{title:Syntax}

{p 8 15 2}
{cmd:gsheet} {cmd:using} {it:"url"} [{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Main}
{synopt:{opt clear}}replace data in memory{p_end}
{synopt:{opt firstrow}}treat first row of data as variable names{p_end}
{synopt:{opt low:ercase}}force all variable names to lowercase (requires {opt firstrow}){p_end}

{syntab:Subset}
{synopt:{opt sheet(string)}}sheet name or numeric GID to import (default is the first sheet){p_end}
{synopt:{opt cellrange(string)}}Excel-style cell range to import (e.g., A1:Z100){p_end}
{synopt:{opt noblankrows}}drop rows that are entirely empty{p_end}
{synopt:{opt noblankcols}}drop columns that are entirely empty{p_end}

{syntab:Output}
{synopt:{opt save(filename)}}save the imported data directly to a {it:.dta} file{p_end}
{synopt:{opt q:uiet}}suppress all console output{p_end}
{synopt:{opt v:erbose}}display extra diagnostic output during Python execution{p_end}
{synoptline}
{p2colreset}{...}
{p 4 6 2}


{marker description}{...}
{title:Description}

{pstd}
{cmd:gsheet} imports data from a Google Sheet directly into Stata. It requires Stata 16 or newer with Python integration configured. 

{pstd}
Because this command downloads the sheet as a CSV via Google's export API, the Google Sheet {bf:must be public} (i.e., its sharing settings must be set to "Anyone with the link can view"). 

{pstd}
{cmd:gsheet} includes built-in data cleaning logic:
{break} - Strict date parsing: Columns are only converted to Stata {it:%tc} datetimes if 100% of the non-empty values parse as dates.
{break} - Variables containing "ID" in their name are protected as strings to prevent dropping leading zeros.
{break} - Variable names are sanitized (spaces and special characters converted to underscores, and "%" converted to "pct").
{break} - UTF-8 character lengths are properly measured in bytes to prevent Stata string overflow errors.


{marker options}{...}
{title:Options}

{dlgtab:Main}

{phang}
{opt clear} specifies that it is okay to replace the data in memory, even if the current dataset has not been saved.

{phang}
{opt firstrow} specifies that the first row of data in the Google Sheet should be used as Stata variable names. If this option is not specified, variables will be named {it:v1, v2, v3}, etc.

{phang}
{opt lowercase} forces all imported variable names to be lowercase. This option may only be used if {opt firstrow} is also specified.

{dlgtab:Subset}

{phang}
{opt sheet(string)} specifies the specific worksheet to import. You can provide either the text name of the sheet tab or its numeric GID (found at the end of the URL when viewing the sheet).

{phang}
{opt cellrange(string)} limits the import to a specific block of cells, using standard Excel notation (e.g., {cmd:cellrange(A4:W1004)}).

{phang}
{opt noblankrows} forces the command to drop any row where every single cell is missing.

{phang}
{opt noblankcols} forces the command to drop any column where every single cell is missing.

{dlgtab:Output}

{phang}
{opt save(filename)} specifies that the imported data should be saved directly to a Stata {it:.dta} file at the specified path.

{phang}
{opt quiet} suppresses the progress messages normally displayed in the Stata results window.

{phang}
{opt verbose} forces the Python backend to display additional diagnostic logs. Cannot be combined with {opt quiet}.


{marker examples}{...}
{title:Examples}

{pstd}
The examples below use the public {bf:Gapminder Life Expectancy} dataset. 

{pstd}Import the "Data-world-by-year" sheet, using the first row as variable names and clearing memory:{p_end}
{phang2}{cmd:. gsheet using "https://docs.google.com/spreadsheets/d/1cvaIhXYhDh70rnUfAtyAhI7hlXhrLSCnLWqhL6UnioE/edit", sheet("Data-world-by-year") firstrow clear}{p_end}

{pstd}Import a specific range of cells from the country-level data sheet, convert names to lowercase, drop blank columns, and save the result:{p_end}
{phang2}{cmd:. gsheet using "https://docs.google.com/spreadsheets/d/1cvaIhXYhDh70rnUfAtyAhI7hlXhrLSCnLWqhL6UnioE/edit", sheet("Data countries etc by year") cellrange(A1:F500) firstrow lowercase noblankcols save("life_expectancy.dta") clear}


{marker author}{...}
{title:Author}

{pstd}Kenneth Elpus{p_end}
{pstd}Version 3.0.4{p_end}

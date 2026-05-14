*! gsheet.ado
*! Import a public Google Sheet into Stata via Python integration
*! Author:  Kenneth Elpus
*! Version: 3.0.4

capture program drop gsheet
program define gsheet
    version 16.0

    syntax using/ ,            ///
           [ sheet(string)     /// Sheet name or numeric GID
             cellrange(string) /// e.g. "A1:G100"
             save(string)      /// Save resulting .dta file
             FIRSTrow          /// Use first row as variable names
             LOWercase         /// Force variable names to lowercase
             NOBLANKROWS       /// Drop entirely empty rows
             NOBLANKCOLS       /// Drop entirely empty columns
             Quiet             /// Suppress all output
             Verbose           /// Extra diagnostic output
             clear             /// Clear data in memory first
           ]

    if "`lowercase'" != "" & "`firstrow'" == "" {
        display as error "Option {bf:lowercase} requires {bf:firstrow}."
        exit 198
    }
    if "`quiet'" != "" & "`verbose'" != "" {
        display as error "Options {bf:quiet} and {bf:verbose} are mutually exclusive."
        exit 198
    }

    capture python query
    if _rc != 0 {
        display as error "Python integration is not available (requires Stata 16+)."
        exit 198
    }

    if "`clear'" != "" {
        clear
    }
    else {
        quietly describe
        if `r(k)' > 0 {
            display as error "Data in memory would be lost. Specify {bf:clear} to proceed."
            exit 4
        }
    }

    local _gsheet_url       `"`using'"'
    local _gsheet_sheet     `"`sheet'"'
    local _gsheet_cellrange `"`cellrange'"'
    local _gsheet_columns   `"`columns'"'
    local _gsheet_firstrow  "`firstrow'"
    local _gsheet_lowercase "`lowercase'"
    local _gsheet_noblankrows "`noblankrows'"
    local _gsheet_noblankcols "`noblankcols'"
    local _gsheet_quiet     "`quiet'"
    local _gsheet_verbose   "`verbose'"

    python: _gsheet_import()

    if "`quiet'" == "" {
        quietly describe, short
        display as text ""
        display as result "{bf:gsheet}: Successfully loaded {bf:`r(N)'} observations and {bf:`r(k)'} variables."
        display as text ""
    }

    if `"`save'"' != "" {
        save `"`save'"', replace
        if "`quiet'" == "" display as result "Dataset saved to: {bf:`save'}"
    }
end

* ===================================================================
* Python back-end
* ===================================================================
python:
import re
import warnings
import pandas as pd
import numpy as np
from sfi import Data, Macro, SFIToolkit, Missing

# Silence Pandas dateutil warnings
warnings.filterwarnings("ignore", category=UserWarning)

_STATA_MISSING = Missing.getValue()
_STATA_EPOCH = pd.Timestamp('1960-01-01')

def _log(msg, quiet, verbose, level='normal'):
    if quiet: return
    if level == 'verbose' and not verbose: return
    SFIToolkit.displayln(msg)

def _make_stata_varname(raw, lowercase=False):
    s = str(raw) if pd.notna(raw) else "v"
    s = s.replace('%', 'pct')  
    if lowercase: s = s.lower()
    s = re.sub(r'[^a-zA-Z0-9_]', '_', s)
    s = re.sub(r'_+', '_', s).strip('_')
    if not s: s = 'v'
    elif s[0].isdigit(): s = 'v_' + s
    return s[:32]

def _fetch_sheet_data(url, sheet, cellrange):
    match = re.search(r'/spreadsheets/d/([a-zA-Z0-9_-]+)', url)
    if not match:
        SFIToolkit.errprintln("{err}ERROR: Could not extract spreadsheet ID.")
        SFIToolkit.exit(198)

    spreadsheet_id = match.group(1)

    if sheet and not sheet.isdigit():
        # Named sheet: gviz/tq endpoint correctly resolves sheet names
        export_url = f"https://docs.google.com/spreadsheets/d/{spreadsheet_id}/gviz/tq?tqx=out:csv&sheet={sheet}"
    else:
        # No sheet or numeric GID: standard export endpoint
        export_url = f"https://docs.google.com/spreadsheets/d/{spreadsheet_id}/export?format=csv"
        if sheet:
            export_url += f"&gid={sheet}"

    if cellrange:
        export_url += f"&range={cellrange}"

    try:
        df = pd.read_csv(export_url, header=None, na_values=['', '#N/A', 'NA'])
        return df
    except Exception as e:
        SFIToolkit.errprintln(f"{{err}}ERROR downloading sheet: {e}")
        SFIToolkit.exit(601)

def _gsheet_import():
    url = Macro.getLocal("_gsheet_url")
    sheet = Macro.getLocal("_gsheet_sheet")
    cellrange = Macro.getLocal("_gsheet_cellrange")
    firstrow = Macro.getLocal("_gsheet_firstrow").strip() != ""
    lowercase = Macro.getLocal("_gsheet_lowercase").strip() != ""
    noblankrows = Macro.getLocal("_gsheet_noblankrows").strip() != ""
    noblankcols = Macro.getLocal("_gsheet_noblankcols").strip() != ""
    quiet = Macro.getLocal("_gsheet_quiet").strip() != ""
    verbose = Macro.getLocal("_gsheet_verbose").strip() != ""

    _log("{txt}Fetching data from Google Sheets...", quiet, verbose)
    
    df = _fetch_sheet_data(url, sheet, cellrange)
    
    if df is None or df.empty:
        _log("{txt}Done (0 observations).", quiet, verbose)
        return

    if firstrow:
        df.columns = df.iloc[0]
        df = df[1:].reset_index(drop=True)
        for col in df.columns:
            try:
                df[col] = pd.to_numeric(df[col])
            except Exception:
                pass

    if noblankcols: df.dropna(axis=1, how='all', inplace=True)
    if noblankrows: df.dropna(axis=0, how='all', inplace=True)

    clean_cols = []
    seen = {}
    var_labels = {}
    for i, raw in enumerate(df.columns):
        raw_str = str(raw) if pd.notna(raw) else f"v{i+1}"
        cleaned = _make_stata_varname(raw_str, lowercase)
        base, n = cleaned, 1
        while cleaned in seen:
            suffix = f"_{n}"
            cleaned = base[:32 - len(suffix)] + suffix
            n += 1
        seen[cleaned] = True
        clean_cols.append(cleaned)
        if firstrow: var_labels[cleaned] = raw_str[:80]
        
    df.columns = clean_cols

    all_missing = [col for col in df.columns if df[col].isna().all()]
    if all_missing:
        df.drop(columns=all_missing, inplace=True)
        clean_cols = [col for col in clean_cols if col not in all_missing]
        _log(f"{{txt}}Dropped {len(all_missing)} variable(s) with all missing values.", quiet, verbose)

    Data.setObsTotal(len(df))

    _log("{txt}Loading data into Stata...", quiet, verbose)
    
    for col in df.columns:
        series = df[col]
        
        # ID variables forced to string
        if re.search(r'id', col, re.IGNORECASE):
            series = series.fillna('').astype(str)
            byte_len = series.str.encode('utf-8').str.len().max()
            max_bytes = max(1, int(byte_len)) if pd.notna(byte_len) else 1
            
            if max_bytes > 2045:
                Data.addVarStrL(col)
            else:
                Data.addVarStr(col, max_bytes)
            Data.store(col, None, series.tolist())
            
        # Numeric variables
        elif pd.api.types.is_numeric_dtype(series):
            series = series.fillna(_STATA_MISSING)
            Data.addVarDouble(col)
            Data.store(col, None, series.tolist())
            
        # Strict Dates and General Strings
        else:
            is_date = False
            try:
                dt_series = pd.to_datetime(series, errors='coerce')
                
                # Count non-blank original strings
                s_str = series.astype(str).str.strip().replace(['', 'nan', 'None', '<NA>', 'NaN'], np.nan)
                non_blank_count = s_str.notna().sum()
                parsed_date_count = dt_series.notna().sum()
                
                # CRITICAL FIX: 100% of non-blank rows MUST parse as dates to be considered a date column
                if parsed_date_count > 0 and parsed_date_count == non_blank_count:
                    is_date = True
            except Exception:
                pass
            
            if is_date:
                stata_dates = (dt_series - _STATA_EPOCH).dt.total_seconds() * 1000
                stata_dates = stata_dates.fillna(_STATA_MISSING)
                Data.addVarDouble(col)
                Data.store(col, None, stata_dates.tolist())
                Data.setVarFormat(col, '%tc')
            else:
                # Fallback to string (Will now properly catch your grade ranges)
                series = series.fillna('').astype(str)
                byte_len = series.str.encode('utf-8').str.len().max()
                max_bytes = max(1, int(byte_len)) if pd.notna(byte_len) else 1
                
                if max_bytes > 2045:
                    Data.addVarStrL(col)
                else:
                    Data.addVarStr(col, max_bytes)
                Data.store(col, None, series.tolist())

        if col in var_labels:
            Data.setVarLabel(col, var_labels[col])

    _log("{txt}Done.", quiet, verbose)
end